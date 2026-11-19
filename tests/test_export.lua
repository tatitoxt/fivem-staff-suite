local T = {}

local function load(env)
  env = setmetatable(env, { __index = _G })
  env.StaffSuiteTranslate = env.StaffSuiteTranslate or function(key, vars)
    return key .. (vars and vars.seq and (':' .. vars.seq) or '')
  end
  env.GetCurrentResourceName = function() return 'staff_suite' end
  env.json = { encode = function(v) return v.content end }
  return assert(loadfile('server/export.lua', 't', env))()
end

local function entry(seq)
  return { seq = seq, hash = string.rep('a', 64), prev_hash = string.rep('b', 64), action = 'x' }
end

function T.test_anchor_appends_without_rereading_log()
  local dir = os.tmpname()
  os.remove(dir)
  assert(os.execute('mkdir -p ' .. dir))
  local export = load({
    GetResourcePath = function() return dir end,
    LoadResourceFile = function() error('no debe releer el log') end,
    SaveResourceFile = function() error('no debe reescribir el log') end,
  })
  export.anchor(entry(20), { file = true })
  export.anchor(entry(40), { file = true })
  local f = assert(io.open(dir .. '/audit_export.log', 'r'))
  local text = f:read('a')
  f:close()
  os.remove(dir .. '/audit_export.log')
  os.remove(dir)
  assert(text == '20|' .. entry(20).hash .. '|' .. entry(20).prev_hash .. '|x\n40|' .. entry(40).hash .. '|' .. entry(40).prev_hash .. '|x\n')
end

function T.test_anchor_falls_back_to_rewrite_without_resource_path()
  local files = { ['audit_export.log'] = '1|h|p|a\n' }
  local export = load({
    LoadResourceFile = function(_, path) return files[path] end,
    SaveResourceFile = function(_, path, data, size) assert(#data == size); files[path] = data; return 1 end,
  })
  export.anchor(entry(2), { file = true })
  assert(files['audit_export.log']:match('^1|h|p|a\n2|'))
end

local function webhookEnv()
  local env = { requests = {}, timers = {}, printed = {} }
  env.PerformHttpRequest = function(url, cb, method, body)
    env.requests[#env.requests + 1] = { url = url, cb = cb, method = method, body = body }
  end
  env.SetTimeout = function(ms, fn) env.timers[#env.timers + 1] = { ms = ms, fn = fn } end
  env.print = function(msg) env.printed[#env.printed + 1] = msg end
  return env
end

function T.test_webhook_retries_with_bounded_backoff_without_blocking()
  local env = webhookEnv()
  local export = load(env)
  local cfg = { webhook = 'https://hook', webhook_retries = 4, webhook_backoff_ms = 1000, webhook_backoff_max_ms = 3000 }
  export.anchor(entry(20), cfg)
  assert(#env.requests == 1 and env.requests[1].method == 'POST' and env.requests[1].body == 'export_anchor:20')
  assert(#env.timers == 0, 'anchor vuelve sin esperar la respuesta')
  env.requests[1].cb(0)
  assert(env.timers[1].ms == 1000)
  env.timers[1].fn()
  env.requests[2].cb(429, '', { ['Retry-After'] = '2' })
  assert(env.timers[2].ms == 2000)
  env.timers[2].fn()
  env.requests[3].cb(502)
  assert(env.timers[3].ms == 3000, 'el backoff respeta el tope')
  env.timers[3].fn()
  env.requests[4].cb(503)
  assert(#env.timers == 3 and #env.requests == 4, 'corta al llegar a webhook_retries')
  assert(env.printed[1] == 'console_export_webhook_failed:20')

  export.anchor(entry(40), cfg)
  env.requests[5].cb(204)
  export.anchor(entry(60), cfg)
  env.requests[6].cb(400)
  assert(#env.timers == 3 and #env.printed == 2, '2xx termina y 4xx no se reintenta')
end

return T
