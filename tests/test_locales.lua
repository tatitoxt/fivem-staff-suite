-- tests/test_locales.lua — completitud de locales ES/EN.
-- Falla si falta una clave en algún idioma, si una traducción está vacía, si los
-- placeholders %{x} no coinciden, o si server/ client/ shared/ core/ usan una
-- clave que no existe en los locales.
local T = {}

local LANGS = { "es", "en" }

local function load_locales()
  local saved = rawget(_G, "Locale")
  rawset(_G, "Locale", nil)
  for _, lang in ipairs(LANGS) do dofile("locales/" .. lang .. ".lua") end
  local out = rawget(_G, "Locale")
  rawset(_G, "Locale", saved)
  return out
end

local function read(path)
  local f = assert(io.open(path, "r"), "no se pudo abrir " .. path)
  local s = f:read("a"); f:close()
  return s
end

local function lua_files(dirs)
  local files = {}
  for _, d in ipairs(dirs) do
    local p = io.popen('find "' .. d .. '" -name "*.lua" 2>/dev/null')
    for line in p:lines() do files[#files + 1] = line end
    p:close()
  end
  table.sort(files)
  return files
end

local function placeholders(s)
  local set = {}
  for name in s:gmatch("%%{([%w_]+)}") do set[name] = true end
  return set
end

local function same_set(a, b)
  for k in pairs(a) do if not b[k] then return false end end
  for k in pairs(b) do if not a[k] then return false end end
  return true
end

local function require_key(L, key, where)
  for _, lang in ipairs(LANGS) do
    assert(L[lang][key], ("falta la clave '%s' en locales/%s.lua (usada en %s)"):format(key, lang, where))
  end
end

function T.test_languages_present()
  local L = load_locales()
  for _, lang in ipairs(LANGS) do
    assert(type(L[lang]) == "table", "falta Locale['" .. lang .. "']")
  end
end

function T.test_same_keys_in_all_languages()
  local L = load_locales()
  for _, a in ipairs(LANGS) do
    for _, b in ipairs(LANGS) do
      for key in pairs(L[a]) do
        assert(L[b][key] ~= nil, ("la clave '%s' existe en %s pero falta en %s"):format(key, a, b))
      end
    end
  end
end

function T.test_values_are_non_empty_strings()
  local L = load_locales()
  for _, lang in ipairs(LANGS) do
    for key, v in pairs(L[lang]) do
      assert(type(v) == "string" and v:match("%S"), ("'%s' vacío o no-string en %s"):format(key, lang))
    end
  end
end

function T.test_placeholders_match()
  local L = load_locales()
  for key, es in pairs(L.es) do
    local en = L.en[key]
    if en then
      assert(same_set(placeholders(es), placeholders(en)),
        ("placeholders distintos en '%s' (es: %s | en: %s)"):format(key, es, en))
    end
  end
end

-- Lua pisa en silencio una clave repetida en el constructor de la tabla.
function T.test_no_duplicate_keys()
  for _, lang in ipairs(LANGS) do
    local seen = {}
    local body = read("locales/" .. lang .. ".lua"):gsub("%-%-[^\n]*", "")
    for key in body:gmatch("([%a_][%w_]*)%s*=%s*['\"]") do
      assert(not seen[key], ("clave duplicada '%s' en locales/%s.lua"):format(key, lang))
      seen[key] = true
    end
  end
end

-- Toda clave literal pasada a t('...') en el adapter tiene que existir.
function T.test_adapter_keys_exist()
  local L = load_locales()
  local n = 0
  for _, path in ipairs(lua_files({ "server", "client", "shared" })) do
    local src = read(path)
    for key in src:gmatch("%f[%w_]t%(%s*['\"]([%w_]+)['\"]") do
      require_key(L, key, path); n = n + 1
    end
    for key in src:gmatch("%f[%w_]t%([^)]-%sor%s+['\"]([%w_]+)['\"]") do
      require_key(L, key, path); n = n + 1
    end
  end
  assert(n > 0, "no se encontraron usos de t('...') en el adapter")
end

-- Los códigos de error del core llegan al jugador vía t(code): tienen que tener traducción.
-- "invalid_transition:<from>-><to>" se traduce por su prefijo.
function T.test_core_error_codes_exist()
  local L = load_locales()
  local n = 0
  for _, path in ipairs(lua_files({ "core" })) do
    for code in read(path):gmatch("return nil,%s*\"([%w_]+)[\":]") do
      require_key(L, code, path); n = n + 1
    end
  end
  assert(n > 0, "no se encontraron códigos de error en core/")
end

-- Categorías y prioridades de config.lua tienen etiqueta cat_* / pri_*.
function T.test_config_categories_and_priorities()
  local L = load_locales()
  local saved = rawget(_G, "Config")
  rawset(_G, "Config", nil)
  dofile("config.lua")
  local cfg = rawget(_G, "Config")
  rawset(_G, "Config", saved)
  for _, c in ipairs(cfg.Categories or {}) do require_key(L, "cat_" .. c, "config.lua Categories") end
  for _, p in ipairs(cfg.Priorities or {}) do require_key(L, "pri_" .. p, "config.lua Priorities") end
  for _, rank in pairs(cfg.RankMap or {}) do require_key(L, "rank_" .. rank, "config.lua RankMap") end
  assert(L[cfg.Locale], "Config.Locale '" .. tostring(cfg.Locale) .. "' no tiene locale")
end

return T
