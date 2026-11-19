-- tests/test_duty.lua — turnos + analytics.
local duty = require("core.duty")
local T = {}

function T.test_clock_in_out()
  local reg = duty.new_registry()
  assert(duty.clock_in(reg,"mod1",1000).event == "duty.in")
  local _, err = duty.clock_in(reg,"mod1",1001)
  assert(err, "double clock-in fails")
  local ev = duty.clock_out(reg,"mod1",4600)  -- 3600s = 1h
  assert(ev.event == "duty.out")
  local snap = duty.snapshot(reg, 5000)
  assert(math.abs(snap[1].duty_hours - 1.0) < 0.001, "1 hour tracked")
end

function T.test_live_session()
  local reg = duty.new_registry()
  duty.clock_in(reg,"mod1",1000)
  local snap = duty.snapshot(reg, 2800)  -- 1800s live = 0.5h
  assert(snap[1].on_duty and math.abs(snap[1].duty_hours - 0.5) < 0.001)
end

function T.test_analytics()
  local reg = duty.new_registry()
  duty.record_resolved(reg,"mod1",120)
  duty.record_resolved(reg,"mod1",60)
  duty.record_rating(reg,"mod1",5)
  duty.record_rating(reg,"mod1",3)
  duty.record_resolved(reg,"mod2",300)
  local snap = duty.snapshot(reg, 1000)
  assert(snap[1].actor == "mod1" and snap[1].resolved == 2, "sorted by resolved")
  assert(snap[1].avg_response == 90, "avg response (120+60)/2")
  assert(snap[1].avg_rating == 4, "avg rating (5+3)/2")
end

return T
