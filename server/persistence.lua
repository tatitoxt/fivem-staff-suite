-- server/persistence.lua — persistencia oxmysql + fallback JSON.
SS = SS or {}
local P = {}
SS.persist = P

local use_oxmysql = false

function P.init()
  use_oxmysql = (Config.Storage == 'oxmysql') and (GetResourceState('oxmysql') == 'started')
  if use_oxmysql then
    exports.oxmysql:execute([[
      CREATE TABLE IF NOT EXISTS staff_audit (
        seq INT PRIMARY KEY, ts BIGINT, actor VARCHAR(128), action VARCHAR(64),
        target VARCHAR(128), reason TEXT, payload TEXT, prev_hash CHAR(64), hash CHAR(64)
      )]])
    exports.oxmysql:execute([[
      CREATE TABLE IF NOT EXISTS staff_tickets (
        id VARCHAR(32) PRIMARY KEY, data LONGTEXT, updated_ts BIGINT
      )]])
    exports.oxmysql:execute([[
      CREATE TABLE IF NOT EXISTS staff_duty (
        actor VARCHAR(128) PRIMARY KEY, data LONGTEXT
      )]])
    if Config.Debug then print('[staff_suite] persistencia: oxmysql') end
  else
    if Config.Debug then print('[staff_suite] persistencia: JSON fallback') end
  end
end

-- AUDIT
function P.append_audit(e)
  if use_oxmysql then
    exports.oxmysql:insert('INSERT INTO staff_audit (seq,ts,actor,action,target,reason,payload,prev_hash,hash) VALUES (?,?,?,?,?,?,?,?,?)',
      { e.seq, e.ts, e.actor, e.action, e.target, e.reason, e.payload, e.prev_hash, e.hash })
  end
end

function P.load_audit(cb)
  if use_oxmysql then
    exports.oxmysql:execute('SELECT * FROM staff_audit ORDER BY seq ASC', {}, function(rows)
      cb(rows or {})
    end)
  else
    local raw = LoadResourceFile(GetCurrentResourceName(), Config.JsonPath)
    local data = raw and json.decode(raw) or {}
    cb(data.audit or {})
  end
end

-- TICKETS
function P.save_ticket(t)
  if use_oxmysql then
    exports.oxmysql:execute('REPLACE INTO staff_tickets (id,data,updated_ts) VALUES (?,?,?)',
      { t.id, json.encode(t), t.updated_ts })
  end
end

function P.load_tickets(cb)
  if use_oxmysql then
    exports.oxmysql:execute('SELECT data FROM staff_tickets', {}, function(rows)
      local out = {}
      for _, r in ipairs(rows or {}) do out[#out+1] = json.decode(r.data) end
      cb(out)
    end)
  else
    local raw = LoadResourceFile(GetCurrentResourceName(), Config.JsonPath)
    local data = raw and json.decode(raw) or {}
    cb(data.tickets or {})
  end
end

-- DUTY
function P.save_duty(reg)
  if use_oxmysql then
    for actor, s in pairs(reg.staff) do
      exports.oxmysql:execute('REPLACE INTO staff_duty (actor,data) VALUES (?,?)', { actor, json.encode(s) })
    end
  end
end

function P.load_duty(cb)
  if use_oxmysql then
    exports.oxmysql:execute('SELECT actor,data FROM staff_duty', {}, function(rows)
      local reg = { staff = {} }
      for _, r in ipairs(rows or {}) do reg.staff[r.actor] = json.decode(r.data) end
      cb(reg)
    end)
  else
    local raw = LoadResourceFile(GetCurrentResourceName(), Config.JsonPath)
    local data = raw and json.decode(raw) or {}
    cb(data.duty or { staff = {} })
  end
end

-- JSON fallback: guardar todo junto
function P.flush_json(audit_entries, tickets, duty_reg)
  if use_oxmysql then return end
  local data = { audit = audit_entries, tickets = tickets, duty = duty_reg }
  SaveResourceFile(GetCurrentResourceName(), Config.JsonPath, json.encode(data), -1)
end

return P
