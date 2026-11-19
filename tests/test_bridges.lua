-- Bridges y wiring del adapter sin levantar FiveM.
local perms = require('core.permissions')
local T = {}

local function sandbox()
  local states, ace = {}, {}
  local env = setmetatable({
    exports = {},
    GetConvar = function(_, default) return default end,
    GetResourceState = function(resource) return states[resource] or 'missing' end,
    GetPlayerIdentifiers = function() return { 'steam:17', 'license:account17' } end,
    GetPlayerName = function() return 'Nombre FiveM' end,
    IsPlayerAceAllowed = function(_, object) return ace[object] == true end,
  }, { __index = _G })
  env.require = function(name)
    local path = name:gsub('%.', '/') .. '.lua'
    return assert(loadfile(path, 't', env))()
  end
  assert(loadfile('config.lua', 't', env))()
  return env, states, ace
end

function T.test_standalone_ace_and_native_identity()
  local env, _, ace = sandbox()
  local bridge = env.require('server.bridges.init')
  ace.admin = true
  local player = bridge.resolve(17, env.Config)
  assert(player.rank == nil and player.identifier == 'license:account17')
  assert(player.name == 'Nombre FiveM')

  ace['staff_suite.helper'], ace['staff_suite.senior_admin'] = true, true
  assert(bridge.resolve(17, env.Config).rank == 'senior_admin')
  ace['staff_suite.senior_admin'] = nil
  assert(bridge.resolve(17, env.Config).rank == 'helper')
  env.Config.StandaloneRanks = { ['license:account17'] = 'admin' }
  assert(bridge.resolve(17, env.Config).rank == 'admin')

  env.GetPlayerIdentifiers = function() return { 'steam:17', 'license2:secondary17' } end
  assert(bridge.resolve(17, env.Config).identifier == 'license2:secondary17')
  env.GetPlayerIdentifiers = function() return { 'steam:17' } end
  assert(bridge.resolve(17, env.Config).identifier == 'steam:17')
  env.GetPlayerIdentifiers = function() return {} end
  env.GetPlayerName = function() return nil end
  player = bridge.resolve(17, env.Config)
  assert(player.identifier == nil and player.name == 'player 17')
end

function T.test_esx_groups_jobs_and_identity()
  local env, states = sandbox()
  local group = 'user'
  states.es_extended = 'started'
  env.exports.es_extended = {
    getSharedObject = function()
      return {
        GetPlayerFromId = function(src)
          assert(src == 17)
          return {
            getIdentifier = function() return 'char1:account17' end,
            getName = function() return 'Personaje ESX' end,
            getGroup = function() return group end,
            getJob = function() return { name = 'ambulance' } end,
          }
        end,
      }
    end,
  }
  local bridge = env.require('server.bridges.init')
  local player = bridge.resolve('17', env.Config)
  assert(player.identifier == 'license:account17' and player.name == 'Personaje ESX')
  assert(player.rank == nil, 'los jobs comunes no dan acceso por defecto')

  env.Config.JobRankMap.esx.ambulance = 'helper'
  assert(bridge.resolve(17, env.Config).rank == 'helper')
  group = 'superadmin'
  assert(bridge.resolve(17, env.Config).rank == 'senior_admin')
  env.GetPlayerIdentifiers = function() return {} end
  assert(bridge.resolve(17, env.Config).identifier == 'char1:account17')
end

function T.test_qbcore_permissions_and_current_job()
  local env, states = sandbox()
  local permissions = { god = true, admin = true, mod = true, custom = true }
  local data = { license = 'license:qb17', charinfo = { firstname = 'Alex' }, job = { name = 'security' } }
  states['qb-core'] = 'started'
  env.GetPlayerIdentifiers = function() return {} end
  env.exports['qb-core'] = {
    GetCoreObject = function()
      return { Functions = {
        GetPlayer = function() return data and { PlayerData = data } end,
        HasPermission = function(src, label)
          assert(src == 17)
          return permissions[label] == true
        end,
      } }
    end,
  }
  env.Config.RankMap.custom = 'rango_inexistente'
  local bridge = env.require('server.bridges.init')
  local player = bridge.resolve(17, env.Config)
  assert(player.rank == 'owner' and player.identifier == 'license:qb17' and player.name == 'Alex')
  permissions.god = nil
  env.Config.RankMap.admin = 'helper'
  assert(bridge.resolve(17, env.Config).rank == 'moderator', 'respeta RankMap y la jerarquía del core')
  env.Config.JobRankMap.qbcore.security = 'admin'
  assert(bridge.resolve(17, env.Config).rank == 'admin')
  data.job.name = 'unemployed'
  assert(bridge.resolve(17, env.Config).rank == 'moderator')
  data = nil
  player = bridge.resolve(17, env.Config)
  assert(player.rank == nil and player.name == 'Nombre FiveM')
end

function T.test_qbox_native_export_and_ace()
  local env, states, ace = sandbox()
  states.qbx_core, states['qb-core'], states.es_extended = 'started', 'started', 'started'
  env.GetPlayerIdentifiers = function() return {} end
  env.exports.qbx_core = {
    GetPlayer = function(_, src)
      assert(src == 17)
      return { PlayerData = {
        license = 'license:qbox17',
        charinfo = { firstname = 'Alex', lastname = 'RP' },
        job = { name = 'mechanic' },
      } }
    end,
  }
  ace.mod, ace.support = true, true
  local bridge = env.require('server.bridges.init')
  assert(bridge.select(env.Config) == 'qbox')
  local player = bridge.resolve(17, env.Config)
  assert(player.rank == 'moderator' and player.name == 'Alex RP' and player.identifier == 'license:qbox17')
  env.Config.JobRankMap.qbox.mechanic = 'admin'
  assert(bridge.resolve(17, env.Config).rank == 'admin')
  ace['staff_suite.owner'] = true
  env.Config.Framework = 'standalone'
  assert(bridge.resolve(17, env.Config).rank == 'owner')
end

function T.test_detection_and_unavailable_framework()
  local env, states, ace = sandbox()
  local bridge = env.require('server.bridges.init')
  assert(bridge.select(env.Config) == 'standalone')
  states.es_extended = 'started'
  assert(bridge.select(env.Config) == 'esx')
  states['qb-core'] = 'started'
  assert(bridge.select(env.Config) == 'qbcore')
  states.qbx_core = 'started'
  assert(bridge.select(env.Config) == 'qbox')
  states.qbx_core = 'stopped'
  assert(bridge.select(env.Config) == 'qbcore')

  ace['staff_suite.owner'] = true
  env.Config.Framework = 'qbox'
  assert(bridge.select(env.Config) == 'qbox')
  local player = bridge.resolve(17, env.Config)
  assert(player.rank == nil and player.identifier == 'license:account17')
  states.qbx_core = 'started' -- El resource figura iniciado, pero el export todavía no está disponible.
  assert(bridge.resolve(17, env.Config).rank == nil)
end

local function readManifest()
  local manifest = {}
  local directives = setmetatable({
    shared_scripts = function(scripts) manifest.shared = scripts end,
    client_scripts = function(scripts) manifest.client = scripts end,
    server_scripts = function(scripts) manifest.server = scripts end,
    files = function(paths) manifest.files = paths end,
  }, { __index = function() return function() end end })
  assert(loadfile('fxmanifest.lua', 't', directives))()
  return manifest
end

function T.test_webhook_and_identifier_allowlist_only_loaded_on_server()
  local manifest = readManifest()
  local env = sandbox()
  local convar_reads = 0
  local webhook = 'https://example.invalid/webhook'
  env.GetConvar = function(name)
    assert(name == 'staff_suite_webhook')
    convar_reads = convar_reads + 1
    return webhook
  end
  for _, paths in ipairs({ manifest.shared, manifest.client, manifest.files }) do
    for _, path in ipairs(paths) do assert(path ~= 'server/config.lua') end
  end
  for _, path in ipairs(manifest.shared) do assert(loadfile(path, 't', env))() end
  assert(env.Config.Export == nil and env.Config.StandaloneRanks == nil and convar_reads == 0)
  assert(manifest.server[1] == 'server/config.lua')
  assert(loadfile(manifest.server[1], 't', env))()
  assert(env.Config.Export.webhook == webhook and convar_reads == 1)
end

local function clone(value)
  if type(value) ~= 'table' then return value end
  local copy = {}
  for key, item in pairs(value) do copy[key] = clone(item) end
  return copy
end

local function serverSandbox(options)
  options = options or {}
  local env, states, ace = sandbox()
  local events, commands, api, sent, recipients, payloads = {}, {}, {}, {}, {}, {}
  local threads, reads, hooks, timers = {}, {}, {}, {}
  local files = options.files or {}
  local server
  states.qbx_core = 'started'
  env.exports.qbx_core = {
    GetPlayer = function()
      return { PlayerData = { charinfo = { firstname = 'Alex', lastname = 'RP' } } }
    end,
  }
  setmetatable(env.exports, { __call = function(_, name, handler) api[name] = handler end })
  env.RegisterNetEvent = function(name, handler) events[name] = handler end
  env.RegisterCommand = function(name, handler) commands[name] = handler end
  env.TriggerClientEvent = function(event, src, data, ...)
    sent[event] = data
    recipients[src] = recipients[src] or {}
    recipients[src][event] = data
    server.lastClientEvent = { event, src, data, ... }
  end
  env.AddEventHandler = function(name, fn)
    hooks[name] = hooks[name] or {}
    hooks[name][#hooks[name] + 1] = fn
  end
  env.GetInvokingResource = function() return server.invoker end
  env.CreateThread = function(handler) threads[#threads + 1] = handler end
  env.SetTimeout = function(_, handler) timers[#timers + 1] = handler end
  env.GetPlayerIdentifiers = function(src)
    local identifier = server.identifiers[tostring(src)]
    return identifier == false and {} or { identifier or ('license:account' .. src) }
  end
  local online = { ['17'] = true, ['18'] = true, ['19'] = true }
  env.GetPlayers = function()
    local players = {}
    for src in pairs(online) do players[#players + 1] = src end
    return players
  end
  env.GetPlayerName = function(src) return online[tostring(src)] and 'Alex RP' end
  server = {
    env = env, ace = ace, api = api, sent = sent, recipients = recipients,
    event = function(name, ...) return events['staff_suite:' .. name](...) end,
    hook = function(name, ...)
      for _, fn in ipairs(hooks[name] or {}) do fn(...) end
    end,
    commands = commands, online = online, payloads = payloads,
    threads = threads, timers = timers, reads = reads, states = states, identifiers = {}, files = files, now = 10000,
  }
  env.GetPlayerPed = function(src) return online[tostring(src)] and src * 10 or 0 end
  env.GetEntityCoords = function(ped) return { x = ped, y = 0, z = 0 } end
  server.buckets = {}
  env.GetPlayerRoutingBucket = function(src) return server.buckets[src] or 0 end
  env.DropPlayer = function(src, reason) server.kicked, server.kickReason = src, reason end
  env.CancelEvent = function() server.cancelled = true end
  env.os = setmetatable({ time = function() return server.now end }, { __index = os })
  env.GetCurrentResourceName = function() return 'staff_suite' end
  env.LoadResourceFile = function(_, path)
    assert(not path:lower():match('%.lua$'), 'LoadResourceFile intentó leer código Lua: ' .. path)
    reads[#reads + 1] = path
    if files[path] then return path end
  end
  env.SaveResourceFile = function(_, path, data)
    if server.failWrites then return false end
    if path == env.Config.JsonFile then files[path] = clone(payloads[tonumber(data)]) end
    return true
  end
  env.json = { encode = function(value)
    payloads[#payloads + 1] = value
    return tostring(#payloads)
  end, decode = function(path) return clone(files[path]) end }
  env.require = function(name) error('require no está disponible en FiveM: ' .. name) end
  env.print = function() end
  local manifest = readManifest()
  for _, scripts in ipairs({ manifest.shared, manifest.server }) do
    for _, path in ipairs(scripts) do
      if path == 'server/main.lua' and options.setup then options.setup(server) end
      assert(loadfile(path, 't', env))()
    end
  end

  env.source = 17
  if not options.deferBoot then threads[1]() end
  return server
end

function T.test_server_boots_from_manifest_without_reading_lua()
  local s = serverSandbox({ deferBoot = true })
  assert(#s.reads == 0)
  s.threads[1]()
  s.env.Config.Export.anchor_every = 1
  s.commands.report(17, { 'bug', 'prueba de arranque' })
  assert(s.api.Verify())
  assert(#s.reads == 2 and s.reads[1] == s.env.Config.JsonFile and s.reads[2] == 'audit_export.log')

  local ok, err = pcall(s.env.StaffSuiteModules.loadmod, 'core.no_registrado')
  assert(not ok and err:find('core.no_registrado', 1, true) and #s.reads == 2)
end

function T.test_server_enforces_mapped_capabilities_and_overrides()
  local server = serverSandbox()
  local ace, commands, api, sent = server.ace, server.commands, server.api, server.sent
  local event = server.event
  commands.report(17, { 'bug', 'reporte de prueba' })
  assert(api.GetState().tickets.tickets[1].reporter == 'license:account17')
  event('getState')
  local state = sent['staff_suite:state']
  assert(state.player.rank == 'player' and state.player.name == 'Alex RP')
  assert(next(state.tickets) == nil and next(state.audit) == nil and next(state.duty) == nil)
  assert(#state.player.capabilities == 0)
  event('verify')
  commands.duty(17)
  assert(sent['staff_suite:auditResult'] == nil and next(api.GetState().duty.staff) == nil)
  event('ticketAction', 1, 'claim')
  assert(api.GetState().tickets.tickets[1].state == 'open')

  ace.support = true
  event('getState')
  state = sent['staff_suite:state']
  assert(state.player.rank == 'helper' and state.tickets[1] and next(state.audit) == nil)
  event('modAction', 'kick', 18, 'regla del servidor')
  assert(server.kicked == nil)
  event('ticketAction', 1, 'claim')
  event('ticketAction', 1, 'resolve')
  assert(api.GetState().tickets.tickets[1].state == 'claimed')

  ace.admin = true
  perms.revoke(api.GetState().perms, 'license:account17', 'audit.view')
  event('getState')
  state = sent['staff_suite:state']
  assert(state.player.rank == 'admin' and next(state.audit) == nil and next(state.verify) == nil)
  perms.grant(api.GetState().perms, 'license:account17', 'audit.view')
  event('getState')
  assert(sent['staff_suite:state'].audit[1].actor == 'license:account17')
  local capabilities = table.concat(sent['staff_suite:state'].player.capabilities, ',')
  for _, action in ipairs({ 'ban', 'warn', 'spectate', 'revive' }) do
    assert(capabilities:find('mod.' .. action, 1, true))
  end
  event('ticketAction', 1, 'resolve')
  assert(api.GetState().tickets.tickets[1].state == 'resolved')
  event('modAction', 'kick', 18, 'regla del servidor')
  assert(server.kicked == 18 and api.GetChain()[#api.GetChain()].target == 'license:account18')
end

function T.test_ticket_message_permissions_and_audit()
  local s = serverSandbox()
  local id = s.api.CreateTicket({ reporter = 'license:account19', category = 'bug' })
  s.api.TicketAction(id, 'claim', 'license:account18')
  local ticket = s.api.GetState().tickets.tickets[1]
  s.env.source = 19
  s.event('ticketMessage', 1, 'nota del jugador', true)
  s.event('ticketMessage', 1, 'sin permiso', false)
  assert(#ticket.messages == 0 and #s.api.GetChain() == 2)

  s.env.source = 17
  s.ace.support = true
  s.event('ticketMessage', 1, ' ', false)
  s.event('ticketMessage', 1, 'nota mal tipada', 'true')
  s.event('ticketMessage', 9, 'ticket inexistente', false)
  assert(#s.api.GetChain() == 2)
  s.event('ticketMessage', 1, 'Respuesta', false)
  s.event('ticketMessage', 1, 'Nota interna', true)
  assert(#ticket.messages == 2 and ticket.messages[1].body == 'Respuesta' and not ticket.messages[1].internal)
  assert(ticket.messages[2].author == 'license:account17' and ticket.messages[2].internal)
  local entries = s.api.GetChain()
  assert(#entries == 4 and entries[3].action == 'ticket_message')
  assert(entries[4].actor == 'license:account17' and entries[4].target == 'ticket:1')
  assert(s.payloads[tonumber(entries[4].payload)].internal == true)
  for _, src in ipairs({ 17, 18 }) do
    assert(s.recipients[src]['staff_suite:state'].tickets[1].messages[2].body == 'Nota interna')
  end
  assert(not s.recipients[19]['staff_suite:state'])

  perms.revoke(s.api.GetState().perms, 'license:account17', 'report.message')
  s.event('ticketMessage', 1, 'nota revocada', true)
  assert(#ticket.messages == 2)
  s.ace.support = nil
  s.env.source = 19
  s.event('getState')
  assert(next(s.sent['staff_suite:state'].tickets) == nil)
end

function T.test_moderation_resolves_connected_identifier()
  local s = serverSandbox()
  s.ace.admin = true
  s.event('modAction', 'kick', 'license:account18', 'regla')
  local entries = s.api.GetChain()
  assert(s.kicked == 18 and #entries == 1 and entries[1].target == 'license:account18')
  s.online['18'], s.kicked = nil, nil
  s.event('modAction', 'kick', 'license:account18', 'regla')
  assert(not s.kicked and #entries == 1 and s.sent['staff_suite:notify'] == s.env.Locale.es.mod_invalid_target)
end

function T.test_warn_requires_reason_permission_and_durable_audit()
  local s = serverSandbox()
  s.event('modAction', 'warn', 18, 'regla')
  assert(#s.api.GetChain() == 0 and not s.recipients[18])
  s.ace.mod = true
  s.env.Config.Moderation.require_reason = false
  s.event('modAction', 'warn', 18, '   ')
  assert(s.sent['staff_suite:notify'] == s.env.Locale.es.reason_required and #s.api.GetChain() == 0)
  s.event('modAction', 'warn', 'license:account18', '  regla del servidor ')
  local chain = s.files[s.env.Config.JsonFile].chain
  assert(chain.entries[1].action == 'mod_warn' and chain.entries[1].reason == 'regla del servidor')
  assert(s.recipients[18]['staff_suite:notify']:find('regla del servidor', 1, true))
  assert(s.api.Verify())
  s.failWrites = true
  s.event('modAction', 'warn', 19, 'fallo de escritura')
  assert(not s.recipients[19] and s.recipients[17]['staff_suite:notify'] == s.env.Locale.es.mod_save_failed)
end

function T.test_ban_persists_before_drop_and_checks_expiration_on_reconnect()
  local s = serverSandbox()
  s.ace.mod = true
  s.event('modAction', 'ban', 18, 'regla', 60)
  assert(#s.api.GetChain() == 0 and not s.kicked)
  s.ace.admin = true
  s.event('modAction', 'ban', 18, '  ', 60)
  assert(s.sent['staff_suite:notify'] == s.env.Locale.es.reason_required)
  s.event('modAction', 'ban', 18, 'regla', -1)
  assert(s.sent['staff_suite:notify'] == s.env.Locale.es.ban_invalid_duration)
  assert(#s.api.GetChain() == 0 and not s.kicked)

  s.event('modAction', 'ban', 18, 'regla', 60)
  local saved = s.files[s.env.Config.JsonFile]
  assert(s.kicked == 18 and s.kickReason:find('regla', 1, true))
  assert(saved.bans['license:account18'].expires_at == 10060)
  assert(saved.chain.entries[1].action == 'mod_ban' and s.api.Verify())

  local reboot = serverSandbox({ files = s.files, deferBoot = true })
  reboot.env.source, reboot.identifiers['42'] = 42, 'license:account18'
  local reason
  local function connecting()
    reason, reboot.cancelled = nil, false
    reboot.hook('playerConnecting', '', function(message) reason = message end)
  end
  connecting()
  assert(reboot.cancelled and reason == reboot.env.Locale.es.persistence_starting)
  reboot.threads[1]()
  connecting()
  assert(reboot.cancelled and reason:find('regla', 1, true))
  reboot.now = 10060
  connecting()
  assert(not reboot.cancelled and reason == nil)

  s.event('modAction', 'ban', 19, 'perma', 0)
  assert(s.api.GetState().bans['license:account19'].expires_at == 0)
  s.env.source = 19
  s.now = 10000000
  s.hook('playerConnecting', '', function(message) reason = message end)
  assert(s.cancelled and reason:find('perma', 1, true))
end

function T.test_failed_ban_does_not_block_connections_or_return_on_retry()
  local s = serverSandbox()
  s.ace.admin = true
  s.failWrites = true
  s.event('modAction', 'ban', 18, 'regla', 60)
  assert(s.recipients[17]['staff_suite:notify'] == s.env.Locale.es.mod_save_failed)
  assert(not s.kicked and not s.api.GetState().bans['license:account18'])
  s.env.source = 18
  s.hook('playerConnecting', '', function() error('un ban fallido no debe bloquear la conexión') end)
  assert(not s.cancelled)

  s.failWrites = false
  s.timers[1]()
  local saved = s.files[s.env.Config.JsonFile]
  assert(not saved.bans['license:account18'])
  assert(saved.chain.entries[2].action == 'mod_ban_failed' and s.api.Verify())
end

function T.test_revive_dispatches_framework_bridge_or_standalone()
  local s = serverSandbox()
  local called
  s.states.qbx_medical = 'started'
  s.env.exports.qbx_medical = { Revive = function(_, src) called = src end }
  s.event('modAction', 'revive', 18)
  assert(not called and #s.api.GetChain() == 0)
  s.ace.admin = true
  s.event('modAction', 'revive', 18)
  assert(called == 18 and s.api.GetChain()[1].action == 'mod_revive')

  s.env.Config.Framework, s.states.es_extended, s.states.esx_death = 'esx', 'started', 'started'
  s.env.exports.es_extended = { getSharedObject = function()
    return { GetPlayerFromId = function()
      return { getGroup = function() return 'admin' end, getJob = function() return nil end,
        getName = function() return 'RP' end, getIdentifier = function() return 'account' end }
    end }
  end }
  s.env.exports.esx_death = { Revive = function(_, src, via)
    assert(via == 'staff_suite')
    called = src
    return false
  end }
  s.event('modAction', 'revive', 19)
  assert(called == 19 and #s.api.GetChain() == 1)
  s.states.esx_death, s.states.esx_ambulancejob = 'missing', 'started'
  s.event('modAction', 'revive', 19)
  assert(s.lastClientEvent[1] == 'esx_ambulancejob:revive' and s.lastClientEvent[2] == 19)
  s.states.esx_ambulancejob = 'missing'
  s.event('modAction', 'revive', 19)
  assert(s.lastClientEvent[1] == 'staff_suite:revive' and s.lastClientEvent[2] == 19)

  s.env.Config.Framework, s.states['qb-core'], s.states['qb-ambulancejob'] = 'qbcore', 'started', 'started'
  s.env.exports['qb-core'] = { GetCoreObject = function()
    return { Functions = {
      GetPlayer = function() return { PlayerData = {} } end,
      HasPermission = function(_, group) return group == 'admin' end,
    } }
  end }
  s.event('modAction', 'revive', 18)
  assert(s.lastClientEvent[1] == 'hospital:client:Revive' and s.lastClientEvent[2] == 18)
  assert(#s.api.GetChain() == 4 and s.api.Verify())
end

function T.test_spectate_only_dispatches_to_authorized_observer()
  local s = serverSandbox()
  s.event('modAction', 'spectate', 18)
  assert(s.lastClientEvent[1] ~= 'staff_suite:spectate')
  s.ace.mod, s.buckets[18] = true, 1
  s.event('modAction', 'spectate', 18)
  assert(s.sent['staff_suite:notify'] == s.env.Locale.es.spectate_unavailable)
  s.event('modAction', 'spectate', 17)
  assert(#s.api.GetChain() == 0)
  s.buckets[18] = 0
  s.event('modAction', 'spectate', 'license:account18')
  local sent = s.lastClientEvent
  assert(sent[1] == 'staff_suite:spectate' and sent[2] == 17 and sent[3] == 18 and sent[4].x == 180)
  assert(s.api.GetChain()[1].action == 'mod_spectate' and s.api.Verify())
end

function T.test_capture_honors_config_and_only_accepts_documented_server_senders()
  local off = serverSandbox({ setup = function(s) s.env.Config.Audit.capture_framework = false end })
  off.invoker = 'monitor'
  off.hook('txAdmin:events:playerKicked', { author = 'staff', target = 18, reason = 'test' })
  assert(#off.api.GetChain() == 0)

  local s = serverSandbox()
  s.env.Config.Framework = 'esx'
  s.hook('esx:setGroup', 18, 'admin', 'user')
  s.invoker = 'other-resource'
  s.hook('esx:setGroup', 18, 'admin', 'user')
  s.invoker = 'es_extended'
  s.hook('esx:setGroup', nil, 'admin', 'user')
  s.hook('esx:onAddInventoryItem', 18, 'item', 'bad count')
  assert(#s.api.GetChain() == 0 and s.commands.ban == nil)
  s.hook('esx:setGroup', 18, 'admin', 'user')
  s.hook('esx:setJob', 18, { name = 'police', grade = 2 })
  s.hook('esx:addAccountMoney', 18, 'bank', 123, 'grant')
  s.hook('esx:onAddInventoryItem', 18, 'bread', 10)
  s.env.Config.Framework, s.invoker = 'qbcore', 'qb-core'
  s.hook('QBCore:Server:OnPlayerUpdated', 18, 'job', { name = 'mechanic', grade = { level = 4 } })
  s.hook('QBCore:Server:OnMoneyChange', 18, 'cash', 3, 'remove', 'purchase')
  s.hook('QBCore:Server:OnMoneyChange', 18, 'cash', 5, 'add', 'gift')
  s.env.Config.Framework, s.invoker = 'qbox', 'qbx_core'
  s.hook('qbx_core:server:onGroupUpdate', 19, 'police')
  s.hook('QBCore:Server:OnMoneyChange', 19, 'bank', 7, 'set')
  s.env.Config.Framework, s.invoker = 'standalone', 'monitor'
  s.hook('txAdmin:events:playerBanned', {
    author = 'operator', targetIds = { 'license:offline' }, actionId = 'B12', reason = 'regla', expiration = false,
  })
  s.hook('txAdmin:events:playerKicked', { author = 'operator', target = -1 })
  s.hook('txAdmin:events:playerWarned', { author = 'operator', targetNetId = 18 })
  s.hook('txAdmin:events:playerHealed', { author = 'operator', target = 18 })
  local entries = s.api.GetChain()
  assert(#entries == 12 and s.api.Verify())
  assert(entries[1].action == 'framework_group' and entries[1].actor == 'system')
  assert(entries[3].action == 'framework_money' and entries[3].reason == 'grant')
  assert(entries[5].target == 'license:account18' and s.payloads[tonumber(entries[5].payload)].grade == 4)
  assert(s.payloads[tonumber(entries[7].payload)].removed == true)
  assert(s.payloads[tonumber(entries[8].payload)].framework == 'qbox')
  assert(entries[9].action == 'txadmin_ban' and entries[9].actor == 'txAdmin:operator')
  assert(entries[9].target == 'license:offline' and s.payloads[tonumber(entries[9].payload)].expiration == false)
  assert(entries[10].target == 'all' and entries[11].action == 'txadmin_warn' and entries[12].action == 'txadmin_heal')
end

function T.test_state_includes_identity_capabilities_duty_and_alerts()
  local s = serverSandbox()
  s.ace.support = true
  s.commands.duty(17)
  s.event('getState')
  local state = s.sent['staff_suite:state']
  assert(state.player.identifier == 'license:account17' and state.player.name == 'Alex RP')
  assert(state.dutySelf.on_duty and next(state.duty) == nil and next(state.alerts) == nil)
  local caps = {}
  for _, cap in ipairs(state.player.capabilities) do caps[cap] = true end
  assert(caps['staff.duty'] and caps['report.message'] and not caps['staff.analytics'])

  s.env.source = 18
  s.ace.admin = true
  s.api.GetChain()[1].reason = 'alterado'
  s.event('getState')
  state = s.sent['staff_suite:state']
  assert(state.player.identifier == 'license:account18' and not state.dutySelf.on_duty)
  assert(state.duty[1].actor == 'license:account17' and state.duty[1].on_duty)
  assert(state.alerts[1].kind == 'audit_chain_broken' and state.alerts[1].vars.seq == 1)
  perms.revoke(s.api.GetState().perms, 'license:account18', 'audit.view')
  s.event('getState')
  assert(next(s.sent['staff_suite:state'].alerts) == nil)
end

function T.test_state_lists_transfer_targets_without_analytics()
  local s = serverSandbox()
  s.env.Config.Framework = 'standalone'
  s.env.Config.StandaloneRanks = {
    ['license:account17'] = 'moderator',
    ['license:account18'] = 'helper',
    ['license:account19'] = 'helper',
    ['license:account20'] = 'helper',
    ['license:account21'] = 'helper',
  }
  s.online['21'] = true
  local permissions = s.api.GetState().perms
  perms.revoke(permissions, 'license:account19', 'report.view')
  perms.revoke(permissions, 'license:account21', 'report.claim')

  s.event('getState')
  local state = s.sent['staff_suite:state']
  assert(state.player.rank == 'moderator' and next(state.duty) == nil)
  assert(#state.transferTargets == 2)
  local names = {}
  for _, target in ipairs(state.transferTargets) do
    names[target.identifier] = target.name
    assert(target.rank == nil)
  end
  assert(names['license:account17'] == 'Alex RP' and names['license:account18'] == 'Alex RP')

  s.env.source = 18
  s.event('getState')
  assert(next(s.sent['staff_suite:state'].transferTargets) == nil)
  s.env.source = 17
  perms.revoke(permissions, 'license:account17', 'report.resolve')
  s.event('getState')
  assert(next(s.sent['staff_suite:state'].transferTargets) == nil)
end

function T.test_state_reports_export_flags_without_webhook_url()
  local s = serverSandbox()
  s.event('getState')
  local state = s.sent['staff_suite:state']
  assert(state.exportStatus.webhook == false and state.exportStatus.file == true)
  assert(state.player.rank == 'player')

  local webhook = 'https://example.invalid/private-webhook'
  s.env.Config.Export.webhook = webhook
  s.env.Config.Export.file = false
  s.event('getState')
  state = s.sent['staff_suite:state']
  assert(state.exportStatus.webhook == true and state.exportStatus.file == false)
  for key, value in pairs(state.exportStatus) do
    assert((key == 'file' or key == 'webhook') and type(value) == 'boolean')
  end
  assert(not state.export and not state.webhook)
end

function T.test_ticket_transfer_assigns_eligible_recipient()
  local s = serverSandbox()
  s.ace.admin = true
  s.commands.report(19, { 'bug', 'reporte' })
  s.event('ticketAction', 1, 'claim')
  local ticket = s.api.GetState().tickets.tickets[1]
  perms.revoke(s.api.GetState().perms, 'license:account19', 'report.claim')
  s.event('ticketAction', 1, 'transfer', { to = 'license:account19' })
  s.event('ticketAction', 1, 'transfer', { to = 'license:offline' })
  s.event('ticketAction', 1, 'transfer', {})
  assert(ticket.claimer == 'license:account17' and #s.api.GetChain() == 2)
  assert(not s.recipients[18])
  s.event('ticketAction', 1, 'transfer', { to = 'license:account18' })
  local entry = s.api.GetChain()[3]
  assert(ticket.claimer == 'license:account18' and entry.actor == 'license:account17')
  assert(s.payloads[tonumber(entry.payload)].assigned_to == 'license:account18')
  assert(s.recipients[18]['staff_suite:state'].tickets[1].claimer == 'license:account18')

  perms.revoke(s.api.GetState().perms, 'license:account19', 'report.view')
  perms.grant(s.api.GetState().perms, 'license:account19', 'report.claim')
  s.recipients[19] = nil
  s.event('ticketAction', 1, 'transfer', { to = 'license:account19' })
  assert(ticket.claimer == 'license:account18' and not s.recipients[19] and #s.api.GetChain() == 3)
end

function T.test_ticket_create_preserves_priority()
  local s = serverSandbox()
  s.event('ticketCreate', 'bug', 'urgent', 'El problema sigue')
  s.event('ticketCreate', 'bug', 'inventada', 'Otro problema')
  s.event('ticketCreate', 'bug', 'high', ' ')
  s.commands.report(17, { 'bug', 'high', 'como parte del texto' })
  local tickets = s.api.GetState().tickets.tickets
  assert(tickets[1].priority == 'urgent' and tickets[1].reporter == 'license:account17')
  assert(tickets[2].priority == 'normal' and tickets[3].priority == 'normal' and not tickets[4])
  assert(tickets[3].description == 'high como parte del texto')
  assert(s.payloads[tonumber(s.api.GetChain()[1].payload)].priority == 'urgent')
  assert(not s.sent['staff_suite:state'], 'crear un reporte no da acceso a la cola')
end

local function perSourceAce(s, bySource)
  s.env.IsPlayerAceAllowed = function(src, label)
    local own = bySource[tonumber(src)]
    if own then return own[label] == true end
    return s.ace[label] == true
  end
end

function T.test_malformed_inputs_do_not_crash_or_mutate_state()
  local s = serverSandbox()
  s.ace.god = true
  local junk = { nil, true, 1e308, -1, 0 / 0, {}, { x = 1 }, string.rep('x', 200000), function() end }
  local events = { 'ticketCreate', 'ticketAction', 'ticketMessage', 'modAction', 'getState', 'verify' }
  for _, name in ipairs(events) do
    for i = 1, #junk + 1 do
      s.now = s.now + 60
      local a = junk[i]
      s.event(name, a, a, a, a)
      s.event(name, 1, a, a, a)
    end
  end
  assert(next(s.api.GetState().tickets.tickets) == nil and not s.kicked)
  for _, a in ipairs({ 'x', 5, {}, true }) do
    assert(s.api.CreateTicket(a) == nil)
    assert(s.api.TicketAction(a, a, a, a) == nil)
    assert(s.api.Record(a, a, a, a, a) == nil or type(a) == 'string' or type(a) == 'number')
    assert(s.api.SetDuty(a, a) == nil)
  end
  assert(s.api.Record('a', 'b', string.rep('r', 5000), '', {}) == nil)
  assert(s.api.Verify())
end

function T.test_ticket_text_limits_and_control_chars()
  local s = serverSandbox()
  local limits = s.env.Config.Limits
  s.event('ticketCreate', 'bug', 'high', string.rep('a', limits.ticket_body + 1))
  assert(next(s.api.GetState().tickets.tickets) == nil)
  assert(s.sent['staff_suite:notify'] == s.env.StaffSuiteTranslate('input_too_long', { max = limits.ticket_body }))
  s.event('ticketCreate', 'bug', 'high', '  hola\0\27[31m mundo\n ')
  local ticket = s.api.GetState().tickets.tickets[1]
  assert(ticket.description == 'hola[31m mundo')

  s.ace.support = true
  s.event('ticketMessage', 1, string.rep('b', limits.message_body + 1), false)
  assert(#ticket.messages == 0)
  s.event('ticketMessage', 1, 'ok\1', false)
  assert(ticket.messages[1].body == 'ok')
  s.ace.god = true
  s.event('ticketAction', 1, 'claim')
  s.event('ticketAction', 1, 'resolve', { resolution = string.rep('c', limits.message_body + 1) })
  assert(ticket.state == 'claimed')
end

function T.test_rate_limit_and_open_ticket_cap()
  local s = serverSandbox()
  local cfg = s.env.Config
  for i = 1, cfg.Limits.open_tickets_per_player + 1 do s.event('ticketCreate', 'bug', 'low', 'r' .. i) end
  local n = 0
  for _ in pairs(s.api.GetState().tickets.tickets) do n = n + 1 end
  assert(n == cfg.Limits.open_tickets_per_player)
  assert(s.sent['staff_suite:notify']:find(tostring(cfg.Limits.open_tickets_per_player), 1, true))

  cfg.Limits.open_tickets_per_player = nil
  local burst = cfg.RateLimit['staff_suite:ticketCreate'].burst
  s.env.source = 18
  for i = 1, burst + 3 do s.event('ticketCreate', 'bug', 'low', 'spam' .. i) end
  n = 0
  for _, tk in pairs(s.api.GetState().tickets.tickets) do
    if tk.reporter == 'license:account18' then n = n + 1 end
  end
  assert(n == burst, 'el burst limita la creación, creó ' .. n)
  assert(s.recipients[18]['staff_suite:notify'] == s.env.Locale.es.rate_limited)
  -- el comando /report comparte el mismo bucket
  s.commands.report(18, { 'bug', 'por comando' })
  s.now = s.now + 60
  s.event('ticketCreate', 'bug', 'low', 'después de esperar')
  assert(s.api.GetState().tickets.tickets[n + 4].description == 'después de esperar')
  s.hook('playerDropped')
end

function T.test_only_claimer_or_resolver_starts_or_unclaims()
  local s = serverSandbox()
  perSourceAce(s, { [17] = { support = true }, [18] = { support = true } })
  s.commands.report(19, { 'bug', 'reporte' })
  s.env.source = 18
  s.event('ticketAction', 1, 'claim')
  local ticket = s.api.GetState().tickets.tickets[1]
  s.env.source = 17
  s.event('ticketAction', 1, 'unclaim')
  s.event('ticketAction', 1, 'start')
  assert(ticket.claimer == 'license:account18' and ticket.state == 'claimed')
  assert(s.recipients[17]['staff_suite:notify'] == s.env.Locale.es.already_claimed)
  s.env.source = 18
  s.event('ticketAction', 1, 'start')
  assert(ticket.state ~= 'claimed')
end

function T.test_staff_cannot_moderate_higher_rank()
  local s = serverSandbox()
  perSourceAce(s, { [17] = { admin = true }, [18] = { owner = true } })
  for _, action in ipairs({ 'kick', 'ban', 'warn', 'freeze', 'bring' }) do
    s.event('modAction', action, 18, 'abuso', 60)
    assert(s.sent['staff_suite:notify'] == s.env.Locale.es.mod_target_protected, action)
  end
  assert(not s.kicked and #s.api.GetChain() == 0)
  s.env.source = 18
  s.event('modAction', 'kick', 17, 'regla')
  assert(s.kicked == 17)
end

function T.test_ban_covers_alternate_identifiers_and_extends_on_evasion()
  local s = serverSandbox()
  s.ace.admin = true
  s.env.GetNumPlayerTokens = function(src) return src == 18 and 1 or 0 end
  s.env.GetPlayerToken = function() return '3:hwid18' end
  local ids = { ['18'] = { 'license:account18', 'steam:18', 'discord:18', 'ip:1.2.3.4' } }
  local base = s.env.GetPlayerIdentifiers
  s.env.GetPlayerIdentifiers = function(src) return ids[tostring(src)] or base(src) end
  s.event('modAction', 'ban', 18, 'cheats', 0)
  local saved = s.files[s.env.Config.JsonFile].bans
  for _, id in ipairs({ 'license:account18', 'steam:18', 'discord:18', 'token:3:hwid18' }) do assert(saved[id], id) end
  assert(not saved['ip:1.2.3.4'])

  -- vuelve con license nueva y la misma cuenta de Discord
  ids['50'] = { 'license:nueva', 'license2:nueva2', 'discord:18' }
  s.env.source = 50
  local reason
  s.hook('playerConnecting', '', function(message) reason = message end)
  assert(s.cancelled and reason:find('cheats', 1, true))
  local state = s.api.GetState()
  assert(state.bans['license:nueva'] and state.bans['license2:nueva2'])
  assert(s.api.GetChain()[#s.api.GetChain()].action == 'mod_ban_extended' and s.api.Verify())
end

return T
