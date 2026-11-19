-- Traduce el snapshot del core a filas y escribe lotes en una sola transacción.
local M = {}

local specs = {
  { name = 'audit', keys = { 'seq' },
    columns = { 'seq', 'ts', 'actor', 'action', 'target', 'reason', 'payload', 'prev_hash', 'hash' },
    numbers = { 'seq', 'ts' } },
  { name = 'tickets', keys = { 'id' },
    columns = { 'id', 'reporter', 'category', 'priority', 'description', 'state', 'claimer',
      'created_ts', 'updated_ts', 'resolution', 'rating' },
    numbers = { 'id', 'created_ts', 'updated_ts', 'rating' } },
  { name = 'messages', keys = { 'ticket_id', 'position' },
    columns = { 'ticket_id', 'position', 'author', 'body', 'internal', 'ts' },
    numbers = { 'ticket_id', 'position', 'internal', 'ts' } },
  { name = 'duty', keys = { 'actor' }, columns = { 'actor', 'on_duty', 'since_ts', 'total_seconds', 'sessions' },
    numbers = { 'on_duty', 'since_ts', 'total_seconds', 'sessions' } },
  { name = 'stats', keys = { 'actor' },
    columns = { 'actor', 'resolved', 'response_sum', 'response_n', 'ratings_sum', 'ratings_n' },
    numbers = { 'resolved', 'response_sum', 'response_n', 'ratings_sum', 'ratings_n' } },
  { name = 'bans', keys = { 'identifier' }, columns = { 'identifier', 'actor', 'reason', 'created_at', 'expires_at' },
    numbers = { 'created_at', 'expires_at' } },
}

local function quoted(columns)
  return '`' .. table.concat(columns, '`, `') .. '`'
end

local function call(method, statement, params, cb)
  local finished = false
  local function done(result)
    if finished then return end
    finished = true
    cb(result)
  end
  SetTimeout(10000, function() done(nil) end)
  local db = exports.oxmysql
  local ok = pcall(function() db[method](db, statement, params, done) end)
  if not ok then done(nil) end
end

local function indexRow(spec, row)
  local key = row[spec.keys[1]]
  if #spec.keys == 2 then key = key .. ':' .. row[spec.keys[2]] end
  return key
end

local function rowValues(spec, row)
  local values = {}
  for i, column in ipairs(spec.columns) do
    local value = row[column]
    if value == nil then value = false end -- Marcador de SQL NULL, nunca se manda a oxmysql.
    values[i] = value
  end
  return values
end

local function decode(raw)
  if not raw then return nil end
  local ok, data = pcall(json.decode, raw)
  if ok and type(data) == 'table' then return data end
end

local function restore(tables, meta)
  local state = {
    chain = { entries = tables.audit, head = meta.head }, tickets = { next_id = meta.next_id or 1, tickets = {} },
    perms = meta.perms, duty = { staff = {} }, bans = {},
  }
  local store = state.tickets
  for _, ticket in ipairs(tables.tickets) do
    ticket.messages = {}
    store.tickets[ticket.id] = ticket
    store.next_id = math.max(store.next_id, ticket.id + 1)
  end
  for _, row in ipairs(tables.messages) do
    local messages = store.tickets[row.ticket_id].messages
    messages[#messages + 1] = { author = row.author, body = row.body, internal = row.internal == 1, ts = row.ts }
  end
  for _, row in ipairs(tables.duty) do
    state.duty.staff[row.actor] = { on_duty = row.on_duty == 1, since = row.since_ts,
      total_seconds = row.total_seconds, sessions = row.sessions,
      resolved = 0, response_sum = 0, response_n = 0, ratings_sum = 0, ratings_n = 0 }
  end
  for _, row in ipairs(tables.stats) do
    local staff = state.duty.staff[row.actor]
    for column, value in pairs(row) do
      if column ~= 'actor' then staff[column] = value end
    end
  end
  for _, row in ipairs(tables.bans) do
    state.bans[row.identifier] = { actor = row.actor, reason = row.reason,
      created_at = row.created_at, expires_at = row.expires_at }
  end
  return state
end

function M.available()
  return GetResourceState('oxmysql') == 'started'
end

function M.load(cb)
  local tables, cache = {}, {}
  local function readTable(i)
    local spec = specs[i]
    if not spec then
      call('query', 'SELECT k, data FROM staff_state WHERE k IN (?, ?)', { 'metadata', 'state' }, function(rows)
        if type(rows) ~= 'table' then cb(false); return end
        local legacy, meta
        for _, row in ipairs(rows) do
          local data = decode(row.data)
          if not data then cb(false); return end
          if row.k == 'metadata' then meta = data else legacy = data end
        end
        if meta then
          local ok, state = pcall(restore, tables, meta)
          if not ok then cb(false); return end
          cb(true, state, cache)
        elseif #tables.audit > 0 then
          -- La fila de metadatos y las filas de la cadena se escriben juntas.
          cb(false)
        else
          cb(true, legacy, cache)
        end
      end)
      return
    end
    local query = 'SELECT ' .. quoted(spec.columns) .. ' FROM staff_' .. spec.name .. ' ORDER BY ' .. quoted(spec.keys)
    call('query', query, {}, function(rows)
      if type(rows) ~= 'table' then cb(false); return end
      local values = {}
      for _, row in ipairs(rows) do
        for _, column in ipairs(spec.numbers) do
          if type(row[column]) == 'boolean' then row[column] = row[column] and 1 or 0 end
          row[column] = tonumber(row[column])
        end
        values[indexRow(spec, row)] = rowValues(spec, row)
      end
      tables[spec.name], cache[spec.name] = rows, values
      readTable(i + 1)
    end)
  end
  readTable(1)
end

local function rowsFor(state)
  local rows = { audit = state.chain.entries, tickets = state.tickets.tickets, messages = {},
    duty = {}, stats = {}, bans = {} }
  for _, ticket in pairs(rows.tickets) do
    for i, msg in ipairs(ticket.messages) do
      rows.messages[#rows.messages + 1] = { ticket_id = ticket.id, position = i,
        author = msg.author, body = msg.body, internal = msg.internal and 1 or 0, ts = msg.ts }
    end
  end
  for actor, staff in pairs(state.duty.staff) do
    rows.duty[#rows.duty + 1] = { actor = actor, on_duty = staff.on_duty and 1 or 0,
      since_ts = staff.since, total_seconds = staff.total_seconds, sessions = staff.sessions }
    rows.stats[#rows.stats + 1] = { actor = actor, resolved = staff.resolved, response_sum = staff.response_sum,
      response_n = staff.response_n, ratings_sum = staff.ratings_sum, ratings_n = staff.ratings_n }
  end
  for identifier, ban in pairs(state.bans) do
    rows.bans[#rows.bans + 1] = { identifier = identifier, actor = ban.actor, reason = ban.reason,
      created_at = ban.created_at, expires_at = ban.expires_at }
  end
  return rows
end

local function changed(spec, before, values)
  if not before then return true end
  if spec.name == 'audit' then return false end -- Las entradas existentes nunca se reescriben.
  for i = 1, #spec.columns do
    if before[i] ~= values[i] then return true end
  end
  return false
end

local function writeRows(spec, rows, previous, queries)
  local insert = 'INSERT INTO staff_' .. spec.name .. ' (' .. quoted(spec.columns) .. ') VALUES '
  local suffix = ''
  if spec.name ~= 'audit' then
    local updates = {}
    for i = #spec.keys + 1, #spec.columns do
      local col = '`' .. spec.columns[i] .. '`'
      updates[#updates + 1] = col .. ' = VALUES(' .. col .. ')'
    end
    suffix = ' ON DUPLICATE KEY UPDATE ' .. table.concat(updates, ', ')
  end

  local output, chunks, params = {}, {}, {}
  local function emit()
    queries[#queries + 1] = { query = insert .. table.concat(chunks, ', ') .. suffix, values = params }
    chunks, params = {}, {}
  end
  for _, row in pairs(rows) do
    local key = indexRow(spec, row)
    local values = rowValues(spec, row)
    output[key] = values
    if changed(spec, previous[key], values) then
      local placeholders = {}
      for i, value in ipairs(values) do
        placeholders[i] = value == false and 'NULL' or '?'
        if value ~= false then params[#params + 1] = value end
      end
      chunks[#chunks + 1] = '(' .. table.concat(placeholders, ', ') .. ')'
      if #chunks == 100 then emit() end
    end
  end
  if #chunks > 0 then emit() end
  return output
end

function M.save(state, cache, cb)
  local rows = rowsFor(state)
  local queries, nextCache = {}, {}
  for _, spec in ipairs(specs) do
    nextCache[spec.name] = writeRows(spec, rows[spec.name], cache[spec.name], queries)
  end
  queries[#queries + 1] = {
    query = 'INSERT INTO staff_state (k, v, data) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',
    values = { 'metadata', '1', json.encode({ head = state.chain.head, next_id = state.tickets.next_id,
      perms = state.perms }) },
  }
  call('transaction', queries, {}, function(ok) cb(ok == true, nextCache) end)
end

if StaffSuiteModules then StaffSuiteModules['server.persist_sql'] = M end
return M
