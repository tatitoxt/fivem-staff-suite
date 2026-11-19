-- server/bridges/standalone.lua — bridge base/fallback (natives + ACE).
SS = SS or {}
SS.bridges = SS.bridges or {}

local B = { name = 'standalone' }

function B.detect() return true end  -- siempre disponible como fallback

function B.get_identifier(src)
  for _, id in ipairs(GetPlayerIdentifiers(src)) do
    if id:match('^license:') then return id end
  end
  return 'license:unknown'
end

function B.get_name(src) return GetPlayerName(src) or ('player' .. src) end

function B.get_rank(src)
  -- ACE: mapear por permiso concedido
  if IsPlayerAceAllowed(src, 'staff_suite.owner') then return 'owner' end
  if IsPlayerAceAllowed(src, 'staff_suite.senior_admin') then return 'senior_admin' end
  if IsPlayerAceAllowed(src, 'staff_suite.admin') then return 'admin' end
  if IsPlayerAceAllowed(src, 'staff_suite.moderator') then return 'moderator' end
  if IsPlayerAceAllowed(src, 'staff_suite.helper') then return 'helper' end
  return Config.DefaultRank
end

function B.mod_action(action, target, reason, actor)
  if action == 'kick' then DropPlayer(target, reason or 'Kicked')
  elseif action == 'ban' then
    -- ban vía ACE/txAdmin no estándar; registramos y delegamos al sistema de bans del server
    TriggerEvent('staff_suite:banRequest', target, reason, actor)
  elseif action == 'freeze' then FreezeEntityPosition(GetPlayerPed(target), true)
  elseif action == 'heal' then SetEntityHealth(GetPlayerPed(target), 200)
  elseif action == 'warn' then TriggerClientEvent('staff_suite:warn', target, reason)
  end
  return true
end

SS.bridges.standalone = B
