-- staff_suite_tests/server.lua — E2E contra staff_suite en un FXServer real.
-- Salida parseable (una línea por resultado):
--   [SSTEST] PASS <nombre> | [SSTEST] FAIL <nombre> :: <detalle> | [SSTEST] SKIP <nombre> :: <motivo>
--   [SSTEST] METRIC <clave>=<valor>
--   [SSTEST] RESULT status=PASS|FAIL passed=N failed=N skipped=N
-- Convars: staff_suite_e2e_autoquit (true), staff_suite_e2e_anchor_every (20),
--          staff_suite_e2e_profile_file (vacío = sin profiler), staff_suite_webhook (vacío = SKIP).
--          staff_suite_e2e_edition (core o lite).
local TARGET = 'staff_suite'
local pass, fail, skip = 0, 0, 0
local webhookPosts = {}

local function log(line) print('[SSTEST] ' .. line) end

local function check(name, cond, detail)
  if cond then pass = pass + 1; log('PASS ' .. name)
  else fail = fail + 1; log('FAIL ' .. name .. ' :: ' .. tostring(detail or 'assert')) end
  return cond
end

local function skipped(name, why) skip = skip + 1; log('SKIP ' .. name .. ' :: ' .. why) end

local function metric(key, value) log(('METRIC %s=%s'):format(key, value)) end

-- Receptor del webhook: staff_suite postea acá cuando staff_suite_webhook apunta a este resource.
SetHttpHandler(function(req, res)
  if req.method ~= 'POST' or req.path ~= '/webhook' then
    res.writeHead(404); res.send('')
    return
  end
  req.setDataHandler(function(body)
    webhookPosts[#webhookPosts + 1] = body
    res.writeHead(204); res.send('')
  end)
end)

local function waitFor(predicate, timeoutMs)
  local deadline = GetGameTimer() + timeoutMs
  while GetGameTimer() < deadline do
    if predicate() then return true end
    Wait(100)
  end
  return predicate()
end

local function ticketOf(ss, id)
  local state = ss:GetState()
  return state and state.tickets and state.tickets.tickets and state.tickets.tickets[id]
end

local function lastLine(text)
  local last
  for line in (text or ''):gmatch('[^\n]+') do last = line end
  return last
end

local function testTickets(ss)
  local now = os.time()
  local id = ss:CreateTicket({ reporter = 'license:e2e_player', category = 'bug', priority = 'high', description = 'reporte e2e', ts = now })
  check('ticket.create devuelve id', type(id) == 'number', id)
  local tk = ticketOf(ss, id)
  check('ticket.create estado open', tk and tk.state == 'open', tk and tk.state)

  local t = ss:TicketAction(id, 'claim', 'license:e2e_staff', { ts = now })
  check('ticket.claim -> claimed', t and t.state == 'claimed' and t.claimer == 'license:e2e_staff', t and t.state)
  local t2, err = ss:TicketAction(id, 'claim', 'license:otro_staff', { ts = now })
  check('ticket.claim doble rechazado', t2 == false and err == 'already_claimed', tostring(t2) .. ',' .. tostring(err))

  t = ss:TicketAction(id, 'transfer', 'license:e2e_staff', { to = 'license:e2e_staff2', ts = now })
  check('ticket.transfer -> claimer nuevo', t and t.state == 'claimed' and t.claimer == 'license:e2e_staff2', t and t.claimer)

  t = ss:TicketAction(id, 'resolve', 'license:e2e_staff2', { resolution = 'arreglado', ts = now })
  check('ticket.resolve -> resolved', t and t.state == 'resolved' and t.resolution == 'arreglado', t and t.state)

  local r, bad = ss:TicketAction(id, 'claim', 'license:e2e_staff2', { ts = now })
  check('ticket transición inválida rechazada',
    r == false and type(bad) == 'string' and bad:find('invalid_transition', 1, true) ~= nil, tostring(r) .. ',' .. tostring(bad))
  r, bad = ss:TicketAction(999999, 'claim', 'license:e2e_staff2', { ts = now })
  check('ticket inexistente rechazado', r == false and bad == 'ticket_not_found', tostring(r) .. ',' .. tostring(bad))

  -- Un evento de red sin jugador con permisos no debe cambiar el ticket.
  TriggerEvent('staff_suite:ticketAction', id, 'close', {})
  Wait(200)
  tk = ticketOf(ss, id)
  check('evento de red sin permisos ignorado', tk and tk.state == 'resolved', tk and tk.state)

  local chain = ss:GetChain()
  local actions = {}
  for _, e in ipairs(chain) do actions[e.action] = (actions[e.action] or 0) + 1 end
  for _, a in ipairs({ 'ticket_create', 'ticket_claim', 'ticket_transfer', 'ticket_resolve' }) do
    check('auditoría registra ' .. a, (actions[a] or 0) >= 1)
  end
end

local function testDuty(ss)
  local actor = 'license:e2e_duty'
  local ev = ss:SetDuty(actor, true)
  check('duty.in', ev and ev.event == 'duty.in', ev and ev.event)
  local again, err = ss:SetDuty(actor, true)
  check('duty.in doble rechazado', again == false and type(err) == 'string', tostring(again) .. ',' .. tostring(err))
  local s = ss:GetState().duty.staff[actor]
  check('duty estado on_duty', s and s.on_duty == true)
  Wait(1100)
  ev = ss:SetDuty(actor, false)
  check('duty.out con segundos', ev and ev.event == 'duty.out' and ev.seconds >= 1, ev and ev.seconds)
  s = ss:GetState().duty.staff[actor]
  check('duty acumula sesión', s and s.on_duty == false and s.sessions == 1 and s.total_seconds >= 1)
  local last = ss:GetChain()
  check('auditoría registra duty.out', last[#last] and last[#last].action == 'duty.out', last[#last] and last[#last].action)
end

local function testExport(ss)
  local every = GetConvarInt('staff_suite_e2e_anchor_every', 20)
  local n = #ss:GetChain()
  local pad = every - (n % every)
  for i = 1, pad do
    ss:Record('e2e_pad', 'license:e2e_staff', 'license:e2e_player', 'relleno ' .. i, { i = i })
  end
  local chain = ss:GetChain()
  local anchored = chain[#chain]
  check('export: cadena en múltiplo de anchor_every', #chain % every == 0, #chain)

  local line = lastLine(LoadResourceFile(TARGET, 'audit_export.log'))
  local seq, hash, prev, action = (line or ''):match('^(%d+)|(%x+)|(%x+)|(.+)$')
  check('export archivo: última línea = head', tonumber(seq) == anchored.seq and hash == anchored.hash
    and prev == anchored.prev_hash and action == anchored.action, line)

  if GetConvar('staff_suite_webhook', '') == '' then
    skipped('export webhook', 'staff_suite_webhook vacío')
    return
  end
  local short = anchored.hash:sub(1, 16)
  local got = waitFor(function()
    for _, body in ipairs(webhookPosts) do
      if body:find(short, 1, true) and body:find(tostring(anchored.seq), 1, true) then return true end
    end
    return false
  end, 10000)
  check('export webhook recibe el anchor', got, #webhookPosts .. ' POST recibidos')
end

local function testVerify(ss)
  local ok, at = ss:Verify()
  check('verify cadena íntegra', ok == true, at)
  local chain = ss:GetChain()
  local sequential, hashed, linked = true, true, true
  for i, e in ipairs(chain) do
    if e.seq ~= i then sequential = false end
    if type(e.hash) ~= 'string' or not e.hash:match('^%x+$') or #e.hash ~= 64 then hashed = false end
    if i > 1 and e.prev_hash ~= chain[i - 1].hash then linked = false end
  end
  check('verify seq secuencial', sequential)
  check('verify hashes SHA-256 (64 hex)', hashed)
  check('verify prev_hash encadenado', linked)
  -- Los exports devuelven copias: el tamper se prueba in-process en tests/test_audit_chain.lua.

  -- El guardado normal es diferido (lote de 1 s); Flush lo fuerza y GetPersistence lo confirma.
  local revision = ss:Flush()
  check('persistencia: Flush devuelve revisión', type(revision) == 'number', revision)
  local saved = type(revision) == 'number' and waitFor(function()
    local st = ss:GetPersistence()
    return st and st.saved >= revision
  end, 15000)
  check('persistencia: guardado confirmado', saved, json.encode(ss:GetPersistence()))
  local raw = LoadResourceFile(TARGET, 'staff_suite_data.json')
  local okJson, data = pcall(json.decode, raw or '')
  local persisted = okJson and data and data.chain and data.chain.entries
  check('persistencia JSON al día', persisted and #persisted == #chain
    and persisted[#persisted].hash == chain[#chain].hash, (persisted and #persisted or 'nil') .. '/' .. #chain)
end

local function measure(ss)
  local n = 50
  local t0 = os.clock()
  for i = 1, n do ss:Record('e2e_perf', 'license:e2e_staff', '', '', { i = i }) end
  metric('record_avg_ms', ('%.3f'):format((os.clock() - t0) * 1000 / n))
  t0 = os.clock()
  for _ = 1, n do ss:GetState() end
  metric('getstate_avg_ms', ('%.3f'):format((os.clock() - t0) * 1000 / n))

  -- Frame del scheduler del server (~50 ms en reposo, 20 Hz): no es costo de staff_suite.
  -- server_cpu_* es CPU de todo el proceso FXServer por frame: cota superior, informativa.
  -- El presupuesto de staff_suite sale del profiler (scripts/e2e-fxserver.sh).
  local frames, maxGap, last = 0, 0, GetGameTimer()
  local start, cpu0 = last, os.clock()
  local stop = last + 3000
  while GetGameTimer() < stop do
    Wait(0)
    local now = GetGameTimer()
    if now - last > maxGap then maxGap = now - last end
    frames = frames + 1
    last = now
  end
  frames = math.max(frames, 1)
  metric('server_frame_avg_ms', ('%.2f'):format((last - start) / frames))
  metric('server_frame_max_ms', maxGap)
  metric('server_cpu_ms_per_frame', ('%.4f'):format((os.clock() - cpu0) * 1000 / frames))
  local ok = ss:Verify()
  check('verify tras carga de rendimiento', ok == true)
end

local function testLite(ss)
  local stateEvent = 'staff_suite:state'
  local actionEvent = 'staff_suite:ticketAction'
  local verifyEvent = 'staff_suite:verify'
  local resultEvent = 'staff_suite:auditResult'
  local function probe(route, ...)
    return ss:LiteE2EProbe(route, ...)
  end
  local function state(role)
    return probe('staff_suite:getState', role)[role][stateEvent]
  end

  for _, name in ipairs({ 'CreateTicket', 'TicketAction', 'Record', 'Verify', 'GetChain', 'GetState', 'SetDuty' }) do
    local ok, err = pcall(function() return ss[name](ss) end)
    check('Lite sin export Core ' .. name, not ok and tostring(err):find('No such export', 1, true), err)
  end
  for _, route in ipairs({ 'duty', 'staff_suite:modAction', 'staff_suite:ticketMessage',
    'staff_suite:ticketRate', 'staff_suite:ticketEvidence', 'staff_suite:evidenceGet' }) do
    check('Lite sin handler Core ' .. route, not probe(route))
  end

  local report = probe('report', 'reporter', 'bug', 'reporte', 'Lite')
  local ticket = report.staff[stateEvent].tickets[1]
  check('Lite report crea ticket abierto y avisa al staff', ticket and ticket.state == 'open'
    and ticket.description == 'reporte Lite' and ticket.reporter == 'license:e2e_reporter'
    and report.reporter[stateEvent] == nil)
  check('Lite reports abre cola', probe('reports', 'staff').staff['staff_suite:openPanel'] == 'tickets')
  check('Lite audit abre visor', probe('audit', 'staff').staff['staff_suite:openPanel'] == 'audit')
  local public = state('reporter')
  check('Lite oculta tickets, auditoría y permisos a jugadores', not next(public.tickets)
    and not next(public.audit) and not next(public.player.capabilities))
  probe(actionEvent, 'reporter', 1, 'claim')
  check('Lite claim sin ACE se ignora', state('staff').tickets[1].state == 'open')
  check('Lite verify sin ACE se ignora', probe(verifyEvent, 'reporter').reporter[resultEvent] == nil)
  probe(actionEvent, 'staff', 1, 'claim')
  local claimed = state('staff').tickets[1]
  check('Lite claim asigna el ticket', claimed.state == 'claimed' and claimed.claimer == 'license:e2e_staff')
  probe(actionEvent, 'staff', 1, 'transfer', { to = 'license:e2e_reporter' })
  check('Lite ignora transferencias', state('staff').tickets[1].claimer == 'license:e2e_staff')
  probe(actionEvent, 'staff', 1, 'resolve', { resolution = 'Revisado' })
  check('Lite resolve registra la resolución', state('staff').tickets[1].resolution == 'Revisado')
  probe(actionEvent, 'staff', 1, 'close')
  check('Lite close cierra el ticket', state('staff').tickets[1].state == 'closed')
  probe(actionEvent, 'staff', 1, 'reopen')
  local verify = probe(verifyEvent, 'staff').staff[resultEvent]
  check('Lite verify valida la cadena', verify and verify.ok == true and verify.at == nil)
  local latest = state('staff')
  check('Lite reopen devuelve el ticket a la cola', latest.tickets[1].state == 'reopened')
  local expected = { 'ticket_create', 'ticket_claim', 'ticket_resolve', 'ticket_close', 'ticket_reopen', 'audit_verify' }
  local previous = string.rep('0', 64)
  local linked = #latest.audit == #expected
  for i, row in ipairs(latest.audit) do
    linked = linked and row.action == expected[i] and row.seq == i and row.prev_hash == previous
      and type(row.hash) == 'string' and #row.hash == 64 and row.hash:match('^%x+$') ~= nil
    previous = row.hash
  end
  check('Lite audita el ciclo básico con SHA-256', linked)
  local data = json.decode(LoadResourceFile(TARGET, 'staff_suite_data.json') or 'null')
  local stored = data and data.tickets and data.tickets.tickets
  local savedTicket = stored and (stored[1] or stored['1'])
  check('Lite guarda tickets en JSON', savedTicket and savedTicket.state == 'reopened'
    and data.tickets.next_id == 2)
  check('Lite guarda la cadena en JSON', data and data.chain and #data.chain.entries == #expected
    and data.chain.head == previous and data.chain.entries[#expected].action == 'audit_verify')
  check('Lite no exporta anclajes a archivo', not LoadResourceFile(TARGET, 'audit_export.log'))
end

local function profile()
  local file = GetConvar('staff_suite_e2e_profile_file', '')
  if file == '' then return end
  ExecuteCommand('profiler record 300')
  Wait(15000)
  ExecuteCommand(('profiler saveJSON "%s"'):format(file))
  Wait(3000)
  metric('profile_file', file)
end

local function run()
  if GetResourceState(TARGET) ~= 'started' then
    check('staff_suite iniciado', false, GetResourceState(TARGET))
    return
  end
  local ss = exports[TARGET]
  local edition = GetConvar('staff_suite_e2e_edition', 'core')
  local steps = edition == 'lite' and { testLite } or { testTickets, testDuty, testExport, testVerify, measure }
  metric('edition', edition)
  for _, step in ipairs(steps) do
    local ok, err = pcall(step, ss)
    if not ok then check('sin errores de Lua', false, err) end
  end
end

CreateThread(function()
  Wait(3000) -- staff_suite restaura su estado en un thread propio.
  run()
  local status = (fail == 0 and pass > 0) and 'PASS' or 'FAIL'
  log(('RESULT status=%s passed=%d failed=%d skipped=%d'):format(status, pass, fail, skip))
  profile()
  log('DONE')
  if GetConvar('staff_suite_e2e_autoquit', 'true') == 'true' then
    Wait(500)
    ExecuteCommand('quit "staff_suite e2e terminado"')
  end
end)
