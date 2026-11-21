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

local capabilities = { 'report.view', 'report.claim', 'report.resolve', 'report.message', 'audit.view', 'audit.verify' }
local actions = { claim = true, resolve = true, close = true, reopen = true }

local function playerIdentifier(src)
  local ids = GetPlayerIdentifiers(src)
  local alternative = ids[1]
  for _, id in ipairs(ids) do
    if id:sub(1, 8) == 'license:' then return id end
    if id:sub(1, 9) == 'license2:' then alternative = id end
  end
  return alternative
end

local function identifier(src)
  return playerIdentifier(src) or 'src:' .. src
end

local function positiveInteger(value)
  local n = tonumber(value)
  if n and n > 0 and n <= 2147483647 and n % 1 == 0 then return math.tointeger(n) end
end

local function isStaff(src)
  return src ~= 0 and IsPlayerAceAllowed(src, 'staff_suite.lite')
end

local function notify(src, key, vars, opts)
  TriggerClientEvent('staff_suite:notify', src, t(key, vars), opts)
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

-- Una entrada corrupta en disco no debe tumbar el handler: se reporta como rotura.
local function safeVerify()
  local done, ok, at = pcall(audit.verify, chain)
  if done then return ok, at end
  return false, 1
end

local verifyCache = {}
local function verifyCached()
  if verifyCache.n ~= #chain.entries or verifyCache.head ~= chain.head then
    verifyCache = { n = #chain.entries, head = chain.head, result = { safeVerify() } }
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
  local reporter = playerIdentifier(src)
  TriggerClientEvent('staff_suite:state', src, {
    tickets = staff and store.tickets or {},
    myTickets = tickets.reporter_view(store, reporter),
    audit = staff and chain.entries or {},
    verify = staff and verifyCached() or {},
    player = {
      identifier = reporter or 'src:' .. src, name = GetPlayerName(src), rank = staff and 'lite_staff' or 'player',
      capabilities = staff and capabilities or {},
    },
  })
end

local function publishUpdates(ticket, staffReply)
  for _, player in ipairs(GetPlayers()) do
    local src = tonumber(player)
    if isStaff(src) then
      TriggerClientEvent('staff_suite:state', src, { tickets = store.tickets, audit = chain.entries })
    end
    if ticket and playerIdentifier(src) == ticket.reporter then
      TriggerClientEvent('staff_suite:state', src, { myTickets = tickets.reporter_view(store, ticket.reporter) })
      if staffReply then notify(src, 'ticket_staff_reply', { id = ticket.id }, { kind = 'reply' }) end
    end
  end
end

-- Devuelve true o false y el motivo, para que el panel conserve el borrador si falla.
local function createReport(src, category, body)
  if src == 0 then return false end
  local tooLong
  body, tooLong = cleanText(body, limits.ticket_body)
  if tooLong then notify(src, 'input_too_long', { max = tooLong }); return false, t('input_too_long', { max = tooLong }) end
  if not body or body == '' then return false end
  local reporter, open = identifier(src), 0
  for _, ticket in pairs(store.tickets) do
    if ticket.reporter == reporter and tickets.is_open(ticket) then open = open + 1 end
  end
  if limits.open_tickets_per_player and open >= limits.open_tickets_per_player then
    notify(src, 'report_too_many_open', { max = limits.open_tickets_per_player })
    return false, t('report_too_many_open', { max = limits.open_tickets_per_player })
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
  publishUpdates(ticket)
  return true
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
    local ok, at = safeVerify()
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
RegisterNetEvent('staff_suite:ticketCreate', function(category, _, body, req)
  local src = source
  local ok, err = false, t('rate_limited')
  if allowRate(src, 'staff_suite:ticketCreate') then ok, err = createReport(src, category, body) end
  req = positiveInteger(req)
  if req then
    TriggerClientEvent('staff_suite:ticketCreateResult', src, { req = req, ok = ok == true, error = err })
  end
end)
net('staff_suite:ticketAction', function(id, action, extra)
  local src = source
  if not isStaff(src) or not actions[action] then return end
  id = positiveInteger(id)
  if not id then return end
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
  publishUpdates(ticket)
end)

local function addTicketMessage(src, id, body, asReporter)
  local reporter = playerIdentifier(src)
  local ticket = store.tickets[positiveInteger(id)]
  if asReporter then
    if not reporter or not ticket or reporter ~= ticket.reporter then return false, t('no_permission') end
  elseif not isStaff(src) then
    return false, t('no_permission')
  end
  local tooLong
  body, tooLong = cleanText(body, limits.message_body or 1000)
  if tooLong then return false, t('input_too_long', { max = tooLong }) end
  if not ticket or not tickets.is_open(ticket) or not body or body == '' then
    return false, t('ticket_message_failed')
  end
  local _, ev = tickets.add_message(store, ticket.id, reporter or 'src:' .. src, body, false, os.time())
  record(ev.action, ev.actor, 'ticket:' .. ticket.id, '', { ticket = ticket.id, internal = false, message = #ticket.messages })
  publishUpdates(ticket, not asReporter and reporter ~= ticket.reporter)
  return true
end

local function receiveTicketMessage(src, id, body, internal, asReporter, req)
  local ok, err = false
  if not allowRate(src, 'staff_suite:ticketMessage') then
    err = t('rate_limited')
  elseif internal ~= nil and internal ~= false then
    err = t('ticket_message_failed')
  else
    ok, err = addTicketMessage(src, id, body, asReporter)
  end
  req = positiveInteger(req)
  if req then
    TriggerClientEvent('staff_suite:ticketMessageResult', src, { req = req, ok = ok, error = err })
  elseif err and err ~= t('rate_limited') then
    TriggerClientEvent('staff_suite:notify', src, err)
  end
end

-- El reportante puede cancelar su ticket mientras siga abierto o reabierto, sin claim.
RegisterNetEvent('staff_suite:ticketCancel', function(id, req)
  local src = source
  req = positiveInteger(req)
  local function reply(ok, err)
    if req then TriggerClientEvent('staff_suite:ticketCancelResult', src, { req = req, ok = ok, error = err }) end
  end
  if not allowRate(src, 'staff_suite:ticketCancel') then return reply(false, t('rate_limited')) end
  local reporter = playerIdentifier(src)
  id = positiveInteger(id)
  local ticket = id and store.tickets[id]
  if not reporter or not ticket or ticket.reporter ~= reporter then return reply(false, t('no_permission')) end
  if ticket.state ~= 'open' and ticket.state ~= 'reopened' then return reply(false, t('ticket_cancel_late')) end
  local tk, ev = tickets.transition(store, id, 'cancel', reporter, { ts = os.time() })
  if not tk then return reply(false, t(ev:match('^[^:]+') or 'invalid_transition')) end
  record(ev.action, ev.actor, 'ticket:' .. id, '', { from = ev.from, to = ev.to })
  reply(true)
  publishUpdates(ticket)
end)

RegisterNetEvent('staff_suite:ticketMessage', function(id, body, internal, req)
  receiveTicketMessage(source, id, body, internal, false, req)
end)
RegisterNetEvent('staff_suite:ticketReply', function(id, body, req)
  receiveTicketMessage(source, id, body, false, true, req)
end)

net('staff_suite:verify', function()
  local src = source
  if not isStaff(src) then return end
  local ok, at = safeVerify()
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
