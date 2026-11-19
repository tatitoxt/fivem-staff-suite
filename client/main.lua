-- client/main.lua — Puente NUI + keybind + handlers. La UI real (React) va en ui/dist.
local panelOpen = false

local function openPanel()
  panelOpen = true
  SetNuiFocus(true, true)
  TriggerServerEvent('staff_suite:getState')
  SendNUIMessage({ type = 'open' })
end

local function closePanel()
  panelOpen = false
  SetNuiFocus(false, false)
  SendNUIMessage({ type = 'close' })
end

RegisterCommand('staffsuite', function() openPanel() end, false)
RegisterKeyMapping('staffsuite', 'Abrir Staff Suite', 'keyboard', Config.PanelKey or 'F6')

RegisterNUICallback('close', function(_, cb) closePanel(); cb({}) end)
RegisterNUICallback('ticketAction', function(data, cb)
  TriggerServerEvent('staff_suite:ticketAction', data.id, data.action, data.extra); cb({})
end)
RegisterNUICallback('modAction', function(data, cb)
  TriggerServerEvent('staff_suite:modAction', data.action, data.target, data.reason); cb({})
end)
RegisterNUICallback('verify', function(_, cb) TriggerServerEvent('staff_suite:verify'); cb({}) end)
RegisterNUICallback('refresh', function(_, cb) TriggerServerEvent('staff_suite:getState'); cb({}) end)

RegisterNetEvent('staff_suite:state', function(state)
  SendNUIMessage({ type = 'state', payload = state })
end)
RegisterNetEvent('staff_suite:auditResult', function(res)
  SendNUIMessage({ type = 'auditResult', payload = res })
end)
RegisterNetEvent('staff_suite:notify', function(msg)
  SendNUIMessage({ type = 'notify', payload = msg })
  -- fallback chat por si la NUI no está abierta
  TriggerEvent('chat:addMessage', { args = { 'Staff Suite', msg } })
end)
RegisterNetEvent('staff_suite:tp', function(coords)
  local ped = PlayerPedId()
  SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
end)
