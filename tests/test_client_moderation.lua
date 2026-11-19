local T = {}

local function sandbox()
  local events, callbacks, hooks = {}, {}, {}
  local client = { visible = true, collision = true, frozen = false, pos = { x = 1, y = 2, z = 3 } }
  local env = setmetatable({
    Config = { Locale = 'es' },
    StaffSuiteTranslate = function(key) return key end,
    RegisterCommand = function() end,
    RegisterKeyMapping = function() end,
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
    IsControlJustPressed = function(_, control) return control == 177 and client.exit end,
    CreateThread = function(fn) client.thread = coroutine.create(fn) end,
    Wait = coroutine.yield,
  }, { __index = _G })
  assert(loadfile('client/main.lua', 't', env))()
  assert(loadfile('client/moderation.lua', 't', env))()
  return client, env, events, callbacks, hooks
end

function T.test_spectate_checks_sender_and_restores_player_on_exit_or_disconnect()
  local c, env, events, _, hooks = sandbox()
  local spectate = events['staff_suite:spectate']
  spectate(42, { x = 100, y = 100, z = 10 })
  assert(not c.thread and c.pos.x == 1)
  env.source, c.inScope = 65535, true
  spectate(42, { x = 100, y = 100, z = 10 })
  assert(not c.visible and c.frozen and not c.collision and c.pos.x == 100)
  assert(coroutine.resume(c.thread))
  assert(c.watched == 20)
  c.exit = true
  assert(coroutine.resume(c.thread))
  assert(c.pos.x == 1 and c.visible and c.collision and not c.frozen and not c.watched)

  c.exit = false
  spectate(42, { x = 200, y = 100, z = 10 })
  assert(coroutine.resume(c.thread))
  assert(c.watched == 20)
  c.inScope = false
  assert(coroutine.resume(c.thread))
  assert(c.pos.x == 1 and not c.watched)

  spectate(42, { x = 300, y = 100, z = 10 })
  hooks.onClientResourceStop('staff_suite')
  assert(c.pos.x == 1 and c.visible and c.collision and not c.frozen)
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

return T
