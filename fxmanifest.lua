fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'staff_suite'
author 'Orkelya Studio'
description 'Staff Suite — reports, moderación y auditoría verificable (hash-chain). Español-first.'
version '0.3.1'

shared_scripts {
  'config.lua',
  'locales/es.lua',
  'locales/en.lua',
  'locales/pt.lua',
  'locales/fr.lua',
  'locales/de.lua',
  'shared/i18n.lua',
}

-- La config privada y las dependencias se cargan antes del adapter.
server_scripts {
  'server/config.lua',
  'shared/loader.lua',
  'core/sha256.lua',
  'core/audit_chain.lua',
  'core/tickets.lua',
  'core/permissions.lua',
  'core/duty.lua',
  'core/ratelimit.lua',
  'server/bridges/standalone.lua',
  'server/bridges/esx.lua',
  'server/bridges/qbcore.lua',
  'server/bridges/qbox.lua',
  'server/bridges/init.lua',
  'server/persist_sql.lua',
  'server/persist_json.lua',
  'server/persist.lua',
  'server/export.lua',
  'server/capture.lua',
  'server/main.lua',
}

ui_page 'ui/dist/index.html'
client_scripts {
  'client/main.lua',
  'client/moderation.lua',
}
files {
  'ui/dist/index.html',
  'ui/dist/assets/*',
  'ui/dist/brand/*',
}

escrow_ignore {
  'config.lua',
  'server/config.lua',
  'locales/*.lua',
  'sql/*.sql',
}
