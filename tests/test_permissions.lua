-- tests/test_permissions.lua — least-privilege + jerarquía + gestión.
local perms = require("core.permissions")
local T = {}
local CAP = perms.CAP

function T.test_helper_limited()
  assert(perms.can("helper", CAP.REPORT_CLAIM), "helper can claim")
  assert(not perms.can("helper", CAP.MOD_BAN), "helper cannot ban")
  assert(not perms.can("helper", CAP.AUDIT_VERIFY), "helper cannot verify audit")
end

function T.test_inheritance()
  assert(perms.can("moderator", CAP.REPORT_CLAIM), "mod inherits helper claim")
  assert(perms.can("moderator", CAP.MOD_KICK), "mod can kick")
  assert(not perms.can("moderator", CAP.MOD_BAN), "mod cannot ban (admin cap)")
  assert(perms.can("admin", CAP.MOD_BAN), "admin can ban")
  assert(perms.can("admin", CAP.MOD_KICK), "admin inherits mod kick")
end

function T.test_owner_wildcard()
  assert(perms.can("owner", CAP.CONFIG_MANAGE), "owner can config")
  assert(perms.can("owner", CAP.MOD_BAN), "owner can ban")
  assert(perms.can("owner", "anything.here"), "owner wildcard")
end

function T.test_invalid_rank()
  assert(not perms.can("hacker", CAP.MOD_BAN), "unknown rank denied")
  assert(not perms.is_valid_rank("hacker"))
end

function T.test_management()
  assert(perms.can_manage("senior_admin","admin"), "senior manages admin")
  assert(not perms.can_manage("admin","senior_admin"), "admin cannot manage senior")
  assert(not perms.can_manage("moderator","helper"), "mod lacks permissions.manage")
end

return T
