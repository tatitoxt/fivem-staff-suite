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

-- Respuestas predefinidas del ticket. Cada entrada es una clave de locales/
-- (canned_<id> y canned_<id>_title) o un texto propio: { title = 'Título', text = 'Mensaje' }.
-- La evidencia con screenshot-basic se activa sola si ese recurso está iniciado.
Config.CannedResponses = { 'greeting', 'investigating', 'need_info', 'resolved' }

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
-- Los rangos por identifier se configuran en server/config.lua.

-- Persistencia: 'json' (Lite, standalone, sin DB) | 'oxmysql' (Core, MySQL).
Config.Persistence = 'json'
Config.JsonFile = 'staff_suite_data.json'

-- Captura de auditoría.
Config.Audit = {
  capture_framework = true,          -- eventos del framework seleccionado y de txAdmin
}

-- Moderación dentro del ticket (acciones permitidas por capability).
Config.Moderation = {
  require_reason = true,             -- razón obligatoria para expulsar
  ban_duration = 86400,              -- duración predeterminada en segundos, 0 = permanente
  ban_tokens = true,                 -- banear también los tokens de hardware del cliente
}

-- Límites de texto (en bytes) y tickets abiertos por jugador. El servidor rechaza lo que exceda.
Config.Limits = {
  ticket_body = 1000,
  message_body = 1000,
  announcement = 300,
  reason = 300,
  open_tickets_per_player = 3,
}

-- Rate limit por jugador y evento: burst acciones seguidas, luego per_second por segundo.
Config.RateLimit = {
  default = { burst = 10, per_second = 2 },
  ['staff_suite:ticketCreate'] = { burst = 5, per_second = 1 / 60 },
  ['staff_suite:ticketMessage'] = { burst = 10, per_second = 1 },
  ['staff_suite:staffChat'] = { burst = 5, per_second = 0.5 },
  ['staff_suite:playerProfile'] = { burst = 3, per_second = 0.5 },
  ['staff_suite:playerProfileNote'] = { burst = 2, per_second = 0.2 },
  ['staff_suite:modTemplate'] = { burst = 3, per_second = 0.5 },
  ['staff_suite:modWarn'] = { burst = 3, per_second = 0.2 },
  ['staff_suite:waypoint'] = { burst = 2, per_second = 0.2 },
  ['staff_suite:verify'] = { burst = 3, per_second = 1 / 10 },
  ['staff_suite:duty'] = { burst = 4, per_second = 1 / 10 },
  ['staff_suite:ticketEvidence'] = { burst = 3, per_second = 1 / 20 },
  ['staff_suite:announce'] = { burst = 1, per_second = 1 / 30 },
  ['staff_suite:banList'] = { burst = 5, per_second = 1 },
  ['staff_suite:banRevoke'] = { burst = 2, per_second = 1 / 10 },
  ['staff_suite:ticketExport'] = { burst = 1, per_second = 1 / 30 },
}
