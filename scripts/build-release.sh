#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$root_dir"

# Reutilizar la lista de scripts que carga FiveM y la versión del resource.
manifest_data=$(lua5.4 - <<'LUA'
local version
local paths = { 'fxmanifest.lua', 'README.md' }
local function add(path)
  paths[#paths + 1] = path
end
local function add_all(scripts)
  for _, path in ipairs(scripts) do add(path) end
end
local manifest = setmetatable({
  version = function(value) version = value end,
  shared_scripts = add_all,
  server_scripts = add_all,
  client_scripts = add_all,
  shared_script = add,
  server_script = add,
  client_script = add,
}, { __index = function() return function() end end })
assert(loadfile('fxmanifest.lua', 't', manifest))()
assert(version and version:match('^[%w.+-]+$'), 'Versión del resource ausente o inválida')
print(version)
for _, path in ipairs(paths) do print(path) end
LUA
)
mapfile -t release < <(printf '%s\n' "$manifest_data")
archive="staff_suite-${release[0]}.zip"

(
  cd ui
  npm ci
  npm run build
)
test -s ui/dist/index.html

stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
resource="$stage/staff_suite"
mkdir -p -- "$resource" dist
cp --parents -- "${release[@]:1}" "$resource"
cp -R --parents -- ui/dist "$resource"
if [[ -d sql ]]; then
  cp -R -- sql "$resource"
fi
for license in LICENSE LICENSE.md LICENSE.txt; do
  if [[ -f "$license" ]]; then cp -- "$license" "$resource"; fi
done

(
  cd -- "$stage"
  zip -qr "$archive" staff_suite
)
mv -f -- "$stage/$archive" "dist/$archive"
printf 'ZIP de release: %s\n' "dist/$archive"
