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
local ratelimit = loadmod('core.ratelimit')

-- ===== Estado =====
local chain = audit.new()
local store = tickets.new_store()
local pmodel = perms.new()
local dreg = duty.new_registry()
local bans = {}
local revokedBans = {}
local pendingBans = {}
local pendingRevocations = {}
local pendingExports = {}
local entry_count = 0
local ready = false
local limiter = ratelimit.new()
local verifyCache = {}
local waypointRequests = {}
local spectators, pendingSpectators, spectateSequence = {}, {}, 0
local onlineRefs, onlineViewedAt, onlineRefSeq = {}, {}, 0
local profileHistory = {}
local profileAuditIntact = true
local playtime, activePlaytime, playtimeSources = {}, {}, {}
local profileKinds = { mod_warn = 'warns', mod_ban = 'bans', mod_ban_failed = 'bans',
  player_profile_note = 'notes' }

local function indexProfileEntry(entry)
  local kind = profileKinds[entry.action]
  if not kind then return end
  local profile = profileHistory[entry.target]
  if not profile then
    profile = { warns = {}, bans = {}, notes = {} }
    profileHistory[entry.target] = profile
  end
  local rows = profile[kind]
  local position = 1
  while rows[position] and rows[position].seq > entry.seq do position = position + 1 end
  if position > 20 then return end
  table.insert(rows, position, { seq = entry.seq, ts = entry.ts, actor = entry.actor, text = entry.reason,
    failed = entry.action == 'mod_ban_failed' or nil })
  rows[21] = nil
end
local rule = type(Config.WarnEscalation) == 'table' and Config.WarnEscalation or {}
local escalate = rule.enabled == true and math.type(rule.threshold) == 'integer'
  and rule.threshold >= 2 and rule.threshold <= 100
  and math.type(rule.window_seconds) == 'integer' and rule.window_seconds >= 60 and rule.window_seconds <= 2592000
local warnings, escalations, pendingEscalations = {}, {}, {}

local function indexWarning(target, ts, now)
  local history = warnings[target] or {}
  warnings[target] = history
  history[#history + 1] = ts
  while history[1] and (#history > rule.threshold or history[1] <= now - rule.window_seconds) do
    table.remove(history, 1)
  end
  return #history
end

local function restoreEscalation(now)
  local cutoff, failures = now - rule.window_seconds, {}
  for _, e in ipairs(chain.entries) do
    if e.ts > cutoff and (e.action == 'mod_warn_failed' or e.action == 'mod_warn_escalation_failed') then
      failures[tonumber(e.reason) or 0] = true
    end
  end
  for _, e in ipairs(chain.entries) do
    if e.ts > cutoff and not failures[e.seq] then
      if e.action == 'mod_warn' then indexWarning(e.target, e.ts, now) end
      if e.action == 'mod_warn_escalation' then escalations[e.target] = e.ts end
    end
  end
end

-- ===== Persistencia =====
local function snapshot()
  return {
    chain = { entries = chain.entries, head = chain.head },
    tickets = store,
    perms = pmodel,
    duty = dreg,
    bans = bans,
    playtime = playtime,
  }
end

local storage = persist.new(Config, function()
  local state = snapshot()
  if next(pendingBans) or next(pendingRevocations) then
    state.bans = {}
    for id, ban in pairs(bans) do state.bans[id] = ban end
    for id, ban in pairs(pendingBans) do state.bans[id] = ban end
    for id, ban in pairs(pendingRevocations) do state.bans[id] = ban end
  end
  return state
end)

-- Los bans anteriores a la migración se agrupan por la entrada original, incluidos
-- aliases añadidos al reconectar. Sin procedencia verificable quedan solo para lectura.
local function recoverBanIds()
  local byAlias, previous = {}, {}
  for _, entry in ipairs(chain.entries) do
    local action = entry.action
    if action == 'mod_ban' or action == 'mod_ban_failed' or action == 'mod_ban_extended' then
      local ok, payload = pcall(json.decode, entry.payload)
      if ok and type(payload) == 'table' and type(payload.identifiers) == 'table' then
        if action == 'mod_ban' then
          previous[entry.seq] = {}
          for _, id in ipairs(payload.identifiers) do
            previous[entry.seq][id] = byAlias[id]
            byAlias[id] = { entry = entry, expires_at = payload.expires_at }
          end
        elseif action == 'mod_ban_extended' then
          local original = byAlias[entry.target]
          for _, id in ipairs(payload.identifiers) do byAlias[id] = original end
        else
          for _, id in ipairs(payload.identifiers) do
            local current = byAlias[id]
            if current and current.entry.target == entry.target and current.entry.actor == entry.actor then
              byAlias[id] = previous[current.entry.seq][id]
            end
          end
        end
      end
    end
  end
  for id, ban in pairs(bans) do
    local known = byAlias[id]
    if not ban.id and known and type(ban.created_at) == 'number'
        and known.entry.actor == ban.actor and known.entry.reason == ban.reason
        and known.expires_at == ban.expires_at and math.abs(known.entry.ts - ban.created_at) <= 1 then
      ban.id = known.entry.seq
    end
  end
end

local function recoverRevokedBans()
  local requests = {}
  for _, entry in ipairs(chain.entries) do
    if entry.action == 'mod_unban' or entry.action == 'mod_unban_failed' then
      local ok, payload = pcall(json.decode, entry.payload)
      if ok and type(payload) == 'table' then
        if entry.action == 'mod_unban' and type(payload.review) == 'table' and type(payload.review.id) == 'number' then
          requests[entry.seq] = payload.review
        elseif entry.action == 'mod_unban_failed' and type(payload.request_seq) == 'number' then
          requests[payload.request_seq] = nil
        end
      end
    end
  end
  for _, row in pairs(requests) do revokedBans[row.id] = row end
end

local function restore(data)
  if not data then return end
  local validChain = false
  if data.chain then
    chain.entries = data.chain.entries or {}
    -- El head sale de la última entrada: un head ausente o distinto encadenaría lo nuevo a otra rama.
    local last = chain.entries[#chain.entries]
    chain.head = type(last) == 'table' and type(last.hash) == 'string' and last.hash or audit.GENESIS
    local verified, ok, at = pcall(audit.verify, chain)
    validChain = verified and ok
    profileAuditIntact = validChain
    if profileAuditIntact then
      local failedNotes = {}
      for _, entry in ipairs(chain.entries) do
        if entry.action == 'player_profile_note_failed' then
          local seq = tonumber(entry.reason)
          if seq then failedNotes[seq] = true end
        end
      end
      for _, entry in ipairs(chain.entries) do
        if entry.action ~= 'player_profile_note' or not failedNotes[entry.seq] then indexProfileEntry(entry) end
      end
    else
      print(t('console_chain_broken', { at = at or '?' }))
    end
    if escalate then
      escalate = validChain
      if escalate then restoreEscalation(os.time()) end
    end
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
  if data.bans then
    bans = data.bans
    if validChain then
      recoverBanIds()
      recoverRevokedBans()
    end
  end
  if data.playtime then playtime = data.playtime end
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
  local retryCallback
  if action == 'player_profile_note' then
    local reply = onSaved
    retryCallback = reply == nil
    onSaved = function(saved)
      if saved and profileAuditIntact then
        indexProfileEntry(e)
      elseif not saved and reply then
        record('player_profile_note_failed', e.actor, e.target, tostring(e.seq))
      end
      if reply then reply(saved) end
    end
  elseif profileAuditIntact then
    indexProfileEntry(e)
  end
  if entry_count % Config.Export.anchor_every == 0 then export.anchor(e, Config.Export) end
  storage.save(onSaved, retryCallback)
  return e
end

-- ===== Permisos / rangos =====
local function getPlayer(src)
  return bridges.resolve(src, Config)
end

local function accountPlaytime(identifier, session, now)
  if now <= session.since then return false end
  playtime[identifier] = (playtime[identifier] or 0) + now - session.since
  session.since = now
  return true
end

local function stopPlaytime(src)
  local identifier = playtimeSources[src]
  if not identifier then return end
  playtimeSources[src] = nil
  local session = activePlaytime[identifier]
  session.connections = session.connections - 1
  if session.connections == 0 then
    activePlaytime[identifier] = nil
    if accountPlaytime(identifier, session, GetGameTimer()) then storage.save() end
  end
end

local function checkpointPlaytime()
  local now, dirty = GetGameTimer(), false
  for identifier, session in pairs(activePlaytime) do
    if accountPlaytime(identifier, session, now) then dirty = true end
  end
  if dirty then storage.save() end
end

local playtimeCheckpointScheduled = false
local function schedulePlaytimeCheckpoint()
  if playtimeCheckpointScheduled then return end
  playtimeCheckpointScheduled = true
  SetTimeout(60000, function()
    playtimeCheckpointScheduled = false
    if not next(activePlaytime) then return end
    checkpointPlaytime()
    schedulePlaytimeCheckpoint()
  end)
end

local function startPlaytime(src)
  src = tonumber(src)
  local player = getPlayer(src)
  local identifier = player.identifier
  if playtimeSources[src] == identifier then return end
  stopPlaytime(src)
  if not identifier then return end
  playtimeSources[src] = identifier
  local session = activePlaytime[identifier]
  if not session then
    session = { since = GetGameTimer(), connections = 0 }
    activePlaytime[identifier] = session
  end
  session.connections = session.connections + 1
  schedulePlaytimeCheckpoint()
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
  -- Corte previo: el recorte y los patrones nunca procesan strings enormes.
  if maxBytes and #value > maxBytes * 4 + 64 then return nil, t('input_too_long', { max = maxBytes }) end
  value = value:gsub('[\0-\8\11\12\14-\31\127]', '')
  local first = value:find('%S')
  if not first then return '' end
  local _, last = value:find('.*%S')
  value = value:sub(first, last)
  if maxBytes and #value > maxBytes then return nil, t('input_too_long', { max = maxBytes }) end
  return value
end

-- Una entrada corrupta en disco no debe tumbar el handler: se reporta como rotura.
local function safeVerify()
  local done, ok, at = pcall(audit.verify, chain)
  if done then return ok, at end
  return false, 1
end

local function verifyCached()
  local n = #chain.entries
  if verifyCache.n ~= n or verifyCache.head ~= chain.head then
    verifyCache = { n = n, head = chain.head, result = { safeVerify() } }
  end
  return verifyCache.result
end

-- Cada evento de red y comando de jugador pasa por acá antes de tocar el estado.
local function allowRate(src, key, fallback)
  src = tonumber(src)
  if not src or src <= 0 then return true end
  local rules = Config.RateLimit or {}
  local ok, first = ratelimit.allow(limiter, src, key, rules[key] or fallback or rules.default, os.time())
  if not ok and first then TriggerClientEvent('staff_suite:notify', src, t('rate_limited')) end
  return ok
end

local function sendTickets(src, player)
  if can(player, 'report.view') then
    TriggerClientEvent('staff_suite:state', src, { tickets = store.tickets })
  end
end

local function sendReporterTickets(src, reporter)
  TriggerClientEvent('staff_suite:state', src, { myTickets = tickets.reporter_view(store, reporter) })
end

local function updateReporter(ticket, notify)
  local src = findPlayerByIdentifier(ticket.reporter)
  if not src then return end
  sendReporterTickets(src, ticket.reporter)
  if notify then TriggerClientEvent('staff_suite:notify', src, t('ticket_staff_reply', { id = ticket.id }), { kind = 'reply' }) end
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

local captureEvidence

local function evidenceFile(id, n)
  return ('staff_suite_evidence_%d_%d.txt'):format(id, n)
end

-- ===== Moderación (wrappers server-authoritative) =====
local function banMessage(ban)
  if ban.expires_at == 0 then return t('ban_permanent', { reason = ban.reason }) end
  return t('ban_expires', { reason = ban.reason, date = os.date('!%Y-%m-%d %H:%M UTC', ban.expires_at) })
end

local function activeBan(ban, now)
  return ban and not ban.revoked_at and (ban.expires_at == 0 or ban.expires_at > now)
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

local function setFrozen(m, frozen)
  local ped = GetPlayerPed(m.tgt)
  if ped == 0 then return false, t('mod_invalid_target') end
  FreezeEntityPosition(ped, frozen)
  for _, player in ipairs(GetPlayers()) do
    local src = tonumber(player)
    if can(getPlayer(src), 'mod.freeze') then
      TriggerClientEvent('staff_suite:freezeState', src, { target = m.target, frozen = frozen })
    end
  end
end

local function frozenPlayers()
  local frozen = {}
  for _, player in ipairs(GetPlayers()) do
    local src = tonumber(player)
    local ped = GetPlayerPed(src)
    if ped ~= 0 and IsEntityPositionFrozen(ped) then frozen[getIdentifier(src)] = true end
  end
  return frozen
end

local modActions = {
  ['goto'] = { run = function(m)
    TriggerClientEvent('staff_suite:tp', m.src, GetEntityCoords(GetPlayerPed(m.tgt)))
  end },
  bring = { protected = true, run = function(m)
    TriggerClientEvent('staff_suite:tp', m.tgt, GetEntityCoords(GetPlayerPed(m.src)))
  end },
  freeze = { protected = true, run = function(m) return setFrozen(m, true) end },
  unfreeze = { protected = true, cap = 'mod.freeze', run = function(m) return setFrozen(m, false) end },
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
    spectateSequence = spectateSequence + 1
    local session = { target = m.tgt, key = spectateSequence }
    pendingSpectators[m.src] = session
    m.onSaved = function(saved)
      if pendingSpectators[m.src] ~= session then return end
      pendingSpectators[m.src] = nil
      local currentPed = GetPlayerPed(m.tgt)
      if not saved or not GetPlayerName(m.src) or currentPed == 0
        or getIdentifier(m.tgt) ~= m.target
        or GetPlayerRoutingBucket(m.src) ~= GetPlayerRoutingBucket(m.tgt) then
        TriggerClientEvent('staff_suite:notify', m.src, t(saved and 'spectate_unavailable' or 'mod_save_failed'))
        return
      end
      spectators[m.src] = session
      TriggerClientEvent('staff_suite:spectate', m.src, m.tgt, GetEntityCoords(currentPed), session.key)
    end
  end },
  warn = { protected = true, reason = true, run = function(m)
    m.onSaved = afterSanction(m, function()
      TriggerClientEvent('staff_suite:notify', m.tgt, t('warn_received', { reason = m.reason }), { kind = 'warn' })
    end)
  end },
  ban = { protected = true, reason = true, run = function(m)
    local identifiers = bridges.ban_identifiers(m.tgt, Config)
    local identifier = identifiers[1]
    if not identifier then return false, t('mod_invalid_target') end
    for _, id in ipairs(identifiers) do
      if pendingBans[id] or pendingRevocations[id] then return false, t('ban_pending') end
    end
    local seconds = m.duration
    if seconds == nil then seconds = Config.Moderation.ban_duration or 86400 end
    if seconds ~= 0 and (type(seconds) ~= 'number' or not positiveInteger(seconds) or seconds > 31536000) then
      return false, t('ban_invalid_duration')
    end
    local now = os.time()
    local ban = { id = #chain.entries + 1, actor = m.actor, reason = m.reason, created_at = now,
      expires_at = seconds == 0 and 0 or now + seconds }
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

local function canEscalate(player)
  return escalate and can(player, 'mod.warn_escalate') and can(player, 'mod.warn') and can(player, 'mod.kick')
end

local function canKickEscalation(ctx)
  if ctx.src == ctx.tgt or not GetPlayerName(ctx.src) or not GetPlayerName(ctx.tgt) then return false end
  local actor, target = getPlayer(ctx.src), getPlayer(ctx.tgt)
  return actor.identifier == ctx.actor and target.identifier == ctx.target and canEscalate(actor)
    and not perms.outranks(target.rank, actor.rank)
end

local function warnSaved(ctx, sequence, saved)
  if not saved then
    record('mod_warn_failed', ctx.actor, ctx.target, tostring(sequence))
    return
  end
  if not escalate then return end
  local now = os.time()
  local count = indexWarning(ctx.target, chain.entries[sequence].ts, now)
  if count < rule.threshold or pendingEscalations[ctx.target]
    or (escalations[ctx.target] or -math.huge) > now - rule.window_seconds then return end
  if not canKickEscalation(ctx) then return end
  pendingEscalations[ctx.target] = true
  local attempt = #chain.entries + 1
  local reason = t('warn_escalation_reason', { count = count })
  record('mod_warn_escalation', ctx.actor, ctx.target, reason, { warn_seq = sequence, count = count }, function(ok)
    pendingEscalations[ctx.target] = nil
    if not ok or not canKickEscalation(ctx) then
      record('mod_warn_escalation_failed', ctx.actor, ctx.target, tostring(attempt))
      return
    end
    escalations[ctx.target] = chain.entries[attempt].ts
    modActions.kick.run({ tgt = ctx.tgt, reason = reason })
  end)
end

local function sanctionTemplate(id)
  if type(id) ~= 'string' or #id > 32 or not id:match('^[%w_%-]+$') then return end
  local template = (Config.SanctionTemplates or {})[id]
  if type(template) ~= 'table' or type(template.reason_key) ~= 'string' then return end
  local action, duration = template.action, template.duration
  if action ~= 'warn' and action ~= 'kick' and action ~= 'ban' then return end
  if action == 'ban' and (type(duration) ~= 'number' or duration ~= 0
    and (not positiveInteger(duration) or duration > 31536000)) then return end
  local reason = cleanText(t(template.reason_key), limit('reason') or 300)
  if not reason or reason == '' or reason == template.reason_key then return end
  return { id = id, action = action, reason = reason, duration = duration }
end

local function sanctionTemplates(player)
  local list = {}
  if can(player, 'mod.template') then
    for id in pairs(Config.SanctionTemplates or {}) do
      local item = sanctionTemplate(id)
      if item and can(player, 'mod.' .. item.action) then list[#list + 1] = item end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
  end
  return list
end

local function doMod(src, action, tgt, reason, duration, templateId)
  if type(action) ~= 'string' then return false, t('mod_unavailable') end
  local player = getPlayer(src)
  local spec = modActions[action]
  if not can(player, spec and spec.cap or ('mod.' .. action)) then return false, t('no_permission') end
  if not spec then return false, t('mod_unavailable') end
  local template
  if templateId ~= nil then
    if not can(player, 'mod.template') then return false, t('no_permission') end
    template = sanctionTemplate(templateId)
    if not template or template.action ~= action then return false, t('sanction_template_invalid') end
    reason, duration = template.reason, template.duration
  end
  if type(tgt) == 'table' then
    if not can(player, 'player.online.view') then return false, t('no_permission') end
    local id = positiveInteger(tgt.id)
    local ref = onlineRefs[id]
    if not ref or ref.key ~= tgt.key or ref.identifier ~= getPlayer(id).identifier then
      return false, t('online_player_changed')
    end
    tgt = id
  else
    tgt = positiveInteger(tgt) or findPlayerByIdentifier(tgt)
  end
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
    reason = reason, duration = duration, payload = { action = action, template = template and template.id } }
  local ok, err = spec.run(ctx)
  if ok == false then return false, err end
  if action == 'warn' and ctx.target:sub(1, 4) ~= 'src:' then
    local sequence, notify = #chain.entries + 1, ctx.onSaved
    ctx.onSaved = function(saved)
      notify(saved)
      warnSaved(ctx, sequence, saved)
    end
  end
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
    if activeBan(ban, now) then
      setKickReason(banMessage(ban))
      CancelEvent()
      if pendingRevocations[identifier] then return end
      -- Evasión con cuentas nuevas: el ban se extiende a los identificadores que no tenía.
      local added = {}
      for _, id in ipairs(identifiers) do
        local old = bans[id]
        if not pendingBans[id] and not pendingRevocations[id] and not activeBan(old, now) then
          bans[id] = ban
          added[#added + 1] = id
        end
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
    if ticket.reporter == reporter and tickets.is_open(ticket) then n = n + 1 end
  end
  return n
end

-- Devuelve true o false y el motivo, para que el panel conserve el borrador si falla.
local function createReport(src, category, priority, body)
  if not positiveInteger(src) then return false end
  local err
  body, err = cleanText(body, limit('ticket_body'))
  if err then TriggerClientEvent('staff_suite:notify', src, err); return false, err end
  if not body or body == '' then return false end
  category = configuredValue(Config.Categories, category, 'other')
  priority = configuredValue(Config.Priorities, priority, 'normal')
  local player = getPlayer(src)
  local maxOpen = limit('open_tickets_per_player')
  if maxOpen and openTickets(actorId(player, src)) >= maxOpen then
    err = t('report_too_many_open', { max = maxOpen })
    TriggerClientEvent('staff_suite:notify', src, err)
    return false, err
  end
  local ticket, ev = tickets.create(store, {
    reporter = actorId(player, src), category = category, priority = priority,
    description = body, ts = os.time(),
  })
  record(ev.action, ev.actor, ev.target, '', { ticket = ticket.id, category = category, priority = priority })
  TriggerClientEvent('staff_suite:notify', src, t('report_created', { id = ticket.id }))
  local catKey, priKey = 'cat_' .. category, 'pri_' .. priority
  local notice = t('report_new_staff', { id = ticket.id, category = t(catKey), priority = t(priKey) })
  for _, candidate in ipairs(GetPlayers()) do
    local staff = tonumber(candidate)
    if staff ~= src and can(getPlayer(staff), 'report.view') then
      TriggerClientEvent('staff_suite:notify', staff, notice, { kind = 'report', priority = priority })
    end
  end
  sendTickets(src, player)
  sendReporterTickets(src, player.identifier)
  return true, nil, ticket
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
    local ok, at = safeVerify()
    print(ok and t('console_audit_ok', { n = #chain.entries }) or t('console_audit_broken', { seq = at }))
    return
  end
  if not can(getPlayer(src), 'audit.view') then TriggerClientEvent('staff_suite:notify', src, t('no_permission')); return end
  local ok, at = safeVerify()
  TriggerClientEvent('staff_suite:auditResult', src, { ok = ok, at = at, n = #chain.entries })
end)

-- ===== NUI / eventos de panel =====
RegisterNetEvent('staff_suite:staffChat', function(body, req)
  local src = source
  req = positiveInteger(req)
  if not req then return end
  local function reply(ok, err)
    TriggerClientEvent('staff_suite:staffChatResult', src, { req = req, ok = ok, error = err })
  end
  if not allowRate(src, 'staff_suite:staffChat') then return reply(false, t('rate_limited')) end
  if not ready then return reply(false, t('persistence_starting')) end
  local player = getPlayer(src)
  if not player.identifier or not can(player, 'staff.chat') then return reply(false, t('no_permission')) end
  local text, err = cleanText(body, limit('message_body') or 1000)
  if not text or text == '' then return reply(false, err or t('staff_chat_empty')) end
  -- El registro confirma el envío sin dar acceso al contenido a través de audit.view.
  local requestSeq = #chain.entries + 1
  record('staff_chat_request', player.identifier, 'staff', '', { bytes = #text }, function(saved)
    local recipients = 0
    if saved then
      for _, target in ipairs(GetPlayers()) do
        local recipient = getPlayer(target)
        if recipient.identifier and can(recipient, 'staff.chat') then
          TriggerClientEvent('staff_suite:staffChatMessage', tonumber(target), player.name, text)
          recipients = recipients + 1
        end
      end
    end
    record('staff_chat_result', player.identifier, 'staff', '',
      { request_seq = requestSeq, ok = saved == true, recipients = recipients })
    if GetPlayerName(src) and getPlayer(src).identifier == player.identifier then
      reply(saved == true, not saved and t('mod_save_failed') or nil)
    end
  end)
end)

local function playedSeconds(identifier, now)
  local session = activePlaytime[identifier]
  local elapsed = session and math.max(now - session.since, 0) or 0
  return ((playtime[identifier] or 0) + elapsed) // 1000
end

local function recentPlayerProfile(identifier)
  local profile = profileHistory[identifier] or {}
  local result = { warns = profile.warns or {}, bans = profile.bans or {}, notes = profile.notes or {}, tickets = {},
    played_seconds = playedSeconds(identifier, GetGameTimer()) }
  -- Los IDs de ticket son monotónicos y el almacenamiento puede tener huecos.
  for _, ticket in pairs(store.tickets) do
    if ticket.reporter == identifier then
      result.tickets[#result.tickets + 1] = { id = ticket.id, state = ticket.state, ts = ticket.created_ts }
    end
  end
  table.sort(result.tickets, function(a, b) return a.id > b.id end)
  for i = #result.tickets, 21, -1 do result.tickets[i] = nil end
  return result
end

local function profileEvent(name, action, cap, fn)
  RegisterNetEvent(name, function(id, req, body)
    local src = source
    req = positiveInteger(req)
    if not req then return end
    local function reply(ok, err, data)
      TriggerClientEvent(action, src, { req = req, ok = ok, error = err, data = data })
    end
    if not allowRate(src, name) then return reply(false, t('rate_limited')) end
    if not ready then return reply(false, t('persistence_starting')) end
    local player = getPlayer(src)
    if not player.identifier or not can(player, 'report.view') or not can(player, 'player.profile.view')
      or not can(player, cap) then return reply(false, t('no_permission')) end
    id = positiveInteger(id)
    local ticket = id and store.tickets[id]
    if not ticket then return reply(false, t('player_profile_missing')) end
    if not profileAuditIntact then return reply(false, t('player_profile_audit_broken')) end
    fn(ticket.reporter, player, body, function(ok, err, data)
      if GetPlayerName(src) and getPlayer(src).identifier == player.identifier then reply(ok, err, data) end
    end)
  end)
end

profileEvent('staff_suite:playerProfile', 'staff_suite:playerProfileResult', 'player.profile.view',
  function(identifier, player, _, reply)
    record('player_profile_view', player.identifier, identifier, '', nil, function(saved)
      reply(saved == true, not saved and t('mod_save_failed') or nil, saved and recentPlayerProfile(identifier) or nil)
    end)
  end)

profileEvent('staff_suite:playerProfileNote', 'staff_suite:playerProfileNoteResult', 'player.profile.note',
  function(identifier, player, body, reply)
    local text, err = cleanText(body, limit('message_body') or 1000)
    if not text or text == '' then return reply(false, err or t('player_profile_note_empty')) end
    record('player_profile_note', player.identifier, identifier, text, nil, function(saved)
      reply(saved == true, not saved and t('mod_save_failed') or nil, saved and recentPlayerProfile(identifier) or nil)
    end)
  end)

RegisterNetEvent('staff_suite:onlinePlayers', function(req)
  local src = tonumber(source)
  req = positiveInteger(req)
  if not src or not req then return end
  local function reply(ok, errorKey, rows)
    TriggerClientEvent('staff_suite:onlinePlayersResult', src, { req = req, ok = ok,
      error = errorKey and t(errorKey), data = rows })
  end
  if not allowRate(src, 'staff_suite:onlinePlayers') then return reply(false, 'rate_limited') end
  if not ready then return reply(false, 'persistence_starting') end
  local viewer = getPlayer(src)
  if not viewer.identifier or not can(viewer, 'player.online.view') then return reply(false, 'no_permission') end
  local counts = {}
  local canSeeTickets = can(viewer, 'report.view')
  if canSeeTickets then
    for _, ticket in pairs(store.tickets) do
      if tickets.is_open(ticket) then counts[ticket.reporter] = (counts[ticket.reporter] or 0) + 1 end
    end
  end
  local rows, now = {}, GetGameTimer()
  for _, entry in ipairs(GetPlayers()) do
    local id = tonumber(entry)
    local identifier = playtimeSources[id]
    local ref = onlineRefs[id]
    if identifier and (not ref or ref.identifier ~= identifier) then
      onlineRefSeq = onlineRefSeq + 1
      ref = { identifier = identifier, key = onlineRefSeq }
      onlineRefs[id] = ref
    end
    rows[#rows + 1] = { id = id, name = GetPlayerName(id) or tostring(id), ping = GetPlayerPing(id), self = id == src,
      key = identifier and ref.key or nil,
      played_seconds = identifier and playedSeconds(identifier, now) or 0,
      tickets = canSeeTickets and (counts[identifier] or 0) or nil }
  end
  local ts = os.time()
  -- Limita la auditoría de las lecturas repetidas por la actualización del panel.
  if not onlineViewedAt[src] or ts - onlineViewedAt[src] >= 300 then
    onlineViewedAt[src] = ts
    record('player_online_view', viewer.identifier, '', '', { count = #rows })
  end
  reply(true, nil, rows)
end)

RegisterNetEvent('staff_suite:staffWeekly', function(req, exporting)
  local src = tonumber(source)
  req = positiveInteger(req)
  if not src or not req then return end
  local function reply(ok, errorKey, data)
    TriggerClientEvent('staff_suite:staffWeeklyResult', src, { req = req, ok = ok,
      error = errorKey and t(errorKey), data = data })
  end
  if not allowRate(src, 'staff_suite:staffWeekly') then return reply(false, 'rate_limited') end
  if not ready then return reply(false, 'persistence_starting') end
  local player = getPlayer(src)
  local cap = exporting == true and 'staff.analytics.export' or 'staff.analytics'
  if not player.identifier or not can(player, cap) or not can(player, 'staff.analytics') then
    return reply(false, 'no_permission')
  end
  if not verifyCached()[1] then return reply(false, 'staff_weekly_unverified') end
  local data = duty.weekly(chain.entries, os.time(), json.decode)
  local action = exporting == true and 'staff_weekly_export' or 'staff_weekly_view'
  record(action, player.identifier, 'staff', '', { from = data.from, to = data.to, rows = #data.staff }, function(saved)
    if not GetPlayerName(src) or getPlayer(src).identifier ~= player.identifier then return end
    if not saved then return reply(false, 'mod_save_failed') end
    return reply(true, nil, data)
  end)
end)

local function net(name, fn)
  RegisterNetEvent(name, function(...)
    if not allowRate(source, name) then return end
    if ready then return fn(...) end
    TriggerClientEvent('staff_suite:notify', source, t('persistence_starting'))
  end)
end

-- `req` es opcional: si viene, el panel recibe ok/error en staff_suite:ticketCreateResult.
RegisterNetEvent('staff_suite:ticketCreate', function(category, priority, body, req, attach)
  local src = source
  local ok, err, ticket = false
  if not allowRate(src, 'staff_suite:ticketCreate') then
    err = t('rate_limited')
  elseif not ready then
    err = t('persistence_starting')
    TriggerClientEvent('staff_suite:notify', src, err)
  else
    ok, err, ticket = createReport(src, category, priority, body)
    if ok and ticket and attach == true and evidenceAvailable() then
      captureEvidence(ticket, src, ticket.reporter, src)
    end
  end
  req = positiveInteger(req)
  if req then TriggerClientEvent('staff_suite:ticketCreateResult', src, { req = req, ok = ok == true, error = err }) end
end)

RegisterNetEvent('staff_suite:announce', function(body, req)
  local src = source
  req = positiveInteger(req)
  local function reply(ok, err)
    if req then TriggerClientEvent('staff_suite:announceResult', src, { req = req, ok = ok, error = err }) end
  end

  if not allowRate(src, 'staff_suite:announce', { burst = 1, per_second = 1 / 30 }) then
    return reply(false, t('rate_limited'))
  end
  if not ready then return reply(false, t('persistence_starting')) end
  local player = getPlayer(src)
  if not player.identifier or not can(player, 'staff.announce') then return reply(false, t('no_permission')) end
  local message, err = cleanText(body, limit('announcement') or 300)
  if not message or message == '' then return reply(false, err or t('announcement_empty')) end

  record('staff_announce', player.identifier, 'server', message, nil, function(saved)
    if saved then TriggerClientEvent('staff_suite:announcement', -1, message) end
    if GetPlayerName(src) and getPlayer(src).identifier == player.identifier then
      reply(saved, not saved and t('announcement_failed') or nil)
    end
  end)
end)

local function banRequest(src, name, req, cap, rate)
  req = positiveInteger(req)
  if not req then return end
  local function reply(ok, errorMessage, data)
    TriggerClientEvent(name .. 'Result', src, { req = req, ok = ok, error = errorMessage, data = data })
  end
  if not allowRate(src, name, rate) then reply(false, t('rate_limited')); return end
  if not ready then reply(false, t('persistence_starting')); return end
  local player = getPlayer(src)
  if not player.identifier or not can(player, 'ban.view') or not can(player, cap) then
    reply(false, t('no_permission'))
    return
  end
  return player, reply
end

RegisterNetEvent('staff_suite:banList', function(page, req)
  local player, reply = banRequest(source, 'staff_suite:banList', req, 'ban.view', { burst = 5, per_second = 1 })
  if not player then return end
  page = positiveInteger(page)
  if not page then return reply(false, t('ban_review_failed')) end

  local now, rows, groups = os.time(), {}, {}
  for identifier, ban in pairs(bans) do
    if not (ban.id and revokedBans[ban.id]) then
      local group = ban.id and groups[ban.id]
      if not group then
        local status = ban.revoked_at and 'revoked' or (activeBan(ban, now) and 'active' or 'expired')
        group = { id = ban.id, identifier = identifier, actor = ban.actor, reason = ban.reason,
          created_at = ban.created_at, expires_at = ban.expires_at, status = status, aliases = 0 }
        if ban.id then groups[ban.id] = group end
        rows[#rows + 1] = group
      end
      group.aliases = group.aliases + 1
      if identifier < group.identifier then group.identifier = identifier end
    end
  end
  for _, row in pairs(revokedBans) do rows[#rows + 1] = row end
  table.sort(rows, function(a, b)
    if a.created_at ~= b.created_at then return a.created_at > b.created_at end
    if a.identifier ~= b.identifier then return a.identifier < b.identifier end
    return (a.id or 0) > (b.id or 0)
  end)
  local result, pageSize = {}, 20
  for i = (page - 1) * pageSize + 1, math.min(page * pageSize, #rows) do result[#result + 1] = rows[i] end
  record('ban_list_view', player.identifier, 'server', '', { page = page })
  return reply(true, nil, { rows = result, hasMore = #rows > page * pageSize })
end)

RegisterNetEvent('staff_suite:banRevoke', function(id, reason, req)
  local src = source
  local player, reply = banRequest(src, 'staff_suite:banRevoke', req, 'ban.revoke', { burst = 2, per_second = 1 / 10 })
  if not player then return end
  id = positiveInteger(id)
  if not id then return reply(false, t('ban_review_failed')) end
  local why, err = cleanText(reason, limit('reason') or 300)
  if not why or why == '' then return reply(false, err or t('reason_required')) end

  local aliases, now = {}, os.time()
  for identifier, ban in pairs(bans) do
    if ban.id == id and activeBan(ban, now) then
      if pendingRevocations[identifier] or pendingBans[identifier] then return reply(false, t('ban_pending')) end
      aliases[#aliases + 1] = identifier
    end
  end
  if #aliases == 0 then return reply(false, t('ban_not_active')) end
  table.sort(aliases)
  for _, identifier in ipairs(aliases) do
    local ban = bans[identifier]
    pendingRevocations[identifier] = { id = ban.id, actor = ban.actor, reason = ban.reason, created_at = ban.created_at,
      expires_at = ban.expires_at, revoked_at = now }
  end
  local original, requestSeq = bans[aliases[1]], #chain.entries + 1
  local review = { id = id, identifier = aliases[1], actor = original.actor, reason = original.reason,
    created_at = original.created_at, expires_at = original.expires_at, status = 'revoked', aliases = #aliases }
  local payload = { ban_id = id, identifiers = aliases, review = review }
  record('mod_unban', player.identifier, aliases[1], why, payload, function(saved)
    for _, identifier in ipairs(aliases) do
      if saved then bans[identifier] = pendingRevocations[identifier] end
      pendingRevocations[identifier] = nil
    end
    if saved then
      revokedBans[id] = review
    else
      record('mod_unban_failed', player.identifier, aliases[1], why, { ban_id = id, request_seq = requestSeq })
    end
    if GetPlayerName(src) and getPlayer(src).identifier == player.identifier then
      reply(saved, not saved and t('mod_save_failed') or nil)
    end
  end)
end)

RegisterNetEvent('staff_suite:ticketExport', function(id, req)
  local src = source
  req = positiveInteger(req)
  if not req then return end
  local function reply(ok, err)
    TriggerClientEvent('staff_suite:ticketExportResult', src, { req = req, ok = ok, error = err })
  end
  if not allowRate(src, 'staff_suite:ticketExport', { burst = 1, per_second = 1 / 30 }) then
    return reply(false, t('rate_limited'))
  end
  if not ready then return reply(false, t('persistence_starting')) end
  local player = getPlayer(src)
  if not player.identifier or not can(player, 'report.view') or not can(player, 'report.export') then
    return reply(false, t('no_permission'))
  end
  local cfg = Config.Export
  if not export.ticketEnabled(cfg) then return reply(false, t('ticket_export_unavailable')) end
  id = positiveInteger(id)
  local ticket = id and store.tickets[id]
  if not ticket then return reply(false, t('ticket_export_missing')) end
  if pendingExports[id] then return reply(false, t('ticket_export_pending')) end
  pendingExports[id] = true
  local target, seq = 'ticket:' .. id, #chain.entries + 1
  local function finish(ok, status)
    pendingExports[id] = nil
    record('ticket_export_result', player.identifier, target, '', { request_seq = seq, ok = ok, status = status })
    if GetPlayerName(src) and getPlayer(src).identifier == player.identifier then
      reply(ok, not ok and t(status == 0 and 'ticket_export_unconfirmed' or 'ticket_export_failed') or nil)
    end
  end
  record('ticket_export_request', player.identifier, target, '', nil, function(saved)
    if saved then
      export.ticket(ticket, cfg, finish)
    else
      pendingExports[id] = nil
      if GetPlayerName(src) and getPlayer(src).identifier == player.identifier then
        reply(false, t('mod_save_failed'))
      end
    end
  end)
end)

net('staff_suite:getState', function()
  local src = source
  local player = getPlayer(src)
  local capabilities = {}
  for _, cap in ipairs(perms.CAPS) do
    local available = cap:sub(1, 4) ~= 'mod.' or cap == 'mod.template' or modActions[cap:sub(5)]
      or cap == 'mod.warn_escalate' and canEscalate(player)
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
    myTickets = tickets.reporter_view(store, player.identifier),
    frozenPlayers = can(player, 'mod.freeze') and frozenPlayers() or {},
    transferTargets = can(player, 'report.resolve') and transferTargets() or {},
    exportStatus = {
      webhook = type(exportConfig.webhook) == 'string' and exportConfig.webhook ~= '',
      file = exportConfig.file == true,
      anchor_every = exportConfig.anchor_every,
      tickets = can(player, 'report.export') and export.ticketEnabled(exportConfig),
    },
    audit = canViewAudit and chain.entries or {},
    duty = canViewAnalytics and duty.snapshot(dreg, now) or {},
    dutySelf = { on_duty = can(player, 'staff.duty') and shift ~= nil and shift.on_duty == true },
    verify = verify,
    alerts = alerts,
    evidenceEnabled = evidenceAvailable(),
    sanctionTemplates = sanctionTemplates(player),
    warnEscalation = canEscalate(player) and { threshold = rule.threshold, windowSeconds = rule.window_seconds } or false,
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
  afterTransition(ticket, ev)
  record(ev.action, ev.actor, 'ticket:' .. id, ev.reason, { from = ev.from, to = ev.to, assigned_to = ev.assigned_to })
  sendTickets(src, player)
  if recipientSrc and recipientSrc ~= tonumber(src) then sendTickets(recipientSrc, recipient) end
  updateReporter(ticket)
end)

local function addTicketMessage(src, id, body, internal, asReporter)
  id = positiveInteger(id)
  local err
  body, err = cleanText(body, limit('message_body'))
  if err then return false, err end
  if not id or not body or body == '' or (internal ~= nil and type(internal) ~= 'boolean') then
    return false, t('ticket_message_failed')
  end
  local player = getPlayer(src)
  local ticket = store.tickets[id]
  if asReporter then
    if not player.identifier or not ticket or ticket.reporter ~= player.identifier then return false, t('no_permission') end
  elseif not can(player, 'report.message') or not can(player, 'report.view') then
    return false, t('no_permission')
  end
  if not ticket or ticket.state == 'closed' or (not internal and not tickets.is_open(ticket)) then
    return false, t('ticket_message_failed')
  end
  local _, ev = tickets.add_message(store, id, actorId(player, src), body, internal, os.time())
  record(ev.action, ev.actor, 'ticket:' .. id, '', { ticket = id, internal = ev.internal, message = #ticket.messages })
  for _, candidate in ipairs(GetPlayers()) do
    local staff = tonumber(candidate)
    if can(getPlayer(staff), 'report.view') then
      TriggerClientEvent('staff_suite:state', staff, { ticket = ticket })
    end
  end
  if not ev.internal then updateReporter(ticket, not asReporter and player.identifier ~= ticket.reporter) end
  return true
end

local function receiveTicketMessage(src, id, body, internal, asReporter, req)
  local ok, err = false
  if not allowRate(src, 'staff_suite:ticketMessage') then
    err = t('rate_limited')
  elseif not ready then
    err = t('persistence_starting')
  else
    ok, err = addTicketMessage(src, id, body, internal, asReporter)
  end
  req = positiveInteger(req)
  if req then
    TriggerClientEvent('staff_suite:ticketMessageResult', src, { req = req, ok = ok, error = err })
  elseif err and err ~= t('rate_limited') then
    TriggerClientEvent('staff_suite:notify', src, err)
  end
end

RegisterNetEvent('staff_suite:ticketMessage', function(id, body, internal, req)
  receiveTicketMessage(source, id, body, internal, false, req)
end)
RegisterNetEvent('staff_suite:ticketReply', function(id, body, req)
  receiveTicketMessage(source, id, body, false, true, req)
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

-- Captura la pantalla de `targetSrc` y la guarda como evidencia del ticket, con su hash auditado.
function captureEvidence(ticket, targetSrc, by, notifySrc)
  local id = ticket.id
  exports['screenshot-basic']:requestClientScreenshot(targetSrc, { encoding = 'jpg', quality = 0.6 }, function(err, data)
    if err or type(data) ~= 'string' or data == '' then
      TriggerClientEvent('staff_suite:notify', notifySrc, t('evidence_failed'))
      return
    end
    ticket.evidence = ticket.evidence or {}
    local n = #ticket.evidence + 1
    if not SaveResourceFile(GetCurrentResourceName(), evidenceFile(id, n), data, -1) then
      TriggerClientEvent('staff_suite:notify', notifySrc, t('evidence_failed'))
      return
    end
    local item = { n = n, ts = os.time(), by = by, sha256 = sha256.hex(data), size = #data, audit_seq = #chain.entries + 1 }
    ticket.evidence[n] = item
    record('ticket_evidence', by, 'ticket:' .. id, '', { n = n, sha256 = item.sha256, size = item.size })
    TriggerClientEvent('staff_suite:notify', notifySrc, t('evidence_saved', { n = n }))
    sendTickets(notifySrc, getPlayer(notifySrc))
  end)
end

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
  captureEvidence(ticket, targetSrc, actorId(player, src), src)
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
    local chainOk, brokenAt = safeVerify()
    ok = chainOk or (brokenAt ~= nil and brokenAt > item.audit_seq)
  end
  TriggerLatentClientEvent('staff_suite:evidence', src, 250000, { id = id, n = n, data = data, ok = ok })
end)

net('staff_suite:modAction', function(action, tgt, reason, duration, templateId)
  local src = source
  if action == 'warn' and not allowRate(src, 'staff_suite:modWarn') then return end
  if templateId ~= nil and not allowRate(src, 'staff_suite:modTemplate') then return end
  local ok, err = doMod(src, action, tgt, reason, duration, templateId)
  if not ok then TriggerClientEvent('staff_suite:notify', src, err) end
end)

net('staff_suite:spectateEnded', function(key)
  local src = tonumber(source)
  local session = spectators[src]
  if session and session.key == key then spectators[src] = nil end
end)

local waypointMessages = { ok = 'waypoint_ok', no_marker = 'waypoint_no_marker',
  unavailable = 'waypoint_unavailable', save_failed = 'waypoint_save_failed' }

local function finishWaypoint(src, request, outcome)
  waypointRequests[src] = nil
  record('staff_waypoint_result', request.actor, request.actor, outcome, { request_seq = request.seq })
  if GetPlayerName(src) and getPlayer(src).identifier == request.actor then
    TriggerClientEvent('staff_suite:notify', src, t(waypointMessages[outcome]))
  end
end

net('staff_suite:waypoint', function()
  local src = source
  local player = getPlayer(src)
  if not player.identifier or not can(player, 'staff.waypoint') or waypointRequests[src] then return end
  local request = { actor = player.identifier, seq = #chain.entries + 1 }
  waypointRequests[src] = request
  record('staff_waypoint_request', request.actor, request.actor, '', nil, function(saved)
    if waypointRequests[src] ~= request then return end
    if not saved then return finishWaypoint(src, request, 'save_failed') end
    local current = getPlayer(src)
    if not GetPlayerName(src) or current.identifier ~= request.actor or not can(current, 'staff.waypoint') then
      return finishWaypoint(src, request, 'unavailable')
    end
    request.dispatched = true
    TriggerClientEvent('staff_suite:waypoint', src, request.seq)
    SetTimeout(12000, function()
      if waypointRequests[src] == request then finishWaypoint(src, request, 'unavailable') end
    end)
  end)
end)

net('staff_suite:waypointResult', function(sequence, outcome)
  local src = source
  local request = waypointRequests[src]
  if outcome ~= 'ok' and outcome ~= 'no_marker' and outcome ~= 'unavailable' then return end
  if request and request.dispatched and sequence == request.seq and getPlayer(src).identifier == request.actor then
    finishWaypoint(src, request, outcome)
  end
end)

net('staff_suite:verify', function()
  local src = source
  local player = getPlayer(src)
  if not can(player, 'audit.verify') then return end
  local ok, at = safeVerify()
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
    ts = tonumber(data.ts) or os.time(),
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
    ts = tonumber(extra.ts) or os.time(),
    reason = reason ~= '' and reason or nil,
    resolution = resolution ~= '' and resolution or nil,
    to = idText(extra.to),
    rating = extra.rating,
  })
  if ticket and ev then
    afterTransition(ticket, ev)
    record(ev.action, ev.actor, 'ticket:' .. id, ev.reason, { from = ev.from, to = ev.to, assigned_to = ev.assigned_to })
    updateReporter(ticket)
  end
  if not ticket then return false, ev end
  return ticket, ev
end)
expose('GetState', snapshot)
expose('SetDuty', function(actor, onDuty)
  actor = idText(actor)
  if not actor or type(onDuty) ~= 'boolean' then return nil, 'invalid_input' end
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
    for _, src in ipairs(GetPlayers()) do startPlaytime(src) end
    capture.install(Config, bridges.select, getIdentifier, record)
    print(t('console_started', { n = #chain.entries, persistence = backend, framework = bridges.select(Config) }))
  end)
end)

AddEventHandler('playerJoining', function()
  if ready then startPlaytime(source) end
end)

AddEventHandler('playerDropped', function()
  local src = tonumber(source)
  spectators[src] = nil
  pendingSpectators[src] = nil
  for observer, session in pairs(pendingSpectators) do
    if session.target == src then pendingSpectators[observer] = nil end
  end
  for observer, session in pairs(spectators) do
    if session.target == src then
      spectators[observer] = nil
      TriggerClientEvent('staff_suite:spectateStop', observer, session.key)
    end
  end
  onlineRefs[src], onlineViewedAt[src] = nil, nil
  local request = waypointRequests[src]
  if request then
    waypointRequests[src] = nil
    record('staff_waypoint_result', request.actor, request.actor, 'disconnected', { request_seq = request.seq })
  end
  stopPlaytime(src)
  ratelimit.forget(limiter, src)
end)

-- Los lotes pendientes se respaldan antes de apagar el recurso.
AddEventHandler('onResourceStop', function(res)
  if ready and res == GetCurrentResourceName() then
    checkpointPlaytime()
    storage.stop()
  end
end)
