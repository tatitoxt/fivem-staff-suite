-- shared/loader.lua — shim de require para los módulos core agnósticos en FiveM.
-- FiveM no tiene require/package estándar; cargamos core/*.lua vía LoadResourceFile.
-- En tests Lua planos se usa el require nativo (este archivo no se carga ahí).
local cache = {}
local res = GetCurrentResourceName()

local function load_module(name)
  if cache[name] ~= nil then return cache[name] end
  local path = name:gsub("%.", "/") .. ".lua"
  local src = LoadResourceFile(res, path)
  if not src then error("[staff_suite] módulo no encontrado: " .. name) end
  local fn, err = load(src, "@" .. path, "t")
  if not fn then error("[staff_suite] error cargando " .. name .. ": " .. tostring(err)) end
  local ok, mod = pcall(fn)
  if not ok then error("[staff_suite] error ejecutando " .. name .. ": " .. tostring(mod)) end
  cache[name] = mod or true
  return cache[name]
end

require = function(name)
  return load_module(name)
end
