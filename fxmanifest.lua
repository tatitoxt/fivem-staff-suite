fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'staff_suite'
author 'Orkelya Studio'
description 'Staff Suite — reports, moderación y auditoría verificable (hash-chain). Español-first.'
version '0.1.0'

shared_scripts {
  'config.lua',
  'locales/es.lua',
  'locales/en.lua',
}

-- main.lua carga core + adapter vía require (package.path = resource root).
server_scripts {
  'server/main.lua',
}

ui_page 'ui/dist/index.html'
client_scripts {
  'client/main.lua',
}
files {
  'ui/dist/index.html',
  'ui/dist/assets/*',
}
