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

if StaffSuiteModules then StaffSuiteModules['server.bridges.qbcore'] = B end
return B
