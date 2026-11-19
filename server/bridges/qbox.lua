-- Qbox: datos de qbx_core y permisos de administración por ACE.
local B = { resource = 'qbx_core' }

function B.get_player(src)
  local player = exports.qbx_core:GetPlayer(src)
  local data = player and player.PlayerData
  if not data then return nil end

  return {
    identifier = data.license,
    charinfo = data.charinfo,
    job = data.job,
    has_group = function(label) return IsPlayerAceAllowed(src, label) end,
  }
end

function B.revive(src)
  if GetResourceState('qbx_medical') ~= 'started' then return end
  exports.qbx_medical:Revive(src)
  return true
end

if StaffSuiteModules then StaffSuiteModules['server.bridges.qbox'] = B end
return B
