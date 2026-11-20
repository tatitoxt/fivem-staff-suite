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
    os = setmetatable({ time = function() return 10000 end }, { __index = os }),
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
  assert(#sent == 2 and sent[1].src == 1 and sent[2].src == 2)
  call(1, 'getState')
  local public = sent[#sent].value
  assert(not next(public.tickets) and not next(public.audit) and not next(public.player.capabilities))
  assert(public.myTickets[1].id == 1)
  assert(public.player.identifier == 'license:1')
  commands.reports(1)
  assert(#sent == 3)
  commands.reports(2)
  assert(sent[#sent].name == 'staff_suite:openPanel' and sent[#sent].value == 'tickets')
  commands.audit(2)
  assert(sent[#sent].value == 'audit')

  call(1, 'ticketAction', 1, 'claim')
  call(1, 'verify')
  call(2, 'ticketAction', 1, 'transfer', { to = 'license:1' })
  assert(#disk.snapshot.chain.entries == 1 and disk.snapshot.tickets.tickets[1].state == 'open')
  assert(not events['staff_suite:modAction'] and events['staff_suite:ticketMessage'] and events['staff_suite:ticketReply'])
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

function T.test_reporter_sees_resolved_thread_until_staff_closes_it()
  local call, _, sent, disk = server()
  local function reporterTickets(...)
    local before = #sent
    call(...)
    for i = #sent, before + 1, -1 do
      local event = sent[i]
      if event.name == 'staff_suite:state' and event.src == 1 then return event.value.myTickets end
    end
    error('No se envió el estado al reportante')
  end
  local function assertResolved(tickets)
    assert(#tickets == 1 and tickets[1].id == 1 and tickets[1].state == 'resolved')
    local messages = tickets[1].messages
    assert(#messages == 1 and messages[1].body == 'Lo revisamos' and not messages[1].author)
  end

  call(1, 'ticketCreate', 'bug', nil, 'Mi reporte')
  call(2, 'ticketAction', 1, 'claim')
  call(2, 'ticketMessage', 1, 'Lo revisamos', false)
  assertResolved(reporterTickets(2, 'ticketAction', 1, 'resolve', { resolution = 'Revisado' }))
  assertResolved(reporterTickets(1, 'getState'))
  call(1, 'ticketReply', 1, 'Respuesta tardía', 1)
  assert(sent[#sent].name == 'staff_suite:ticketMessageResult' and sent[#sent].value.ok == false)
  assert(#disk.snapshot.tickets.tickets[1].messages == 1)

  assert(not next(reporterTickets(2, 'ticketAction', 1, 'close')))
  assert(not next(reporterTickets(1, 'getState')))
  assert(reporterTickets(2, 'ticketAction', 1, 'reopen')[1].state == 'reopened')
end

function T.test_client_opens_basic_panel_and_registers_basic_actions()
  local events, callbacks, nui, sent = {}, {}, {}, {}
  local request
  local env = setmetatable({
    RegisterCommand = function() end,
    RegisterKeyMapping = function() end,
    RegisterNetEvent = function(name, handler) events[name] = handler end,
    RegisterNUICallback = function(name, handler) callbacks[name] = handler end,
    AddEventHandler = function() end,
    GetCurrentResourceName = function() return 'staff_suite' end,
    GetResourceMetadata = function() return '0.2.0' end,
    GetPlayerName = function() return 'Lite player' end,
    PlayerId = function() return 1 end,
    SetNuiFocus = function() end,
    SendNUIMessage = function(message) nui[#nui + 1] = message end,
    TriggerServerEvent = function(name, ...) sent[#sent + 1] = name; request = { ... } end,
    SetTimeout = function() end,
  }, { __index = _G })
  local manifest = scripts()
  for _, file in ipairs(manifest.shared_scripts) do loadLua(file, env) end
  for _, file in ipairs(manifest.client_scripts) do loadLua(file, env) end
  env.source = 65535
  events['staff_suite:openPanel']('tickets')
  assert(#nui == 0 and sent[1] == 'staff_suite:getState')
  events['staff_suite:state']({ tickets = {} }) -- Una actualización parcial puede llegar primero.
  assert(#nui == 0, 'con el panel cerrado los datos esperan')
  events['staff_suite:state']({ player = { name = 'Lite staff', rank = 'lite_staff', capabilities = { 'report.view' } } })
  assert(nui[#nui - 2].type == 'init' and nui[#nui - 2].payload.player.capabilities[1] == 'report.view')
  assert(nui[#nui - 1].type == 'open' and nui[#nui - 1].payload.view == 'tickets')
  assert(nui[#nui].type == 'tickets', 'al abrir llegan los datos guardados')
  local before = #nui
  events['staff_suite:openPanel']('audit')
  assert(#nui == before and sent[2] == 'staff_suite:getState')
  events['staff_suite:state']({ player = { name = 'Lite staff', rank = 'lite_staff', capabilities = { 'audit.view' } } })
  assert(nui[#nui].type == 'open' and nui[#nui].payload.view == 'audit')
  assert(callbacks.ticket_create and callbacks.ticket_claim and callbacks.audit_verify)
  assert(callbacks.ticket_message and callbacks.ticket_reply)
  assert(not callbacks.ticket_transfer and not callbacks.duty_toggle)
  assert(not callbacks.mod_action and not events['staff_suite:spectate'] and not events['staff_suite:tp'])
  assert(not callbacks.ticket_rate and not callbacks.ticket_evidence and not callbacks.evidence_get)
  assert(not events['staff_suite:ratePrompt'] and not events['staff_suite:evidence'])
  events['staff_suite:state']({ myTickets = { { id = 1, messages = {} } } })
  assert(nui[#nui].type == 'myTickets' and nui[#nui].payload.tickets[1].id == 1)
  local response
  callbacks.ticket_reply({ id = 1, body = 'Gracias' }, function(result) response = result end)
  assert(sent[#sent] == 'staff_suite:ticketReply' and request[1] == 1 and request[2] == 'Gracias')
  env.source = 1
  events['staff_suite:ticketMessageResult']({ req = request[3], ok = true })
  assert(response == nil)
  env.source = 65535
  events['staff_suite:ticketMessageResult']({ req = request[3], ok = false, error = 'Límite' })
  assert(not response.ok and response.error == 'Límite')
end

function T.test_lite_public_chat_ownership_limits_and_persistence()
  local call, _, sent, disk, audit = server()
  local function last()
    local event = sent[#sent]
    assert(event.name == 'staff_suite:ticketMessageResult')
    return event.value
  end
  call(1, 'ticketCreate', 'bug', nil, 'Mi reporte')
  call(2, 'ticketReply', 1, 'No es mío', 1)
  assert(not last().ok)
  call(1, 'ticketMessage', 1, 'No soy staff', false, 2)
  assert(not last().ok)
  call(2, 'ticketMessage', 1, 'Nota interna no disponible', true, 3)
  assert(not last().ok)
  call(2, 'ticketMessage', 1, 'Respuesta pública', false, 4)
  assert(last().ok)
  call(1, 'ticketReply', 1, string.rep('é', 501), 5)
  assert(not last().ok)
  call(1, 'ticketReply', 1, ' Gracias\0 ', 6)
  assert(last().ok)
  for _ = 1, 7 do call(1, 'ticketReply', 999, 'No existe', 7) end
  call(1, 'ticketReply', 1, 'Rate', 8)
  assert(not last().ok and last().error == 'Estás enviando acciones demasiado rápido. Esperá unos segundos.')
  assert(#disk.snapshot.chain.entries == 3 and audit.verify(disk.snapshot.chain))
  local restored, _, afterRestart = server(disk)
  restored(1, 'getState')
  local thread = afterRestart[1].value.myTickets[1].messages
  assert(#thread == 2 and thread[1].body == 'Respuesta pública' and not thread[1].mine)
  assert(thread[2].body == 'Gracias' and thread[2].mine)
  assert(not thread[1].author and not thread[1].internal)
  restored(2, 'ticketAction', 1, 'close')
  restored(1, 'getState')
  assert(not next(afterRestart[#afterRestart].value.myTickets))
  restored(1, 'ticketReply', 1, 'Cerrado', 9)
  assert(not afterRestart[#afterRestart].value.ok)
end

function T.test_lite_limits_text_open_tickets_and_rate()
  local call, commands, _, disk, audit = server()
  local function count()
    local n = 0
    for _ in pairs(disk.snapshot and disk.snapshot.tickets.tickets or {}) do n = n + 1 end
    return n
  end
  call(1, 'ticketCreate', 'bug', nil, string.rep('a', 1001))
  call(1, 'ticketCreate', 'bug', nil, { 'no' })
  assert(count() == 0)
  for i = 1, 5 do call(1, 'ticketCreate', 'bug', nil, 'reporte ' .. i .. '\0') end
  assert(count() == 3 and disk.snapshot.tickets.tickets[1].description == 'reporte 1')
  commands.report(1, { 'bug', 'por comando' })
  assert(count() == 3)
  for _ = 1, 6 do call(2, 'verify') end
  assert(#disk.snapshot.chain.entries == 3 + 3, 'verify limitado a 3 por burst')
  assert(audit.verify(disk.snapshot.chain))
end

function T.test_lite_ticket_create_replies_to_panel()
  local call, _, sent = server()
  local function last()
    for i = #sent, 1, -1 do
      if sent[i].name == 'staff_suite:ticketCreateResult' then return sent[i].value end
    end
  end
  call(1, 'ticketCreate', 'bug', nil, 'uno', 3)
  assert(last().req == 3 and last().ok)
  call(1, 'ticketCreate', 'bug', nil, 'dos', 4)
  call(1, 'ticketCreate', 'bug', nil, 'tres', 5)
  call(1, 'ticketCreate', 'bug', nil, 'cuatro', 6)
  assert(last().req == 6 and not last().ok and last().error:find('3', 1, true))
end

return T
