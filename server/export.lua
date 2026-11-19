-- server/export.lua — Export off-box de la cadena (webhook Discord + archivo).
local M = {}
local t = StaffSuiteTranslate
local LOG = 'audit_export.log'

local function res() return GetCurrentResourceName() end

-- Agrega la línea al final del log (O(1)). Sin io/GetResourcePath, cae a reescribir el archivo.
local function appendLine(line)
  local dir = GetResourcePath and GetResourcePath(res())
  if type(dir) == 'string' and dir ~= '' and io and io.open then
    local f = io.open(dir .. '/' .. LOG, 'ab')
    if f then
      local ok = f:write(line)
      f:close()
      if ok then return true end
    end
  end
  local prev = LoadResourceFile(res(), LOG) or ''
  return SaveResourceFile(res(), LOG, prev .. line, #prev + #line)
end

local function retryAfterMs(headers)
  if type(headers) ~= 'table' then return 0 end
  for k, v in pairs(headers) do
    if type(k) == 'string' and k:lower() == 'retry-after' then return (tonumber(v) or 0) * 1000 end
  end
  return 0
end

-- Reintenta en segundo plano (SetTimeout) con backoff exponencial acotado; nunca bloquea.
local function post(url, payload, cfg, seq, attempt)
  PerformHttpRequest(url, function(status, _, headers)
    status = tonumber(status) or 0
    if status >= 200 and status < 300 then return end
    local retryable = status == 0 or status == 429 or status >= 500
    local maxAttempts = tonumber(cfg.webhook_retries) or 5
    if not retryable or attempt >= maxAttempts then
      print(t('console_export_webhook_failed', { seq = seq, status = status, attempts = attempt }))
      return
    end
    local base, cap = tonumber(cfg.webhook_backoff_ms) or 2000, tonumber(cfg.webhook_backoff_max_ms) or 60000
    local delay = math.min(cap, math.max(base * 2 ^ (attempt - 1), retryAfterMs(headers)))
    SetTimeout(math.floor(delay), function() post(url, payload, cfg, seq, attempt + 1) end)
  end, 'POST', payload, { ['Content-Type'] = 'application/json' })
end

-- Ancla una entrada (o el head) fuera del server para verificación independiente.
function M.anchor(entry, cfg)
  if cfg.file then
    appendLine(string.format('%d|%s|%s|%s\n', entry.seq, entry.hash, entry.prev_hash, entry.action))
  end
  if cfg.webhook and cfg.webhook ~= '' then
    local payload = json.encode({
      content = t('export_anchor', { seq = entry.seq, hash = entry.hash:sub(1, 16) }),
      username = t('export_username'),
    })
    post(cfg.webhook, payload, cfg, entry.seq, 1)
  end
end

if StaffSuiteModules then StaffSuiteModules['server.export'] = M end
return M
