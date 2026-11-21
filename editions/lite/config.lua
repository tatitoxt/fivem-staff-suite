Config = {
  Edition = 'lite',
  Locale = 'es',
  PanelKey = 'F6',
  Theme = 'light', -- 'light' | 'dark' | 'auto'
  Brand = { name = '', logo = '', accent = '' }, -- ver config.lua de Core
  Categories = { 'bug', 'player', 'staff', 'question', 'other' },
  -- Etiquetas de triaje del staff sobre tickets; se validan contra esta lista.
  TicketLabels = { 'cheater', 'harassment', 'rdm', 'vdm', 'question', 'other' },
  Commands = { report = 'report', reports = 'reports', audit = 'audit' },
  JsonFile = 'staff_suite_data.json',
  CoreUrl = '', -- URL HTTPS del paquete en Tebex, si está disponible.
  -- Máximo en bytes de reportes, mensajes y resoluciones, y reportes abiertos por jugador.
  Limits = { ticket_body = 1000, message_body = 1000, resolution = 1000, open_tickets_per_player = 3 },
  -- Token bucket por jugador: burst acciones seguidas, luego per_second por segundo.
  RateLimit = {
    default = { burst = 10, per_second = 2 },
    ['staff_suite:ticketCreate'] = { burst = 5, per_second = 1 / 60 },
    ['staff_suite:ticketMessage'] = { burst = 10, per_second = 1 },
    ['staff_suite:verify'] = { burst = 3, per_second = 1 / 10 },
    ['staff_suite:ticketLabel'] = { burst = 6, per_second = 1 },
    ['staff_suite:ticketHistory'] = { burst = 4, per_second = 1 },
    ['staff_suite:ticketInvite'] = { burst = 4, per_second = 1 / 2 },
  },
}
