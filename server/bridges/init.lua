-- Selección del bridge e identidad común para los permisos del core.
local loadmod = StaffSuiteModules and StaffSuiteModules.loadmod or require
local standalone = loadmod('server.bridges.standalone')
local adapters = {
  esx = loadmod('server.bridges.esx'),
  qbcore = loadmod('server.bridges.qbcore'),
  qbox = loadmod('server.bridges.qbox'),
}
local detection_order = { 'qbox', 'qbcore', 'esx' }
local rank_level = { helper = 1, moderator = 2, admin = 3, senior_admin = 4, owner = 5 }
local standalone_ranks = {}
for rank in pairs(rank_level) do standalone_ranks[rank] = rank end

local M = {}

function M.select(config)
  local override = config.Framework or 'auto'
  if override ~= 'auto' then
    assert(override == 'standalone' or adapters[override], '[StaffSuite] Config.Framework inválido')
    return override
  end

  -- Qbox puede ofrecer compatibilidad con qb-core. Usar primero su API nativa.
  for _, name in ipairs(detection_order) do
    if GetResourceState(adapters[name].resource) == 'started' then return name end
  end
  return 'standalone'
end

local function highest_rank(mapping, has_group, best)
  for label, rank in pairs(mapping or {}) do
    if (rank_level[rank] or 0) > (rank_level[best] or 0) and has_group(label) then
      best = rank
    end
  end
  return best
end

local function framework_player(src, framework, config)
  local adapter = adapters[framework]
  if GetResourceState(adapter.resource) ~= 'started' then return nil end
  local player = adapter.get_player(src)
  if not player then return nil end

  local jobs = config.JobRankMap and config.JobRankMap[framework]
  local job_rank = jobs and player.job and jobs[player.job.name]
  if not rank_level[job_rank] then job_rank = nil end
  player.rank = highest_rank(config.RankMap, player.has_group, job_rank)
  return player
end

local function nonempty(value)
  return type(value) == 'string' and value:match('%S') and value or nil
end

local function display_name(player)
  if not player.charinfo then return nonempty(player.name) end
  local first = nonempty(player.charinfo.firstname)
  local last = nonempty(player.charinfo.lastname)
  if first and last then return first .. ' ' .. last end
  return first or last
end

function M.resolve(src, config)
  src = tonumber(src)
  if not src or src <= 0 or src % 1 ~= 0 then return {} end

  local framework = M.select(config)
  local native = standalone.get_player(src)
  if framework == 'standalone' then
    local identifier = native.license or native.identifier
    local rank = config.StandaloneRanks and config.StandaloneRanks[identifier]
    native.rank = highest_rank(standalone_ranks, native.has_group, rank_level[rank] and rank)
  else
    -- Si el export aún no está listo, conservar la identidad nativa sin permisos del framework.
    local ok, player = pcall(framework_player, src, framework, config)
    if ok and player then
      native.identifier = nonempty(player.identifier) or native.identifier
      native.name = display_name(player) or native.name
      native.rank = player.rank
    end
  end

  return {
    identifier = native.license or native.identifier,
    name = nonempty(native.name) or ('player ' .. src),
    rank = native.rank,
  }
end

if StaffSuiteModules then StaffSuiteModules['server.bridges.init'] = M end
return M
