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
  local db = { tables = {}, calls = {} }
  function db:query(query, params, cb)
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

local function boot(state, memory, db, dbStarted)
  memory.values = memory.values or {}
  local timers = {}
  local env = setmetatable({
    exports = { oxmysql = db },
    GetCurrentResourceName = function() return 'staff_suite' end,
    LoadResourceFile = function() return memory.checkpoint end,
    SaveResourceFile = function(_, _, raw) memory.checkpoint = raw; return true end,
    GetResourceState = function() return dbStarted == false and 'stopped' or 'started' end,
    StaffSuiteTranslate = function(key) return key end,
    print = function() end,
    SetTimeout = function(ms, fn) timers[#timers + 1] = { ms = ms, fn = fn } end,
    json = { encode = function(value)
      memory.values[#memory.values + 1] = copy(value)
      return tostring(#memory.values)
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
  ticket.evidence = { { n = 1, ts = 6, by = 'license:staff', sha256 = ('a'):rep(64), size = 10, audit_seq = 1 } }
  duty.clock_in(state.duty, 'license:staff', 5)
  duty.record_resolved(state.duty, 'license:staff', 50)
  duty.record_rating(state.duty, 'license:staff', 4)
  perms.grant(state.perms, 'license:staff', 'mod.warn')
  state.bans['license:player'] = { actor = 'license:staff', reason = "O'Brien", created_at = 10, expires_at = 20 }
  storage.save()
  storage.save()
  assert(#db.calls == 0)
  flush()
  assert(#db.calls == 1 and #db.calls[1] == 8)
  local restored = fresh()
  local nextStorage, nextFlush = boot(restored, memory, db)
  assert(restored.chain.head == state.chain.head and audit.verify(restored.chain))
  assert(restored.tickets.next_id == 2 and restored.tickets.tickets[1].claimer == nil)
  assert(restored.tickets.tickets[1].messages[1].body == "O'Brien")
  local back = restored.tickets.tickets[1]
  assert(back.first_response_ts == 4 and back.resolved_by == 'license:staff')
  assert(back.evidence[1].by == 'license:staff' and back.evidence[1].sha256 == ('a'):rep(64) and back.evidence[1].audit_seq == 1)
  assert(restored.tickets.tickets[1].messages[1].internal and not restored.tickets.tickets[1].messages[2].internal)
  assert(restored.duty.staff['license:staff'].since == 5 and restored.duty.staff['license:staff'].ratings_n == 1)
  assert(restored.duty.staff['license:staff'].response_sum == 50)
  assert(restored.bans['license:player'].expires_at == 20 and perms.can(restored.perms, 'license:staff', nil, 'mod.warn'))
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

return T
