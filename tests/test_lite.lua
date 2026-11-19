local T = {}
local resource = os.getenv('STAFF_SUITE_LITE_RESOURCE')

local function loadLua(path, env)
  if resource then
    path = resource .. '/' .. path
  elseif path == 'fxmanifest.lua' or path == 'config.lua' then
    path = 'editions/lite/' .. path
  end
  return assert(loadfile(path, 't', env))()
end

local function scripts()
  local manifest = {}
  for _, key in ipairs({ 'shared_scripts', 'server_scripts', 'client_scripts' }) do
    manifest[key] = function(paths) manifest[key] = paths end
  end
  setmetatable(manifest, { __index = function() return function() end end })
  loadLua('fxmanifest.lua', manifest)
  return manifest
end

local function copy(value)
  if type(value) ~= 'table' then return value end
  local clone = {}
  for k, v in pairs(value) do clone[k] = copy(v) end
  return clone
end

local function server(disk)
  disk = disk or {}
  local events, commands, sent = {}, {}, {}
  local encoded
  local env = setmetatable({
    GetCurrentResourceName = function() return 'staff_suite' end,
    GetPlayerName = function(src) return 'Player ' .. src end,
    GetPlayerIdentifiers = function(src) return { 'license2:alternate', 'license:' .. src } end,
    GetPlayers = function() return { '1', '2' } end,
    IsPlayerAceAllowed = function(src, ace) return src == 2 and ace == 'staff_suite.lite' end,
    RegisterNetEvent = function(name, handler) events[name] = handler end,
    RegisterCommand = function(name, handler) commands[name] = handler end,
    AddEventHandler = function() end,
    TriggerClientEvent = function(name, src, value)
      if name ~= 'staff_suite:notify' then sent[#sent + 1] = { name = name, src = src, value = copy(value) } end
    end,
    LoadResourceFile = function(_, path)
      assert(path == 'staff_suite_data.json')
      return disk.snapshot and 'snapshot'
    end,
    SaveResourceFile = function(_, path, data, bytes)
      assert(path == 'staff_suite_data.json' and #data == bytes)
      disk.snapshot = copy(encoded)
      return true
    end,
    json = {
      encode = function(value) encoded = value; return 'encoded' end,
      decode = function() return copy(disk.snapshot) end,
    },
  }, { __index = _G })
  local manifest = scripts()
  for _, file in ipairs(manifest.shared_scripts) do loadLua(file, env) end
  for _, file in ipairs(manifest.server_scripts) do loadLua(file, env) end

  local function call(src, name, ...)
    env.source = src
    events['staff_suite:' .. name](...)
  end
  return call, commands, sent, disk, env.StaffSuiteModules.loadmod('core.audit_chain'), events
end

function T.test_basic_tickets_are_authorized_audited_and_restored()
  local call, commands, sent, disk, audit, events = server()
  commands.report(1, { 'player', 'sample', 'report' })
  assert(#sent == 1 and sent[1].src == 2)
  call(1, 'getState')
  local public = sent[#sent].value
  assert(not next(public.tickets) and not next(public.audit) and not next(public.player.capabilities))
  assert(public.player.identifier == 'license:1')
  commands.reports(1)
  assert(#sent == 2)
  commands.reports(2)
  assert(sent[#sent].name == 'staff_suite:openPanel' and sent[#sent].value == 'tickets')
  commands.audit(2)
  assert(sent[#sent].value == 'audit')

  call(1, 'ticketAction', 1, 'claim')
  call(1, 'verify')
  call(2, 'ticketAction', 1, 'transfer', { to = 'license:1' })
  assert(#disk.snapshot.chain.entries == 1 and disk.snapshot.tickets.tickets[1].state == 'open')
  assert(not events['staff_suite:modAction'] and not events['staff_suite:ticketMessage'])
  call(2, 'ticketAction', 1, 'claim')
  call(2, 'ticketAction', 1, 'resolve', { resolution = 'Revisado' })
  call(2, 'ticketAction', 1, 'close')
  call(2, 'ticketAction', 1, 'reopen')
  call(1, 'ticketCreate', 'bug', 'urgent', 'Another report')
  assert(audit.verify(disk.snapshot.chain) and #disk.snapshot.chain.entries == 6)
  assert(disk.snapshot.tickets.tickets[2].priority == 'normal')
  call(2, 'verify')
  assert(sent[#sent].value.ok and disk.snapshot.chain.entries[7].action == 'audit_verify')

  local restored, _, afterRestart = server(disk)
  restored(2, 'getState')
  local state = afterRestart[1].value
  assert(state.verify[1] and #state.audit == 7)
  assert(state.tickets[1].state == 'reopened' and state.tickets[2].reporter == 'license:1')
  restored(1, 'ticketCreate', 'bug', 'normal', 'After restart')
  assert(disk.snapshot.tickets.tickets[3].description == 'After restart')
  disk.snapshot.chain.entries[1].actor = 'changed'
  local edited, _, editedMessages = server(disk)
  edited(2, 'verify')
  assert(not editedMessages[#editedMessages].value.ok and editedMessages[#editedMessages].value.at == 1)
end

function T.test_client_opens_basic_panel_and_registers_basic_actions()
  local events, callbacks, nui, sent = {}, {}, {}, {}
  local env = setmetatable({
    RegisterCommand = function() end,
    RegisterKeyMapping = function() end,
    RegisterNetEvent = function(name, handler) events[name] = handler end,
    RegisterNUICallback = function(name, handler) callbacks[name] = handler end,
    AddEventHandler = function() end,
    GetCurrentResourceName = function() return 'staff_suite' end,
    GetResourceMetadata = function() return '0.1.0' end,
    GetPlayerName = function() return 'Lite player' end,
    PlayerId = function() return 1 end,
    SetNuiFocus = function() end,
    SendNUIMessage = function(message) nui[#nui + 1] = message end,
    TriggerServerEvent = function(name) sent[#sent + 1] = name end,
  }, { __index = _G })
  local manifest = scripts()
  for _, file in ipairs(manifest.shared_scripts) do loadLua(file, env) end
  for _, file in ipairs(manifest.client_scripts) do loadLua(file, env) end
  env.source = 65535
  events['staff_suite:openPanel']('tickets')
  assert(nui[1].type == 'init' and not next(nui[1].payload.player.capabilities))
  assert(nui[2].type == 'open' and nui[2].payload.view == 'tickets')
  assert(sent[1] == 'staff_suite:getState')
  assert(callbacks.ticket_create and callbacks.ticket_claim and callbacks.audit_verify)
  assert(not callbacks.ticket_message and not callbacks.ticket_transfer and not callbacks.duty_toggle)
  assert(not callbacks.mod_action and not events['staff_suite:spectate'] and not events['staff_suite:tp'])
  assert(not callbacks.ticket_rate and not callbacks.ticket_evidence and not callbacks.evidence_get)
  assert(not events['staff_suite:ratePrompt'] and not events['staff_suite:evidence'])
end

return T
