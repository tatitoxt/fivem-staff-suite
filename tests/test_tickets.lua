-- tests/test_tickets.lua — state machine de reports.
local tickets = require("core.tickets")
local T = {}

local function store_with_ticket()
  local s = tickets.new_store()
  local t = tickets.create(s, { reporter = "license:p1", category = "bug", priority = "high", description = "x", ts = 100 })
  return s, t
end

function T.test_create()
  local s, t = store_with_ticket()
  assert(t.id == 1 and t.state == "open", "create open id 1")
  assert(t.priority == "high", "preserves the requested priority")
  assert(s.next_id == 2, "next_id increments")
end

function T.test_happy_path()
  local s, t = store_with_ticket()
  local _, e1 = tickets.transition(s, 1, "claim", "license:staff1", { ts = 101 })
  assert(t.state == "claimed" and t.claimer == "license:staff1", "claimed")
  assert(e1.action == "ticket_claim" and e1.from == "open" and e1.to == "claimed", "claim event")
  tickets.transition(s, 1, "start", "license:staff1", { ts = 102 })
  assert(t.state == "in_progress", "in_progress")
  tickets.transition(s, 1, "resolve", "license:staff1", { resolution = "fixed", ts = 103 })
  assert(t.state == "resolved" and t.resolution == "fixed", "resolved")
  tickets.transition(s, 1, "close", "license:staff1", { ts = 104 })
  assert(t.state == "closed", "closed")
end

function T.test_invalid_transition()
  local s = store_with_ticket()
  local _, err = tickets.transition(s, 1, "resolve", "license:staff1")
  assert(err and err:find("invalid_transition"), "cannot resolve from open")
end

function T.test_double_claim()
  local s = store_with_ticket()
  tickets.transition(s, 1, "claim", "license:staff1")
  local _, err = tickets.transition(s, 1, "claim", "license:staff2")
  assert(err == "already_claimed", "second staff cannot claim")
end

function T.test_transfer()
  local s = store_with_ticket()
  tickets.transition(s, 1, "claim", "license:staff1")
  local t, e = tickets.transition(s, 1, "transfer", "license:staff2", { to = "license:staff3" })
  assert(t.claimer == "license:staff3", "transfer assigns the recipient")
  assert(e.actor == "license:staff2" and e.assigned_to == "license:staff3", "audit distinguishes sender and recipient")
  assert(not tickets.transition(s, 1, "transfer", "license:staff2", { to = " " }))
  assert(t.claimer == "license:staff3", "invalid recipient leaves the assignment unchanged")
end

function T.test_reopen()
  local s = store_with_ticket()
  tickets.transition(s, 1, "claim", "license:s")
  tickets.transition(s, 1, "resolve", "license:s", { resolution = "x" })
  tickets.transition(s, 1, "reopen", "license:p1")
  local t = s.tickets[1]
  assert(t.state == "reopened" and t.claimer == nil and t.resolution == nil, "reopen clears")
end

function T.test_messages_and_rating()
  local s = store_with_ticket()
  tickets.add_message(s, 1, "license:p1", "hola", false, 101)
  tickets.add_message(s, 1, "license:s", "nota interna", true, 102)
  assert(#s.tickets[1].messages == 2, "2 messages")
  assert(s.tickets[1].messages[2].internal, "internal flag")
  tickets.transition(s, 1, "claim", "license:s")
  tickets.transition(s, 1, "resolve", "license:s", { resolution = "ok" })
  local rt = tickets.rate(s, 1, "license:p1", 5, 105)
  assert(rt and s.tickets[1].rating == 5, "rating ok")
  local _, err2 = tickets.rate(s, 1, "license:other", 3, 106)
  assert(err2 == "not_reporter", "only reporter rates")
end

function T.test_first_response_resolver_and_single_rating()
  local s = tickets.new_store()
  tickets.create(s, { reporter = "license:p1", ts = 100 })
  tickets.add_message(s, 1, "license:p1", "sigo esperando", false, 110)
  tickets.add_message(s, 1, "license:s1", "nota", true, 120)
  assert(s.tickets[1].first_response_ts == nil, "ni el reporter ni las notas internas cuentan")
  tickets.add_message(s, 1, "license:s1", "hola", false, 130)
  tickets.add_message(s, 1, "license:s1", "otra", false, 140)
  assert(s.tickets[1].first_response_ts == 130)
  tickets.transition(s, 1, "claim", "license:s1", { ts = 150 })
  tickets.transition(s, 1, "resolve", "license:s1", { ts = 160, resolution = "ok" })
  assert(s.tickets[1].resolved_by == "license:s1")
  assert(tickets.rate(s, 1, "license:p1", 4, 170))
  local _, err = tickets.rate(s, 1, "license:p1", 5, 171)
  assert(err == "already_rated" and s.tickets[1].rating == 4)
end

return T
