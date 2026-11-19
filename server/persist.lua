-- server/persist.lua — Persistencia: JSON (Lite standalone) + oxmysql (Core).
local M = {}

local function res() return GetCurrentResourceName() end

-- ===== JSON (Lite, sin DB) =====
function M.load_json(file)
  local raw = LoadResourceFile(res(), file)
  if not raw or raw == '' then return nil end
  local ok, data = pcall(json.decode, raw)
  if ok then return data end
  return nil
end

function M.save_json(file, state)
  local raw = json.encode(state)
  SaveResourceFile(res(), file, raw, #raw)
end

-- ===== oxmysql (Core, MySQL) =====
-- Esquema: staff_audit(seq,hash,prev_hash,data), staff_tickets(id,data),
--         staff_state(k,v). El core es agnóstico; acá solo se persiste.
function M.db_ready()
  return GetResourceState('oxmysql') == 'started'
end

function M.load_db(cb)
  if not M.db_ready() then cb(nil); return end
  exports.oxmysql:query('SELECT data FROM staff_state WHERE k = ?', { 'state' }, function(rows)
    if rows and rows[1] and rows[1].data then
      local ok, data = pcall(json.decode, rows[1].data)
      cb(ok and data or nil)
    else cb(nil) end
  end)
end

function M.save_db(state, cb)
  if not M.db_ready() then if cb then cb(false) end; return end
  local raw = json.encode(state)
  exports.oxmysql:query(
    'INSERT INTO staff_state (k, v, data) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = ?',
    { 'state', 'state', raw, raw },
    function() if cb then cb(true) end end)
end

function M.init_schema(cb)
  if not M.db_ready() then if cb then cb(false) end; return end
  exports.oxmysql:query([[
    CREATE TABLE IF NOT EXISTS staff_state (
      k VARCHAR(64) PRIMARY KEY, v VARCHAR(64), data LONGTEXT
    )
  ]], {}, function() if cb then cb(true) end end)
end

if StaffSuiteModules then StaffSuiteModules['server.persist'] = M end
return M
