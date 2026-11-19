-- Guarda snapshots en la carpeta del recurso.
local M = {}

function M.load(file)
  local raw = LoadResourceFile(GetCurrentResourceName(), file)
  if not raw or raw == '' then return nil end
  local ok, data = pcall(json.decode, raw)
  if ok and type(data) == 'table' then return data end
end

-- Las natives BOOL de FiveM devuelven 1/false, no true/false: se normaliza a boolean.
function M.save(file, state)
  local raw = json.encode(state)
  return SaveResourceFile(GetCurrentResourceName(), file, raw, #raw) and true or false
end

if StaffSuiteModules then StaffSuiteModules['server.persist_json'] = M end
return M
