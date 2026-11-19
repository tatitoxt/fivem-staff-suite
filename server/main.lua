-- server/main.lua — Adapter FiveM. Conecta el core agnóstico al server.
-- Lite: persistencia JSON standalone. Core: oxmysql. Captura + auditoría + tickets.
local t = StaffSuiteTranslate

local loadmod = StaffSuiteModules.loadmod
local audit  = loadmod('core.audit_chain')
local tickets = loadmod('core.tickets')
local perms  = loadmod('core.permissions')
local bridges = loadmod('server.bridges.init')
local duty   = loadmod('core.duty')
local persist = loadmod('server.persist')
local export = loadmod('server.export')
local capture = loadmod('server.capture')
local ratelimit = loadmod('core.ratelimit')

-- ===== Estado =====
local chain = audit.new()
local store = tickets.new_store()
local pmodel = perms.new()
local dreg = duty.new_registry()
local bans = {}
local pendingBans = {}
local entry_count = 0
local ready = false
local limiter = ratelimit.new()
local verifyCache = {}

-- ===== Persistencia =====
local function snapshot()
  return {
    chain = { entries = chain.entries, head = chain.head },
    tickets = store,
    perms = pmodel,
    duty = dreg,
    bans = bans,
  }
end

local storage = persist.new(Config, function()
  local state = snapshot()
  if next(pendingBans) then
    state.bans = {}
    for id, ban in pairs(bans) do state.bans[id] = ban end
    for id, ban in pairs(pendingBans) do state.bans[id] = ban end
  end
  return state
end)

local function restore(data)
  if not data then return end
  if data.chain then
    chain.entries = data.chain.entries or {}
    -- El head sale de la última entrada: un head ausente o distinto encadenaría lo nuevo a otra rama.
    local last = chain.entries[#chain.entries]
    chain.head = last and last.hash or audit.GENESIS
    local ok, at = audit.verify(chain)
    if not ok then print(t('console_chain_broken', { at = at })) end
  end
  if data.tickets then
    store.next_id = data.tickets.next_id or 1
    for _, ticket in pairs(data.tickets.tickets or {}) do
      store.tickets[ticket.id] = ticket
      store.next_id = math.max(store.next_id, ticket.id + 1)
    end
  end
  if data.perms then pmodel = data.perms end
  if data.duty then dreg = data.duty end
  if data.bans then bans = data.bans end
  entry_count = #chain.entries
end

-- ===== Auditoría =====
local function record(action, actor, target, reason, payload, onSaved)
  local e = audit.append(chain, {
    ts = os.time(), actor = actor or 'system', action = action,
    target = target or '', reason = reason or '',
    payload = payload and json.encode(payload) or '',
  })
  entry_count = entry_count + 1
  if entry_count % Config.Export.anchor_every == 0 then export.anchor(e, Config.Export) end
  storage.save(onSaved)
  return e
end

-- ===== Permisos / rangos =====
local function getPlayer(src)
  return bridges.resolve(src, Config)
end

local function actorId(player, src)
  return player.identifier or ('src:' .. tostring(src))
end

local function getIdentifier(src)
  return actorId(getPlayer(src), src)
end

local function can(player, cap)
  return perms.can(pmodel, player.identifier, player.rank, cap)
end

local function findPlayerByIdentifier(identifier)
  if type(identifier) ~= 'string' or identifier == '' then return nil end
  for _, candidate in ipairs(GetPlayers()) do
    local src = tonumber(candidate)
    local player = getPlayer(src)
    if player.identifier == identifier then return src, player end
  end
end

local function canReceiveTransfer(player)
  return player.identifier ~= nil and can(player, 'report.view') and can(player, 'report.claim')
end

local function transferTargets()
  local targets = {}
  for _, src in ipairs(GetPlayers()) do
    local player = getPlayer(src)
    if canReceiveTransfer(player) then
      targets[#targets + 1] = { name = player.name, identifier = player.identifier }
    end
  end
  return targets
end

local function positiveInteger(value)
  local n = tonumber(value)
  if n and n > 0 and n <= 2147483647 and n % 1 == 0 then return math.tointeger(n) end
end

local function limit(name)
  return Config.Limits and Config.Limits[name]
end

-- Texto de cliente: string, sin caracteres de control (salvo saltos de línea y tabs),
-- recortado y dentro del límite en bytes. Devuelve nil, error si no cumple.
local function cleanText(value, maxBytes)
  if type(value) ~= 'string' then return nil end
  value = value:gsub('[\0-\8\11\12\14-\31\127]', ''):match('^%s*(.-)%s*$')
  if maxBytes and #value > maxBytes then return nil, t('input_too_long', { max = maxBytes }) end
  return value
end

local function verifyCached()
  local n = #chain.entries
  if verifyCache.n ~= n or verifyCache.head ~= chain.head then
    verifyCache = { n = n, head = chain.head, result = { audit.verify(chain) } }
  end
  return verifyCache.result
end

-- Cada evento de red y comando de jugador pasa por acá antes de tocar el estado.
local function allowRate(src, key)
  src = tonumber(src)
  if not src or src <= 0 then return true end
  local rules = Config.RateLimit or {}
  local ok, first = ratelimit.allow(limiter, src, key, rules[key] or rules.default, os.time())
  if not ok and first then TriggerClientEvent('staff_suite:notify', src, t('rate_limited')) end
  return ok
end

local function sendTickets(src, player)
  if can(player, 'report.view') then
    TriggerClientEvent('staff_suite:state', src, { tickets = store.tickets })
  end
end

-- ===== Moderación (wrappers server-authoritative) =====
local function banMessage(ban)
  if ban.expires_at == 0 then return t('ban_permanent', { reason = ban.reason }) end
  return t('ban_expires', { reason = ban.reason, date = os.date('!%Y-%m-%d %H:%M UTC', ban.expires_at) })
end

local function afterSanction(ctx, fn)
  return function(ok)
    if not ok then
      if getIdentifier(ctx.src) == ctx.actor then
        TriggerClientEvent('staff_suite:notify', ctx.src, t('mod_save_failed'))
      end
      return
    end
    if GetPlayerName(ctx.tgt) and getIdentifier(ctx.tgt) == ctx.target then fn() end
  end
end

local modActions = {
  ['goto'] = { run = function(m)
    TriggerClientEvent('staff_suite:tp', m.src, GetEntityCoords(GetPlayerPed(m.tgt)))
  end },
  bring = { protected = true, run = function(m)
    TriggerClientEvent('staff_suite:tp', m.tgt, GetEntityCoords(GetPlayerPed(m.src)))
  end },
  freeze = { protected = true, run = function(m) FreezeEntityPosition(GetPlayerPed(m.tgt), true) end },
  heal = { run = function(m) SetEntityHealth(GetPlayerPed(m.tgt), 200) end },
  kick = { protected = true, reason = 'configured', run = function(m) DropPlayer(m.tgt, m.reason or t('kick_default_reason')) end },
  revive = { run = function(m)
    if not bridges.revive(m.tgt, Config) then return false, t('mod_unavailable') end
  end },
  spectate = { run = function(m)
    local ped = GetPlayerPed(m.tgt)
    if m.src == m.tgt or ped == 0 or GetPlayerRoutingBucket(m.src) ~= GetPlayerRoutingBucket(m.tgt) then
      return false, t('spectate_unavailable')
    end
    TriggerClientEvent('staff_suite:spectate', m.src, m.tgt, GetEntityCoords(ped))
  end },
  warn = { protected = true, reason = true, run = function(m)
    m.onSaved = afterSanction(m, function()
      TriggerClientEvent('staff_suite:notify', m.tgt, t('warn_received', { reason = m.reason }))
    end)
  end },
  ban = { protected = true, reason = true, run = function(m)
    local identifiers = bridges.ban_identifiers(m.tgt, Config)
    local identifier = identifiers[1]
    if not identifier then return false, t('mod_invalid_target') end
    for _, id in ipairs(identifiers) do
      if pendingBans[id] then return false, t('ban_pending') end
    end
    local seconds = m.duration
    if seconds == nil then seconds = Config.Moderation.ban_duration or 86400 end
    if seconds ~= 0 and (type(seconds) ~= 'number' or not positiveInteger(seconds) or seconds > 31536000) then
      return false, t('ban_invalid_duration')
    end
    local now = os.time()
    local ban = { actor = m.actor, reason = m.reason, created_at = now, expires_at = seconds == 0 and 0 or now + seconds }
    for _, id in ipairs(identifiers) do pendingBans[id] = ban end
    m.payload.expires_at = ban.expires_at
    m.payload.identifier = identifier
    m.payload.identifiers = identifiers
    local notify = afterSanction(m, function() DropPlayer(m.tgt, banMessage(ban)) end)
    m.onSaved = function(ok)
      for _, id in ipairs(identifiers) do
        pendingBans[id] = nil
        if ok then bans[id] = ban end
      end
      if not ok then record('mod_ban_failed', m.actor, m.target, m.reason, m.payload) end
      notify(ok)
    end
  end },
}

local function doMod(src, action, tgt, reason, duration)
  if type(action) ~= 'string' then return false, t('mod_unavailable') end
  local player = getPlayer(src)
  if not can(player, 'mod.' .. action) then return false, t('no_permission') end

  local spec = modActions[action]
  if not spec then return false, t('mod_unavailable') end
  tgt = positiveInteger(tgt) or findPlayerByIdentifier(tgt)
  if not tgt or not GetPlayerName(tgt) then
    return false, t('mod_invalid_target')
  end
  if spec.protected and tonumber(src) ~= tgt and perms.outranks(getPlayer(tgt).rank, player.rank) then
    return false, t('mod_target_protected')
  end
  local reasonErr
  reason, reasonErr = cleanText(reason, limit('reason'))
  if reasonErr then return false, reasonErr end
  if reason == '' then reason = nil end
  if not reason and (spec.reason == true or spec.reason == 'configured' and Config.Moderation.require_reason) then
    return false, t('reason_required')
  end
  local ctx = { src = tonumber(src), tgt = tgt, actor = actorId(player, src), target = getIdentifier(tgt),
    reason = reason, duration = duration, payload = { action = action } }
  local ok, err = spec.run(ctx)
  if ok == false then return false, err end
  record('mod_' .. action, ctx.actor, ctx.target, reason, ctx.payload, ctx.onSaved)
  return true
end

AddEventHandler('playerConnecting', function(_, setKickReason)
  if not ready then
    setKickReason(t('persistence_starting'))
    CancelEvent()
    return
  end
  local now = os.time()
  local identifiers = bridges.ban_identifiers(source, Config)
  for _, identifier in ipairs(identifiers) do
    local ban = bans[identifier]
    if ban and (ban.expires_at == 0 or ban.expires_at > now) then
      setKickReason(banMessage(ban))
      CancelEvent()
      -- Evasión con cuentas nuevas: el ban se extiende a los identificadores que no tenía.
      local added = {}
      for _, id in ipairs(identifiers) do
        if not bans[id] then bans[id] = ban; added[#added + 1] = id end
      end
      if #added > 0 then
        record('mod_ban_extended', 'system', identifier, ban.reason, { identifiers = added, expires_at = ban.expires_at })
      end
      return
    end
  end
end)

-- ===== Comandos =====
local function configuredValue(values, requested, default)
  for _, value in ipairs(values) do
    if value == requested then return value end
  end
  return default
end

local function openTickets(reporter)
  local n = 0
  for _, ticket in pairs(store.tickets) do
    if ticket.reporter == reporter and ticket.state ~= 'resolved' and ticket.state ~= 'closed' then n = n + 1 end
  end
  return n
end

local function createReport(src, category, priority, body)
  if not positiveInteger(src) then return end
  local err
  body, err = cleanText(body, limit('ticket_body'))
  if err then TriggerClientEvent('staff_suite:notify', src, err); return end
  if not body or body == '' then return end
  category = configuredValue(Config.Categories, category, 'other')
  priority = configuredValue(Config.Priorities, priority, 'normal')
  local player = getPlayer(src)
  local maxOpen = limit('open_tickets_per_player')
  if maxOpen and openTickets(actorId(player, src)) >= maxOpen then
    TriggerClientEvent('staff_suite:notify', src, t('report_too_many_open', { max = maxOpen }))
    return
  end
  local ticket, ev = tickets.create(store, {
    reporter = actorId(player, src), category = category, priority = priority,
    description = body, ts = os.time(),
  })
  record(ev.action, ev.actor, ev.target, '', { ticket = ticket.id, category = category, priority = priority })
  TriggerClientEvent('staff_suite:notify', src, t('report_created', { id = ticket.id }))
  sendTickets(src, player)
end

local function command(name, fn, rateKey)
  RegisterCommand(name, function(src, ...)
    if not allowRate(src, rateKey or ('command:' .. name)) then return end
    if ready then return fn(src, ...) end
    if src ~= 0 then TriggerClientEvent('staff_suite:notify', src, t('persistence_starting')) end
  end, false)
end

command(Config.Commands.report, function(src, args)
  createReport(src, args[1], nil, table.concat(args, ' ', 2))
end, 'staff_suite:ticketCreate')

command(Config.Commands.duty, function(src)
  if src == 0 then return end
  local player = getPlayer(src)
  if not can(player, 'staff.duty') then TriggerClientEvent('staff_suite:notify', src, t('no_permission')); return end
  local id = actorId(player, src)
  local s = dreg.staff[id]
  local ev
  if s and s.on_duty then ev = duty.clock_out(dreg, id, os.time()); TriggerClientEvent('staff_suite:notify', src, t('duty_out', { time = string.format('%.1fh', (ev.seconds or 0) / 3600) }))
  else ev = duty.clock_in(dreg, id, os.time()); TriggerClientEvent('staff_suite:notify', src, t('duty_in')) end
  if ev then record(ev.event, id, id, '', {}) end
end, 'staff_suite:duty')

command(Config.Commands.audit, function(src)
  if src == 0 then
    local ok, at = audit.verify(chain)
    print(ok and t('console_audit_ok', { n = #chain.entries }) or t('console_audit_broken', { seq = at }))
    return
  end
  if not can(getPlayer(src), 'audit.view') then TriggerClientEvent('staff_suite:notify', src, t('no_permission')); return end
  local ok, at = audit.verify(chain)
  TriggerClientEvent('staff_suite:auditResult', src, { ok = ok, at = at, n = #chain.entries })
end)

-- ===== NUI / eventos de panel =====
local function net(name, fn)
  RegisterNetEvent(name, function(...)
    if not allowRate(source, name) then return end
    if ready then return fn(...) end
    TriggerClientEvent('staff_suite:notify', source, t('persistence_starting'))
  end)
end

net('staff_suite:ticketCreate', function(category, priority, body)
  createReport(source, category, priority, body)
end)

net('staff_suite:getState', function()
  local src = source
  local player = getPlayer(src)
  local capabilities = {}
  for _, cap in ipairs(perms.CAPS) do
    local available = cap:sub(1, 4) ~= 'mod.' or modActions[cap:sub(5)]
    if available and can(player, cap) then capabilities[#capabilities + 1] = cap end
  end
  local rank = player.rank or 'player'
  local canViewAudit = can(player, 'audit.view')
  local canViewAnalytics = can(player, 'staff.analytics')
  local now = os.time()
  local verify = canViewAudit and verifyCached() or {}
  local alerts = {}
  if canViewAnalytics and verify[1] == false then
    alerts[1] = {
      id = 'audit-chain:' .. verify[2], kind = 'audit_chain_broken', severity = 'high',
      actor = 'system', ts = now, vars = { seq = verify[2] },
    }
  end
  local shift = dreg.staff[actorId(player, src)]
  local exportConfig = Config.Export
  TriggerClientEvent('staff_suite:state', src, {
    tickets = can(player, 'report.view') and store.tickets or {},
    transferTargets = can(player, 'report.resolve') and transferTargets() or {},
    exportStatus = {
      webhook = type(exportConfig.webhook) == 'string' and exportConfig.webhook ~= '',
      file = exportConfig.file == true,
    },
    audit = canViewAudit and chain.entries or {},
    duty = canViewAnalytics and duty.snapshot(dreg, now) or {},
    dutySelf = { on_duty = can(player, 'staff.duty') and shift ~= nil and shift.on_duty == true },
    verify = verify,
    alerts = alerts,
    player = { name = player.name, rank = rank, identifier = player.identifier or '', capabilities = capabilities },
    rank = rank, locale = Config.Locale,
  })
end)

local ticketActionCaps = {
  claim = 'report.claim', start = 'report.claim', unclaim = 'report.claim',
  transfer = 'report.resolve', resolve = 'report.resolve', close = 'report.resolve', reopen = 'report.resolve',
}

net('staff_suite:ticketAction', function(id, action, extra)
  local src = source
  local player = getPlayer(src)
  local cap = ticketActionCaps[action]
  if not cap or not can(player, cap) then return end
  id = positiveInteger(id)
  if not id then return end
  extra = type(extra) == 'table' and extra or {}
  local actor = actorId(player, src)
  local current = store.tickets[id]
  if (action == 'start' or action == 'unclaim') and current and current.claimer ~= actor
    and not can(player, 'report.resolve') then
    TriggerClientEvent('staff_suite:notify', src, t('already_claimed'))
    return
  end
  local reason, reasonErr = cleanText(extra.reason, limit('reason'))
  local resolution, resolutionErr = cleanText(extra.resolution, limit('message_body'))
  if reasonErr or resolutionErr then
    TriggerClientEvent('staff_suite:notify', src, reasonErr or resolutionErr)
    return
  end
  local recipientSrc, recipient
  if action == 'transfer' then
    recipientSrc, recipient = findPlayerByIdentifier(extra.to)
    if not recipient or not canReceiveTransfer(recipient) then
      TriggerClientEvent('staff_suite:notify', src, t('ticket_invalid_recipient'))
      return
    end
  end
  local ticket, ev = tickets.transition(store, id, action, actor, {
    ts = os.time(),
    reason = reason ~= '' and reason or nil,
    resolution = resolution,
    to = extra.to,
  })
  if not ticket then
    TriggerClientEvent('staff_suite:notify', src, t(ev:match('^[^:]+') or 'invalid_transition'))
    return
  end
  if action == 'resolve' then duty.record_resolved(dreg, ev.actor) end
  record(ev.action, ev.actor, 'ticket:' .. id, ev.reason, { from = ev.from, to = ev.to, assigned_to = ev.assigned_to })
  sendTickets(src, player)
  if recipientSrc and recipientSrc ~= tonumber(src) then sendTickets(recipientSrc, recipient) end
end)

net('staff_suite:ticketMessage', function(id, body, internal)
  local src = source
  id = positiveInteger(id)
  local err
  body, err = cleanText(body, limit('message_body'))
  if err then TriggerClientEvent('staff_suite:notify', src, err); return end
  if not id or not body or body == '' then return end
  if internal ~= nil and type(internal) ~= 'boolean' then return end
  local player = getPlayer(src)
  if not can(player, 'report.message') or not can(player, 'report.view') then
    TriggerClientEvent('staff_suite:notify', src, t('no_permission'))
    return
  end
  local ticket = store.tickets[id]
  if not ticket or ticket.state == 'closed' then return end

  local _, ev = tickets.add_message(store, id, actorId(player, src), body, internal, os.time())
  record(ev.action, ev.actor, 'ticket:' .. id, '', { ticket = id, internal = ev.internal, message = #ticket.messages })
  sendTickets(src, player)
  local claimerSrc, claimer = findPlayerByIdentifier(ticket.claimer)
  if claimerSrc and claimerSrc ~= tonumber(src) then sendTickets(claimerSrc, claimer) end
end)

net('staff_suite:modAction', function(action, tgt, reason, duration)
  local src = source
  local ok, err = doMod(src, action, tgt, reason, duration)
  if not ok then TriggerClientEvent('staff_suite:notify', src, err) end
end)

net('staff_suite:verify', function()
  local src = source
  local player = getPlayer(src)
  if not can(player, 'audit.verify') then return end
  local ok, at = audit.verify(chain)
  record('audit_verify', actorId(player, src), '', ok and 'ok' or ('broken:' .. tostring(at)), {})
  TriggerClientEvent('staff_suite:auditResult', src, { ok = ok, at = at, n = #chain.entries })
end)

-- ===== Exports (para test resource E2E + otros recursos) =====
local function expose(name, fn)
  exports(name, function(...)
    if ready then return fn(...) end
    return nil, 'persistence_starting'
  end)
end

local function idText(value)
  if type(value) == 'number' then value = tostring(value) end
  if type(value) ~= 'string' or value == '' or #value > 128 then return nil end
  return value
end

local function exportText(value, maxBytes)
  if value == nil then return '' end
  return cleanText(value, maxBytes)
end

-- Otros recursos del servidor pueden integrarse, pero con los mismos tipos y límites que la red.
expose('Record', function(action, actor, target, reason, payload)
  action, actor = idText(action), idText(actor)
  target, reason = exportText(target, 128), exportText(reason, limit('reason'))
  if not action or not actor or not target or not reason then return nil, 'invalid_input' end
  if payload ~= nil and type(payload) ~= 'table' then return nil, 'invalid_input' end
  return record(action, actor, target, reason, payload or {})
end)
expose('Verify', function() return table.unpack(verifyCached()) end)
expose('GetChain', function() return chain.entries end)
expose('CreateTicket', function(data)
  if type(data) ~= 'table' then return nil, 'invalid_input' end
  local reporter = idText(data.reporter)
  local description = exportText(data.description, limit('ticket_body'))
  if not reporter or not description then return nil, 'invalid_input' end
  local tk, ev = tickets.create(store, {
    ts = os.time(),
    reporter = reporter,
    reporter_name = exportText(data.reporter_name, 64) or reporter,
    category = configuredValue(Config.Categories, data.category, 'other'),
    priority = configuredValue(Config.Priorities, data.priority, 'normal'),
    description = description,
  })
  if not tk then return nil, ev end
  record(ev.action, ev.actor, ev.target, '', { ticket = tk.id })
  return tk.id
end)
expose('TicketAction', function(id, action, actor, extra)
  id, actor = positiveInteger(id), idText(actor)
  if not id or type(action) ~= 'string' or not actor then return nil, 'invalid_input' end
  extra = type(extra) == 'table' and extra or {}
  local reason = exportText(extra.reason, limit('reason'))
  local resolution = exportText(extra.resolution, limit('message_body'))
  if not reason or not resolution then return nil, 'invalid_input' end
  local ticket, ev = tickets.transition(store, id, action, actor, {
    ts = os.time(),
    reason = reason ~= '' and reason or nil,
    resolution = resolution ~= '' and resolution or nil,
    to = idText(extra.to),
    rating = extra.rating,
  })
  if ticket and ev then
    if action == 'resolve' then duty.record_resolved(dreg, ev.actor) end
    record(ev.action, ev.actor, 'ticket:' .. id, ev.reason, { from = ev.from, to = ev.to, assigned_to = ev.assigned_to })
  end
  return ticket, ev
end)
expose('GetState', snapshot)
expose('SetDuty', function(actor, onDuty)
  actor = idText(actor)
  if not actor or type(onDuty) ~= 'boolean' then return nil, 'invalid_input' end
  local ev, err
  if onDuty then ev, err = duty.clock_in(dreg, actor, os.time()) else ev, err = duty.clock_out(dreg, actor, os.time()) end
  if ev then record(ev.event, actor, actor, '', {}) end
  return ev, err
end)

-- ===== Init =====
CreateThread(function()
  storage.load(function(data, backend)
    restore(data)
    ready = true
    capture.install(Config, bridges.select, getIdentifier, record)
    print(t('console_started', { n = #chain.entries, persistence = backend, framework = bridges.select(Config) }))
  end)
end)

AddEventHandler('playerDropped', function()
  ratelimit.forget(limiter, tonumber(source))
end)

-- Los lotes pendientes se respaldan antes de apagar el recurso.
AddEventHandler('onResourceStop', function(res)
  if ready and res == GetCurrentResourceName() then storage.stop() end
end)
