-- ESX Legacy: grupo de administración e identidad del xPlayer.
local B = { resource = 'es_extended' }

function B.get_player(src)
  local esx = exports.es_extended:getSharedObject()
  local player = esx.GetPlayerFromId(src)
  if not player then return nil end

  local group = player.getGroup()
  return {
    identifier = player.license or player.identifier or player.getIdentifier(),
    name = player.getName(),
    job = player.getJob(),
    has_group = function(label) return label == group end,
  }
end

return B
