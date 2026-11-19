-- QBCore: permisos del framework y datos del personaje.
local B = { resource = 'qb-core' }

function B.get_player(src)
  local qb = exports['qb-core']:GetCoreObject({ 'Functions' }).Functions
  local player = qb.GetPlayer(src)
  local data = player and player.PlayerData
  if not data then return nil end

  return {
    identifier = data.license,
    charinfo = data.charinfo,
    job = data.job,
    has_group = function(label) return qb.HasPermission(src, label) end,
  }
end

function B.revive(src)
  if GetResourceState('qb-ambulancejob') ~= 'started' then return end
  TriggerClientEvent('hospital:client:Revive', src)
  return true
end

if StaffSuiteModules then StaffSuiteModules['server.bridges.qbcore'] = B end
return B
