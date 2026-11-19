-- core/tickets.lua — State machine de reports/tickets. Agnóstico (D019).
-- Cada transición devuelve un evento para que el adapter lo audite.
local M = {}

M.STATES = { OPEN="open", CLAIMED="claimed", IN_PROGRESS="in_progress",
             RESOLVED="resolved", CLOSED="closed", REOPENED="reopened" }
M.PRIORITIES = { LOW="low", NORMAL="normal", HIGH="high", URGENT="urgent" }

-- transiciones válidas: estado -> {acción -> estado destino}
local TRANSITIONS = {
  open        = { claim="claimed", close="closed" },
  claimed     = { start="in_progress", unclaim="open", resolve="resolved", transfer="claimed" },
  in_progress = { resolve="resolved", unclaim="open", transfer="claimed" },
  resolved    = { close="closed", reopen="reopened" },
  closed      = { reopen="reopened" },
  reopened    = { claim="claimed", close="closed" },
}

function M.new(id, reporter, category, priority, ts)
  return {
    id = id, reporter = reporter, category = category or "general",
    priority = priority or M.PRIORITIES.NORMAL,
    state = M.STATES.OPEN, claimer = nil,
    created_ts = ts, updated_ts = ts,
    messages = {}, resolution = nil, rating = nil,
  }
end

local function transition(t, action, actor, ts, extra)
  local allowed = TRANSITIONS[t.state]
  if not allowed or not allowed[action] then
    return nil, ("invalid transition '%s' from state '%s'"):format(action, t.state)
  end
  local from = t.state
  t.state = allowed[action]
  t.updated_ts = ts
  if action == "claim" then t.claimer = actor
  elseif action == "unclaim" then t.claimer = nil
  elseif action == "transfer" then t.claimer = extra and extra.to or actor
  elseif action == "resolve" then t.resolution = extra and extra.resolution or ""
  elseif action == "reopen" then t.claimer = nil; t.resolution = nil
  end
  return { event="ticket."..action, ticket=t.id, actor=actor, from=from, to=t.state, ts=ts }
end

function M.claim(t, actor, ts) return transition(t, "claim", actor, ts) end
function M.unclaim(t, actor, ts) return transition(t, "unclaim", actor, ts) end
function M.start(t, actor, ts) return transition(t, "start", actor, ts) end
function M.transfer(t, actor, ts, to) return transition(t, "transfer", actor, ts, {to=to}) end
function M.resolve(t, actor, ts, resolution) return transition(t, "resolve", actor, ts, {resolution=resolution}) end
function M.close(t, actor, ts) return transition(t, "close", actor, ts) end
function M.reopen(t, actor, ts) return transition(t, "reopen", actor, ts) end

-- claim exclusivo: no se puede reclamar un ticket ya reclamado por otro
function M.can_claim(t, actor)
  return (t.state == M.STATES.OPEN or t.state == M.STATES.REOPENED)
end

function M.add_message(t, author, body, ts, internal)
  local msg = { author=author, body=body, ts=ts, internal=internal or false }
  t.messages[#t.messages+1] = msg
  t.updated_ts = ts
  return { event="ticket.message", ticket=t.id, actor=author, ts=ts, internal=msg.internal }
end

function M.rate(t, reporter, stars, ts)
  if t.state ~= M.STATES.RESOLVED and t.state ~= M.STATES.CLOSED then
    return nil, "can only rate resolved/closed tickets"
  end
  if stars < 1 or stars > 5 then return nil, "rating must be 1..5" end
  t.rating = stars
  return { event="ticket.rating", ticket=t.id, actor=reporter, stars=stars, ts=ts }
end

return M
