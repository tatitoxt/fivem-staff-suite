-- tests/test_ratelimit.lua — token bucket por jugador/evento.
local ratelimit = require("core.ratelimit")
local T = {}

function T.test_burst_then_refill()
  local l, rule = ratelimit.new(), { burst = 2, per_second = 0.5 }
  assert(ratelimit.allow(l, 1, "e", rule, 0))
  assert(ratelimit.allow(l, 1, "e", rule, 0))
  local ok, first = ratelimit.allow(l, 1, "e", rule, 0)
  assert(not ok and first)
  ok, first = ratelimit.allow(l, 1, "e", rule, 1)
  assert(not ok and not first, "aviso una sola vez")
  assert(ratelimit.allow(l, 1, "e", rule, 2))
  assert(ratelimit.allow(l, 2, "e", rule, 2), "otro jugador tiene su propio bucket")
  assert(ratelimit.allow(l, 1, "otro", rule, 2), "otro evento tiene su propio bucket")
end

function T.test_tokens_capped_and_forget()
  local l, rule = ratelimit.new(), { burst = 1, per_second = 1 }
  assert(ratelimit.allow(l, 1, "e", rule, 0))
  assert(ratelimit.allow(l, 1, "e", rule, 1000))
  assert(not ratelimit.allow(l, 1, "e", rule, 1000), "no acumula más que el burst")
  ratelimit.forget(l, 1)
  assert(ratelimit.allow(l, 1, "e", rule, 1000))
  assert(ratelimit.allow(l, 1, "e", nil, 0), "sin regla no limita")
end

return T
