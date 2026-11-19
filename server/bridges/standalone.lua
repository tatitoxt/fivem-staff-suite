-- Identidad nativa de FiveM y permisos standalone por ACE.
local B = {}

function B.get_player(src)
  local identifiers = GetPlayerIdentifiers(src)
  local license, license2
  for _, id in ipairs(identifiers) do
    if id:sub(1, 8) == 'license:' then license = id end
    if id:sub(1, 9) == 'license2:' then license2 = id end
  end

  return {
    license = license,
    identifier = license2 or identifiers[1],
    name = GetPlayerName(src),
    has_group = function(rank) return IsPlayerAceAllowed(src, 'staff_suite.' .. rank) end,
  }
end

if StaffSuiteModules then StaffSuiteModules['server.bridges.standalone'] = B end
return B
