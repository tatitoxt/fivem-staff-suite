-- server/export.lua — export off-box del head de auditoría (Discord + archivo append-only).
SS = SS or {}
local E = {}
SS.export = E

local function append_file(line)
  local path = Config.Audit.ExportFile
  local existing = LoadResourceFile(GetCurrentResourceName(), path) or ''
  SaveResourceFile(GetCurrentResourceName(), path, existing .. line .. '\n', -1)
end

-- export de una entrada + head (para verificación independiente off-box)
function E.entry(e)
  local line = json.encode({ seq=e.seq, hash=e.hash, prev_hash=e.prev_hash, action=e.action, actor=e.actor, ts=e.ts })
  append_file(line)
  if Config.Audit.DiscordWebhook ~= '' then
    local payload = json.encode({
      username = 'Staff Suite Audit',
      embeds = {{
        title = ('Audit seq %d — %s'):format(e.seq, e.action),
        description = ('**%s** → %s\nRazón: %s'):format(e.actor, e.target, e.reason),
        color = 3066993,
        footer = { text = 'head: ' .. e.hash:sub(1, 16) },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ', e.ts),
      }},
    })
    PerformHttpRequest(Config.Audit.DiscordWebhook, function() end, 'POST', payload, { ['Content-Type'] = 'application/json' })
  end
end

-- alerta de manipulación al dueño
function E.tamper_alert(broken_at, head)
  local msg = ('⚠️ Staff Suite: cadena de auditoría ROTA en seq %s. Head esperado: %s'):format(tostring(broken_at), head:sub(1,16))
  append_file(json.encode({ alert='tamper', broken_at=broken_at, head=head, ts=os.time() }))
  if Config.Audit.DiscordWebhook ~= '' then
    PerformHttpRequest(Config.Audit.DiscordWebhook, function() end, 'POST',
      json.encode({ username='Staff Suite', content=msg }), { ['Content-Type']='application/json' })
  end
  print('[staff_suite] ' .. msg)
end

return E
