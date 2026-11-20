-- core/permissions.lua — Modelo de capabilities por rango (least-privilege). Agnóstico.
-- El adapter mapea los grupos del framework (ESX/QB/Qbox) a estos rangos.
local M = {}

-- Capacidades atómicas. Cada acción de moderación/auditoría requiere una.
M.CAPS = {
  "report.view", "report.claim", "report.resolve", "report.message",
  "report.export",
  "mod.goto", "mod.bring", "mod.spectate", "mod.freeze", "mod.heal",
  "mod.revive", "mod.kick", "mod.warn", "mod.ban",
  "ban.view", "ban.revoke",
  "mod.template",
  "mod.warn_escalate",
  "audit.view", "audit.verify", "audit.export",
  "staff.duty", "staff.analytics", "staff.analytics.export", "staff.announce", "staff.chat",
  "player.profile.view", "player.profile.note", "player.online.view",
  "staff.waypoint",
  "admin.config", "admin.permissions",
}

-- Rangos base con su set de capabilities (least-privilege, escalado).
local RANK_CAPS = {
  helper = {
    "report.view", "report.claim", "report.message", "staff.duty", "staff.chat",
  },
  moderator = {
    "report.view", "report.claim", "report.resolve", "report.message",
    "mod.goto", "mod.bring", "mod.spectate", "mod.freeze", "mod.heal",
    "mod.kick", "mod.warn", "audit.view", "staff.duty", "staff.chat",
    "player.profile.view", "player.profile.note", "player.online.view",
    "mod.template",
  },
  admin = {
    "report.view", "report.claim", "report.resolve", "report.message",
    "report.export",
    "mod.goto", "mod.bring", "mod.spectate", "mod.freeze", "mod.heal",
    "mod.revive", "mod.kick", "mod.warn", "mod.ban",
    "audit.view", "audit.verify", "staff.duty", "staff.analytics", "staff.announce", "staff.chat",
    "ban.view",
    "player.profile.view", "player.profile.note", "player.online.view",
    "mod.template",
    "mod.warn_escalate",
    "staff.waypoint",
  },
  senior_admin = {
    "report.view", "report.claim", "report.resolve", "report.message",
    "report.export",
    "mod.goto", "mod.bring", "mod.spectate", "mod.freeze", "mod.heal",
    "mod.revive", "mod.kick", "mod.warn", "mod.ban",
    "ban.view", "ban.revoke",
    "mod.template",
    "mod.warn_escalate",
    "audit.view", "audit.verify", "audit.export",
    "staff.duty", "staff.analytics", "staff.analytics.export", "staff.announce", "staff.chat", "admin.config",
    "player.profile.view", "player.profile.note", "player.online.view",
    "staff.waypoint",
  },
  owner = nil, -- owner = todas (se resuelve abajo)
}

function M.new()
  return { overrides = {} } -- overrides[identifier] = {grant={cap:true}, revoke={cap:true}}
end

local function rank_has(rank, cap)
  if rank == "owner" then return true end
  local set = RANK_CAPS[rank]
  if not set then return false end
  for _, c in ipairs(set) do if c == cap then return true end end
  return false
end

-- can(model, identifier, rank, cap): override revoke > override grant > rank.
function M.can(model, identifier, rank, cap)
  local ov = model.overrides[identifier]
  if ov then
    if ov.revoke and ov.revoke[cap] then return false end
    if ov.grant and ov.grant[cap] then return true end
  end
  return rank_has(rank, cap)
end

function M.grant(model, identifier, cap)
  local ov = model.overrides[identifier] or { grant = {}, revoke = {} }
  ov.grant = ov.grant or {}; ov.revoke = ov.revoke or {}
  ov.grant[cap] = true; ov.revoke[cap] = nil
  model.overrides[identifier] = ov
end

function M.revoke(model, identifier, cap)
  local ov = model.overrides[identifier] or { grant = {}, revoke = {} }
  ov.grant = ov.grant or {}; ov.revoke = ov.revoke or {}
  ov.revoke[cap] = true; ov.grant[cap] = nil
  model.overrides[identifier] = ov
end

local RANK_LEVEL = { helper = 1, moderator = 2, admin = 3, senior_admin = 4, owner = 5 }

-- true si target tiene un rango estrictamente mayor que actor (los jugadores no tienen rango).
function M.outranks(target_rank, actor_rank)
  return (RANK_LEVEL[target_rank] or 0) > (RANK_LEVEL[actor_rank] or 0)
end

function M.rank_caps(rank)
  if rank == "owner" then return { table.unpack(M.CAPS) } end
  return RANK_CAPS[rank] or {}
end

if StaffSuiteModules then StaffSuiteModules['core.permissions'] = M end
return M
