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

local function stopSpectating(session)
  if observing ~= session then return end
  observing = nil
  local ped = session.ped
  NetworkSetInSpectatorMode(false, PlayerPedId())
  if not DoesEntityExist(ped) then return end
  local pos = session.origin
  SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
  SetEntityVisible(ped, session.visible, false)
  SetEntityCollision(ped, not session.noCollision, false)
  FreezeEntityPosition(ped, session.frozen)
end

RegisterNetEvent('staff_suite:spectate', function(target, coords)
  if source ~= 65535 then return end
  if observing then stopSpectating(observing) end
  local ped = PlayerPedId()
  if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then
    SendNUIMessage({ type = 'toast', payload = { kind = 'info', text = t('spectate_unavailable') } })
    return
  end
  TriggerEvent('staff_suite:closePanel')
  local session = {
    ped = ped, origin = GetEntityCoords(ped), visible = IsEntityVisible(ped),
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
    local watched = 0
    while observing == session do
      if IsControlJustPressed(0, 177) or PlayerPedId() ~= ped or IsEntityDead(ped) then break end
      local player = GetPlayerFromServerId(target)
      local targetPed = player ~= -1 and GetPlayerPed(player) or 0
      if targetPed ~= 0 then
        if targetPed ~= watched then NetworkSetInSpectatorMode(true, targetPed); watched = targetPed end
      elseif watched ~= 0 or GetGameTimer() >= deadline then
        TriggerEvent('chat:addMessage', { args = { t('notify_title'), t('spectate_unavailable') } })
        break
      end
      Wait(0)
    end
    stopSpectating(session)
  end)
end)

AddEventHandler('onClientResourceStop', function(resource)
  if resource == GetCurrentResourceName() and observing then stopSpectating(observing) end
end)
