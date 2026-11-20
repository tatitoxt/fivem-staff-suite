local T = {}

local function sandbox()
  local events, callbacks, hooks = {}, {}, {}
  local client = { visible = true, collision = true, frozen = false, pos = { x = 1, y = 2, z = 3 }, keys = {} }
  local env = setmetatable({
    Config = { Locale = 'es' },
    StaffSuiteTranslate = function(key) return key end,
    RegisterCommand = function(name, fn) client.commands = client.commands or {}; client.commands[name] = fn end,
    RegisterKeyMapping = function(name, _, mapper, key) client.keys[name] = { mapper, key } end,
    RegisterNetEvent = function(event, fn) events[event] = fn end,
    RegisterNUICallback = function(action, fn) callbacks[action] = fn end,
    AddEventHandler = function(event, fn)
      local previous = hooks[event]
      hooks[event] = previous and function(...) previous(...); fn(...) end or fn
    end,
    GetCurrentResourceName = function() return 'staff_suite' end,
    SetNuiFocus = function() end,
    SendNUIMessage = function() end,
    TriggerEvent = function(event) if hooks[event] then hooks[event]() end end,
    TriggerServerEvent = function(...) client.args = { ... } end,
    PlayerPedId = function() return 10 end,
    IsEntityDead = function() return client.dead end,
    IsPedInAnyVehicle = function() return false end,
    DoesEntityExist = function() return true end,
    GetEntityCoords = function() return client.pos end,
    GetEntityHeading = function() return 45 end,
    SetEntityHeading = function(_, heading) client.heading = heading end,
    SetFocusEntity = function(ped) client.focus = ped end,
    ClearFocus = function() client.focus = nil end,
    GetEntityMaxHealth = function() return 200 end,
    GetEntityCollisionDisabled = function() return not client.collision end,
    IsEntityVisible = function() return client.visible end,
    IsEntityPositionFrozen = function() return client.frozen end,
    SetEntityHealth = function(_, health) client.health = health end,
    SetEntityVisible = function(_, value) client.visible = value end,
    SetEntityCollision = function(_, value) client.collision = value end,
    FreezeEntityPosition = function(_, value) client.frozen = value end,
    SetEntityCoordsNoOffset = function(_, x, y, z) client.pos = { x = x, y = y, z = z } end,
    NetworkResurrectLocalPlayer = function(x, y, z, heading)
      client.dead = false
      client.resurrected = { x, y, z, heading }
    end,
    NetworkSetInSpectatorMode = function(active, ped) client.watched = active and ped or nil end,
    GetPlayerFromServerId = function(src) return src == 42 and client.inScope and 2 or -1 end,
    GetPlayerPed = function(player) return player == 2 and 20 or 0 end,
    GetGameTimer = function() return 100 end,
    CreateThread = function(fn) client.thread = coroutine.create(fn) end,
    Wait = coroutine.yield,
  }, { __index = _G })
  assert(loadfile('client/main.lua', 't', env))()
  assert(loadfile('client/moderation.lua', 't', env))()
  return client, env, events, callbacks, hooks
end

function T.test_emergency_shutdown_restores_local_controlled_entities_without_server_rpc()
  local c, env, events, _, hooks = sandbox()
  env.NetworkDoesEntityExistWithNetworkId = function(id) return id == 2 end
  env.NetworkGetEntityFromNetworkId = function() return env.PlayerPedId() end
  env.source, c.frozen = 65535, true
  events['staff_suite:emergencyEntities']({ ['2'] = false })
  hooks.onClientResourceStop('staff_suite')
  assert(not c.frozen)
end

function T.test_waypoint_does_not_move_without_authorization_marker_or_ground()
  local client, env, events, callbacks = sandbox()
  local move = events['staff_suite:waypoint']
  env.GetFirstBlipInfoId = function() return 8 end
  env.DoesBlipExist = function() return client.marker end
  env.GetBlipInfoIdCoord = function() return { x = 50, y = 70, z = 0 } end
  env.NewLoadSceneStartSphere = function() return true end
  env.IsNewLoadSceneLoaded = function() return true end
  env.NewLoadSceneStop = function() client.sceneStopped = true end
  env.GetGroundZFor_3dCoord = function() return client.ground, 30 end
  callbacks.goto_waypoint({}, function() end)
  assert(client.args[1] == 'staff_suite:waypoint')
  move(1)
  assert(client.pos.x == 1 and client.args[1] == 'staff_suite:waypoint')
  env.source = 65535
  move(2)
  assert(client.args[2] == 2 and client.args[3] == 'no_marker')
  client.marker = true
  move(3)
  assert(client.args[3] == 'unavailable' and client.pos.x == 1 and client.sceneStopped)
  client.ground = true
  move(4)
  assert(client.args[3] == 'ok' and client.pos.x == 50 and client.pos.z == 31)
end

function T.test_spectate_checks_sender_and_restores_player_on_exit_or_disconnect()
  local c, env, events, _, hooks = sandbox()
  local spectate = events['staff_suite:spectate']
  assert(c.keys.staffsuitestopspectate[2] == 'BACK')
  assert(c.keys['~!staffsuitestopspectate'][2] == 'RRIGHT_INDEX')
  spectate(42, { x = 100, y = 100, z = 10 }, 8)
  assert(not c.thread and c.pos.x == 1)
  env.source, c.inScope = 65535, true
  spectate(42, { x = 100, y = 100, z = 10 }, 9)
  assert(not c.visible and c.frozen and not c.collision and c.pos.x == 100)
  assert(coroutine.resume(c.thread))
  assert(c.watched == 20 and c.focus == 20)
  events['staff_suite:spectateStop'](8)
  assert(c.watched == 20)
  c.commands.staffsuitestopspectate()
  assert(c.pos.x == 1 and c.heading == 45 and c.visible and c.collision and not c.frozen and not c.watched and not c.focus)
  assert(c.args[1] == 'staff_suite:spectateEnded' and c.args[2] == 9)

  spectate(42, { x = 200, y = 100, z = 10 })
  assert(coroutine.resume(c.thread))
  assert(c.watched == 20)
  c.inScope = false
  assert(coroutine.resume(c.thread))
  assert(c.pos.x == 1 and not c.watched)

  spectate(42, { x = 300, y = 100, z = 10 })
  hooks.onClientResourceStop('staff_suite')
  assert(c.pos.x == 1 and c.visible and c.collision and not c.frozen)

  spectate(42, { x = 500, y = 100, z = 10 })
  c.dead = true
  assert(coroutine.resume(c.thread))
  assert(c.pos.x == 1 and c.visible and c.collision and not c.frozen)
end

function T.test_noclip_moves_forward_and_up_with_the_camera()
  local c, env, events = sandbox()
  env.source = 65535
  env.GetDisabledControlNormal = function(_, control) return control == 31 and -1 or 0 end
  env.GetGameplayCamRot = function() return { x = 20, z = 0 } end
  env.GetFrameTime = function() return 1 / 60 end
  env.IsControlPressed = function() return false end
  env.DisableControlAction = function() end
  env.SetEntityVelocity = function() end
  events['staff_suite:staffMode']('noclip', true, 1)
  assert(coroutine.resume(c.thread))
  assert(c.pos.x == 1 and c.pos.y > 2 and c.pos.z > 3)
end

function T.test_invisible_restores_state_on_death_or_resource_stop()
  local c, env, events, _, hooks = sandbox()
  local change = events['staff_suite:staffMode']
  change('invisible', true, 1)
  assert(c.visible)
  env.source = 65535
  change('invisible', true, 2)
  assert(not c.visible)
  assert(coroutine.resume(c.thread))
  c.dead = true
  assert(coroutine.resume(c.thread))
  assert(c.visible and c.args[1] == 'staff_suite:staffModeEnded' and c.args[3] == 2)
  c.dead = false
  change('invisible', true, 3)
  hooks.onClientResourceStop('staff_suite')
  assert(c.visible)
end

function T.test_standalone_revive_and_nui_ban_duration()
  local c, env, events, callbacks = sandbox()
  c.dead = true
  events['staff_suite:revive']()
  assert(c.dead and not c.health)
  env.source = 65535
  events['staff_suite:revive']()
  assert(not c.dead and c.health == 200 and c.resurrected[4] == 45)
  callbacks.mod_action({ action = 'ban', target = 'license:test', reason = 'regla', duration = 0 }, function(response)
    assert(response.ok)
  end)
  assert(c.args[1] == 'staff_suite:modAction' and c.args[3] == 'license:test' and c.args[5] == 0)
end

function T.test_nui_focus_released_on_close_dismiss_and_resource_stop()
  local _, env, _, callbacks, hooks = sandbox()
  local focus
  env.SetNuiFocus = function(a, b) focus = { a, b } end
  local noop = function() end
  callbacks['close_ui']({}, noop)
  assert(focus and focus[1] == false and focus[2] == false, 'cerrar libera teclado y mouse')
  focus = nil
  if callbacks['rate_dismiss'] then
    callbacks['rate_dismiss']({}, noop)
    assert(focus and focus[1] == false, 'descartar la valoración libera el foco')
  end
  focus = nil
  hooks['onClientResourceStop']('otro_recurso')
  assert(focus == nil)
  hooks['onClientResourceStop']('staff_suite')
  assert(focus and focus[1] == false and focus[2] == false, 'parar el recurso libera el foco')
end

function T.test_teleport_only_accepts_server_sender()
  local client, env, events = sandbox()
  env.SetEntityCoords = function(_, x, y, z) client.pos = { x = x, y = y, z = z } end
  env.source = 3
  events['staff_suite:tp']({ x = 9, y = 9, z = 9 })
  assert(client.pos.x == 1)
  env.source = 65535
  events['staff_suite:tp']('basura')
  events['staff_suite:tp']({ x = 9, y = 8, z = 7 })
  assert(client.pos.x == 9 and client.pos.z == 7)
end

function T.test_ticket_create_waits_for_server_result()
  local c, env, events, callbacks = sandbox()
  local timers, replies = {}, {}
  env.SetTimeout = function(_, fn) timers[#timers + 1] = fn end
  callbacks.ticket_create({ category = 'bug', priority = 'high', body = 'hola' }, function(r) replies[#replies + 1] = r end)
  assert(#replies == 0 and c.args[1] == 'staff_suite:ticketCreate' and c.args[4] == 'hola')
  local req = c.args[5]
  env.source = 12
  events['staff_suite:ticketCreateResult']({ req = req, ok = true })
  assert(#replies == 0, 'solo el server responde')
  env.source = 65535
  events['staff_suite:ticketCreateResult']({ req = req, ok = false, error = 'tope' })
  assert(replies[1].ok == false and replies[1].error == 'tope')
  events['staff_suite:ticketCreateResult']({ req = req, ok = true })
  timers[1]()
  assert(#replies == 1, 'una respuesta por pedido')

  callbacks.ticket_create({ body = 'sin respuesta' }, function(r) replies[#replies + 1] = r end)
  timers[2]()
  assert(replies[2].ok == false and replies[2].error == 'report_failed')
end

function T.test_hidden_panel_defers_data_until_open()
  local client, env, events = sandbox()
  local msgs = {}
  env.SendNUIMessage = function(m) msgs[#msgs + 1] = m end
  env.GetResourceMetadata = function() return '1.0' end
  env.GetPlayerName = function() return 'Fausto' end
  env.PlayerId = function() return 1 end
  events['staff_suite:state']({ tickets = { { id = 1, messages = {} } } })
  events['staff_suite:state']({ tickets = { { id = 1, messages = {} }, { id = 2, messages = {} } } })
  for _, m in ipairs(msgs) do
    assert(m.type ~= 'tickets' and m.type ~= 'dashboard', 'con el panel cerrado no se mandan datos a la NUI')
  end
  client.commands.staffsuite()
  local open, tickets, count = nil, nil, 0
  for i, m in ipairs(msgs) do
    if m.type == 'open' then open = i end
    if m.type == 'tickets' then tickets, count = i, count + 1 end
  end
  assert(open and tickets and tickets > open, 'al abrir se manda el último estado')
  assert(count == 1 and #msgs[tickets].payload.tickets == 2, 'solo el último de cada tipo')
end

function T.test_notices_show_without_taking_focus()
  local _, env, events = sandbox()
  local msgs, chat, sounds, focus = {}, {}, {}, nil
  env.SendNUIMessage = function(m) msgs[#msgs + 1] = m end
  env.TriggerEvent = function(event, data) if event == 'chat:addMessage' then chat[#chat + 1] = data end end
  env.PlaySoundFrontend = function(_, name) sounds[#sounds + 1] = name end
  env.SetNuiFocus = function(a) focus = a end
  env.GetResourceMetadata = function() return '1.0' end
  env.GetPlayerName = function() return 'Fausto' end
  env.PlayerId = function() return 1 end
  events['staff_suite:notify']('Te respondieron el reporte #12', { kind = 'reply' })
  assert(msgs[1].type == 'init', 'manda init para tener los textos')
  local last = msgs[#msgs]
  assert(last.type == 'notice' and last.payload.kind == 'reply' and last.payload.max == 3 and last.payload.duration == 6000)
  assert(focus == nil, 'el aviso no toma el foco')
  events['staff_suite:notify']('Reporte nuevo', { kind = 'report', priority = 'urgent' })
  assert(msgs[#msgs].payload.priority == 'urgent' and #sounds == 0)
  env.Config.Notifications = { sound = { name = 'Text_Arrive_Tone', set = 'Phone_SoundSet_Default' } }
  events['staff_suite:notify']('Reporte nuevo', { kind = 'report' })
  assert(sounds[1] == 'Text_Arrive_Tone', 'sonido opcional en reportes nuevos')
  env.Config.Notifications = { staff_reports = false }
  local before = #msgs
  events['staff_suite:notify']('Reporte nuevo', { kind = 'report' })
  assert(#msgs == before, 'los avisos de reportes se pueden apagar')
  env.Config.Notifications = { enabled = false }
  events['staff_suite:notify']('Al chat')
  assert(#msgs == before and chat[1].args[2] == 'Al chat', 'desactivados vuelven al chat')
end

function T.test_theme_and_brand_come_from_config_and_kvp()
  local _, env, events, callbacks = sandbox()
  local msgs, kvp = {}, {}
  env.SendNUIMessage = function(m) msgs[#msgs + 1] = m end
  env.TriggerEvent = function() end
  env.GetResourceMetadata = function() return '1.0' end
  env.GetPlayerName = function() return 'Fausto' end
  env.PlayerId = function() return 1 end
  env.GetResourceKvpString = function(k) return kvp[k] end
  env.SetResourceKvp = function(k, v) kvp[k] = v end
  env.Config.Theme = 'dark'
  env.Config.Brand = { name = 'Los Santos RP', logo = 'javascript:alert(1)', accent = '#1d4ed8' }
  events['staff_suite:notify']('hola', { kind = 'reply' })
  local init = msgs[1].payload
  assert(msgs[1].type == 'init' and init.theme == 'dark' and init.config.theme == 'dark', 'usa Config.Theme sin preferencia guardada')
  local brand = init.config.brand
  assert(brand.name == 'Los Santos RP' and brand.accent == '#1d4ed8' and brand.logo == nil, 'descarta logos que no son https ni brand/')
  callbacks['set_theme']({ theme = 'light' }, function() end)
  assert(kvp['staff_suite:theme'] == 'light', 'guarda la preferencia en KVP')
  callbacks['set_theme']({ theme = 'neon' }, function() end)
  assert(kvp['staff_suite:theme'] == 'light', 'ignora temas inválidos')
end

return T
