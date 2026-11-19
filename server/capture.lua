-- server/capture.lua — hooks de eventos/comandos → auditoría.
-- SS.record(action, actor, target, reason, payload) lo define main.lua.
SS = SS or {}
local C = {}
SS.capture = C

function C.init()
  if not Config.Audit.CaptureFrameworkEvents then return end

  -- Hooks genéricos de eventos de admin (otros resources pueden dispararlos)
  AddEventHandler('staff_suite:audit', function(action, actor, target, reason, payload)
    SS.record(action, actor or 'system', target or '', reason or '', payload)
  end)

  -- ESX: grants de dinero/items frecuentes como vector de abuso
  AddEventHandler('esx:playerLoaded', function() end)  -- placeholder no-op
  AddEventHandler('staff_suite:moneyGrant', function(actor, target, amount)
    SS.record('grant_money', actor, target, 'money grant', json.encode({ amount = amount }))
  end)
  AddEventHandler('staff_suite:itemGrant', function(actor, target, item, count)
    SS.record('grant_item', actor, target, 'item grant', json.encode({ item = item, count = count }))
  end)

  -- QBCore/Qbox: eventos de ban/kick
  AddEventHandler('QBCore:Server:OnPlayerKick', function(src, reason)
    SS.record('kick', 'system', SS.bridge.get_identifier(src), reason or '')
  end)

  if Config.Debug then print('[staff_suite] capture hooks inicializados') end
end

-- Export público para que OTROS resources registren en la auditoría
exports('RecordAudit', function(action, actor, target, reason, payload)
  SS.record(action, actor, target, reason, payload)
end)

return C
