-- Configuración privada. FiveM carga este archivo únicamente en el servidor.
Config.Export = {
  -- En server.cfg usá set staff_suite_webhook "URL", sin replicarlo con setr.
  webhook = GetConvar('staff_suite_webhook', ''),
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

-- Optativo. Tras este número de advertencias en la ventana, expulsa una vez por ventana.
Config.WarnEscalation = { enabled = false, threshold = 3, window_seconds = 86400 }
