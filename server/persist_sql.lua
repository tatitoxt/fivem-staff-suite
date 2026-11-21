-- Traduce el snapshot del core a filas y escribe lotes en una sola transacción.
local M = {}

local function t(key, vars) return StaffSuiteTranslate(key, vars) end

-- Migraciones de sql/ que se aplican solas al iniciar y quedan registradas en staff_schema.
M.MIGRATIONS = {
  { version = 1, file = 'sql/001_staff_suite.sql' },
  { version = 2, file = 'sql/002_tickets_f2.sql' },
  { version = 3, file = 'sql/003_ban_review.sql' },
  { version = 4, file = 'sql/004_ticket_labels.sql' },
}

local specs = {
  { name = 'audit', keys = { 'seq' },
    columns = { 'seq', 'ts', 'actor', 'action', 'target', 'reason', 'payload', 'prev_hash', 'hash' },
    numbers = { 'seq', 'ts' } },
  { name = 'tickets', keys = { 'id' },
    columns = { 'id', 'reporter', 'category', 'priority', 'description', 'state', 'claimer',
      'created_ts', 'updated_ts', 'resolution', 'rating', 'first_response_ts', 'resolved_by',
      'labels' },
    numbers = { 'id', 'created_ts', 'updated_ts', 'rating', 'first_response_ts' } },
  { name = 'messages', keys = { 'ticket_id', 'position' },
    columns = { 'ticket_id', 'position', 'author', 'body', 'internal', 'ts' },
    numbers = { 'ticket_id', 'position', 'internal', 'ts' } },
  { name = 'evidence', keys = { 'ticket_id', 'n' },
    columns = { 'ticket_id', 'n', 'ts', 'actor', 'sha256', 'size', 'audit_seq' },
    numbers = { 'ticket_id', 'n', 'ts', 'size', 'audit_seq' } },
  { name = 'duty', keys = { 'actor' }, columns = { 'actor', 'on_duty', 'since_ts', 'total_seconds', 'sessions' },
    numbers = { 'on_duty', 'since_ts', 'total_seconds', 'sessions' } },
  { name = 'stats', keys = { 'actor' },
    columns = { 'actor', 'resolved', 'response_sum', 'response_n', 'ratings_sum', 'ratings_n' },
    numbers = { 'resolved', 'response_sum', 'response_n', 'ratings_sum', 'ratings_n' } },
  { name = 'bans', keys = { 'identifier' },
    columns = { 'identifier', 'actor', 'reason', 'created_at', 'expires_at', 'ban_id', 'revoked_at' },
    numbers = { 'created_at', 'expires_at', 'ban_id', 'revoked_at' } },
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
    if type(value) == 'table' then value = json.encode(value) end
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
    perms = meta.perms, duty = { staff = {} }, bans = {}, playtime = meta.playtime,
  }
  local store = state.tickets
  for _, ticket in ipairs(tables.tickets) do
    ticket.labels = decode(ticket.labels) or {}
    ticket.messages = {}
    store.tickets[ticket.id] = ticket
    store.next_id = math.max(store.next_id, ticket.id + 1)
  end
  for _, row in ipairs(tables.messages) do
    local messages = store.tickets[row.ticket_id].messages
    messages[#messages + 1] = { author = row.author, body = row.body, internal = row.internal == 1, ts = row.ts }
  end
  for _, row in ipairs(tables.evidence) do
    local ticket = store.tickets[row.ticket_id]
    ticket.evidence = ticket.evidence or {}
    ticket.evidence[row.n] = { n = row.n, ts = row.ts, by = row.actor, sha256 = row.sha256,
      size = row.size, audit_seq = row.audit_seq }
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
      created_at = row.created_at, expires_at = row.expires_at, id = row.ban_id, revoked_at = row.revoked_at }
  end
  return state
end

local function statements(raw)
  local out = {}
  for stmt in raw:gsub('%-%-[^\n]*', ''):gmatch('[^;]+') do
    stmt = stmt:match('^%s*(.-)%s*$')
    if stmt ~= '' then out[#out + 1] = stmt end
  end
  return out
end

M.specs = specs

-- Sin permiso para crear staff_schema: alcanza con que el esquema ya esté completo
-- (migraciones aplicadas a mano). Devuelve la primera columna faltante.
local function checkColumns(cb)
  local function check(i)
    local spec = specs[i]
    if not spec then cb(true); return end
    local name = 'staff_' .. spec.name
    call('query', 'SELECT COLUMN_NAME AS name FROM information_schema.COLUMNS '
      .. 'WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name }, function(rows)
      if type(rows) ~= 'table' then cb(false, name); return end
      local present = {}
      for _, row in ipairs(rows) do present[row.name or row.COLUMN_NAME] = true end
      for _, column in ipairs(spec.columns) do
        if not present[column] then cb(false, name .. '.' .. column); return end
      end
      check(i + 1)
    end)
  end
  check(1)
end

-- Idempotente: CREATE TABLE IF NOT EXISTS y ADD COLUMN solo si la columna no existe.
function M.migrate(cb)
  local schema = 'CREATE TABLE IF NOT EXISTS staff_schema (version INT PRIMARY KEY, name VARCHAR(191) NOT NULL, '
    .. 'applied_at BIGINT NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin'
  local function schemaOnly()
    checkColumns(function(ok, missing) cb(ok, 'staff_schema', missing) end)
  end
  call('query', schema, {}, function(created)
    if created == nil then schemaOnly(); return end
    call('query', 'SELECT version FROM staff_schema', {}, function(rows)
      if type(rows) ~= 'table' then schemaOnly(); return end
      local applied = {}
      for _, row in ipairs(rows) do applied[tonumber(row.version)] = true end
      local function step(i)
        local migration = M.MIGRATIONS[i]
        if not migration then cb(true); return end
        if applied[migration.version] then step(i + 1); return end
        local raw = LoadResourceFile(GetCurrentResourceName(), migration.file)
        if type(raw) ~= 'string' then cb(false, migration.file); return end
        local list = statements(raw)
        local function run(j)
          local stmt = list[j]
          local function proceed(result)
            if result == nil then cb(false, migration.file) else run(j + 1) end
          end
          if not stmt then
            call('query', 'INSERT INTO staff_schema (version, name, applied_at) VALUES (?, ?, ?) '
              .. 'ON DUPLICATE KEY UPDATE name = VALUES(name)', { migration.version, migration.file, os.time() },
              function(result)
                if result == nil then cb(false, migration.file) else step(i + 1) end
              end)
            return
          end
          local tbl, col = stmt:match('^ALTER%s+TABLE%s+`?([%w_]+)`?%s+ADD%s+COLUMN%s+`?([%w_]+)`?')
          if not tbl then call('query', stmt, {}, proceed); return end
          call('query', 'SELECT COUNT(*) AS n FROM information_schema.COLUMNS '
            .. 'WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?', { tbl, col }, function(found)
            if type(found) ~= 'table' then cb(false, migration.file); return end
            if (tonumber(found[1] and found[1].n) or 0) > 0 then run(j + 1) else call('query', stmt, {}, proceed) end
          end)
        end
        run(1)
      end
      step(1)
    end)
  end)
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
  M.migrate(function(ok, failed, missing)
    if not ok then
      if missing then
        print(t('persistence_schema_missing', { column = missing }))
      else
        print(t('persistence_migration_failed', { file = failed }))
      end
      cb(false)
      return
    end
    readTable(1)
  end)
end

local function rowsFor(state)
  local rows = { audit = state.chain.entries, tickets = state.tickets.tickets, messages = {}, evidence = {},
    duty = {}, stats = {}, bans = {} }
  for _, ticket in pairs(rows.tickets) do
    for i, msg in ipairs(ticket.messages) do
      rows.messages[#rows.messages + 1] = { ticket_id = ticket.id, position = i,
        author = msg.author, body = msg.body, internal = msg.internal and 1 or 0, ts = msg.ts }
    end
    for _, item in ipairs(ticket.evidence or {}) do
      rows.evidence[#rows.evidence + 1] = { ticket_id = ticket.id, n = item.n, ts = item.ts, actor = item.by,
        sha256 = item.sha256, size = item.size, audit_seq = item.audit_seq }
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
      created_at = ban.created_at, expires_at = ban.expires_at, ban_id = ban.id, revoked_at = ban.revoked_at }
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
      perms = state.perms, playtime = state.playtime }) },
  }
  call('transaction', queries, {}, function(ok) cb(ok == true, nextCache) end)
end

if StaffSuiteModules then StaffSuiteModules['server.persist_sql'] = M end
return M
