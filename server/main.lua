-- server/main.lua — Adapter FiveM. Conecta el core agnóstico al server.
-- Lite: persistencia JSON standalone. Core: oxmysql. Captura + auditoría + tickets.

-- FiveM no expone package/require estándar (sandbox). Shim de módulos con
-- LoadResourceFile + load + cache. Resuelve también los require internos del core.
-- Entorno Lua por-resource: override de require es seguro (solo afecta staff_suite).
local _cache = {}
local function loadmod(name)
  if _cache[name] ~= nil then return _cache[name] end
  local path = name:gsub('%.', '/') .. '.lua'
  local src = LoadResourceFile(GetCurrentResourceName(), path)
  if not src then error('[StaffSuite] módulo no encontrado: ' .. name) end
  local fn = assert(load(src, '@staff_suite/' .. path, 't'))
  local mod = fn()
  _cache[name] = mod or true
  return mod
end
require = loadmod

local audit  = loadmod('core.audit_chain')
local tickets = loadmod('core.tickets')
local perms  = loadmod('core.permissions')
local bridges = loadmod('server.bridges.init')
local duty   = loadmod('core.duty')
local persist = loadmod('server.persist')
local export = loadmod('server.export')

local L = Locale[Config.Locale] or Locale['en']
local function t(key, vars)
  local s = L[key] or key
  if vars then for k, v in pairs(vars) do s = s:gsub('%%{' .. k .. '}', tostring(v)) end end
  return s
end

-- ===== Estado =====
local chain = audit.new()
local store = tickets.new_store()
local pmodel = perms.new()
local dreg = duty.new_registry()
local entry_count = 0

-- ===== Persistencia =====
local function snapshot()
  return {
    chain = { entries = chain.entries, head = chain.head },
    tickets = store,
    perms = pmodel,
    duty = dreg,
  }
end

local function save()
  if Config.Persistence == 'oxmysql' and persist.db_ready() then
    persist.save_db(snapshot())
  else
    persist.save_json(Config.JsonFile, snapshot())
  end
end

local function restore(data)
  if not data then return end
  if data.chain then chain.entries = data.chain.entries or {}; chain.head = data.chain.head or audit.GENESIS end
  if data.tickets then store = data.tickets end
  if data.perms then pmodel = data.perms end
  if data.duty then dreg = data.duty end
  entry_count = #chain.entries
end

-- ===== Auditoría =====
local function record(action, actor, target, reason, payload)
  local e = audit.append(chain, {
    ts = os.time(), actor = actor or 'system', action = action,
    target = target or '', reason = reason or '',
    payload = payload and json.encode(payload) or '',
  })
  entry_count = entry_count + 1
  if entry_count % Config.Export.anchor_every == 0 then export.anchor(e, Config.Export) end
  save()
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

-- ===== Moderación (wrappers server-authoritative) =====
local modActions = {
  ['goto'] = function(src, tgt) local p = GetPlayerPed(tgt); local c = GetEntityCoords(p); TriggerClientEvent('staff_suite:tp', src, c) end,
  bring   = function(src, tgt) local p = GetPlayerPed(src); local c = GetEntityCoords(p); TriggerClientEvent('staff_suite:tp', tgt, c) end,
  freeze  = function(_, tgt) FreezeEntityPosition(GetPlayerPed(tgt), true) end,
  heal    = function(_, tgt) SetEntityHealth(GetPlayerPed(tgt), 200) end,
  kick    = function(_, tgt, reason) DropPlayer(tgt, reason or 'Kicked') end,
}

local function doMod(src, action, tgt, reason)
  local player = getPlayer(src)
  local cap = 'mod.' .. action
  if not can(player, cap) then return false, t('no_permission') end
  if Config.Moderation.require_reason and (action == 'kick' or action == 'ban' or action == 'warn') and (not reason or reason == '') then
    return false, t('reason_required')
  end
  local target = getIdentifier(tgt)
  local fn = modActions[action]
  if fn then fn(src, tgt, reason) end
  record('mod_' .. action, actorId(player, src), target, reason, { action = action })
  return true
end

-- ===== Comandos =====
RegisterCommand(Config.Commands.report, function(src, args)
  if src == 0 then return end
  local category = args[1] or 'other'
  local desc = table.concat(args, ' ', 2)
  local ticket, ev = tickets.create(store, {
    reporter = getIdentifier(src), category = category, priority = 'normal',
    description = desc, ts = os.time(),
  })
  record(ev.action, ev.actor, ev.target, '', { ticket = ticket.id, category = category })
  TriggerClientEvent('staff_suite:notify', src, t('report_created', { id = ticket.id }))
end, false)

RegisterCommand(Config.Commands.duty, function(src)
  if src == 0 then return end
  local player = getPlayer(src)
  if not can(player, 'staff.duty') then TriggerClientEvent('staff_suite:notify', src, t('no_permission')); return end
  local id = actorId(player, src)
  local s = dreg.staff[id]
  local ev
  if s and s.on_duty then ev = duty.clock_out(dreg, id, os.time()); TriggerClientEvent('staff_suite:notify', src, t('duty_out', { time = string.format('%.1fh', (ev.seconds or 0) / 3600) }))
  else ev = duty.clock_in(dreg, id, os.time()); TriggerClientEvent('staff_suite:notify', src, t('duty_in')) end
  if ev then record(ev.event, id, id, '', {}) end
end, false)

RegisterCommand(Config.Commands.audit, function(src)
  if src == 0 then
    local ok, at = audit.verify(chain)
    print(ok and ('[StaffSuite] audit OK: ' .. #chain.entries .. ' entries') or ('[StaffSuite] audit BROKEN at ' .. tostring(at)))
    return
  end
  if not can(getPlayer(src), 'audit.view') then TriggerClientEvent('staff_suite:notify', src, t('no_permission')); return end
  local ok, at = audit.verify(chain)
  TriggerClientEvent('staff_suite:auditResult', src, { ok = ok, at = at, n = #chain.entries })
end, false)

-- ===== NUI / eventos de panel =====
RegisterNetEvent('staff_suite:getState', function()
  local src = source
  local player = getPlayer(src)
  local capabilities = {}
  for _, cap in ipairs(perms.CAPS) do
    if can(player, cap) then capabilities[#capabilities + 1] = cap end
  end
  local rank = player.rank or 'player'
  local canViewAudit = can(player, 'audit.view')
  TriggerClientEvent('staff_suite:state', src, {
    tickets = can(player, 'report.view') and store.tickets or {},
    audit = canViewAudit and chain.entries or {},
    duty = can(player, 'staff.analytics') and duty.snapshot(dreg, os.time()) or {},
    verify = canViewAudit and { audit.verify(chain) } or {},
    player = { name = player.name, rank = rank, capabilities = capabilities },
    rank = rank, locale = Config.Locale,
  })
end)

local ticketActionCaps = {
  claim = 'report.claim', start = 'report.claim', unclaim = 'report.claim',
  transfer = 'report.resolve', resolve = 'report.resolve', close = 'report.resolve', reopen = 'report.resolve',
}

RegisterNetEvent('staff_suite:ticketAction', function(id, action, extra)
  local src = source
  local player = getPlayer(src)
  local cap = ticketActionCaps[action]
  if not cap or not can(player, cap) then return end
  local ticket, ev = tickets.transition(store, id, action, actorId(player, src), extra)
  if not ticket then TriggerClientEvent('staff_suite:notify', src, t(ev or 'invalid_transition')); return end
  record(ev.action, ev.actor, 'ticket:' .. id, ev.reason, { from = ev.from, to = ev.to })
  if can(player, 'report.view') then
    TriggerClientEvent('staff_suite:state', src, { tickets = store.tickets })
  end
end)

RegisterNetEvent('staff_suite:modAction', function(action, tgt, reason)
  local src = source
  local ok, err = doMod(src, action, tgt, reason)
  if not ok then TriggerClientEvent('staff_suite:notify', src, err) end
end)

RegisterNetEvent('staff_suite:verify', function()
  local src = source
  local player = getPlayer(src)
  if not can(player, 'audit.verify') then return end
  local ok, at = audit.verify(chain)
  record('audit_verify', actorId(player, src), '', ok and 'ok' or ('broken:' .. tostring(at)), {})
  TriggerClientEvent('staff_suite:auditResult', src, { ok = ok, at = at, n = #chain.entries })
end)

-- ===== Captura de comandos de admin (best-effort) =====
if Config.Audit.capture_commands then
  for _, cmd in ipairs({ 'ban', 'kick', 'warn', 'giveitem', 'givemoney', 'setjob' }) do
    RegisterCommand(cmd, function(src, args)
      if src == 0 then return end
      record('cmd_' .. cmd, getIdentifier(src), args[1] or '', table.concat(args, ' ', 2), { args = args })
    end, true)  -- restricted: solo si ya existe el comando con permisos
  end
end

-- ===== Exports (para test resource E2E + otros recursos) =====
exports('Record', record)
exports('Verify', function() return audit.verify(chain) end)
exports('GetChain', function() return chain.entries end)
exports('CreateTicket', function(data) local tk, ev = tickets.create(store, data); record(ev.action, ev.actor, ev.target, '', { ticket = tk.id }); return tk.id end)
exports('TicketAction', function(id, action, actor, extra)
  local ticket, ev = tickets.transition(store, id, action, actor, extra)
  if ticket and ev then record(ev.action, ev.actor, 'ticket:' .. id, ev.reason, { from = ev.from, to = ev.to }) end
  return ticket, ev
end)
exports('GetState', snapshot)

-- ===== Init =====
CreateThread(function()
  if Config.Persistence == 'oxmysql' and persist.db_ready() then
    persist.init_schema(function() persist.load_db(restore) end)
  else
    restore(persist.load_json(Config.JsonFile))
  end
  print(('[StaffSuite] iniciado · %d entradas de auditoría · persistencia=%s · framework=%s')
    :format(#chain.entries, Config.Persistence, bridges.select(Config)))
end)

-- Guardado periódico + al apagar
CreateThread(function()
  while true do Wait(60000); save() end
end)
AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() then save() end
end)
