local audit = require('core.audit_chain')
local duty = require('core.duty')
local perms = require('core.permissions')
local tickets = require('core.tickets')
local T = {}

local function copy(value)
  if type(value) ~= 'table' then return value end
  local result = {}
  for k, v in pairs(value) do result[k] = copy(v) end
  return result
end

local keys = { staff_audit = 'seq', staff_tickets = 'id', staff_messages = 'ticket_id', staff_evidence = 'ticket_id',
  staff_duty = 'actor', staff_stats = 'actor', staff_bans = 'identifier', staff_state = 'k' }

local function sqlMock()
  local db = { tables = {}, calls = {}, queries = {}, columns = {}, schema = {}, alters = 0 }
  function db:query(query, params, cb)
    self.queries[#self.queries + 1] = query
    if self.failOn and query:find(self.failOn, 1, true) then cb(nil); return end
    local created = query:match('^CREATE TABLE IF NOT EXISTS (staff_%w+)')
    if created then
      self.tables[created] = self.tables[created] or {}
      cb({ affectedRows = 0 }); return
    end
    local altered, column = query:match('^ALTER TABLE (staff_%w+) ADD COLUMN ([%w_]+)')
    if altered then
      assert(not self.columns[altered .. '.' .. column], 'columna duplicada')
      self.columns[altered .. '.' .. column] = true
      self.alters = self.alters + 1
      cb({ affectedRows = 0 }); return
    end
    if query:find('information_schema', 1, true) then
      if params[2] == nil then
        local rows = {}
        for key in pairs(self.columns) do
          local tbl, col = key:match('^([^.]+)%.(.+)$')
          if tbl == params[1] then rows[#rows + 1] = { name = col } end
        end
        cb(rows); return
      end
      cb({ { n = self.columns[params[1] .. '.' .. params[2]] and 1 or 0 } }); return
    end
    if query:match('^INSERT INTO staff_schema') then
      self.schema[params[1]] = params[2]
      cb({ affectedRows = 1 }); return
    end
    if query:match('^SELECT version FROM staff_schema') then
      local rows = {}
      for version in pairs(self.schema) do rows[#rows + 1] = { version = version } end
      cb(rows); return
    end
    local tableName = assert(query:match(' FROM (staff_%w+)'))
    local rows = {}
    if tableName == 'staff_state' then assert(params[1] == 'metadata' and params[2] == 'state') end
    for _, row in pairs(self.tables[tableName] or {}) do rows[#rows + 1] = copy(row) end
    table.sort(rows, function(a, b)
      local key = keys[tableName]
      if a[key] == b[key] then return (a.position or a.n) < (b.position or b.n) end
      return a[key] < b[key]
    end)
    cb(rows)
  end
  function db:transaction(queries, _, cb)
    self.calls[#self.calls + 1] = queries
    local function complete(success)
      if not success then cb(false); return end
      for _, item in ipairs(queries) do
        local name, columns, rest = item.query:match('^INSERT INTO (staff_%w+) %(([^)]+)%) VALUES (.+)$')
        assert(not item.query:find("O'Brien", 1, true), 'los valores deben ir por parámetros')
        local col, index = {}, 1
        for field in columns:gmatch('%w[%w_]*') do col[#col + 1] = field end
        local tuples = rest:gsub(' ON DUPLICATE KEY UPDATE .*', '')
        self.tables[name] = self.tables[name] or {}
        for tuple in tuples:gmatch('%(([^)]+)%)') do
          local row, field = {}, 1
          for placeholder in tuple:gmatch('[^, ]+') do
            if placeholder == '?' then
              row[col[field]] = assert(item.values[index])
              index = index + 1
            else
              assert(placeholder == 'NULL')
            end
            field = field + 1
          end
          local key = assert(row[keys[name]])
          if name == 'staff_messages' then key = key .. ':' .. row.position end
          if name == 'staff_evidence' then key = key .. ':' .. row.n end
          if name == 'staff_audit' then assert(not self.tables[name][key], 'una entrada auditada es inmutable') end
          self.tables[name][key] = row
        end
        assert(index == #item.values + 1)
      end
      cb(true)
    end
    if self.defer then self.complete = complete else complete(true) end
  end
  return db
end

local function fresh()
  return { chain = audit.new(), tickets = tickets.new_store(), perms = perms.new(),
    duty = duty.new_registry(), bans = {} }
end

local function serJson(value)
  if type(value) ~= 'table' then return tostring(value) end
  local names, parts = {}, {}
  for key in pairs(value) do names[#names + 1] = key end
  table.sort(names, function(a, b) return tostring(a) < tostring(b) end)
  for _, key in ipairs(names) do parts[#parts + 1] = tostring(key) .. '=' .. serJson(value[key]) end
  return '{' .. table.concat(parts, ',') .. '}'
end

local function boot(state, memory, db, dbStarted)
  memory.values = memory.values or {}
  memory.jsonCache = memory.jsonCache or {}
  local timers = {}
  local env = setmetatable({
    exports = { oxmysql = db },
    GetCurrentResourceName = function() return 'staff_suite' end,
    LoadResourceFile = function(_, path)
      if path:match('^sql/') then
        local f = assert(io.open(path, 'r'))
        local raw = f:read('a'); f:close()
        return raw
      end
      return memory.checkpoint
    end,
    SaveResourceFile = function(_, _, raw) memory.checkpoint = raw; return 1 end, -- BOOL de FiveM: 1/false
    GetResourceState = function() return dbStarted == false and 'stopped' or 'started' end,
    StaffSuiteTranslate = function(key) return key end,
    print = function(msg) memory.printed = memory.printed or {}; memory.printed[#memory.printed + 1] = msg end,
    SetTimeout = function(ms, fn) timers[#timers + 1] = { ms = ms, fn = fn } end,
    json = { encode = function(value)
      -- Determinista como el json real: el mismo valor produce el mismo texto.
      local key = serJson(value)
      if not memory.jsonCache[key] then
        memory.values[#memory.values + 1] = copy(value)
        memory.jsonCache[key] = tostring(#memory.values)
      end
      return memory.jsonCache[key]
    end, decode = function(raw) return copy(memory.values[tonumber(raw)]) end },
  }, { __index = _G })
  env.require = function(name)
    return assert(loadfile(name:gsub('%.', '/') .. '.lua', 't', env))()
  end
  local persist = env.require('server.persist')
  local module = persist.new({ Persistence = 'oxmysql', JsonFile = 'data.json' }, function()
    local snapshot = {}
    for key, value in pairs(state) do snapshot[key] = value end
    return snapshot
  end)
  local booted
  module.load(function(data, backend)
    if data then for key, value in pairs(data) do state[key] = value end end
    booted = backend
  end)
  local function flush()
    for i, timer in ipairs(timers) do
      if timer.ms == 1000 then
        table.remove(timers, i)
        timer.fn()
        return
      end
    end
    error('No hay lote pendiente')
  end
  return module, flush, booted
end

local function append(state, reason)
  audit.append(state.chain, { ts = 10, actor = 'license:staff', action = 'test', reason = reason })
end

function T.test_oxmysql_round_trip_for_all_tables_and_batches_changes()
  local state, db, memory = fresh(), sqlMock(), {}
  local storage, flush, backend = boot(state, memory, db)
  assert(backend == 'oxmysql')
  append(state, "O'Brien")
  local ticket = tickets.create(state.tickets, { reporter = 'license:player', description = 'texto', ts = 2 })
  tickets.add_message(state.tickets, ticket.id, 'license:staff', "O'Brien", true, 3)
  tickets.add_message(state.tickets, ticket.id, 'license:staff', 'respuesta', false, 4)
  ticket.resolved_by = 'license:staff'
  tickets.set_label(state.tickets, ticket.id, 'rdm', 'license:staff', true, 5)
  ticket.evidence = { { n = 1, ts = 6, by = 'license:staff', sha256 = ('a'):rep(64), size = 10, audit_seq = 1 } }
  duty.clock_in(state.duty, 'license:staff', 5)
  duty.record_resolved(state.duty, 'license:staff', 50)
  duty.record_rating(state.duty, 'license:staff', 4)
  perms.grant(state.perms, 'license:staff', 'mod.warn')
  state.bans['license:player'] = { actor = 'license:staff', reason = "O'Brien",
    created_at = 10, expires_at = 20, id = 1, revoked_at = 12,
    appeal = { state = 'pending', note = 'esperando Discord', by = 'license:staff', ts = 11 } }
  state.playtime = { ['license:player'] = 15000 }
  storage.save()
  storage.save()
  assert(#db.calls == 0)
  flush()
  assert(#db.calls == 1 and #db.calls[1] == 8)
  local restored = fresh()
  local nextStorage, nextFlush = boot(restored, memory, db)
  assert(restored.chain.head == state.chain.head and audit.verify(restored.chain))
  assert(restored.playtime['license:player'] == 15000)
  assert(restored.tickets.next_id == 2 and restored.tickets.tickets[1].claimer == nil)
  assert(restored.tickets.tickets[1].messages[1].body == "O'Brien")
  local back = restored.tickets.tickets[1]
  assert(back.first_response_ts == 4 and back.resolved_by == 'license:staff')
  assert(back.labels[1] == 'rdm' and #back.labels == 1, 'labels persisten por SQL')
  assert(back.evidence[1].by == 'license:staff' and back.evidence[1].sha256 == ('a'):rep(64) and back.evidence[1].audit_seq == 1)
  assert(restored.tickets.tickets[1].messages[1].internal and not restored.tickets.tickets[1].messages[2].internal)
  assert(restored.duty.staff['license:staff'].since == 5 and restored.duty.staff['license:staff'].ratings_n == 1)
  assert(restored.duty.staff['license:staff'].response_sum == 50)
  assert(restored.bans['license:player'].expires_at == 20 and perms.can(restored.perms, 'license:staff', nil, 'mod.warn'))
  assert(restored.bans['license:player'].id == 1 and restored.bans['license:player'].revoked_at == 12)
  assert(restored.bans['license:player'].appeal.state == 'pending'
    and restored.bans['license:player'].appeal.note == 'esperando Discord', 'la apelación persiste por SQL')
  append(restored, 'segunda entrada')
  nextStorage.save()
  nextFlush()
  assert(#db.calls == 2 and #db.calls[2] == 2)
  assert(db.tables.staff_audit[1].reason == "O'Brien" and db.tables.staff_audit[2].reason == 'segunda entrada')
end

function T.test_oxmysql_failure_serializes_and_recovers_newer_checkpoint()
  local state, db, memory = fresh(), sqlMock(), {}
  local storage, flush = boot(state, memory, db)
  append(state, 'en sql')
  flush()
  db.defer = true
  append(state, 'en checkpoint')
  local first, second
  storage.save(function(ok) first = ok end)
  append(state, 'en cola')
  storage.save(function(ok) second = ok end)
  assert(#db.calls == 2 and first == nil and second == nil)
  db.complete(false)
  assert(first and second and #db.calls == 2)

  local fallback = fresh()
  local _, _, backend = boot(fallback, memory, db, false)
  assert(backend == 'json' and #fallback.chain.entries == 3 and audit.verify(fallback.chain))

  db.defer = false
  local restored = fresh()
  local _, flushRecovery = boot(restored, memory, db)
  assert(#restored.chain.entries == 3 and audit.verify(restored.chain))
  flushRecovery()
  assert(#db.calls == 3 and db.tables.staff_audit[3].reason == 'en cola')
end

function T.test_flush_saves_now_and_status_tracks_confirmed_revision()
  local state, db, memory = fresh(), sqlMock(), {}
  local storage, flush = boot(state, memory, db)
  flush()
  append(state, 'diferido')
  storage.save()
  local pending = storage.status()
  assert(pending.pending and pending.saved < pending.revision)
  db.defer = true
  local revision = storage.flush()
  assert(revision == storage.status().revision and storage.status().pending)
  db.complete(true)
  local status = storage.status()
  assert(not status.pending and status.saved == revision)
  assert(db.tables.staff_audit[1].reason == 'diferido')
end

function T.test_legacy_staff_state_is_imported_without_rehashing()
  local previous, db, memory = fresh(), sqlMock(), {}
  append(previous, 'snapshot legado')
  memory.values = { copy(previous) }
  db.tables.staff_state = { state = { k = 'state', data = '1' } }
  local restored = fresh()
  local _, flush, backend = boot(restored, memory, db)
  assert(backend == 'oxmysql' and restored.chain.head == previous.chain.head)
  flush()
  assert(db.tables.staff_audit[1].hash == previous.chain.entries[1].hash)
  assert(db.tables.staff_state.metadata)
end

local function count(list, needle)
  local n = 0
  for _, item in ipairs(list) do
    if item:find(needle, 1, true) then n = n + 1 end
  end
  return n
end

function T.test_migrations_apply_once_and_are_recorded()
  local db, memory = sqlMock(), {}
  local _, _, backend = boot(fresh(), memory, db)
  assert(backend == 'oxmysql')
  assert(db.schema[1] == 'sql/001_staff_suite.sql' and db.schema[2] == 'sql/002_tickets_f2.sql')
  assert(db.schema[4] == 'sql/004_ticket_labels.sql' and db.schema[5] == 'sql/005_ban_appeal.sql')
  assert(db.alters == 6 and db.tables.staff_evidence and db.tables.staff_tickets)
  local creates = count(db.queries, 'CREATE TABLE IF NOT EXISTS staff_tickets')
  local _, _, again = boot(fresh(), memory, db)
  assert(again == 'oxmysql' and db.alters == 6)
  assert(count(db.queries, 'CREATE TABLE IF NOT EXISTS staff_tickets') == creates, 'no reaplica migraciones registradas')

  -- Instalación que ya aplicó 002 y 003 a mano antes de staff_schema.
  local manual = sqlMock()
  manual.columns['staff_tickets.first_response_ts'] = true
  manual.columns['staff_tickets.resolved_by'] = true
  manual.columns['staff_bans.ban_id'] = true
  manual.columns['staff_bans.revoked_at'] = true
  manual.columns['staff_tickets.labels'] = true
  manual.columns['staff_bans.appeal'] = true
  local _, _, manualBackend = boot(fresh(), {}, manual)
  assert(manualBackend == 'oxmysql' and manual.alters == 0 and manual.schema[2] and manual.schema[5])
end

function T.test_failed_migration_falls_back_to_json_with_clear_error()
  local db, memory = sqlMock(), {}
  db.failOn = 'ALTER TABLE'
  local state = fresh()
  local storage, _, backend = boot(state, memory, db)
  assert(backend == 'json')
  assert(db.schema[1] and not db.schema[2], 'la 002 no queda registrada si falla')
  local printed = table.concat(memory.printed or {}, '\n')
  assert(printed:find('persistence_migration_failed', 1, true), 'error claro en consola')
  append(state, 'sigue funcionando')
  local saved
  storage.save(function(ok) saved = ok end)
  assert(saved == true and memory.checkpoint, 'guarda en el respaldo JSON')
  assert(#db.calls == 0, 'no escribe en la base sin el esquema')

  db.failOn = nil
  local _, _, recovered = boot(fresh(), memory, db)
  assert(recovered == 'oxmysql' and db.schema[2] and db.schema[3] and db.schema[5] and db.alters == 6)
end

function T.test_manual_schema_without_create_privilege()
  rawset(_G, 'StaffSuiteModules', nil)
  local specs = require('server.persist_sql').specs
  local function manualDb()
    local db = sqlMock()
    db.failOn = 'CREATE TABLE IF NOT EXISTS staff_schema'
    for _, spec in ipairs(specs) do
      for _, column in ipairs(spec.columns) do db.columns['staff_' .. spec.name .. '.' .. column] = true end
    end
    return db
  end
  local complete = manualDb()
  local _, _, backend = boot(fresh(), {}, complete)
  assert(backend == 'oxmysql' and complete.alters == 0, 'esquema completo aplicado a mano: usa la base')

  local partial, memory = manualDb(), {}
  partial.columns['staff_tickets.resolved_by'] = nil
  local _, _, fallback = boot(fresh(), memory, partial)
  assert(fallback == 'json')
  local printed = table.concat(memory.printed or {}, '\n')
  assert(printed:find('persistence_schema_missing', 1, true), 'indica la columna faltante')
end

return T
