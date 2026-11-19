-- core/permissions.lua — Modelo de capabilities por rango (least-privilege).
-- Agnóstico (D019). El adapter mapea rangos del framework (ESX/QB groups) a estos ranks.
local M = {}

-- Capabilities atómicas
M.CAP = {
  REPORT_VIEW="report.view", REPORT_CLAIM="report.claim", REPORT_RESOLVE="report.resolve",
  REPORT_TRANSFER="report.transfer", REPORT_RATE_VIEW="report.rate_view",
  MOD_KICK="mod.kick", MOD_BAN="mod.ban", MOD_WARN="mod.warn", MOD_FREEZE="mod.freeze",
  MOD_HEAL="mod.heal", MOD_TELEPORT="mod.teleport", MOD_SPECTATE="mod.spectate",
  AUDIT_VIEW="audit.view", AUDIT_VERIFY="audit.verify", AUDIT_EXPORT="audit.export",
  DUTY_SELF="duty.self", DUTY_VIEW_ALL="duty.view_all",
  STAFF_ANALYTICS="staff.analytics", PERMISSIONS_MANAGE="permissions.manage",
  CONFIG_MANAGE="config.manage",
}

-- Definición de rangos: cada uno lista sus capabilities PROPIAS (no heredadas).
local RANK_CAPS = {
  helper = { "report.view","report.claim","duty.self","mod.warn" },
  moderator = { "report.resolve","report.transfer","mod.kick","mod.freeze","mod.heal",
                "mod.teleport","mod.spectate","audit.view" },
  admin = { "mod.ban","audit.verify","audit.export","duty.view_all","staff.analytics" },
  senior_admin = { "permissions.manage","config.manage" },
  owner = {},  -- owner tiene todo (wildcard)
}

-- Jerarquía: cada rango hereda del anterior.
local HIERARCHY = { "helper","moderator","admin","senior_admin","owner" }
local RANK_LEVEL = {}
for i, r in ipairs(HIERARCHY) do RANK_LEVEL[r] = i end

-- cache de capabilities efectivas por rango
local effective = {}
local function build_caps(rank)
  if effective[rank] then return effective[rank] end
  local set = {}
  local level = RANK_LEVEL[rank]
  if not level then effective[rank] = set; return set end
  for i = 1, level do
    local r = HIERARCHY[i]
    for _, c in ipairs(RANK_CAPS[r] or {}) do set[c] = true end
  end
  if rank == "owner" then set["*"] = true end
  effective[rank] = set
  return set
end

function M.is_valid_rank(rank) return RANK_LEVEL[rank] ~= nil end

function M.can(rank, capability)
  if not RANK_LEVEL[rank] then return false end
  local set = build_caps(rank)
  return set["*"] == true or set[capability] == true
end

function M.capabilities(rank)
  local set = build_caps(rank)
  local out = {}
  for c in pairs(set) do out[#out+1] = c end
  table.sort(out)
  return out
end

-- ¿puede un rango gestionar a otro? (solo rangos superiores gestionan inferiores)
function M.can_manage(manager_rank, target_rank)
  if not M.can(manager_rank, M.CAP.PERMISSIONS_MANAGE) then return false end
  local ml, tl = RANK_LEVEL[manager_rank], RANK_LEVEL[target_rank]
  if not ml or not tl then return false end
  return ml > tl
end

M.HIERARCHY = HIERARCHY
return M
