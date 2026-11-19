-- Guarda snapshots en la carpeta del recurso.
local M = {}

function M.load(file)
  local raw = LoadResourceFile(GetCurrentResourceName(), file)
  if not raw or raw == '' then return nil end
  local ok, data = pcall(json.decode, raw)
  if ok and type(data) == 'table' then return data end
end

function M.save(file, state)
  local raw = json.encode(state)
  return SaveResourceFile(GetCurrentResourceName(), file, raw, #raw)
end

if StaffSuiteModules then StaffSuiteModules['server.persist_json'] = M end
return M
