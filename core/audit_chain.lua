-- core/audit_chain.lua — Cadena de auditoría a prueba de manipulación.
-- Agnóstico de plataforma (D019): lógica pura, sin natives FiveM.
-- Cada entrada encadena el hash de la anterior (SHA-256). Si alguien edita o
-- borra una entrada, verify() detecta la ruptura. El adapter persiste a DB y
-- exporta el head off-box (webhook/archivo) para verificación independiente.
local loadmod = StaffSuiteModules and StaffSuiteModules.loadmod or require
local sha256 = loadmod("core.sha256")

local M = {}
local GENESIS = string.rep("0", 64)
local FS = "\x1f"  -- separador de campos (unit separator)
local RS = "\x1e"  -- separador canonical->prev_hash (record separator)

-- Serialización canónica determinista de una entrada (sin el campo hash).
-- payload ya viene serializado como string por el adapter.
function M.canonical(e)
  return table.concat({
    tostring(e.seq), tostring(e.ts), tostring(e.actor),
    tostring(e.action), tostring(e.target), tostring(e.reason),
    tostring(e.payload or ""),
  }, FS)
end

function M.new()
  return { entries = {}, head = GENESIS }
end

-- data: {ts, actor, action, target, reason, payload}
function M.append(chain, data)
  local seq = #chain.entries + 1
  local e = {
    seq = seq,
    ts = data.ts,
    actor = data.actor,
    action = data.action,
    target = data.target or "",
    reason = data.reason or "",
    payload = data.payload or "",
    prev_hash = chain.head,
  }
  e.hash = sha256.hex(M.canonical(e) .. RS .. e.prev_hash)
  chain.entries[seq] = e
  chain.head = e.hash
  return e
end

-- Recalcula toda la cadena. Devuelve ok, broken_seq (nil si ok).
function M.verify(chain)
  local prev = GENESIS
  for i = 1, #chain.entries do
    local e = chain.entries[i]
    if e.seq ~= i then return false, i end
    if e.prev_hash ~= prev then return false, i end
    local expect = sha256.hex(M.canonical(e) .. RS .. e.prev_hash)
    if e.hash ~= expect then return false, i end
    prev = e.hash
  end
  return true, nil
end

-- Verifica contra un head anclado off-box (detecta truncado/borrado al final).
-- Recalcula el head efectivo desde las entradas reales (no el cacheado, que
-- puede quedar stale tras un truncado).
function M.verify_head(chain, anchored_head)
  local ok, at = M.verify(chain)
  if not ok then return false, at end
  local effective = (#chain.entries > 0) and chain.entries[#chain.entries].hash or GENESIS
  if effective ~= anchored_head then return false, #chain.entries end
  return true, nil
end

M.GENESIS = GENESIS
if StaffSuiteModules then StaffSuiteModules['core.audit_chain'] = M end
return M
