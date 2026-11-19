-- server/bridges/qbcore.lua — bridge QBCore.
SS = SS or {}
SS.bridges = SS.bridges or {}
local B = { name = 'qbcore' }
local QBCore = nil

function B.detect()
  if GetResourceState('qb-core') ~= 'started' then return false end
  local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
  if ok and obj then QBCore = obj; return true end
  return false
end

function B.get_identifier(src)
  local p = QBCore and QBCore.Functions.GetPlayer(src)
  return p and p.PlayerData.license or SS.bridges.standalone.get_identifier(src)
end

function B.get_name(src)
  local p = QBCore and QBCore.Functions.GetPlayer(src)
  if p then return p.PlayerData.charinfo.firstname .. ' ' .. p.PlayerData.charinfo.lastname end
  return SS.bridges.standalone.get_name(src)
end

function B.get_rank(src)
  if QBCore and QBCore.Functions.HasPermission(src, 'god') then return 'owner' end
  if QBCore and QBCore.Functions.HasPermission(src, 'admin') then return 'admin' end
  if QBCore and QBCore.Functions.HasPermission(src, 'mod') then return 'moderator' end
  return Config.DefaultRank
end

function B.mod_action(action, target, reason, actor)
  if action == 'kick' then
    QBCore.Functions.Kick(target, reason or 'Kicked', true)
  elseif action == 'ban' then
    QBCore.Functions.BanPlayer(target, reason or 'Banned', 0, actor)
  else
    return SS.bridges.standalone.mod_action(action, target, reason, actor)
  end
  return true
end

SS.bridges.qbcore = B
