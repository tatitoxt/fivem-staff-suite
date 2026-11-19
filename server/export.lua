-- server/export.lua — Export off-box de la cadena (webhook Discord + archivo).
local M = {}

local function res() return GetCurrentResourceName() end

-- Ancla una entrada (o el head) fuera del server para verificación independiente.
function M.anchor(entry, cfg)
  if cfg.file then
    local line = string.format('%d|%s|%s|%s\n', entry.seq, entry.hash, entry.prev_hash, entry.action)
    local prev = LoadResourceFile(res(), 'audit_export.log') or ''
    SaveResourceFile(res(), 'audit_export.log', prev .. line, #(prev .. line))
  end
  if cfg.webhook and cfg.webhook ~= '' then
    local payload = json.encode({
      content = string.format('🔐 Audit anchor · seq %d · `%s`', entry.seq, entry.hash:sub(1, 16)),
      username = 'Staff Suite Audit',
    })
    PerformHttpRequest(cfg.webhook, function() end, 'POST', payload, { ['Content-Type'] = 'application/json' })
  end
end

return M
