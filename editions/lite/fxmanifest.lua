fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'staff_suite'
author 'Orkelya Studio'
description 'Staff Suite Free Lite — reportes y auditoría verificable.'
version '@VERSION@'

shared_scripts {
  'config.lua',
  'locales/es.lua',
  'locales/en.lua',
  'shared/i18n.lua',
}

server_scripts {
  'shared/loader.lua',
  'core/sha256.lua',
  'core/audit_chain.lua',
  'core/tickets.lua',
  'core/ratelimit.lua',
  'server/persist_json.lua',
  'server/lite.lua',
}

client_scripts {
  'client/main.lua',
}
ui_page 'ui/dist/index.html'
files {
  'ui/dist/index.html',
  'ui/dist/assets/*',
}
