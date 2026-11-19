-- server/bridges/esx.lua — bridge ESX Legacy.
SS = SS or {}
SS.bridges = SS.bridges or {}
local B = { name = 'esx' }
local ESX = nil

function B.detect()
  if GetResourceState('es_extended') ~= 'started' then return false end
  local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
  if ok and obj then ESX = obj; return true end
  return false
end

function B.get_identifier(src)
  local xP = ESX and ESX.GetPlayerFromId(src)
  return xP and xP.identifier or SS.bridges.standalone.get_identifier(src)
end

function B.get_name(src)
  local xP = ESX and ESX.GetPlayerFromId(src)
  return xP and xP.getName() or SS.bridges.standalone.get_name(src)
end

function B.get_rank(src)
  local xP = ESX and ESX.GetPlayerFromId(src)
  if not xP then return Config.DefaultRank end
  local grp = xP.getGroup()
  return Config.RankMap[grp] or Config.DefaultRank
end

function B.mod_action(action, target, reason, actor)
  if action == 'kick' then
    local xP = ESX.GetPlayerFromId(target)
    if xP then xP.kick(reason or 'Kicked') end
  elseif action == 'ban' then
    TriggerEvent('esx:banPlayer', target, reason, actor)
  else
    return SS.bridges.standalone.mod_action(action, target, reason, actor)
  end
  return true
end

SS.bridges.esx = B
