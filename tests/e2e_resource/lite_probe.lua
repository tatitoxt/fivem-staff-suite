-- Se carga solo en la copia de Lite que prepara el runner headless.
-- Conserva el registro real de comandos/eventos y simula dos jugadores al invocar sus handlers.
local routes = {}
local players = { reporter = 51001, staff = 51002 }
local outgoing
local nativeNetEvent, nativeCommand = RegisterNetEvent, RegisterCommand
local nativeIds, nativeName, nativePlayers = GetPlayerIdentifiers, GetPlayerName, GetPlayers
local nativeAce, nativeSend = IsPlayerAceAllowed, TriggerClientEvent

function RegisterCommand(name, handler, restricted)
  routes[name] = function(...) handler(source, { ... }) end
  return nativeCommand(name, handler, restricted)
end

function RegisterNetEvent(name, handler)
  routes[name] = handler
  return nativeNetEvent(name, handler)
end

function GetPlayerIdentifiers(src)
  if outgoing then return { 'license:e2e_' .. (src == players.staff and 'staff' or 'reporter') } end
  return nativeIds(src)
end

function GetPlayerName(src)
  if outgoing then return src == players.staff and 'E2E Staff' or 'E2E Reporter' end
  return nativeName(src)
end

function GetPlayers()
  if outgoing then return { tostring(players.reporter), tostring(players.staff) } end
  return nativePlayers()
end

function IsPlayerAceAllowed(src, ace)
  if outgoing then return src == players.staff and ace == 'staff_suite.lite' end
  return nativeAce(src, ace)
end

function TriggerClientEvent(event, target, ...)
  if outgoing then
    local role = target == players.staff and 'staff' or 'reporter'
    outgoing[role][event] = ...
    return
  end
  return nativeSend(event, target, ...)
end

exports('LiteE2EProbe', function(route, actor, ...)
  assert(GetInvokingResource() == 'staff_suite_tests')
  local handler = routes[route]
  if actor == nil then return handler ~= nil end
  assert(handler and players[actor], 'ruta o actor desconocido: ' .. route)
  local previous = source
  source = players[actor]
  outgoing = { staff = {}, reporter = {} }
  local ok, err = pcall(handler, ...)
  local replies = outgoing
  outgoing, source = nil, previous
  if not ok then error(err) end
  return replies
end)
