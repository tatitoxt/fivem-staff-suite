-- Configuración privada. FiveM carga este archivo únicamente en el servidor.
Config.Export = {
  -- En server.cfg usá set staff_suite_webhook "URL", sin replicarlo con setr.
  webhook = GetConvar('staff_suite_webhook', ''),
  -- Canal Discord dedicado al hilo público de tickets. También es server-only.
  ticket_webhook = GetConvar('staff_suite_ticket_webhook', ''),
  file = true,
  anchor_every = 20,
  -- Reintentos del webhook ante 429/5xx/sin respuesta: backoff exponencial con tope.
  webhook_retries = 5,
  webhook_backoff_ms = 2000,
  webhook_backoff_max_ms = 60000,
}

-- Mapeo opcional por identificador estable en standalone.
-- Ejemplo: ['license:...'] = 'admin'
Config.StandaloneRanks = {}

-- Plantillas fijas para Core. reason_key se traduce con el idioma del servidor.
-- IDs de hasta 32 bytes. duration es obligatoria para ban (0 = permanente).
Config.SanctionTemplates = {
  rp_warning = { action = 'warn', reason_key = 'sanction_reason_rp' },
  evasion_day = { action = 'ban', reason_key = 'sanction_reason_evasion', duration = 86400 },
}

-- Optativo. Tras este número de advertencias en la ventana, expulsa una vez por ventana.
Config.WarnEscalation = { enabled = false, threshold = 3, window_seconds = 86400 }
