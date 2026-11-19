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

local function serverSandbox()
  local env, states, ace = sandbox()
  local events, commands, api, sent, recipients, payloads = {}, {}, {}, {}, {}, {}
  local threads, reads = {}, {}
  states.qbx_core = 'started'
  env.exports.qbx_core = {
    GetPlayer = function()
      return { PlayerData = { charinfo = { firstname = 'Alex', lastname = 'RP' } } }
    end,
  }
  setmetatable(env.exports, { __call = function(_, name, handler) api[name] = handler end })
  env.RegisterNetEvent = function(name, handler) events[name] = handler end
  env.RegisterCommand = function(name, handler) commands[name] = handler end
  env.TriggerClientEvent = function(event, src, data)
    sent[event] = data
    recipients[src] = recipients[src] or {}
    recipients[src][event] = data
  end
  env.AddEventHandler = function() end
  env.CreateThread = function(handler) threads[#threads + 1] = handler end
  env.GetPlayerIdentifiers = function(src) return { 'license:account' .. src } end
  local online = { ['17'] = true, ['18'] = true, ['19'] = true }
  env.GetPlayers = function()
    local players = {}
    for src in pairs(online) do players[#players + 1] = src end
    return players
  end
  env.GetPlayerName = function(src) return online[tostring(src)] and 'Alex RP' end
  local server = {
    env = env, ace = ace, api = api, sent = sent, recipients = recipients,
    event = function(name, ...) return events['staff_suite:' .. name](...) end,
    commands = commands, online = online, payloads = payloads,
    threads = threads, reads = reads, states = states,
  }
  env.DropPlayer = function(src) server.kicked = src end
  env.GetCurrentResourceName = function() return 'staff_suite' end
  env.LoadResourceFile = function(_, path)
    assert(not path:lower():match('%.lua$'), 'LoadResourceFile intentó leer código Lua: ' .. path)
    reads[#reads + 1] = path
  end
  env.SaveResourceFile = function() end
  env.json = { encode = function(value)
    payloads[#payloads + 1] = value
    return tostring(#payloads)
  end }
  env.require = function(name) error('require no está disponible en FiveM: ' .. name) end
  env.print = function() end
  local manifest = readManifest()
  for _, scripts in ipairs({ manifest.shared, manifest.server }) do
    for _, path in ipairs(scripts) do assert(loadfile(path, 't', env))() end
  end

  env.source = 17
  return server
end

function T.test_server_boots_from_manifest_without_reading_lua()
  local s = serverSandbox()
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
  local env, ace, commands, api, sent = server.env, server.ace, server.commands, server.api, server.sent
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
  for _, cap in ipairs(sent['staff_suite:state'].player.capabilities) do
    assert(cap ~= 'mod.ban' and cap ~= 'mod.warn' and cap ~= 'mod.spectate' and cap ~= 'mod.revive')
  end
  local entry_count = #api.GetChain()
  for _, action in ipairs({ 'ban', 'warn', 'spectate', 'revive' }) do
    event('modAction', action, 18, 'regla del servidor')
    assert(sent['staff_suite:notify'] == env.Locale.es.mod_unavailable)
  end
  assert(#api.GetChain() == entry_count)
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
    assert(((key == 'file' or key == 'webhook') and type(value) == 'boolean')
      or (key == 'anchor_every' and type(value) == 'number'))
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

function T.test_resolve_and_rating_feed_staff_analytics()
  local s = serverSandbox()
  s.ace.admin = true
  local id = s.api.CreateTicket({ reporter = 'license:account19', category = 'bug', ts = os.time() - 120 })
  s.event('ticketAction', id, 'claim', {})
  s.event('ticketMessage', id, 'Hola', false)
  local ticket = s.api.GetState().tickets.tickets[id]
  assert(ticket.first_response_ts)
  s.event('ticketAction', id, 'resolve', { resolution = 'listo' })
  assert(ticket.state == 'resolved' and ticket.resolved_by == 'license:account17')
  assert(s.recipients[19]['staff_suite:ratePrompt'].id == id)
  local st = s.api.GetState().duty.staff['license:account17']
  assert(st.resolved == 1 and st.response_n == 1 and st.response_sum >= 0)

  s.env.source = 18
  s.event('ticketRate', id, 4)
  assert(ticket.rating == nil)
  s.env.source = 19
  s.event('ticketRate', id, 9)
  assert(ticket.rating == nil)
  s.event('ticketRate', id, 4)
  assert(ticket.rating == 4 and st.ratings_n == 1 and st.ratings_sum == 4)
  s.event('ticketRate', id, 5)
  assert(ticket.rating == 4 and st.ratings_n == 1)
  local entries = s.api.GetChain()
  assert(entries[#entries].action == 'ticket_rate' and entries[#entries].actor == 'license:account19')

  s.env.source = 17
  s.event('getState')
  local row
  for _, r in ipairs(s.sent['staff_suite:state'].duty) do
    if r.actor == 'license:account17' then row = r end
  end
  assert(row.resolved == 1 and row.avg_rating == 4 and row.avg_response ~= nil)
end

function T.test_evidence_detected_captured_and_verified()
  local s = serverSandbox()
  s.ace.admin = true
  local id = s.api.CreateTicket({ reporter = 'license:account19', category = 'player' })
  local ticket = s.api.GetState().tickets.tickets[id]
  s.event('getState')
  local state = s.sent['staff_suite:state']
  assert(state.evidenceEnabled == false)
  assert(state.exportStatus.anchor_every == s.env.Config.Export.anchor_every)
  s.event('ticketEvidence', id)
  assert(ticket.evidence == nil)

  local files, requested, latent = {}, nil, nil
  local shot = 'data:image/jpeg;base64,AAAA'
  s.states['screenshot-basic'] = 'started'
  s.env.exports['screenshot-basic'] = {
    requestClientScreenshot = function(_, src, opts, cb)
      requested = src
      assert(opts.encoding == 'jpg')
      cb(false, shot)
    end,
  }
  s.env.SaveResourceFile = function(_, path, data) files[path] = data end
  s.env.LoadResourceFile = function(_, path) return files[path] end
  s.env.TriggerLatentClientEvent = function(event, src, _, data) latent = { event = event, src = src, data = data } end
  s.event('getState')
  assert(s.sent['staff_suite:state'].evidenceEnabled == true)
  s.event('ticketEvidence', id)
  assert(requested == 19 and #ticket.evidence == 1)
  local item = ticket.evidence[1]
  assert(item.by == 'license:account17' and item.size == #shot and #item.sha256 == 64)
  local entries = s.api.GetChain()
  assert(entries[#entries].action == 'ticket_evidence' and entries[#entries].target == 'ticket:' .. id)

  s.event('evidenceGet', id, 1)
  assert(latent.event == 'staff_suite:evidence' and latent.src == 17)
  assert(latent.data.ok == true and latent.data.data == shot)
  files['staff_suite_evidence_' .. id .. '_1.txt'] = 'data:image/jpeg;base64,BBBB'
  s.event('evidenceGet', id, 1)
  assert(latent.data.ok == false)
end

return T
