fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'staff_suite'
author 'Orkelya'
description 'Staff Suite — reports, moderación y auditoría verificable (hash-chain)'
version '0.1.0'

shared_scripts {
  'shared/loader.lua',
  'config.lua',
  'locales/es.lua',
  'locales/en.lua',
  'shared/constants.lua',
}

server_scripts {
  'server/persistence.lua',
  'server/bridges/standalone.lua',
  'server/bridges/esx.lua',
  'server/bridges/qbcore.lua',
  'server/bridges/qbox.lua',
  'server/export.lua',
  'server/capture.lua',
  'server/moderation.lua',
  'server/reports.lua',
  'server/main.lua',
}

client_scripts {
  'client/main.lua',
}

ui_page 'ui/dist/index.html'

files {
  'ui/dist/index.html',
  'ui/dist/**/*',
}

-- core agnóstico leído por el loader (no se lista como script)
-- core/sha256.lua, core/audit_chain.lua, core/tickets.lua, core/permissions.lua, core/duty.lua

dependencies {
  '/server:7290',
  '/onesync',
}
