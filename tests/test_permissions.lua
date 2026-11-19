-- tests/test_permissions.lua — capabilities por rango + overrides.
local perms = require("core.permissions")
local T = {}

function T.test_rank_least_privilege()
  local m = perms.new()
  assert(perms.can(m, "license:h", "helper", "report.view"), "helper view reports")
  assert(not perms.can(m, "license:h", "helper", "mod.ban"), "helper cannot ban")
  assert(not perms.can(m, "license:h", "helper", "admin.config"), "helper cannot config")
end

function T.test_moderator_vs_admin()
  local m = perms.new()
  assert(perms.can(m, "license:m", "moderator", "mod.kick"), "mod can kick")
  assert(not perms.can(m, "license:m", "moderator", "mod.ban"), "mod cannot ban")
  assert(perms.can(m, "license:a", "admin", "mod.ban"), "admin can ban")
  assert(not perms.can(m, "license:a", "admin", "admin.permissions"), "admin cannot manage perms")
end

function T.test_owner_all()
  local m = perms.new()
  for _, cap in ipairs(perms.CAPS) do
    assert(perms.can(m, "license:o", "owner", cap), "owner has " .. cap)
  end
end

function T.test_grant_override()
  local m = perms.new()
  assert(not perms.can(m, "license:h", "helper", "mod.kick"), "before grant")
  perms.grant(m, "license:h", "mod.kick")
  assert(perms.can(m, "license:h", "helper", "mod.kick"), "after grant")
end

function T.test_revoke_beats_rank()
  local m = perms.new()
  assert(perms.can(m, "license:a", "admin", "mod.ban"), "admin ban before")
  perms.revoke(m, "license:a", "mod.ban")
  assert(not perms.can(m, "license:a", "admin", "mod.ban"), "revoke beats rank")
end

function T.test_revoke_beats_grant()
  local m = perms.new()
  perms.grant(m, "license:x", "mod.ban")
  perms.revoke(m, "license:x", "mod.ban")
  assert(not perms.can(m, "license:x", "helper", "mod.ban"), "revoke wins over grant")
end

function T.test_unknown_rank()
  local m = perms.new()
  assert(not perms.can(m, "license:n", "nonexistent", "report.view"), "unknown rank denies")
end

return T
