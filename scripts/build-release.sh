#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$root_dir"

edition=core
if [[ $# -gt 0 ]]; then
  if [[ $# -ne 2 || $1 != --edition || ( $2 != lite && $2 != core ) ]]; then
    printf 'Uso: %s [--edition lite|core]\n' "$0" >&2
    exit 2
  fi
  edition=$2
fi

manifest_path=fxmanifest.lua
archive_prefix=staff_suite
if [[ $edition == lite ]]; then
  manifest_path=editions/lite/fxmanifest.lua
  archive_prefix=staff_suite_lite
fi

# Reutilizar la lista de scripts que carga FiveM y la versión del resource.
manifest_data=$(lua5.4 - "$manifest_path" <<'LUA'
local version
assert(loadfile('fxmanifest.lua', 't', setmetatable({
  version = function(value) version = value end,
}, { __index = function() return function() end end })))()
assert(version and version:match('^[%w.+-]+$'), 'Versión del recurso ausente o inválida')

local paths = {}
local function add(path)
  paths[#paths + 1] = path
end
local function add_all(scripts)
  for _, path in ipairs(scripts) do add(path) end
end
local manifest = setmetatable({
  shared_scripts = add_all,
  server_scripts = add_all,
  client_scripts = add_all,
  shared_script = add,
  server_script = add,
  client_script = add,
}, { __index = function() return function() end end })
assert(loadfile(arg[1], 't', manifest))()
print(version)
for _, path in ipairs(paths) do print(path) end
LUA
)
mapfile -t release < <(printf '%s\n' "$manifest_data")
archive="$archive_prefix-${release[0]}.zip"

(
  cd ui
  npm ci --include=dev
  VITE_STAFF_SUITE_EDITION="$edition" npm run build
)
test -s ui/dist/index.html

stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
resource="$stage/staff_suite"
mkdir -p -- "$resource" dist
if [[ $edition == lite ]]; then
  for path in "${release[@]:1}"; do
    if [[ $path != config.lua ]]; then cp --parents -- "$path" "$resource"; fi
  done
  sed "s/@VERSION@/${release[0]}/g" "$manifest_path" > "$resource/fxmanifest.lua"
  cp -- editions/lite/{config.lua,LICENSE,README.md} "$resource"
else
  cp --parents -- "$manifest_path" README.md "${release[@]:1}" "$resource"
  if [[ -d sql ]]; then cp -R -- sql "$resource"; fi
  for license in LICENSE LICENSE.md LICENSE.txt; do
    if [[ -f "$license" ]]; then cp -- "$license" "$resource"; fi
  done
fi
cp -R --parents -- ui/dist "$resource"
mkdir -p "$resource/third-party-licenses"
for dependency in react react-dom scheduler lucide-react @fontsource/dm-sans @fontsource/manrope; do
  cp -- "ui/node_modules/$dependency/LICENSE" "$resource/third-party-licenses/${dependency##*/}.txt"
done

(
  cd -- "$stage"
  zip -qr "$archive" staff_suite
)
mv -f -- "$stage/$archive" "dist/$archive"
printf 'ZIP de release: %s\n' "dist/$archive"
