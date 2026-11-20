-- client/main.lua — Puente NUI (React, ui/dist) <-> server. Contrato: NUI_SPEC.md.
-- Traduce los eventos del adapter (staff_suite:state/auditResult/notify) a los
-- mensajes tipados de la NUI (init/audit/tickets/dashboard/duty/toast).
-- luacheck: globals GetResourceMetadata GetPlayerName PlayerId SetTimeout GetCloudTimeAsInt ExecuteCommand PlaySoundFrontend
local t = StaffSuiteTranslate
local lite = Config.Edition == 'lite'
local panelOpen = false
local pendingLiteOpen
local uiLocale = Config.Locale or 'es'
local rank = lite and 'player' or 'helper'
local ticketsCache, ticketsById = {}, {}
local dutyCache = {}
local alertsCache = {}
local playerInfo = nil
local transferTargets = nil
local exportStatus = nil
local evidenceEnabled = false
local initSent = false
local sanctionTemplates = {}
local warnEscalation

local function strings(lang)
  return (Locale and (Locale[lang] or Locale.es)) or {}
end

-- Con el panel cerrado, los datos no se mandan a la NUI: se guarda el último de cada tipo y se envía al abrir.
local DEFER_HIDDEN = { tickets = true, myTickets = true, frozenPlayers = true, audit = true, duty = true, dashboard = true }
local deferred, deferredOrder = {}, {}

local function nui(kind, payload)
  if not panelOpen and DEFER_HIDDEN[kind] then
    local prev = deferred[kind]
    if kind == 'audit' and prev then
      payload = { entries = payload.entries or prev.entries, verify = payload.verify or prev.verify }
    end
    if prev == nil then deferredOrder[#deferredOrder + 1] = kind end
    deferred[kind] = payload
    return
  end
  SendNUIMessage({ type = kind, payload = payload })
end

local function flushDeferred()
  local order, data = deferredOrder, deferred
  deferred, deferredOrder = {}, {}
  for _, kind in ipairs(order) do SendNUIMessage({ type = kind, payload = data[kind] }) end
end

local function cannedList()
  local s, out = strings(uiLocale), {}
  for i, c in ipairs(Config.CannedResponses or {}) do
    if type(c) == 'table' then
      out[#out + 1] = { id = tostring(c.id or i), title = tostring(c.title or ''), text = tostring(c.text or '') }
    elseif type(c) == 'string' then
      out[#out + 1] = { id = c, title = s['canned_' .. c .. '_title'] or c, text = s['canned_' .. c] or c }
    end
  end
  return out
end

local function sendInit()
  initSent = true
  local locales = {}
  for code in pairs(Locale or {}) do locales[#locales + 1] = code end
  table.sort(locales)
  nui('init', {
    locale = uiLocale,
    strings = strings(uiLocale),
    version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '',
    player = playerInfo or { name = GetPlayerName(PlayerId()), rank = rank, capabilities = lite and {} or nil },
    config = {
      panel_key = Config.PanelKey or 'F6',
      locales = locales,
      categories = Config.Categories,
      limits = Config.Limits,
      core_url = Config.CoreUrl,
      priorities = Config.Priorities,
      require_reason = Config.Moderation and Config.Moderation.require_reason ~= false,
      persistence = Config.Persistence,
      export = (exportStatus and {
        webhook = exportStatus.webhook == true,
        file = exportStatus.file == true,
        tickets = exportStatus.tickets == true,
        anchor_every = exportStatus.anchor_every,
      }) or (Config.Export and {
        webhook = (Config.Export.webhook or '') ~= '',
        file = Config.Export.file == true,
        anchor_every = Config.Export.anchor_every,
      }) or nil,
      transfer_targets = transferTargets,
      canned = not lite and cannedList() or nil,
      evidence = not lite and evidenceEnabled,
      sanction_templates = not lite and sanctionTemplates or nil,
      warn_escalation = warnEscalation,
    },
  })
end

local function ticketList(map)
  local list = {}
  for _, tk in pairs(map or {}) do
    if type(tk) == 'table' and tk.id then list[#list + 1] = tk end
  end
  table.sort(list, function(a, b) return a.id < b.id end)
  return list
end

local function auditList(entries)
  local out = {}
  for i, e in ipairs(entries or {}) do
    local payload = e.payload
    if type(payload) == 'table' then payload = json.encode(payload) end
    out[i] = {
      seq = e.seq or i, ts = e.ts or 0, actor = e.actor or '', action = e.action or '',
      target = e.target or '', reason = e.reason or '', payload = payload or '',
      prev_hash = e.prev_hash or '', hash = e.hash or '',
    }
  end
  return out
end

local function sendDashboard()
  local open, resolved, onDuty = 0, 0, 0
  for _, tk in ipairs(ticketsCache) do
    if tk.state == 'resolved' or tk.state == 'closed' then resolved = resolved + 1 else open = open + 1 end
  end
  local rSum, rN, gSum, gN = 0, 0, 0, 0
  for _, s in ipairs(dutyCache) do
    if s.on_duty then onDuty = onDuty + 1 end
    if s.avg_response then rSum, rN = rSum + s.avg_response, rN + 1 end
    if s.avg_rating then gSum, gN = gSum + s.avg_rating, gN + 1 end
  end
  nui('dashboard', {
    kpis = {
      open = open, resolved = resolved, on_duty = onDuty,
      avg_response = rN > 0 and rSum / rN or nil,
      avg_rating = gN > 0 and gSum / gN or nil,
    },
    leaderboard = dutyCache,
    alerts = alertsCache,
  })
end

local function verifyResult(ok, at)
  return { ok = ok == true, broken_at = (ok ~= true) and at or nil }
end

local function showPanel(view)
  panelOpen = true
  SetNuiFocus(true, true)
  nui('open', { view = view })
  flushDeferred()
end

local function openPanel(view)
  if lite then
    -- La NUI necesita las capabilities antes de elegir la vista inicial.
    pendingLiteOpen = { view = view }
    TriggerServerEvent('staff_suite:getState')
    return
  end
  sendInit()
  TriggerServerEvent('staff_suite:getState')
  showPanel(view)
end

local function closePanel()
  pendingLiteOpen = nil
  panelOpen = false
  SetNuiFocus(false, false)
  nui('close')
end

if not lite then AddEventHandler('staff_suite:closePanel', closePanel) end

RegisterCommand('staffsuite', function() openPanel() end, false)
RegisterKeyMapping('staffsuite', t('keybind_open'), 'keyboard', Config.PanelKey or 'F6')

-- ===== NUI -> Lua (acciones de NUI_SPEC.md) =====
local function on(action, fn)
  RegisterNUICallback(action, function(data, cb)
    fn(data or {})
    cb({ ok = true })
  end)
end

local function refreshSoon()
  SetTimeout(250, function() TriggerServerEvent('staff_suite:getState') end)
end

local function ticketAction(action)
  return function(d)
    d.ts = GetCloudTimeAsInt()
    TriggerServerEvent('staff_suite:ticketAction', d.id, action, d)
    refreshSoon()
  end
end

on('close_ui', function() closePanel() end)
on('refresh', function() TriggerServerEvent('staff_suite:getState') end)
on('set_locale', function(d)
  if Locale and Locale[d.locale] then uiLocale = d.locale; sendInit() end
end)
on('audit_verify', function() TriggerServerEvent('staff_suite:verify') end)
on('audit_filter', function() end) -- el filtrado es local en la NUI
on('ticket_claim', ticketAction('claim'))
on('ticket_resolve', ticketAction('resolve'))
on('ticket_close', ticketAction('close'))
on('ticket_reopen', ticketAction('reopen'))
-- Los callbacks esperan al servidor para conservar el borrador si falla el envío.
local pendingRequests, requestSeq = {}, 0
local function ticketRequest(action, result, failure, send, afterSuccess, timeout)
  RegisterNUICallback(action, function(d, cb)
    requestSeq = requestSeq % 2147483647 + 1
    local req = requestSeq
    local pending = { result = result, cb = cb, afterSuccess = afterSuccess }
    pendingRequests[req] = pending
    send(d or {}, req)
    SetTimeout(timeout or 10000, function()
      if pendingRequests[req] == pending then
        pendingRequests[req] = nil
        cb({ ok = false, error = t(failure) })
      end
    end)
  end)
end
local function ticketResult(result)
  RegisterNetEvent(result, function(res)
    if source ~= 65535 or type(res) ~= 'table' then return end
    local pending = pendingRequests[res.req]
    if not pending or pending.result ~= result then return end
    pendingRequests[res.req] = nil
    pending.cb({ ok = res.ok == true, error = type(res.error) == 'string' and res.error or nil, data = res.data })
    if res.ok == true and pending.afterSuccess then pending.afterSuccess() end
  end)
end
ticketResult('staff_suite:ticketCreateResult')
ticketResult('staff_suite:ticketMessageResult')
ticketRequest('ticket_create', 'staff_suite:ticketCreateResult', 'report_failed', function(d, req)
  TriggerServerEvent('staff_suite:ticketCreate', d.category or 'other', d.priority or 'normal', tostring(d.body or ''), req, d.attach == true)
end, refreshSoon)
ticketRequest('ticket_message', 'staff_suite:ticketMessageResult', 'ticket_message_failed', function(d, req)
  TriggerServerEvent('staff_suite:ticketMessage', d.id, d.body, d.internal == true, req)
end)
ticketRequest('ticket_reply', 'staff_suite:ticketMessageResult', 'ticket_message_failed', function(d, req)
  TriggerServerEvent('staff_suite:ticketReply', d.id, d.body, req)
end)
if not lite then
  ticketResult('staff_suite:announceResult')
  ticketRequest('announce', 'staff_suite:announceResult', 'announcement_failed', function(d, req)
    TriggerServerEvent('staff_suite:announce', d.body, req)
  end)
  ticketResult('staff_suite:banListResult')
  ticketResult('staff_suite:banRevokeResult')
  ticketRequest('ban_list', 'staff_suite:banListResult', 'ban_review_failed', function(d, req)
    TriggerServerEvent('staff_suite:banList', d.page, req)
  end)
  ticketRequest('ban_revoke', 'staff_suite:banRevokeResult', 'ban_review_failed', function(d, req)
    TriggerServerEvent('staff_suite:banRevoke', d.id, d.reason, req)
  end)
  ticketResult('staff_suite:ticketExportResult')
  ticketRequest('ticket_export', 'staff_suite:ticketExportResult', 'ticket_export_unconfirmed', function(d, req)
    TriggerServerEvent('staff_suite:ticketExport', d.id, req)
  end, nil, 40000)
  ticketResult('staff_suite:staffChatResult')
  ticketRequest('staff_chat', 'staff_suite:staffChatResult', 'staff_chat_failed', function(d, req)
    TriggerServerEvent('staff_suite:staffChat', d.body, req)
  end)
  RegisterNetEvent('staff_suite:staffChatMessage', function(name, body)
    if source ~= 65535 or type(name) ~= 'string' or type(body) ~= 'string' then return end
    local label = ('%s · %s'):format(t('ui_staff_chat'), name)
    local chat = GetResourceState('chat') == 'started'
    if chat then TriggerEvent('chat:addMessage', { args = { label, body } }) end
    if panelOpen or not chat then nui('toast', { kind = 'info', text = label .. ': ' .. body, outside = not chat }) end
  end)
  ticketResult('staff_suite:playerProfileResult')
  ticketResult('staff_suite:playerProfileNoteResult')
  ticketResult('staff_suite:onlinePlayersResult')
  ticketResult('staff_suite:staffWeeklyResult')
  ticketResult('staff_suite:emergencyFreezeResult')
  ticketRequest('emergency_freeze', 'staff_suite:emergencyFreezeResult', 'emergency_failed', function(d, req)
    TriggerServerEvent('staff_suite:emergencyFreeze', req, d.enabled, d.reason)
  end)
  ticketRequest('staff_weekly', 'staff_suite:staffWeeklyResult', 'staff_weekly_failed', function(d, req)
    TriggerServerEvent('staff_suite:staffWeekly', req, d.export == true)
  end)
  ticketRequest('online_players', 'staff_suite:onlinePlayersResult', 'online_players_failed', function(_, req)
    TriggerServerEvent('staff_suite:onlinePlayers', req)
  end)
  ticketRequest('player_profile', 'staff_suite:playerProfileResult', 'player_profile_failed', function(d, req)
    TriggerServerEvent('staff_suite:playerProfile', d.id, req)
  end)
  ticketRequest('player_profile_note', 'staff_suite:playerProfileNoteResult', 'player_profile_note_failed', function(d, req)
    TriggerServerEvent('staff_suite:playerProfileNote', d.id, req, d.body)
  end)
  on('ticket_rate', function(d)
    TriggerServerEvent('staff_suite:ticketRate', d.id, d.score)
    if not panelOpen then SetNuiFocus(false, false) end
  end)
  on('rate_dismiss', function()
    if not panelOpen then SetNuiFocus(false, false) end
  end)
  on('ticket_evidence', function(d) TriggerServerEvent('staff_suite:ticketEvidence', d.id) end)
  on('evidence_get', function(d) TriggerServerEvent('staff_suite:evidenceGet', d.id, d.n) end)
  on('ticket_transfer', ticketAction('transfer'))
  on('mod_action', function(d)
    TriggerServerEvent('staff_suite:modAction', d.action, d.target, d.reason, d.duration, d.template)
  end)
  on('goto_waypoint', function() TriggerServerEvent('staff_suite:waypoint') end)
  on('staff_mode', function(d) TriggerServerEvent('staff_suite:staffMode', d.mode) end)
  on('duty_toggle', function()
    ExecuteCommand(Config.Commands.duty)
    refreshSoon()
  end)
end

-- ===== server -> NUI =====
RegisterNetEvent('staff_suite:state', function(state)
  state = state or {}
  local initDirty = false
  if state.transferTargets then transferTargets = state.transferTargets; initDirty = true end
  if state.exportStatus then exportStatus = state.exportStatus; initDirty = true end
  if state.evidenceEnabled ~= nil then evidenceEnabled = state.evidenceEnabled == true; initDirty = true end
  if state.sanctionTemplates then sanctionTemplates = state.sanctionTemplates; initDirty = true end
  if state.warnEscalation ~= nil then warnEscalation = state.warnEscalation or nil; initDirty = true end
  if state.player then
    playerInfo = state.player
    rank = state.player.rank or rank
    initDirty = true
  elseif state.rank and state.rank ~= rank then
    rank = state.rank
    initDirty = true
  end
  if initDirty then sendInit() end
  if state.alerts then alertsCache = state.alerts end
  if state.tickets or state.ticket then
    if state.tickets then
      ticketsById = {}
      for _, ticket in ipairs(ticketList(state.tickets)) do ticketsById[ticket.id] = ticket end
    end
    if state.ticket then ticketsById[state.ticket.id] = state.ticket end
    ticketsCache = ticketList(ticketsById)
    nui('tickets', { tickets = ticketsCache })
  end
  if state.myTickets then nui('myTickets', { tickets = ticketList(state.myTickets) }) end
  if not lite and state.frozenPlayers then nui('frozenPlayers', state.frozenPlayers) end
  if state.audit then
    local v = state.verify
    nui('audit', {
      entries = auditList(state.audit),
      verify = v and verifyResult(v[1], v[2]) or nil,
    })
  end
  if state.duty or state.dutySelf then
    if state.duty then dutyCache = state.duty end
    local selfOn = state.dutySelf and state.dutySelf.on_duty == true
    if not state.dutySelf then
      local me = playerInfo and playerInfo.identifier or GetPlayerName(PlayerId())
      for _, s in ipairs(dutyCache) do
        if s.actor == me then selfOn = s.on_duty == true end
      end
    end
    nui('duty', { self = { on_duty = selfOn }, staff = dutyCache })
  end
  if not lite then sendDashboard() end
  if pendingLiteOpen and state.player then
    local view = pendingLiteOpen.view
    pendingLiteOpen = nil
    showPanel(view)
  end
end)

if lite then
  RegisterNetEvent('staff_suite:openPanel', function(view)
    if source == 65535 then openPanel(view) end
  end)
else
  RegisterNetEvent('staff_suite:freezeState', function(state)
    if source == 65535 and type(state) == 'table' then nui('freezeState', state) end
  end)
end

RegisterNetEvent('staff_suite:auditResult', function(res)
  res = res or {}
  nui('audit', { verify = verifyResult(res.ok, res.at) })
end)

-- Avisos: con el panel abierto van como toast; cerrado, como aviso NUI sin foco (o al chat si está desactivado).
local NOTICE_KINDS = { info = true, reply = true, warn = true, announce = true, report = true }
local function notice(text, opts)
  local cfg = Config.Notifications or {}
  opts = type(opts) == 'table' and opts or {}
  local kind = NOTICE_KINDS[opts.kind] and opts.kind or 'info'
  if kind == 'report' and cfg.staff_reports == false then return end
  text = tostring(text)
  if panelOpen then
    nui('toast', { kind = 'info', text = opts.title and (opts.title .. ' · ' .. text) or text })
  elseif cfg.enabled == false then
    TriggerEvent('chat:addMessage', { args = { opts.title or t('notify_title'), text } })
  else
    if not initSent then sendInit() end
    nui('notice', { kind = kind, text = text, priority = opts.priority, duration = cfg.duration or 6000, max = cfg.max or 3 })
  end
  local sound = cfg.sound
  if kind == 'report' and type(sound) == 'table' and sound.name then
    PlaySoundFrontend(-1, sound.name, sound.set or 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
  end
end

RegisterNetEvent('staff_suite:notify', notice)

if not lite then
  RegisterNetEvent('staff_suite:announcement', function(message)
    if source ~= 65535 or type(message) ~= 'string' then return end
    local title = strings(uiLocale).announcement_title or t('announcement_title')
    notice(message, { kind = 'announce', title = title })
  end)

  -- Valoración del reporter al resolverse su ticket (el panel puede estar cerrado).
  RegisterNetEvent('staff_suite:ratePrompt', function(p)
    if type(p) ~= 'table' or not p.id then return end
    sendInit()
    SetNuiFocus(true, true)
    nui('rate', { id = p.id })
  end)

  RegisterNetEvent('staff_suite:evidence', function(p)
    if type(p) == 'table' then nui('evidence', p) end
  end)
end

-- Nunca dejar el foco NUI tomado si el recurso se detiene con el panel abierto.
AddEventHandler('onClientResourceStop', function(resource)
  if resource == GetCurrentResourceName() then SetNuiFocus(false, false) end
end)
