-- core/tickets.lua — State machine de reports/tickets. Agnóstico (D019).
-- Cada transición devuelve un evento para que el adapter lo encadene en auditoría.
local M = {}

M.STATES = { "open", "claimed", "in_progress", "resolved", "closed", "reopened" }

-- transiciones válidas: estado -> { acción -> estado destino }
local TRANSITIONS = {
  open        = { claim = "claimed", close = "closed" },
  claimed     = { start = "in_progress", unclaim = "open", transfer = "claimed", resolve = "resolved", close = "closed" },
  in_progress = { resolve = "resolved", unclaim = "claimed", close = "closed" },
  resolved    = { close = "closed", reopen = "reopened" },
  closed      = { reopen = "reopened" },
  reopened    = { claim = "claimed", close = "closed" },
}

function M.new_store()
  return { tickets = {}, next_id = 1 }
end

-- data: {reporter, category, priority, description, ts}
function M.create(store, data)
  local id = store.next_id
  store.next_id = id + 1
  local t = {
    id = id,
    reporter = data.reporter,
    category = data.category or "general",
    priority = data.priority or "normal",
    description = data.description or "",
    state = "open",
    claimer = nil,
    messages = {},
    created_ts = data.ts,
    updated_ts = data.ts,
    resolution = nil,
    rating = nil,
  }
  store.tickets[id] = t
  return t, { action = "ticket_create", ticket = id, actor = data.reporter, target = data.reporter }
end

-- Transición validada. Devuelve ticket, event o nil, error.
function M.transition(store, id, action, actor, extra)
  local t = store.tickets[id]
  if not t then return nil, "ticket_not_found" end
  -- conflicto de claim primero (mensaje claro aunque el estado no admita claim)
  if action == "claim" and t.claimer and t.claimer ~= actor then
    return nil, "already_claimed"
  end
  local allowed = TRANSITIONS[t.state]
  if not allowed or not allowed[action] then
    return nil, "invalid_transition:" .. t.state .. "->" .. action
  end
  local assignee
  if action == "transfer" then
    assignee = extra and extra.to
    if assignee == nil then assignee = actor end -- Compatibilidad con los exports existentes.
    if type(assignee) ~= "string" or not assignee:match("%S") then return nil, "invalid_transition" end
  end
  local from = t.state
  t.state = allowed[action]
  if action == "claim" then t.claimer = actor end
  if action == "transfer" then t.claimer = assignee end
  if action == "unclaim" then t.claimer = nil end
  if action == "resolve" then t.resolution = (extra and extra.resolution) or ""; t.resolved_by = actor end
  if action == "reopen" then t.claimer = nil; t.resolution = nil; t.resolved_by = nil end
  t.updated_ts = (extra and extra.ts) or t.updated_ts
  return t, {
    action = "ticket_" .. action, ticket = id, actor = actor,
    from = from, to = t.state, assigned_to = assignee, reason = (extra and extra.reason) or "",
  }
end

function M.add_message(store, id, author, body, internal, ts)
  local t = store.tickets[id]
  if not t then return nil, "ticket_not_found" end
  local msg = { author = author, body = body, internal = internal or false, ts = ts }
  t.messages[#t.messages + 1] = msg
  if not msg.internal and author ~= t.reporter and not t.first_response_ts then t.first_response_ts = ts end
  t.updated_ts = ts or t.updated_ts
  return msg, { action = "ticket_message", ticket = id, actor = author, internal = msg.internal }
end

function M.rate(store, id, reporter, score, ts)
  local t = store.tickets[id]
  if not t then return nil, "ticket_not_found" end
  if t.reporter ~= reporter then return nil, "not_reporter" end
  if t.state ~= "resolved" and t.state ~= "closed" then return nil, "not_resolved" end
  if score < 1 or score > 5 then return nil, "invalid_score" end
  if t.rating then return nil, "already_rated" end
  t.rating = score
  return t, { action = "ticket_rate", ticket = id, actor = reporter, score = score }
end

if StaffSuiteModules then StaffSuiteModules['core.tickets'] = M end
return M
