-- Configuración privada. FiveM carga este archivo únicamente en el servidor.
Config.Export = {
  -- En server.cfg usá set staff_suite_webhook "URL", sin replicarlo con setr.
  webhook = GetConvar('staff_suite_webhook', ''),
  file = true,
  anchor_every = 20,
}

-- Mapeo opcional por identificador estable en standalone.
-- Ejemplo: ['license:...'] = 'admin'
Config.StandaloneRanks = {}
