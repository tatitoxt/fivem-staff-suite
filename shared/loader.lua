-- FiveM ejecuta los módulos declarados en fxmanifest.lua en orden de dependencias.
StaffSuiteModules = {}

function StaffSuiteModules.loadmod(name)
  local module = StaffSuiteModules[name]
  if not module then
    error(StaffSuiteTranslate('console_module_missing', { module = name }), 2)
  end
  return module
end
