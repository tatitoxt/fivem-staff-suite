-- client/main.lua — Puente NUI (React, ui/dist) <-> server. Contrato: NUI_SPEC.md.
-- Traduce los eventos del adapter (staff_suite:state/auditResult/notify) a los
-- mensajes tipados de la NUI (init/audit/tickets/dashboard/duty/toast).
-- luacheck: globals GetResourceMetadata GetPlayerName PlayerId SetTimeout GetCloudTimeAsInt ExecuteCommand
local t = StaffSuiteTranslate
local lite = Config.Edition == 'lite'
local panelOpen = false
local uiLocale = Config.Locale or 'es'
local rank = lite and 'player' or 'helper'
local ticketsCache = {}
local dutyCache = {}
local alertsCache = {}
local playerInfo = nil
local transferTargets = nil
local exportStatus = nil
local evidenceEnabled = false

local function strings(lang)
  return (Locale and (Locale[lang] or Locale.es)) or {}
end

local function nui(kind, payload)
  SendNUIMessage({ type = kind, payload = payload })
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
      core_url = Config.CoreUrl,
      priorities = Config.Priorities,
      require_reason = Config.Moderation and Config.Moderation.require_reason ~= false,
      persistence = Config.Persistence,
      export = (exportStatus and {
        webhook = exportStatus.webhook == true,
        file = exportStatus.file == true,
        anchor_every = exportStatus.anchor_every,
      }) or (Config.Export and {
        webhook = (Config.Export.webhook or '') ~= '',
        file = Config.Export.file == true,
        anchor_every = Config.Export.anchor_every,
      }) or nil,
      transfer_targets = transferTargets,
      canned = not lite and cannedList() or nil,
      evidence = not lite and evidenceEnabled,
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

local function openPanel(view)
  panelOpen = true
  SetNuiFocus(true, true)
  sendInit()
  TriggerServerEvent('staff_suite:getState')
  nui('open', { view = view })
end

local function closePanel()
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
on('ticket_create', function(d)
  TriggerServerEvent('staff_suite:ticketCreate', d.category or 'other', d.priority or 'normal', tostring(d.body or ''))
  refreshSoon()
end)
if not lite then
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
  on('ticket_message', function(d)
    TriggerServerEvent('staff_suite:ticketMessage', d.id, d.body, d.internal == true)
  end)
  on('mod_action', function(d)
    TriggerServerEvent('staff_suite:modAction', d.action, d.target, d.reason, d.duration)
  end)
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
  if state.tickets then
    ticketsCache = ticketList(state.tickets)
    nui('tickets', { tickets = ticketsCache })
  end
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
end)

if lite then
  RegisterNetEvent('staff_suite:openPanel', function(view)
    if source == 65535 then openPanel(view) end
  end)
end

RegisterNetEvent('staff_suite:auditResult', function(res)
  res = res or {}
  nui('audit', { verify = verifyResult(res.ok, res.at) })
end)

RegisterNetEvent('staff_suite:notify', function(msg)
  if panelOpen then
    nui('toast', { kind = 'info', text = tostring(msg) })
  else
    TriggerEvent('chat:addMessage', { args = { t('notify_title'), msg } })
  end
end)

if not lite then
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
