-- server/export.lua — Export off-box de la cadena (webhook Discord + archivo).
local M = {}
local loadmod = StaffSuiteModules and StaffSuiteModules.loadmod or require
local sha256 = loadmod('core.sha256')
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

function M.ticketEnabled(cfg)
  local url = cfg.ticket_webhook
  return type(url) == 'string' and url:match('^https://discord%.com/api/webhooks/%d+/[%w_%-]+$') ~= nil
end

local function publicTranscript(ticket)
  local maxBytes = 64 * 1024
  local heading = t('ticket_export_heading', { id = ticket.id })
  -- La longitud de los datos anteriores puede superar los límites de la config actual.
  local description = (ticket.description or ''):sub(1, 4096)
  local header = heading .. '\n\n' .. description .. '\n'
  local size, messages, truncated = #header + 256, {}, #(ticket.description or '') > #description
  for i = #(ticket.messages or {}), 1, -1 do
    local msg = ticket.messages[i]
    if not msg.internal then
      local role = t(msg.author == ticket.reporter and 'ticket_export_reporter' or 'ticket_export_staff')
      local body = msg.body or ''
      if #body + #role + size + 4 > maxBytes then
        truncated = true
        break
      end
      local line = role .. ':\n' .. body .. '\n'
      size = size + #line + 1
      messages[#messages + 1] = line
    end
  end
  local parts = { header }
  if truncated then parts[#parts + 1] = t('ticket_export_truncated') end
  for i = #messages, 1, -1 do parts[#parts + 1] = messages[i] end
  return table.concat(parts, '\n'):gsub('[\0-\8\11\12\14-\31\127]', '')
end

function M.ticket(ticket, cfg, onResult)
  local text = publicTranscript(ticket)
  local boundary = 'staff-suite-' .. sha256.hex(text):sub(1, 32)
  while text:find(boundary, 1, true) do boundary = 'staff-suite-' .. sha256.hex(boundary):sub(1, 32) end
  local file = ('ticket-%d.txt'):format(ticket.id)
  local payload = json.encode({
    content = t('ticket_export_heading', { id = ticket.id }),
    attachments = { { id = 0, filename = file } },
  })
  local body = table.concat({
    '--' .. boundary,
    'Content-Disposition: form-data; name="payload_json"',
    'Content-Type: application/json',
    '', payload,
    '--' .. boundary,
    'Content-Disposition: form-data; name="files[0]"; filename="' .. file .. '"',
    'Content-Type: text/plain; charset=utf-8',
    '', text,
    '--' .. boundary .. '--', '',
  }, '\r\n')
  local finished = false
  local function finish(status)
    if finished then return end
    finished = true
    status = math.max(0, tonumber(status) or 0)
    onResult(status >= 200 and status < 300, status)
  end
  -- Una respuesta ausente es ambigua. Un reintento automático podría duplicar el mensaje.
  SetTimeout(15000, function() finish(0) end)
  local started = pcall(PerformHttpRequest, cfg.ticket_webhook .. '?wait=true', finish, 'POST', body,
    { ['Content-Type'] = 'multipart/form-data; boundary=' .. boundary }, { followLocation = false })
  if not started then finish(0) end
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
