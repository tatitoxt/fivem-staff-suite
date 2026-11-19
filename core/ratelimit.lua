-- core/ratelimit.lua — Token bucket por jugador y evento. Agnóstico (D019).
-- rule = { burst = n, per_second = r }: n acciones seguidas y r por segundo después.
local M = {}

function M.new()
  return { buckets = {} }
end

-- Devuelve allowed, first_denial. first_denial evita repetir el aviso en cada intento.
function M.allow(limiter, key, scope, rule, now)
  if type(rule) ~= "table" then return true, false end
  local burst, rate = tonumber(rule.burst) or 1, tonumber(rule.per_second) or 0
  local byKey = limiter.buckets[key]
  if not byKey then byKey = {}; limiter.buckets[key] = byKey end
  local b = byKey[scope]
  if not b then b = { tokens = burst, ts = now }; byKey[scope] = b end
  b.tokens = math.min(burst, b.tokens + math.max(0, now - b.ts) * rate)
  b.ts = now
  if b.tokens >= 1 then
    b.tokens = b.tokens - 1
    b.denied = false
    return true, false
  end
  local first = not b.denied
  b.denied = true
  return false, first
end

function M.forget(limiter, key)
  limiter.buckets[key] = nil
end

if StaffSuiteModules then StaffSuiteModules['core.ratelimit'] = M end
return M
