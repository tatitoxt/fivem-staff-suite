-- config.lua — ABIERTO (editable por el comprador). Staff Suite.
Config = {}

Config.Locale = 'es'                 -- 'es' | 'en' | 'pt' | 'fr' | 'de'
Config.PanelKey = 'F6'               -- tecla para abrir el panel NUI
Config.Theme = 'light'               -- 'light' | 'dark' | 'auto'; cada staff lo puede cambiar en Ajustes

-- Marca del server en el panel. Vacío = marca de Staff Suite.
Config.Brand = {
  name = '',                         -- nombre del server (máx. 40 caracteres)
  logo = '',                         -- URL https:// o 'brand/logo.png' (archivo en ui/public/brand/ antes del build)
  accent = '',                       -- color '#RRGGBB'; se ignora si no cumple contraste AA en el tema activo
}

Config.Commands = {
  report  = 'report',                -- jugador: abrir report
  reports = 'reports',               -- staff: cola de tickets
  audit   = 'audit',                 -- staff: visor de auditoría
  duty    = 'duty',                  -- staff: on/off duty
}

Config.Categories = { 'bug', 'player', 'staff', 'question', 'other' }
Config.Priorities = { 'low', 'normal', 'high', 'urgent' }

-- Etiquetas de triaje del staff sobre tickets (paridad rcore). El staff las
-- marca/desmarca desde el detalle del ticket; se validan contra esta lista.
Config.TicketLabels = { 'cheater', 'harassment', 'rdm', 'vdm', 'question', 'other' }

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

-- Avisos in-game con el panel cerrado: arriba a la derecha, sin tomar el foco ni bloquear el juego.
Config.Notifications = {
  enabled = true,                    -- false: los avisos van al chat, como antes
  staff_reports = true,              -- avisar al staff de cada reporte nuevo
  duration = 6000,                   -- milisegundos en pantalla
  max = 3,                           -- avisos apilados como máximo
  sound = false,                     -- sonido para reportes nuevos, p. ej. { name = 'Text_Arrive_Tone', set = 'Phone_SoundSet_Default' }
}

-- Limpieza de vehículos vacíos desde Ajustes: cuentas regresivas que puede elegir el staff (segundos).
Config.VehicleCleanup = {
  countdowns = { 10, 30, 60 },
}

-- Límites de texto (en bytes) y tickets abiertos por jugador. El servidor rechaza lo que exceda.
Config.Limits = {
  ticket_body = 1000,
  message_body = 1000,
  announcement = 300,
  reason = 300,
  open_tickets_per_player = 3,
  -- Tamaño máximo de una captura de screenshot-basic (data URI JPEG), en bytes.
  evidence_bytes = 3 * 1024 * 1024,
}

-- Rate limit por jugador y evento: burst acciones seguidas, luego per_second por segundo.
Config.RateLimit = {
  default = { burst = 10, per_second = 2 },
  ['staff_suite:ticketCreate'] = { burst = 5, per_second = 1 / 60 },
  ['staff_suite:ticketMessage'] = { burst = 10, per_second = 1 },
  ['staff_suite:staffChat'] = { burst = 5, per_second = 0.5 },
  ['staff_suite:playerProfile'] = { burst = 3, per_second = 0.5 },
  ['staff_suite:playerProfileNote'] = { burst = 2, per_second = 0.2 },
  ['staff_suite:onlinePlayers'] = { burst = 2, per_second = 0.2 },
  ['staff_suite:staffWeekly'] = { burst = 2, per_second = 0.1 },
  ['staff_suite:modTemplate'] = { burst = 3, per_second = 0.5 },
  ['staff_suite:modWarn'] = { burst = 3, per_second = 0.2 },
  ['staff_suite:modVehicle'] = { burst = 3, per_second = 0.5 },
  ['staff_suite:emergencyFreeze'] = { burst = 4, per_second = 0.25 },
  ['staff_suite:ownerPermissions'] = { burst = 6, per_second = 0.5 },
  ['staff_suite:waypoint'] = { burst = 2, per_second = 0.2 },
  ['staff_suite:coords'] = { burst = 2, per_second = 0.2 },
  ['staff_suite:staffMode'] = { burst = 3, per_second = 1 },
  ['staff_suite:verify'] = { burst = 3, per_second = 1 / 10 },
  ['staff_suite:duty'] = { burst = 4, per_second = 1 / 10 },
  ['staff_suite:ticketEvidence'] = { burst = 3, per_second = 1 / 20 },
  ['staff_suite:ticketCancel'] = { burst = 2, per_second = 1 / 10 },
  ['staff_suite:ticketLabel'] = { burst = 6, per_second = 1 },
  ['staff_suite:announce'] = { burst = 1, per_second = 1 / 30 },
  ['staff_suite:banList'] = { burst = 5, per_second = 1 },
  ['staff_suite:banRevoke'] = { burst = 2, per_second = 1 / 10 },
  ['staff_suite:ticketExport'] = { burst = 1, per_second = 1 / 30 },
  ['staff_suite:vehicleCleanup'] = { burst = 2, per_second = 1 / 10 },
  ['staff_suite:vehicleCleanupCancel'] = { burst = 2, per_second = 1 / 5 },
}
