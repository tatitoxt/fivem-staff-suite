-- Persiste snapshots JSON y serializa los lotes de oxmysql.
local loadmod = StaffSuiteModules and StaffSuiteModules.loadmod or require
local sql = loadmod('server.persist_sql')
local audit = loadmod('core.audit_chain')
local M = {}

local function res() return GetCurrentResourceName() end

-- ===== JSON (Lite, sin DB) =====
function M.load_json(file)
  local raw = LoadResourceFile(res(), file)
  if not raw or raw == '' then return nil end
  local ok, data = pcall(json.decode, raw)
  if ok and type(data) == 'table' then return data end
  return nil
end

function M.save_json(file, state)
  local raw = json.encode(state)
  return SaveResourceFile(res(), file, raw, #raw)
end

-- Solo se recupera un checkpoint más reciente que prolonga la misma cadena.
local function extends(backup, database)
  if not (backup and backup.database_checkpoint and backup.chain and database.chain) then return false end
  local previous, newer = database.chain.entries, backup.chain.entries
  if type(previous) ~= 'table' or type(newer) ~= 'table' then return false end
  if #previous >= #newer then return false end
  if not audit.verify(database.chain) or not audit.verify(backup.chain) then return false end
  for i, entry in ipairs(previous) do
    if entry.hash ~= newer[i].hash then return false end
  end
  return #previous == 0 or database.chain.head == newer[#previous].hash
end

function M.new(config, snapshot)
  local storage = {}
  local useDb, busy, scheduled, dirty, stopped = false, false, false, false, false
  local cache, waiting = nil, {}
  local wantsDb = config.Persistence == 'oxmysql'

  local function fallback()
    useDb = false
    print(StaffSuiteTranslate('persistence_fallback'))
  end

  local function checkpoint(state)
    state.database_checkpoint = wantsDb or nil
    local ok, result = pcall(M.save_json, config.JsonFile, state)
    return ok and result == true
  end

  local flush
  local function schedule(delay)
    if busy or scheduled or not dirty or stopped then return end
    scheduled = true
    SetTimeout(delay or 1000, function()
      scheduled = false
      flush()
    end)
  end

  flush = function()
    if busy or not dirty or stopped then return end
    busy, dirty = true, false
    local waiters = waiting
    waiting = {}
    local state = snapshot()
    local jsonOK = checkpoint(state)

    local function done(dbOK, nextCache)
      busy = false
      if dbOK then cache = nextCache end
      local saved = dbOK or jsonOK
      if not saved then
        dirty = true
        print(StaffSuiteTranslate('persistence_save_failed'))
      end
      for _, cb in ipairs(waiters) do cb(saved) end
      if #waiting > 0 then flush() else schedule(not saved and 60000 or nil) end
    end

    if useDb and sql.available() then
      sql.save(state, cache, function(ok, nextCache)
        if not ok then fallback() end
        done(ok, nextCache)
      end)
    else
      if useDb then fallback() end
      done(false)
    end
  end

  function storage.load(cb)
    local backup = M.load_json(config.JsonFile)
    if wantsDb and sql.available() then
      sql.load(function(ok, state, dbCache)
        if ok then
          useDb, cache = true, dbCache
          local recover = not state or extends(backup, state)
          cb(recover and backup or state, 'oxmysql')
          -- Importa el snapshot legado o el checkpoint antes de la próxima escritura.
          storage.save()
        else
          fallback()
          cb(backup, 'json')
        end
      end)
    else
      if wantsDb then fallback() end
      cb(backup, 'json')
    end
  end

  function storage.save(cb)
    dirty = true
    if cb then waiting[#waiting + 1] = cb end
    if cb then flush() else schedule() end
  end

  function storage.stop()
    stopped = true
    if dirty then checkpoint(snapshot()) end
  end

  return storage
end

if StaffSuiteModules then StaffSuiteModules['server.persist'] = M end
return M
