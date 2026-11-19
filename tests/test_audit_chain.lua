-- tests/test_audit_chain.lua — integridad + detección de manipulación.
local chain = require("core.audit_chain")
local T = {}

local function sample(n)
  local c = chain.new()
  for i = 1, n do
    chain.append(c, {
      ts = 1700000000 + i, actor = "license:admin" .. (i % 3),
      action = "grant_money", target = "license:player" .. i,
      reason = "test", payload = '{"amount":' .. (i * 100) .. "}",
    })
  end
  return c
end

function T.test_append_and_verify()
  local c = sample(5)
  assert(#c.entries == 5, "5 entries")
  local ok, at = chain.verify(c)
  assert(ok, "chain should verify, broken at " .. tostring(at))
end

function T.test_linkage()
  local c = sample(3)
  assert(c.entries[1].prev_hash == chain.GENESIS, "genesis link")
  assert(c.entries[2].prev_hash == c.entries[1].hash, "link 1->2")
  assert(c.entries[3].prev_hash == c.entries[2].hash, "link 2->3")
  assert(c.head == c.entries[3].hash, "head = last hash")
end

function T.test_tamper_edit()
  local c = sample(5)
  c.entries[3].payload = '{"amount":999999}'  -- editar un grant
  local ok, at = chain.verify(c)
  assert(not ok and at == 3, "edit at 3 must be detected, got " .. tostring(at))
end

function T.test_tamper_delete()
  local c = sample(5)
  table.remove(c.entries, 2)  -- borrar una entrada
  local ok, at = chain.verify(c)
  assert(not ok, "deletion must be detected")
end

function T.test_tamper_reorder()
  local c = sample(4)
  c.entries[2], c.entries[3] = c.entries[3], c.entries[2]
  local ok = chain.verify(c)
  assert(not ok, "reorder must be detected")
end

function T.test_head_anchor()
  local c = sample(4)
  local anchored = c.head
  assert(chain.verify_head(c, anchored), "valid head")
  table.remove(c.entries)  -- truncar la última
  local ok = chain.verify_head(c, anchored)
  assert(not ok, "truncation vs anchored head must be detected")
end

function T.test_separators_cannot_shift_fields()
  local a, b = chain.new(), chain.new()
  chain.append(a, { ts = 1, actor = "x", action = "kick", target = "p\30evil", reason = "" })
  chain.append(b, { ts = 1, actor = "x", action = "kick", target = "p", reason = "evil" })
  assert(a.entries[1].target == "pevil" and a.head ~= b.head)
end

function T.test_integer_floats_from_storage_still_verify()
  local c = sample(3)
  for _, e in ipairs(c.entries) do e.seq, e.ts = e.seq + 0.0, e.ts + 0.0 end
  assert(chain.verify(c))
end

return T
