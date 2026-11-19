-- staff_suite_tests/server.lua — E2E contra el server vivo vía exports.
local pass, fail = 0, 0
local function check(name, cond)
  if cond then pass = pass + 1; print('[SSTEST] ok   ' .. name)
  else fail = fail + 1; print('[SSTEST] FAIL ' .. name) end
end

local function run()
  local ss = exports.staff_suite
  local now = os.time()

  -- Tickets: ciclo completo
  local id = ss:CreateTicket({ reporter = 'license:e2e_player', category = 'bug', description = 'reporte e2e', ts = now })
  check('create ticket devuelve id', type(id) == 'number')
  local t = ss:TicketAction(id, 'claim', 'license:e2e_staff', {})
  check('claim -> claimed', t and t.state == 'claimed')
  local t2 = ss:TicketAction(id, 'claim', 'license:otro_staff', {})
  check('doble claim rechazado', t2 == nil)
  t = ss:TicketAction(id, 'resolve', 'license:e2e_staff', { resolution = 'arreglado' })
  check('resolve -> resolved', t and t.state == 'resolved')

  -- Auditoría: registrar acciones y verificar cadena
  ss:Record('grant_money', 'license:e2e_staff', 'license:e2e_player', 'pago', { amount = 5000 })
  ss:Record('ban', 'license:e2e_staff', 'license:cheater', 'cheating', { days = 30 })
  local ok, at = ss:Verify()
  check('verify cadena íntegra', ok == true)
  local chain = ss:GetChain()
  check('chain tiene >= 4 entradas (ticket+claim+resolve+grants)', #chain >= 4)
  check('head encadenado', chain[#chain].prev_hash == chain[#chain - 1].hash)

  -- Integridad estructural. NOTA: los exports de FiveM devuelven COPIAS (serializan),
  -- así que mutar el chain retornado no toca el chain vivo. La detección de tamper
  -- se testea in-process en los unit tests (test_audit_chain). Acá validamos estructura.
  local sequential, hashed = true, true
  for i, e in ipairs(chain) do
    if e.seq ~= i then sequential = false end
    if not e.hash or #e.hash ~= 64 then hashed = false end
  end
  check('seq secuencial en toda la cadena', sequential)
  check('todas las entradas tienen hash SHA-256 (64 hex)', hashed)

  -- Duty
  local state = ss:GetState()
  check('GetState tiene tickets + audit + duty', state.tickets ~= nil and state.chain ~= nil and state.duty ~= nil)

  print(('[SSTEST] ====== %d passed, %d failed ======'):format(pass, fail))
end

CreateThread(function()
  Wait(3000)  -- esperar a que staff_suite termine de iniciar
  local ok, err = pcall(run)
  if not ok then print('[SSTEST] ERROR en run: ' .. tostring(err)) end
end)
