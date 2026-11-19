-- server/bridges/qbox.lua — bridge Qbox (qbx_core).
SS = SS or {}
SS.bridges = SS.bridges or {}
local B = { name = 'qbox' }

function B.detect()
  return GetResourceState('qbx_core') == 'started'
end

function B.get_identifier(src)
  local ok, license = pcall(function() return exports.qbx_core:GetPlayer(src).PlayerData.license end)
  if ok and license then return license end
  return SS.bridges.standalone.get_identifier(src)
end

function B.get_name(src)
  local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
  if ok and p then return p.PlayerData.charinfo.firstname .. ' ' .. p.PlayerData.charinfo.lastname end
  return SS.bridges.standalone.get_name(src)
end

function B.get_rank(src)
  local ok, groups = pcall(function() return exports.qbx_core:GetGroups(src) end)
  if ok and groups then
    if groups.god then return 'owner' end
    if groups.admin then return 'admin' end
    if groups.mod then return 'moderator' end
  end
  return Config.DefaultRank
end

function B.mod_action(action, target, reason, actor)
  if action == 'kick' then
    DropPlayer(target, reason or 'Kicked')
  elseif action == 'ban' then
    TriggerEvent('staff_suite:banRequest', target, reason, actor)
  else
    return SS.bridges.standalone.mod_action(action, target, reason, actor)
  end
  return true
end

SS.bridges.qbox = B
