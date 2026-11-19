-- server/export.lua — Export off-box de la cadena (webhook Discord + archivo).
local M = {}
local t = StaffSuiteTranslate

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
      content = t('export_anchor', { seq = entry.seq, hash = entry.hash:sub(1, 16) }),
      username = t('export_username'),
    })
    PerformHttpRequest(cfg.webhook, function() end, 'POST', payload, { ['Content-Type'] = 'application/json' })
  end
end

if StaffSuiteModules then StaffSuiteModules['server.export'] = M end
return M
