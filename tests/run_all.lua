-- tests/run_all.lua — runner de tests Lua sin FiveM.
-- Uso: lua5.4 tests/run_all.lua (desde la raíz del repo)
package.path = "./?.lua;" .. package.path

local modules = {
  "tests.test_sha256",
  "tests.test_audit_chain",
  "tests.test_tickets",
  "tests.test_permissions",
  "tests.test_duty",
  "tests.test_bridges",
}
local pass, fail = 0, 0
local failed = {}

for _, modname in ipairs(modules) do
  local ok, T = pcall(require, modname)
  if not ok then
    print("LOAD FAIL " .. modname .. ": " .. tostring(T)); fail = fail + 1
  else
    local names = {}
    for k in pairs(T) do names[#names+1] = k end
    table.sort(names)
    for _, name in ipairs(names) do
      local ok2, err = pcall(T[name])
      if ok2 then
        pass = pass + 1
        print("  ok   " .. modname .. "." .. name)
      else
        fail = fail + 1
        failed[#failed+1] = modname .. "." .. name .. " -> " .. tostring(err)
        print("  FAIL " .. modname .. "." .. name .. " -> " .. tostring(err))
      end
    end
  end
end

print(string.format("\n=== %d passed, %d failed ===", pass, fail))
if fail > 0 then
  print("Failures:"); for _, f in ipairs(failed) do print("  " .. f) end
  os.exit(1)
end
