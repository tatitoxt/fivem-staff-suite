-- Handlers de moderación de Staff Suite Core.
local t = StaffSuiteTranslate

RegisterNetEvent('staff_suite:tp', function(coords)
  if source ~= 65535 or type(coords) ~= 'table' and type(coords) ~= 'vector3' then return end
  local ped = PlayerPedId()
  SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
end)

-- Solo el servidor autoriza el revive y el inicio del modo espectador.
RegisterNetEvent('staff_suite:revive', function()
  if source ~= 65535 then return end
  local ped = PlayerPedId()
  if IsEntityDead(ped) then
    local pos = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(ped), 0, false)
    ped = PlayerPedId()
  end
  SetEntityHealth(ped, GetEntityMaxHealth(ped))
end)

local observing
local streamingWaypoint = false

local function waypointDestination(coords)
  if streamingWaypoint then return end
  if not NewLoadSceneStartSphere(coords.x, coords.y, coords.z, 100.0, 0) then return end
  streamingWaypoint = true
  local deadline = GetGameTimer() + 5000
  while not IsNewLoadSceneLoaded() and GetGameTimer() < deadline do Wait(0) end
  local found, z = GetGroundZFor_3dCoord(coords.x, coords.y, 1000.0, false)
  NewLoadSceneStop()
  streamingWaypoint = false
  if found then return z end
end

local function canUseWaypoint(ped)
  return not observing and DoesEntityExist(ped) and not IsEntityDead(ped)
    and not IsEntityPositionFrozen(ped) and not IsPedInAnyVehicle(ped, false)
end

RegisterNetEvent('staff_suite:waypoint', function(seq)
  if source ~= 65535 then return end
  local function reply(outcome) TriggerServerEvent('staff_suite:waypointResult', seq, outcome) end
  local marker = GetFirstBlipInfoId(8)
  if not DoesBlipExist(marker) then return reply('no_marker') end
  local ped = PlayerPedId()
  if not canUseWaypoint(ped) then return reply('unavailable') end
  local coords = GetBlipInfoIdCoord(marker)
  local z = waypointDestination(coords)
  if not z or PlayerPedId() ~= ped or not canUseWaypoint(ped) then
    return reply('unavailable')
  end
  SetEntityCoordsNoOffset(ped, coords.x, coords.y, z + 1.0, false, false, false)
  reply('ok')
end)

local function stopSpectating(session)
  if observing ~= session then return end
  observing = nil
  local ped = session.ped
  if session.watched then
    NetworkSetInSpectatorMode(false, PlayerPedId())
    ClearFocus()
  end
  if DoesEntityExist(ped) then
    if ped == PlayerPedId() then
      local pos = session.origin
      SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
      SetEntityHeading(ped, session.heading)
    end
    SetEntityVisible(ped, session.visible, false)
    SetEntityCollision(ped, not session.noCollision, false)
    FreezeEntityPosition(ped, session.frozen)
  end
  if session.key then TriggerServerEvent('staff_suite:spectateEnded', session.key) end
end

local function exitSpectate()
  if observing then stopSpectating(observing) end
end

RegisterCommand('staffsuitestopspectate', exitSpectate, false)
RegisterKeyMapping('staffsuitestopspectate', t('spectate_stop'), 'keyboard', 'BACK')
RegisterNUICallback('spectate_stop', function(_, cb)
  exitSpectate()
  cb({ ok = true })
end)

RegisterNetEvent('staff_suite:spectateStop', function(key)
  if source == 65535 and observing and observing.key == key then exitSpectate() end
end)

RegisterNetEvent('staff_suite:spectate', function(target, coords, key)
  if source ~= 65535 then return end
  if observing then stopSpectating(observing) end
  local ped = PlayerPedId()
  if streamingWaypoint or IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) or IsEntityPositionFrozen(ped) then
    if key then TriggerServerEvent('staff_suite:spectateEnded', key) end
    TriggerEvent('chat:addMessage', { args = { t('notify_title'), t('spectate_unavailable') } })
    return
  end
  TriggerEvent('staff_suite:closePanel')
  local session = {
    ped = ped, key = key, origin = GetEntityCoords(ped), heading = GetEntityHeading(ped), visible = IsEntityVisible(ped),
    frozen = IsEntityPositionFrozen(ped), noCollision = GetEntityCollisionDisabled(ped),
  }
  observing = session
  FreezeEntityPosition(ped, true)
  SetEntityVisible(ped, false, false)
  SetEntityCollision(ped, false, false)
  -- OneSync necesita que el objetivo entre en el scope del espectador.
  SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z + 1.0, false, false, false)
  TriggerEvent('chat:addMessage', { args = { t('notify_title'), t('spectate_exit') } })

  CreateThread(function()
    local deadline = GetGameTimer() + 5000
    while observing == session do
      if PlayerPedId() ~= ped or IsEntityDead(ped) then break end
      local player = GetPlayerFromServerId(target)
      local targetPed = player ~= -1 and GetPlayerPed(player) or 0
      if targetPed ~= 0 and DoesEntityExist(targetPed) then
        if targetPed ~= session.watched then
          SetFocusEntity(targetPed)
          NetworkSetInSpectatorMode(true, targetPed)
          session.watched = targetPed
        end
      elseif session.watched or GetGameTimer() >= deadline then
        TriggerEvent('chat:addMessage', { args = { t('notify_title'), t('spectate_unavailable') } })
        break
      end
      Wait(100)
    end
    stopSpectating(session)
  end)
end)

AddEventHandler('onClientResourceStop', function(resource)
  if resource ~= GetCurrentResourceName() then return end
  if observing then stopSpectating(observing) end
  if streamingWaypoint then NewLoadSceneStop() end
end)
