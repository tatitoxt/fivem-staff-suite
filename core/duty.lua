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
  local seconds = ts - s.since
  s.total_seconds = s.total_seconds + seconds
  s.on_duty = false; s.since = nil
  return { event="duty.out", actor=actor, ts=ts, seconds=seconds }
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

function M.weekly(entries, now, decode)
  local from = now - 7 * 86400
  local byActor, shifts, rows = {}, {}, {}
  local function row(actor)
    if not byActor[actor] then
      byActor[actor] = { actor = actor, duty_seconds = 0, sessions = 0, resolved = 0, ratings = 0, rating_sum = 0 }
      rows[#rows + 1] = byActor[actor]
    end
    return byActor[actor]
  end
  local function addShift(actor, start, finish)
    if start and finish > math.max(start, from) then
      local staff = row(actor)
      staff.duty_seconds = staff.duty_seconds + finish - math.max(start, from)
    end
  end
  for _, entry in ipairs(entries) do
    local actor, action, ts = entry.actor, entry.action, entry.ts
    if ts <= now then
      if action == 'duty.in' then
        shifts[actor] = ts
        if ts >= from then row(actor).sessions = row(actor).sessions + 1 end
      elseif action == 'duty.out' then
        addShift(actor, shifts[actor], ts)
        shifts[actor] = nil
      elseif ts >= from and action == 'ticket_resolve' then
        row(actor).resolved = row(actor).resolved + 1
      elseif ts >= from and action == 'ticket_rate' then
        local ok, payload = pcall(decode, entry.payload)
        if ok and type(payload) == 'table' and type(payload.staff) == 'string' and
          type(payload.score) == 'number' and payload.score >= 1 and payload.score <= 5 then
          local staff = row(payload.staff)
          staff.ratings = staff.ratings + 1
          staff.rating_sum = staff.rating_sum + payload.score
        end
      end
    end
  end
  for actor, start in pairs(shifts) do addShift(actor, start, now) end
  table.sort(rows, function(a, b)
    if a.resolved ~= b.resolved then return a.resolved > b.resolved end
    return a.actor < b.actor
  end)
  for _, staff in ipairs(rows) do
    staff.avg_rating = staff.ratings > 0 and staff.rating_sum / staff.ratings or nil
    staff.rating_sum = nil
  end
  return { from = from, to = now, staff = rows }
end

if StaffSuiteModules then StaffSuiteModules['core.duty'] = M end
return M
