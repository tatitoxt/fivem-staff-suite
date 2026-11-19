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

function T.test_webhook_and_identifier_allowlist_only_loaded_on_server()
  local shared, client, server, files
  local manifest = setmetatable({
    shared_scripts = function(scripts) shared = scripts end,
    client_scripts = function(scripts) client = scripts end,
    server_scripts = function(scripts) server = scripts end,
    files = function(paths) files = paths end,
  }, { __index = function() return function() end end })
  assert(loadfile('fxmanifest.lua', 't', manifest))()

  local env = sandbox()
  local convar_reads = 0
  local webhook = 'https://example.invalid/webhook'
  env.GetConvar = function(name)
    assert(name == 'staff_suite_webhook')
    convar_reads = convar_reads + 1
    return webhook
  end
  for _, paths in ipairs({ shared, client, files }) do
    for _, path in ipairs(paths) do assert(path ~= 'server/config.lua') end
  end
  for _, path in ipairs(shared) do assert(loadfile(path, 't', env))() end
  assert(env.Config.Export == nil and env.Config.StandaloneRanks == nil and convar_reads == 0)
  assert(server[1] == 'server/config.lua' and server[2] == 'server/main.lua')
  assert(loadfile(server[1], 't', env))()
  assert(env.Config.Export.webhook == webhook and convar_reads == 1)
end

function T.test_server_enforces_mapped_capabilities_and_overrides()
  local env, states, ace = sandbox()
  local events, commands, api, sent = {}, {}, {}, {}
  local kicked
  states.qbx_core = 'started'
  env.exports.qbx_core = {
    GetPlayer = function()
      return { PlayerData = { charinfo = { firstname = 'Alex', lastname = 'RP' } } }
    end,
  }
  setmetatable(env.exports, { __call = function(_, name, handler) api[name] = handler end })
  env.RegisterNetEvent = function(name, handler) events[name] = handler end
  env.RegisterCommand = function(name, handler) commands[name] = handler end
  env.TriggerClientEvent = function(event, _, data) sent[event] = data end
  env.AddEventHandler = function() end
  env.CreateThread = function() end
  env.GetPlayerIdentifiers = function(src) return { 'license:account' .. src } end
  env.DropPlayer = function(src) kicked = src end
  env.GetCurrentResourceName = function() return 'staff_suite' end
  env.LoadResourceFile = function(_, path)
    local file = assert(io.open(path, 'rb'))
    local data = file:read('a')
    file:close()
    return data
  end
  env.SaveResourceFile = function() end
  env.json = { encode = function() return '{}' end }
  env.load = function(data, chunk, mode) return load(data, chunk, mode, env) end
  assert(loadfile('locales/es.lua', 't', env))()
  assert(loadfile('locales/en.lua', 't', env))()
  assert(loadfile('shared/i18n.lua', 't', env))()
  assert(loadfile('server/config.lua', 't', env))()
  assert(loadfile('server/main.lua', 't', env))()

  env.source = 17
  commands.report(17, { 'bug', 'reporte de prueba' })
  assert(api.GetState().tickets.tickets[1].reporter == 'license:account17')
  events['staff_suite:getState']()
  local state = sent['staff_suite:state']
  assert(state.player.rank == 'player' and state.player.name == 'Alex RP')
  assert(next(state.tickets) == nil and next(state.audit) == nil and next(state.duty) == nil)
  assert(#state.player.capabilities == 0)
  events['staff_suite:verify']()
  commands.duty(17)
  assert(sent['staff_suite:auditResult'] == nil and next(api.GetState().duty.staff) == nil)
  events['staff_suite:ticketAction'](1, 'claim')
  assert(api.GetState().tickets.tickets[1].state == 'open')

  ace.support = true
  events['staff_suite:getState']()
  state = sent['staff_suite:state']
  assert(state.player.rank == 'helper' and state.tickets[1] and next(state.audit) == nil)
  events['staff_suite:modAction']('kick', 18, 'regla del servidor')
  assert(kicked == nil)
  events['staff_suite:ticketAction'](1, 'claim')
  events['staff_suite:ticketAction'](1, 'resolve')
  assert(api.GetState().tickets.tickets[1].state == 'claimed')

  ace.admin = true
  perms.revoke(api.GetState().perms, 'license:account17', 'audit.view')
  events['staff_suite:getState']()
  state = sent['staff_suite:state']
  assert(state.player.rank == 'admin' and next(state.audit) == nil and next(state.verify) == nil)
  perms.grant(api.GetState().perms, 'license:account17', 'audit.view')
  events['staff_suite:getState']()
  assert(sent['staff_suite:state'].audit[1].actor == 'license:account17')
  for _, cap in ipairs(sent['staff_suite:state'].player.capabilities) do
    assert(cap ~= 'mod.ban' and cap ~= 'mod.warn' and cap ~= 'mod.spectate' and cap ~= 'mod.revive')
  end
  local entry_count = #api.GetChain()
  for _, action in ipairs({ 'ban', 'warn', 'spectate', 'revive' }) do
    events['staff_suite:modAction'](action, 18, 'regla del servidor')
    assert(sent['staff_suite:notify'] == env.Locale.es.mod_unavailable)
  end
  assert(#api.GetChain() == entry_count)
  events['staff_suite:ticketAction'](1, 'resolve')
  assert(api.GetState().tickets.tickets[1].state == 'resolved')
  events['staff_suite:modAction']('kick', 18, 'regla del servidor')
  assert(kicked == 18 and api.GetChain()[#api.GetChain()].target == 'license:account18')
end

return T
