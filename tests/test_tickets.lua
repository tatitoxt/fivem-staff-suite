-- tests/test_tickets.lua — state machine + claim exclusivo + rating.
local tickets = require("core.tickets")
local T = {}

local function mk() return tickets.new("t1","license:player1","bug","high",1000) end

function T.test_lifecycle()
  local t = mk()
  assert(t.state == "open")
  assert(tickets.claim(t,"license:mod1",1001).to == "claimed")
  assert(tickets.start(t,"license:mod1",1002).to == "in_progress")
  assert(tickets.resolve(t,"license:mod1",1003,"fixed").to == "resolved")
  assert(tickets.close(t,"license:mod1",1004).to == "closed")
  assert(t.resolution == "fixed")
end

function T.test_invalid_transition()
  local t = mk()
  local ev, err = tickets.resolve(t,"license:mod1",1001,"x")  -- open -> resolve inválido
  assert(ev == nil and err, "resolve from open must fail")
end

function T.test_claim_exclusive()
  local t = mk()
  tickets.claim(t,"license:mod1",1001)
  assert(not tickets.can_claim(t,"license:mod2"), "claimed ticket not claimable")
  local ev, err = tickets.claim(t,"license:mod2",1002)
  assert(ev == nil, "double claim must fail")
end

function T.test_transfer()
  local t = mk()
  tickets.claim(t,"license:mod1",1001)
  local ev = tickets.transfer(t,"license:mod1",1002,"license:mod2")
  assert(ev.to == "claimed" and t.claimer == "license:mod2", "transfer reassigns")
end

function T.test_reopen()
  local t = mk()
  tickets.claim(t,"m",1001); tickets.resolve(t,"m",1002,"x"); tickets.close(t,"m",1003)
  local ev = tickets.reopen(t,"license:player1",1004)
  assert(ev.to == "reopened" and t.claimer == nil, "reopen clears claimer")
end

function T.test_messages_and_rating()
  local t = mk()
  tickets.add_message(t,"license:player1","hay un bug",1001,false)
  tickets.add_message(t,"license:mod1","lo veo",1002,true)  -- nota interna
  assert(#t.messages == 2 and t.messages[2].internal)
  tickets.claim(t,"m",1003); tickets.resolve(t,"m",1004,"ok")
  assert(tickets.rate(t,"license:player1",5,1005).stars == 5)
  local _, err = tickets.rate(t,"license:player1",9,1006)
  assert(err, "rating > 5 must fail")
end

return T
