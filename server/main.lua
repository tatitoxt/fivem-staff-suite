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
local sha256 = loadmod('core.sha256')
local capture = loadmod('server.capture')

-- ===== Estado =====
local chain = audit.new()
local store = tickets.new_store()
local pmodel = perms.new()
local dreg = duty.new_registry()
local bans = {}
local pendingBans = {}
local entry_count = 0
local ready = false

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
  if data.chain then chain.entries = data.chain.entries or {}; chain.head = data.chain.head or audit.GENESIS end
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
  if n and n > 0 and n % 1 == 0 then return n end
end

local function sendTickets(src, player)
  if can(player, 'report.view') then
    TriggerClientEvent('staff_suite:state', src, { tickets = store.tickets })
  end
end

-- ===== Tickets: analytics, rating y evidencia =====
local function afterTransition(ticket, ev)
  if not ticket or not ev or ev.action ~= 'ticket_resolve' then return end
  local now = os.time()
  local created = ticket.created_ts or now
  duty.record_resolved(dreg, ev.actor, math.max(0, (ticket.first_response_ts or now) - created))
  local reporterSrc = findPlayerByIdentifier(ticket.reporter)
  if reporterSrc and not ticket.rating then
    TriggerClientEvent('staff_suite:ratePrompt', reporterSrc, { id = ticket.id })
  end
end

local function evidenceAvailable()
  return GetResourceState('screenshot-basic') == 'started'
end

local function evidenceFile(id, n)
  return ('staff_suite_evidence_%d_%d.txt'):format(id, n)
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
  bring = { run = function(m)
    TriggerClientEvent('staff_suite:tp', m.tgt, GetEntityCoords(GetPlayerPed(m.src)))
  end },
  freeze = { run = function(m) FreezeEntityPosition(GetPlayerPed(m.tgt), true) end },
  heal = { run = function(m) SetEntityHealth(GetPlayerPed(m.tgt), 200) end },
  kick = { reason = 'configured', run = function(m) DropPlayer(m.tgt, m.reason or t('kick_default_reason')) end },
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
  warn = { reason = true, run = function(m)
    m.onSaved = afterSanction(m, function()
      TriggerClientEvent('staff_suite:notify', m.tgt, t('warn_received', { reason = m.reason }))
    end)
  end },
  ban = { reason = true, run = function(m)
    local identifier = bridges.ban_identifiers(m.tgt)[1]
    if not identifier then return false, t('mod_invalid_target') end
    if pendingBans[identifier] then return false, t('ban_pending') end
    local seconds = m.duration
    if seconds == nil then seconds = Config.Moderation.ban_duration or 86400 end
    if seconds ~= 0 and (type(seconds) ~= 'number' or not positiveInteger(seconds) or seconds > 31536000) then
      return false, t('ban_invalid_duration')
    end
    local now = os.time()
    local ban = { actor = m.actor, reason = m.reason, created_at = now, expires_at = seconds == 0 and 0 or now + seconds }
    pendingBans[identifier] = ban
    m.payload.expires_at = ban.expires_at
    m.payload.identifier = identifier
    local notify = afterSanction(m, function() DropPlayer(m.tgt, banMessage(ban)) end)
    m.onSaved = function(ok)
      pendingBans[identifier] = nil
      if ok then
        bans[identifier] = ban
      else
        record('mod_ban_failed', m.actor, m.target, m.reason, m.payload)
      end
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
  reason = type(reason) == 'string' and reason:match('^%s*(.-)%s*$') or nil
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
  for _, identifier in ipairs(bridges.ban_identifiers(source)) do
    local ban = bans[identifier]
    if ban and (ban.expires_at == 0 or ban.expires_at > now) then
      setKickReason(banMessage(ban))
      CancelEvent()
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

local function createReport(src, category, priority, body)
  if not positiveInteger(src) or type(body) ~= 'string' then return end
  category = configuredValue(Config.Categories, category, 'other')
  priority = configuredValue(Config.Priorities, priority, 'normal')
  local player = getPlayer(src)
  local ticket, ev = tickets.create(store, {
    reporter = actorId(player, src), category = category, priority = priority,
    description = body, ts = os.time(),
  })
  record(ev.action, ev.actor, ev.target, '', { ticket = ticket.id, category = category, priority = priority })
  TriggerClientEvent('staff_suite:notify', src, t('report_created', { id = ticket.id }))
  sendTickets(src, player)
end

local function command(name, fn)
  RegisterCommand(name, function(src, ...)
    if ready then return fn(src, ...) end
    if src ~= 0 then TriggerClientEvent('staff_suite:notify', src, t('persistence_starting')) end
  end, false)
end

command(Config.Commands.report, function(src, args)
  createReport(src, args[1], nil, table.concat(args, ' ', 2))
end)

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
end)

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
    if ready then return fn(...) end
    TriggerClientEvent('staff_suite:notify', source, t('persistence_starting'))
  end)
end

net('staff_suite:ticketCreate', function(category, priority, body)
  if type(body) ~= 'string' or not body:match('%S') then return end
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
  local verify = canViewAudit and { audit.verify(chain) } or {}
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
      anchor_every = exportConfig.anchor_every,
    },
    audit = canViewAudit and chain.entries or {},
    duty = canViewAnalytics and duty.snapshot(dreg, now) or {},
    dutySelf = { on_duty = can(player, 'staff.duty') and shift ~= nil and shift.on_duty == true },
    verify = verify,
    alerts = alerts,
    evidenceEnabled = evidenceAvailable(),
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
  local recipientSrc, recipient
  if action == 'transfer' then
    recipientSrc, recipient = findPlayerByIdentifier(extra.to)
    if not recipient or not canReceiveTransfer(recipient) then
      TriggerClientEvent('staff_suite:notify', src, t('ticket_invalid_recipient'))
      return
    end
  end
  local ticket, ev = tickets.transition(store, id, action, actorId(player, src), {
    ts = os.time(),
    reason = type(extra.reason) == 'string' and extra.reason or nil,
    resolution = type(extra.resolution) == 'string' and extra.resolution or nil,
    to = extra.to,
  })
  if not ticket then
    TriggerClientEvent('staff_suite:notify', src, t(ev:match('^[^:]+') or 'invalid_transition'))
    return
  end
  afterTransition(ticket, ev)
  record(ev.action, ev.actor, 'ticket:' .. id, ev.reason, { from = ev.from, to = ev.to, assigned_to = ev.assigned_to })
  sendTickets(src, player)
  if recipientSrc and recipientSrc ~= tonumber(src) then sendTickets(recipientSrc, recipient) end
end)

net('staff_suite:ticketMessage', function(id, body, internal)
  local src = source
  id = positiveInteger(id)
  if not id or type(body) ~= 'string' or not body:match('%S') then return end
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

net('staff_suite:ticketRate', function(id, score)
  local src = source
  id, score = positiveInteger(id), positiveInteger(score)
  if not id or not score then return end
  local player = getPlayer(src)
  local ticket, ev = tickets.rate(store, id, actorId(player, src), score, os.time())
  if not ticket then
    TriggerClientEvent('staff_suite:notify', src, t(ev))
    return
  end
  local staff = ticket.resolved_by or ticket.claimer
  if staff then duty.record_rating(dreg, staff, score) end
  record(ev.action, ev.actor, 'ticket:' .. id, '', { score = score, staff = staff })
  TriggerClientEvent('staff_suite:notify', src, t('rating_thanks'))
end)

net('staff_suite:ticketEvidence', function(id)
  local src = source
  local player = getPlayer(src)
  id = positiveInteger(id)
  local ticket = id and store.tickets[id]
  if not ticket or not can(player, 'report.claim') then return end
  if not evidenceAvailable() then
    TriggerClientEvent('staff_suite:notify', src, t('evidence_unavailable'))
    return
  end
  local targetSrc = findPlayerByIdentifier(ticket.reporter)
  if not targetSrc then
    TriggerClientEvent('staff_suite:notify', src, t('evidence_offline'))
    return
  end
  local by = actorId(player, src)
  exports['screenshot-basic']:requestClientScreenshot(targetSrc, { encoding = 'jpg', quality = 0.6 }, function(err, data)
    if err or type(data) ~= 'string' or data == '' then
      TriggerClientEvent('staff_suite:notify', src, t('evidence_failed'))
      return
    end
    ticket.evidence = ticket.evidence or {}
    local n = #ticket.evidence + 1
    if not SaveResourceFile(GetCurrentResourceName(), evidenceFile(id, n), data, -1) then
      TriggerClientEvent('staff_suite:notify', src, t('evidence_failed'))
      return
    end
    local item = { n = n, ts = os.time(), by = by, sha256 = sha256.hex(data), size = #data, audit_seq = #chain.entries + 1 }
    ticket.evidence[n] = item
    record('ticket_evidence', by, 'ticket:' .. id, '', { n = n, sha256 = item.sha256, size = item.size })
    TriggerClientEvent('staff_suite:notify', src, t('evidence_saved', { n = n }))
    sendTickets(src, player)
  end)
end)

net('staff_suite:evidenceGet', function(id, n)
  local src = source
  id, n = positiveInteger(id), positiveInteger(n)
  local ticket = id and store.tickets[id]
  local item = ticket and n and ticket.evidence and ticket.evidence[n]
  if not item or not can(getPlayer(src), 'report.view') then return end
  local data = LoadResourceFile(GetCurrentResourceName(), evidenceFile(id, n))
  if not data then
    TriggerClientEvent('staff_suite:notify', src, t('evidence_failed'))
    return
  end
  -- Se verifica contra la entrada de auditoría (protegida por la cadena), no contra el ticket.
  local entry = item.audit_seq and chain.entries[item.audit_seq]
  local hash = sha256.hex(data)
  local ok = entry ~= nil and entry.action == 'ticket_evidence' and entry.target == 'ticket:' .. id
    and type(entry.payload) == 'string' and entry.payload:find(hash, 1, true) ~= nil
  if ok then
    local chainOk, brokenAt = audit.verify(chain)
    ok = chainOk or (brokenAt ~= nil and brokenAt > item.audit_seq)
  end
  TriggerLatentClientEvent('staff_suite:evidence', src, 250000, { id = id, n = n, data = data, ok = ok })
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
-- Contrato: éxito devuelve el valor; error devuelve false, código. Nunca un nil inicial:
-- msgpack corta los valores que siguen a un nil en llamadas cross-resource.
local function expose(name, fn)
  exports(name, function(...)
    if ready then return fn(...) end
    return false, 'persistence_starting'
  end)
end

expose('Record', function(action, actor, target, reason, payload) return record(action, actor, target, reason, payload) end)
expose('Verify', function() return audit.verify(chain) end)
expose('GetChain', function() return chain.entries end)
expose('CreateTicket', function(data)
  local tk, ev = tickets.create(store, data)
  record(ev.action, ev.actor, ev.target, '', { ticket = tk.id })
  return tk.id
end)
expose('TicketAction', function(id, action, actor, extra)
  local ticket, ev = tickets.transition(store, id, action, actor, extra)
  if ticket and ev then
    afterTransition(ticket, ev)
    record(ev.action, ev.actor, 'ticket:' .. id, ev.reason, { from = ev.from, to = ev.to, assigned_to = ev.assigned_to })
  end
  if not ticket then return false, ev end
  return ticket, ev
end)
expose('GetState', snapshot)
expose('SetDuty', function(actor, onDuty)
  local ev, err
  if onDuty then ev, err = duty.clock_in(dreg, actor, os.time()) else ev, err = duty.clock_out(dreg, actor, os.time()) end
  if not ev then return false, err end
  record(ev.event, actor, actor, '', {})
  return ev
end)
expose('Flush', function() return storage.flush() end)
expose('GetPersistence', function() return storage.status() end)

-- ===== Init =====
CreateThread(function()
  storage.load(function(data, backend)
    restore(data)
    ready = true
    capture.install(Config, bridges.select, getIdentifier, record)
    print(t('console_started', { n = #chain.entries, persistence = backend, framework = bridges.select(Config) }))
  end)
end)

-- Los lotes pendientes se respaldan antes de apagar el recurso.
AddEventHandler('onResourceStop', function(res)
  if ready and res == GetCurrentResourceName() then storage.stop() end
end)
