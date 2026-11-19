-- Captura best-effort de eventos locales emitidos por los recursos originales.
local M = {}

local function str(value)
  if type(value) == 'string' and value ~= '' then return value end
end

function M.install(config, selectFramework, identifier, record)
  if not config.Audit.capture_framework then return end

  local function hook(event, resource, framework, fn)
    AddEventHandler(event, function(...)
      if GetInvokingResource() ~= resource then return end
      if framework and selectFramework(config) ~= framework then return end
      fn(...)
    end)
  end

  local function frameworkEvent(framework, action, src, reason, details)
    src = tonumber(src)
    if not src or src < 1 or src % 1 ~= 0 then return end
    details.framework = framework
    record(action, 'system', identifier(src), str(reason) or '', details)
  end

  local function job(framework, src, data)
    if type(data) ~= 'table' or not str(data.name) then return end
    local grade = data.grade
    if type(grade) == 'table' then grade = grade.level end
    frameworkEvent(framework, 'framework_job', src, '', { job = data.name, grade = tonumber(grade) })
  end

  hook('esx:setJob', 'es_extended', 'esx', function(src, data) job('esx', src, data) end)
  hook('esx:setGroup', 'es_extended', 'esx', function(src, group, previous)
    if not str(group) then return end
    frameworkEvent('esx', 'framework_group', src, '', { group = group, previous = str(previous) })
  end)
  hook('esx:onAddInventoryItem', 'es_extended', 'esx', function(src, item, total)
    if not str(item) or type(total) ~= 'number' then return end
    frameworkEvent('esx', 'framework_item_added', src, '', { item = item, total = total })
  end)

  local function money(framework, src, account, amount, operation, reason)
    if not str(account) or type(amount) ~= 'number' then return end
    if operation ~= 'add' and operation ~= 'set' then return end
    frameworkEvent(framework, 'framework_money', src, reason, {
      account = account, amount = amount, operation = operation,
    })
  end
  hook('esx:addAccountMoney', 'es_extended', 'esx', function(src, account, amount, reason)
    money('esx', src, account, amount, 'add', reason)
  end)
  hook('esx:setAccountMoney', 'es_extended', 'esx', function(src, account, amount, reason)
    money('esx', src, account, amount, 'set', reason)
  end)
  hook('QBCore:Server:OnPlayerUpdated', 'qb-core', 'qbcore', function(src, field, data)
    if field == 'job' then job('qbcore', src, data) end
  end)
  hook('QBCore:Server:OnJobUpdate', 'qb-core', 'qbcore', function(src, data) job('qbcore', src, data) end)
  for framework, resource in pairs({ qbcore = 'qb-core', qbox = 'qbx_core' }) do
    hook('QBCore:Server:OnMoneyChange', resource, framework, function(...)
      money(framework, ...)
    end)
  end
  hook('qbx_core:server:onGroupUpdate', 'qbx_core', 'qbox', function(src, group, grade)
    if not str(group) then return end
    frameworkEvent('qbox', 'framework_group', src, '', {
      group = group, grade = tonumber(grade), removed = grade == nil,
    })
  end)

  local events = { playerBanned = 'ban', playerKicked = 'kick', playerWarned = 'warn', playerHealed = 'heal' }
  for event, action in pairs(events) do
    hook('txAdmin:events:' .. event, 'monitor', nil, function(data)
      if type(data) ~= 'table' or not str(data.author) then return end
      local src = tonumber(data.targetNetId or data.target)
      local ids = {}
      for _, id in ipairs(type(data.targetIds) == 'table' and data.targetIds or {}) do
        if str(id) then ids[#ids + 1] = id end
      end
      local target = src == -1 and 'all' or src and src > 0 and identifier(src) or ids[1] or str(data.targetName)
      if not target then return end
      record('txadmin_' .. action, 'txAdmin:' .. data.author, target, str(data.reason) or '', {
        ids = #ids > 0 and ids or nil, name = str(data.targetName),
        action_id = data.actionId, expiration = data.expiration,
      })
    end)
  end
end

if StaffSuiteModules then StaffSuiteModules['server.capture'] = M end
return M
