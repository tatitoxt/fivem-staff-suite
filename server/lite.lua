-- Adapter de Free Lite. El ACE staff_suite.lite habilita el panel de staff.
local t = StaffSuiteTranslate
local loadmod = StaffSuiteModules.loadmod
local audit = loadmod('core.audit_chain')
local tickets = loadmod('core.tickets')
local localFile = loadmod('server.persist_json')
local ratelimit = loadmod('core.ratelimit')
local limiter = ratelimit.new()
local limits = Config.Limits or {}

local saved = localFile.load(Config.JsonFile) or {}
local chain = audit.new()
if saved.chain then
  chain.entries = saved.chain.entries or {}
  local last = chain.entries[#chain.entries]
  chain.head = type(last) == 'table' and type(last.hash) == 'string' and last.hash or audit.GENESIS
end
local store = tickets.new_store()
for _, ticket in pairs(saved.tickets and saved.tickets.tickets or {}) do
  store.tickets[ticket.id] = ticket
  store.next_id = math.max(store.next_id, ticket.id + 1)
end
store.next_id = math.max(store.next_id, saved.tickets and saved.tickets.next_id or 1)

local capabilities = { 'report.view', 'report.claim', 'report.resolve', 'audit.view', 'audit.verify' }
local actions = { claim = true, resolve = true, close = true, reopen = true }

local function identifier(src)
  local ids = GetPlayerIdentifiers(src)
  local alternative = ids[1]
  for _, id in ipairs(ids) do
    if id:sub(1, 8) == 'license:' then return id end
    if id:sub(1, 9) == 'license2:' then alternative = id end
  end
  return alternative or 'src:' .. src
end

local function isStaff(src)
  return src ~= 0 and IsPlayerAceAllowed(src, 'staff_suite.lite')
end

local function notify(src, key, vars)
  TriggerClientEvent('staff_suite:notify', src, t(key, vars))
end

local function allowRate(src, key)
  src = tonumber(src)
  if not src or src <= 0 then return true end
  local rules = Config.RateLimit or {}
  local ok, first = ratelimit.allow(limiter, src, key, rules[key] or rules.default, os.time())
  if not ok and first then notify(src, 'rate_limited') end
  return ok
end

local function cleanText(value, maxBytes)
  if type(value) ~= 'string' then return nil end
  -- Corte previo: el recorte y los patrones nunca procesan strings enormes.
  if maxBytes and #value > maxBytes * 4 + 64 then return nil, maxBytes end
  value = value:gsub('[\0-\8\11\12\14-\31\127]', '')
  local first = value:find('%S')
  if not first then return '' end
  local _, last = value:find('.*%S')
  value = value:sub(first, last)
  if maxBytes and #value > maxBytes then return nil, maxBytes end
  return value
end

local verifyCache = {}
local function verifyCached()
  if verifyCache.n ~= #chain.entries or verifyCache.head ~= chain.head then
    verifyCache = { n = #chain.entries, head = chain.head, result = { audit.verify(chain) } }
  end
  return verifyCache.result
end

local function save()
  local ok, wrote = pcall(localFile.save, Config.JsonFile, { chain = chain, tickets = store })
  if not ok or not wrote then print(t('persistence_save_failed')) end
end

local function record(action, actor, target, reason, payload)
  audit.append(chain, {
    ts = os.time(), action = action, actor = actor, target = target, reason = reason,
    payload = payload and json.encode(payload) or '',
  })
  save()
end

local function sendState(src)
  local staff = isStaff(src)
  TriggerClientEvent('staff_suite:state', src, {
    tickets = staff and store.tickets or {},
    audit = staff and chain.entries or {},
    verify = staff and verifyCached() or {},
    player = {
      identifier = identifier(src), name = GetPlayerName(src), rank = staff and 'lite_staff' or 'player',
      capabilities = staff and capabilities or {},
    },
  })
end

local function publishUpdates()
  for _, player in ipairs(GetPlayers()) do
    local src = tonumber(player)
    if isStaff(src) then
      TriggerClientEvent('staff_suite:state', src, { tickets = store.tickets, audit = chain.entries })
    end
  end
end

local function createReport(src, category, body)
  if src == 0 then return end
  local tooLong
  body, tooLong = cleanText(body, limits.ticket_body)
  if tooLong then notify(src, 'input_too_long', { max = tooLong }); return end
  if not body or body == '' then return end
  local reporter, open = identifier(src), 0
  for _, ticket in pairs(store.tickets) do
    if ticket.reporter == reporter and ticket.state ~= 'resolved' and ticket.state ~= 'closed' then open = open + 1 end
  end
  if limits.open_tickets_per_player and open >= limits.open_tickets_per_player then
    notify(src, 'report_too_many_open', { max = limits.open_tickets_per_player })
    return
  end
  local selected = 'other'
  for _, allowed in ipairs(Config.Categories) do
    if category == allowed then selected = allowed; break end
  end
  local ticket, ev = tickets.create(store, {
    reporter = reporter, category = selected, description = body, ts = os.time(),
  })
  record(ev.action, ev.actor, ev.target, '', { ticket = ticket.id, category = selected })
  notify(src, 'report_created', { id = ticket.id })
  publishUpdates()
end

RegisterCommand(Config.Commands.report, function(src, args)
  if not allowRate(src, 'staff_suite:ticketCreate') then return end
  createReport(src, args[1], table.concat(args, ' ', 2))
end, false)
RegisterCommand(Config.Commands.reports, function(src)
  if isStaff(src) then TriggerClientEvent('staff_suite:openPanel', src, 'tickets') end
end, false)
RegisterCommand(Config.Commands.audit, function(src)
  if src == 0 then
    local ok, at = audit.verify(chain)
    print(ok and t('console_audit_ok', { n = #chain.entries }) or t('console_audit_broken', { seq = at }))
  elseif isStaff(src) then
    TriggerClientEvent('staff_suite:openPanel', src, 'audit')
  end
end, false)

-- Cada evento de red pasa por el rate limit antes de tocar el estado.
local function net(name, fn)
  RegisterNetEvent(name, function(...)
    if allowRate(source, name) then return fn(...) end
  end)
end

net('staff_suite:getState', function() sendState(source) end)
net('staff_suite:ticketCreate', function(category, _, body) createReport(source, category, body) end)
net('staff_suite:ticketAction', function(id, action, extra)
  local src = source
  if not isStaff(src) or not actions[action] then return end
  id = tonumber(id)
  if not id or id < 1 or id % 1 ~= 0 then return end
  extra = type(extra) == 'table' and extra or {}
  local resolution, tooLong = cleanText(extra.resolution, limits.resolution)
  if tooLong then notify(src, 'input_too_long', { max = tooLong }); return end
  local ticket, ev = tickets.transition(store, id, action, identifier(src), {
    ts = os.time(), resolution = resolution ~= '' and resolution or nil,
  })
  if not ticket then
    notify(src, ev:match('^[^:]+') or 'invalid_transition')
    return
  end
  record(ev.action, ev.actor, 'ticket:' .. id, ev.reason, { from = ev.from, to = ev.to })
  publishUpdates()
end)

net('staff_suite:verify', function()
  local src = source
  if not isStaff(src) then return end
  local ok, at = audit.verify(chain)
  record('audit_verify', identifier(src), '', ok and 'ok' or ('broken:' .. tostring(at)))
  publishUpdates()
  TriggerClientEvent('staff_suite:auditResult', src, { ok = ok, at = at, n = #chain.entries })
end)

AddEventHandler('playerDropped', function()
  ratelimit.forget(limiter, tonumber(source))
end)

AddEventHandler('onResourceStop', function(resource)
  if resource == GetCurrentResourceName() then save() end
end)
