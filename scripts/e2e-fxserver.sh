#!/usr/bin/env bash
# E2E de Staff Suite en un FXServer real (Linux x86_64, headless, OneSync).
#
# Uso: scripts/e2e-fxserver.sh [--edition core|lite] [--resource <carpeta|zip>] [--download-only] [--dry-run]
#   --edition        suite Core (default) o Lite
#   --resource       carpeta o ZIP de release (default: raíz del repo para Core, generar el ZIP para Lite)
#   --download-only  descarga y extrae el artifact recomendado, sin levantar el server
#   --dry-run        además arma server-data y server.cfg, sin levantar el server
#
# Env: FIVEM_LICENSE_KEY (obligatoria para correr), FXSERVER_ARTIFACT_URL (forzar build),
#      E2E_CACHE_DIR, E2E_WORK_DIR, E2E_PORT (30120), E2E_TIMEOUT (180 s),
#      E2E_MAX_TICK_MS (0.05, presupuesto por tick de staff_suite medido con el profiler).
#
# Códigos de salida: 0 PASS · 1 FAIL de tests · 2 error de entorno/uso
#                    3 el server no reportó resultado · 4 presupuesto de rendimiento excedido
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
resource_src=
edition=core
mode=run
while (($#)); do
  case $1 in
    --edition) edition=${2:-}; [[ $edition == core || $edition == lite ]] || { echo '--edition requiere core o lite' >&2; exit 2; }; shift 2 ;;
    --resource) resource_src=${2:?--resource requiere una ruta}; shift 2 ;;
    --download-only) mode=download; shift ;;
    --dry-run) mode=dry; shift ;;
    -h|--help) sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Argumento desconocido: $1" >&2; exit 2 ;;
  esac
done

die() { echo "[e2e] ERROR: $1" >&2; exit "${2:-2}"; }
info() { echo "[e2e] $*"; }

[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || die 'solo Linux x86_64'
for bin in curl tar xz python3; do command -v "$bin" >/dev/null || die "falta $bin"; done

cache_dir=${E2E_CACHE_DIR:-$root_dir/.cache/fxserver}
port=${E2E_PORT:-30120}
timeout_s=${E2E_TIMEOUT:-180}
max_tick_ms=${E2E_MAX_TICK_MS:-0.05}

# ===== Artifact recomendado =====
changelog=https://changelogs-live.fivem.net/api/changelog/versions/linux/server
artifact_url=${FXSERVER_ARTIFACT_URL:-}
if [[ -z $artifact_url ]]; then
  artifact_url=$(curl -fsSL --retry 3 "$changelog" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["recommended_download"])') \
    || die "no se pudo consultar $changelog"
fi
[[ $artifact_url =~ /([0-9]+)-[0-9a-f]+/fx\.tar\.xz$ ]] || die "URL de artifact inesperada: $artifact_url"
build=${BASH_REMATCH[1]}
fx_dir=$cache_dir/$build
if [[ ! -f $fx_dir/.ok ]]; then
  info "descargando FXServer $build"
  rm -rf -- "$fx_dir"; mkdir -p -- "$fx_dir"
  curl -fSL --retry 3 -o "$fx_dir/fx.tar.xz" "$artifact_url" || die 'falló la descarga del artifact'
  tar -xJf "$fx_dir/fx.tar.xz" -C "$fx_dir" || die 'falló la extracción del artifact'
  rm -f -- "$fx_dir/fx.tar.xz"
  [[ -f $fx_dir/run.sh && -x $fx_dir/alpine/opt/cfx-server/FXServer ]] || die 'el artifact no tiene run.sh/FXServer'
  touch -- "$fx_dir/.ok"
fi
info "FXServer $build listo en $fx_dir"
[[ $mode == download ]] && exit 0

if [[ -z $resource_src ]]; then
  resource_src=$root_dir
  if [[ $edition == lite ]]; then
    "$root_dir/scripts/build-release.sh" --edition lite || die 'falló el build de Lite'
    version=$(sed -n "s/^version '\(.*\)'$/\1/p" "$root_dir/fxmanifest.lua")
    resource_src=$root_dir/dist/staff_suite_lite-$version.zip
  fi
fi

# ===== server-data =====
work_dir=${E2E_WORK_DIR:-$(mktemp -d)}
mkdir -p -- "$work_dir"
work_dir=$(cd -- "$work_dir" && pwd)
data_dir=$work_dir/server-data
resources="$data_dir/resources/[staff]"
rm -rf -- "$data_dir"; mkdir -p -- "$resources"

if [[ -f $resource_src && $resource_src == *.zip ]]; then
  command -v unzip >/dev/null || die 'falta unzip'
  zip_dir=$(mktemp -d -- "$work_dir/zip.XXXXXX")
  trap 'rm -rf -- "$zip_dir"' EXIT
  unzip -q "$resource_src" -d "$zip_dir"
  manifest=$(find "$zip_dir" -maxdepth 2 -name fxmanifest.lua -print -quit)
  [[ -n $manifest ]] || die "el ZIP no contiene fxmanifest.lua: $resource_src"
  mv -- "$(dirname -- "$manifest")" "$resources/staff_suite"
  rm -rf -- "$zip_dir"
  trap - EXIT
elif [[ -f $resource_src/fxmanifest.lua ]]; then
  tar -C "$resource_src" --exclude=.git --exclude=.cache --exclude=node_modules --exclude=./tests \
    --exclude=./dist --exclude=./.github --exclude=./scripts --exclude=./plan --exclude=./launch --exclude=./docs -cf - . \
    | tar -C "$resources" --one-top-level=staff_suite -xf -
else
  die "--resource debe ser una carpeta con fxmanifest.lua o un .zip: $resource_src"
fi
rm -f -- "$resources/staff_suite/staff_suite_data.json" "$resources/staff_suite/audit_export.log"
cp -R -- "$root_dir/tests/e2e_resource" "$resources/staff_suite_tests"

manifest=$resources/staff_suite/fxmanifest.lua
if [[ $edition == lite ]]; then
  grep -Fq "'server/lite.lua'" "$manifest" || die '--edition lite requiere un recurso Free Lite'
  # El ZIP queda intacto. El probe se carga antes del adapter, solo en server-data.
  cp -- "$root_dir/tests/e2e_resource/lite_probe.lua" "$resources/staff_suite/e2e_lite_probe.lua"
  sed -i "/^server_scripts[[:space:]]*{/a\  'e2e_lite_probe.lua'," "$manifest"
  grep -Fq "'e2e_lite_probe.lua'" "$manifest" || die 'no se pudo cargar el probe de Lite'
elif grep -Fq "'server/lite.lua'" "$manifest"; then
  die 'usá --edition lite con el recurso Free Lite'
fi

profile=$work_dir/profile.json
log=$work_dir/fxserver.log
rm -f -- "$profile" "$log"
cat > "$data_dir/server.cfg" <<CFG
endpoint_add_tcp "127.0.0.1:$port"
endpoint_add_udp "127.0.0.1:$port"
sv_maxclients 1
sv_hostname "staff_suite e2e"
set onesync on
exec secrets.cfg
set staff_suite_webhook "http://127.0.0.1:$port/staff_suite_tests/webhook"
set staff_suite_e2e_edition "$edition"
set staff_suite_e2e_autoquit true
set staff_suite_e2e_profile_file "$profile"
add_ace resource.staff_suite_tests command.quit allow
add_ace resource.staff_suite_tests command.profiler allow
add_ace resource.staff_suite_tests command.record allow
add_ace resource.staff_suite_tests command.saveJSON allow
ensure staff_suite
ensure staff_suite_tests
CFG
info "server-data en $data_dir"

key=${FIVEM_LICENSE_KEY:-}
if [[ $mode == dry ]]; then
  key=${key:-dry_run_placeholder}
elif [[ -z $key ]]; then
  die 'FIVEM_LICENSE_KEY no está definida (https://portal.cfx.re/servers/registration-keys)'
fi
[[ $key =~ ^[A-Za-z0-9_-]+$ ]] || die 'FIVEM_LICENSE_KEY tiene caracteres inválidos'
secrets=$data_dir/secrets.cfg
(umask 077; printf 'sv_licenseKey "%s"\n' "$key" > "$secrets")
unset key
trap 'rm -f -- "$secrets"' EXIT
[[ $mode == dry ]] && { info 'dry-run: server no iniciado'; exit 0; }

# ===== Correr headless =====
info "iniciando FXServer (timeout ${timeout_s}s, log $log)"
# Grupo de procesos propio para poder apagar FXServer y sus hijos juntos.
# stdin abierto (tail) para que la consola no reciba EOF.
# shellcheck disable=SC2016 # se expande en el bash hijo
setsid bash -c 'cd -- "$1" && tail -f /dev/null | exec timeout --kill-after=10 "$2" bash "$3/run.sh" +set onesync on +exec server.cfg' \
  _ "$data_dir" "$timeout_s" "$fx_dir" > "$log" 2>&1 &
server_pid=$!
stop_server() { kill -- -"$server_pid" 2>/dev/null || true; }
trap 'rm -f -- "$secrets"; stop_server' EXIT

clean() { sed -E 's/\x1b\[[0-9;]*m//g' "$log"; }
# Sin grep -q: con pipefail, el SIGPIPE de sed haría fallar el chequeo.
log_has() { clean | grep -E "$1" >/dev/null; }
deadline=$((SECONDS + timeout_s))
while kill -0 "$server_pid" 2>/dev/null && ((SECONDS < deadline)); do
  if log_has '\[SSTEST\] DONE'; then break; fi
  sleep 1
done
for _ in $(seq 15); do kill -0 "$server_pid" 2>/dev/null || break; sleep 1; done
stop_server
wait "$server_pid" 2>/dev/null || true
rm -f -- "$secrets"

if log_has 'Could not authenticate server license key|does not have a license key'; then
  clean | grep -E 'license key' >&2 || true
  die 'el server rechazó FIVEM_LICENSE_KEY'
fi

clean | grep -E 'SCRIPT ERROR|\[SSTEST\]' || true
result=$(clean | grep -oE '\[SSTEST\] RESULT .*' | tail -1 || true)
if [[ -z $result ]]; then
  clean | tail -40 >&2
  die 'el server terminó sin línea RESULT' 3
fi
if log_has 'SCRIPT ERROR'; then
  echo '[e2e] FAIL: hubo SCRIPT ERROR en la consola' >&2; exit 1
fi
[[ $result == *status=PASS* ]] || { echo "[e2e] FAIL: $result" >&2; exit 1; }

# ===== Rendimiento (best-effort) =====
if [[ -s $profile ]]; then
  if ! python3 - "$profile" "$max_tick_ms" <<'PY'
import json, sys
path, budget = sys.argv[1], float(sys.argv[2])
data = json.load(open(path))
events = data.get('traceEvents', data) if isinstance(data, dict) else data
total_us, n, timed = 0.0, 0, 0
for ev in events if isinstance(events, list) else []:
    if not isinstance(ev, dict) or 'dur' not in ev:
        continue
    timed += 1
    blob = json.dumps(ev)
    if 'staff_suite' in blob and 'staff_suite_tests' not in blob:
        total_us += float(ev['dur']); n += 1
if not timed:
    print('[e2e] profiler sin eventos: presupuesto de staff_suite no medido')
    sys.exit(0)
per_tick = total_us / 1000 / 300
print(f'[e2e] METRIC profiler_events={timed} profiler_staff_suite_events={n}')
print(f'[e2e] METRIC profiler_staff_suite_ms_per_tick={per_tick:.4f} (presupuesto {budget})')
sys.exit(4 if per_tick > budget else 0)
PY
  then
    echo "[e2e] FAIL: staff_suite supera ${max_tick_ms} ms por tick" >&2; exit 4
  fi
else
  info 'profiler sin datos: rendimiento no medido (ver METRIC server_*/record_* arriba)'
fi
echo "[e2e] PASS: $result"
