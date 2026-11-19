-- config.lua — ABIERTO (editable por el comprador). Toda la configuración del Staff Suite.
Config = {}

Config.Locale = 'es'                 -- 'es' | 'en'
Config.Keybind = 'F6'                -- tecla para abrir el panel (client)
Config.Command = 'staffpanel'        -- comando alternativo

-- Framework: 'auto' detecta ESX/QBCore/Qbox; o 'standalone'
Config.Framework = 'auto'

-- Persistencia: 'oxmysql' (recomendado) o 'json' (fallback standalone)
Config.Storage = 'oxmysql'
Config.JsonPath = 'data/staff_suite.json'   -- solo si Storage='json'

-- Auditoría
Config.Audit = {
  ExportEvery = 25,                  -- exportar head off-box cada N entradas
  DiscordWebhook = '',               -- webhook para export off-box (opcional)
  ExportFile = 'data/audit_export.jsonl',  -- archivo append-only local
  CaptureCommands = true,            -- auditar comandos de admin registrados
  CaptureFrameworkEvents = true,     -- auditar eventos del framework (grants, bans)
}

-- Moderación: acciones habilitadas (todas requieren razón)
Config.Moderation = {
  RequireReason = true,
  Actions = { 'kick','ban','warn','freeze','heal','teleport','spectate' },
}

-- Tickets
Config.Tickets = {
  Categories = { 'bug','player_report','harassment','cheating','question','other' },
  Priorities = { 'low','normal','high','urgent' },
  MaxOpenPerPlayer = 3,
  AllowRating = true,
}

-- Mapeo de rangos del framework -> ranks del core (helper/moderator/admin/senior_admin/owner)
Config.RankMap = {
  -- ESX groups
  ['user'] = 'helper', ['mod'] = 'moderator', ['admin'] = 'admin',
  ['superadmin'] = 'senior_admin', ['owner'] = 'owner',
  -- QBCore/Qbox permissions
  ['mod'] = 'moderator', ['admin'] = 'admin', ['god'] = 'owner',
}
Config.DefaultRank = 'helper'

-- Debug
Config.Debug = false
