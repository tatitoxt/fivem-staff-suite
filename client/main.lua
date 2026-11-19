-- client/main.lua — Puente NUI (React, ui/dist) <-> server. Contrato: NUI_SPEC.md.
-- Traduce los eventos del adapter (staff_suite:state/auditResult/notify) a los
-- mensajes tipados de la NUI (init/audit/tickets/dashboard/duty/toast).
local t = StaffSuiteTranslate
local panelOpen = false
local uiLocale = Config.Locale or 'es'
local rank = 'helper'
local ticketsCache = {}
local dutyCache = {}

local function strings(lang)
  return (Locale and (Locale[lang] or Locale.es)) or {}
end

local function nui(kind, payload)
  SendNUIMessage({ type = kind, payload = payload })
end

local function sendInit()
  local locales = {}
  for code in pairs(Locale or {}) do locales[#locales + 1] = code end
  table.sort(locales)
  nui('init', {
    locale = uiLocale,
    strings = strings(uiLocale),
    version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '',
    player = { name = GetPlayerName(PlayerId()), rank = rank },
    config = {
      panel_key = Config.PanelKey or 'F6',
      locales = locales,
      categories = Config.Categories,
      priorities = Config.Priorities,
      require_reason = Config.Moderation and Config.Moderation.require_reason ~= false,
      persistence = Config.Persistence,
      export = Config.Export and {
        webhook = (Config.Export.webhook or '') ~= '',
        file = Config.Export.file == true,
        anchor_every = Config.Export.anchor_every or 0,
      } or nil,
    },
  })
end

local function ticketList(map)
  local list = {}
  for _, t in pairs(map or {}) do
    if type(t) == 'table' and t.id then list[#list + 1] = t end
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
  for _, t in ipairs(ticketsCache) do
    if t.state == 'resolved' or t.state == 'closed' then resolved = resolved + 1 else open = open + 1 end
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
    alerts = {},
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
on('ticket_transfer', ticketAction('transfer'))
on('ticket_resolve', ticketAction('resolve'))
on('ticket_close', ticketAction('close'))
on('ticket_reopen', ticketAction('reopen'))
on('ticket_message', function(d)
  TriggerServerEvent('staff_suite:ticketMessage', d.id, d.body, d.internal == true)
end)
on('ticket_create', function(d)
  local body = tostring(d.body or ''):gsub('[\r\n]+', ' ')
  ExecuteCommand(('%s %s %s'):format(Config.Commands.report, d.category or 'other', body))
  refreshSoon()
end)
on('mod_action', function(d)
  TriggerServerEvent('staff_suite:modAction', d.action, d.target, d.reason)
end)
on('duty_toggle', function()
  ExecuteCommand(Config.Commands.duty)
  refreshSoon()
end)

-- ===== server -> NUI =====
RegisterNetEvent('staff_suite:state', function(state)
  state = state or {}
  if state.rank and state.rank ~= rank then rank = state.rank; sendInit() end
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
  if state.duty then
    dutyCache = state.duty
    local me, selfOn = GetPlayerName(PlayerId()), false
    for _, s in ipairs(dutyCache) do
      if s.actor == me then selfOn = s.on_duty == true end
    end
    nui('duty', { self = { on_duty = selfOn }, staff = dutyCache })
  end
  sendDashboard()
end)

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

RegisterNetEvent('staff_suite:tp', function(coords)
  local ped = PlayerPedId()
  SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
end)
