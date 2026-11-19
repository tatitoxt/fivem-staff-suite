-- config.lua — ABIERTO (editable por el comprador). Staff Suite.
Config = {}

Config.Locale = 'es'                 -- 'es' | 'en'
Config.PanelKey = 'F6'               -- tecla para abrir el panel NUI

Config.Commands = {
  report  = 'report',                -- jugador: abrir report
  reports = 'reports',               -- staff: cola de tickets
  audit   = 'audit',                 -- staff: visor de auditoría
  duty    = 'duty',                  -- staff: on/off duty
}

Config.Categories = { 'bug', 'player', 'staff', 'question', 'other' }
Config.Priorities = { 'low', 'normal', 'high', 'urgent' }

-- 'auto' prioriza Qbox, QBCore, ESX y finalmente standalone.
-- Forzá 'qbox', 'qbcore', 'esx' o 'standalone' si hay más de uno en tu servidor.
Config.Framework = 'auto'

-- Grupo ESX, permiso QBCore u objeto ACE de Qbox -> rango de Staff Suite.
Config.RankMap = {
  helper = 'helper',
  support = 'helper',
  mod = 'moderator',
  moderator = 'moderator',
  admin = 'admin',
  superadmin = 'senior_admin',
  owner = 'owner',
  god = 'owner',
}

-- Jobs activos que pueden dar acceso, por ejemplo esx = { staff = 'helper' }.
-- Si coinciden varios mapeos de grupo, permiso o job, se aplica el rango más alto.
Config.JobRankMap = {
  esx = {},
  qbcore = {},
  qbox = {},
}

-- En standalone, otorgá staff_suite.<rango> por ACE en server.cfg.
-- Ejemplo: add_ace group.admin staff_suite.admin allow

-- Persistencia: 'json' (Lite, standalone, sin DB) | 'oxmysql' (Core, MySQL).
Config.Persistence = 'json'
Config.JsonFile = 'staff_suite_data.json'

-- Export off-box de la cadena de auditoría.
Config.Export = {
  webhook = '',                      -- Discord webhook URL (credencial, server-side)
  file = true,                       -- archivo append-only local
  anchor_every = 20,                 -- anclar head cada N entradas
}

-- Captura de auditoría.
Config.Audit = {
  capture_commands = true,           -- comandos de admin registrados
  capture_framework = true,          -- eventos de grants/bans del framework
}

-- Moderación dentro del ticket (acciones permitidas por capability).
Config.Moderation = {
  require_reason = true,             -- razón obligatoria en kick/ban/warn
}
