-- core/duty.lua — Tracking de turnos + analytics de staff. Agnóstico (D019).
local M = {}

function M.new_registry()
  return { staff = {} }  -- staff[actor] = {on_duty, since, total_seconds, sessions, resolved, response_sum, response_n, ratings_sum, ratings_n}
end

local function ensure(reg, actor)
  if not reg.staff[actor] then
    reg.staff[actor] = { on_duty=false, since=nil, total_seconds=0, sessions=0,
                         resolved=0, response_sum=0, response_n=0, ratings_sum=0, ratings_n=0 }
  end
  return reg.staff[actor]
end

function M.clock_in(reg, actor, ts)
  local s = ensure(reg, actor)
  if s.on_duty then return nil, "already on duty" end
  s.on_duty = true; s.since = ts; s.sessions = s.sessions + 1
  return { event="duty.in", actor=actor, ts=ts }
end

function M.clock_out(reg, actor, ts)
  local s = ensure(reg, actor)
  if not s.on_duty then return nil, "not on duty" end
  s.total_seconds = s.total_seconds + (ts - s.since)
  s.on_duty = false; s.since = nil
  return { event="duty.out", actor=actor, ts=ts, seconds=(ts - (s.since or ts)) }
end

function M.record_resolved(reg, actor, response_seconds)
  local s = ensure(reg, actor)
  s.resolved = s.resolved + 1
  if response_seconds then s.response_sum = s.response_sum + response_seconds; s.response_n = s.response_n + 1 end
end

function M.record_rating(reg, actor, stars)
  local s = ensure(reg, actor)
  s.ratings_sum = s.ratings_sum + stars; s.ratings_n = s.ratings_n + 1
end

-- snapshot de analytics (para el dashboard del dueño)
function M.snapshot(reg, now)
  local out = {}
  for actor, s in pairs(reg.staff) do
    local live = s.total_seconds + (s.on_duty and (now - s.since) or 0)
    out[#out+1] = {
      actor = actor, on_duty = s.on_duty,
      duty_hours = live / 3600, sessions = s.sessions, resolved = s.resolved,
      avg_response = s.response_n > 0 and (s.response_sum / s.response_n) or nil,
      avg_rating = s.ratings_n > 0 and (s.ratings_sum / s.ratings_n) or nil,
    }
  end
  table.sort(out, function(a,b) return a.resolved > b.resolved end)
  return out
end

return M
