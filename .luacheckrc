std = 'lua54'
max_line_length = false
exclude_files = { '**/node_modules/**', 'dist/**' }

-- API compartida por los scripts cliente y servidor de FiveM.
local runtime = {
  'AddEventHandler', 'CreateThread', 'GetCurrentResourceName', 'GetResourceState',
  'LoadResourceFile', 'RegisterCommand', 'RegisterNetEvent', 'TriggerEvent', 'Wait',
  'exports', 'json', 'Config', 'Locale', 'StaffSuiteTranslate',
}

local function runtime_with(globals)
  for _, name in ipairs(runtime) do globals[#globals + 1] = name end
  return globals
end

files['server/**/*.lua'].read_globals = runtime_with({
  'DropPlayer', 'FreezeEntityPosition', 'GetConvar', 'GetEntityCoords', 'GetPlayerIdentifiers',
  'GetPlayerName', 'GetPlayerPed', 'GetPlayers', 'IsPlayerAceAllowed', 'PerformHttpRequest',
  'SaveResourceFile', 'SetEntityHealth', 'StaffSuiteModules', 'TriggerClientEvent', 'source',
})
files['client/**/*.lua'].read_globals = runtime_with({
  'PlayerPedId', 'RegisterKeyMapping', 'RegisterNUICallback', 'SendNUIMessage',
  'SetEntityCoords', 'SetNuiFocus', 'TriggerServerEvent',
})
files['tests/e2e_resource/server.lua'].read_globals = runtime
files['shared/loader.lua'].read_globals = runtime

files['**/fxmanifest.lua'].read_globals = {
  'author', 'client_scripts', 'dependency', 'description', 'escrow_ignore', 'files', 'fx_version',
  'game', 'lua54', 'name', 'server_script', 'server_scripts', 'shared_scripts',
  'ui_page', 'version',
}

-- Globals que estos archivos inicializan mediante el entorno del resource.
files['config.lua'].globals = { 'Config' }
files['server/config.lua'].globals = { 'Config.Export', 'Config.StandaloneRanks' }
files['locales/*.lua'].globals = { 'Locale' }
files['shared/constants.lua'].globals = { 'SS' }
files['shared/i18n.lua'].read_globals = { 'Config', 'Locale' }
files['shared/i18n.lua'].globals = { 'StaffSuiteTranslate' }
files['server/capture.lua'].globals = { 'SS' }
files['server/persistence.lua'].globals = { 'SS' }
files['shared/loader.lua'].globals = { 'StaffSuiteModules' }
files['core/*.lua'].globals = { 'StaffSuiteModules' }
files['server/bridges/*.lua'].globals = { 'StaffSuiteModules' }
files['server/persist.lua'].globals = { 'StaffSuiteModules' }
files['server/export.lua'].globals = { 'StaffSuiteModules' }

-- Advertencias preexistentes, acotadas al archivo y al símbolo.
files['core/tickets.lua'].ignore = { '212/ts' }
files['tests/e2e_resource/server.lua'].ignore = { '211/at' }
files['tests/test_audit_chain.lua'].ignore = { '211/at' }
