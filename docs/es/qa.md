# QA y E2E en FXServer

Staff Suite tiene dos capas de tests automáticos:

| Capa | Qué prueba | Cómo se corre | Requisitos |
|---|---|---|---|
| Unit | `core/`, bridges y locales con natives mockeados | `lua5.4 tests/run_all.lua` | Lua 5.4 |
| E2E | El resource real dentro de un FXServer headless con OneSync | `scripts/e2e-fxserver.sh` | Linux x86_64, `FIVEM_LICENSE_KEY` |

La NUI tiene sus propios tests (`cd ui && npm ci && npm test`).

## Qué prueba el E2E

`tests/e2e_resource` es un resource (`staff_suite_tests`) que arranca después de `staff_suite`, dispara eventos simulados a través de los exports y hace asserts:

- **Tickets:** crear, claim, doble claim rechazado, transfer a otro staff, resolve, transición inválida y ticket inexistente rechazados (`false, código`) y un evento de red sin permisos que no cambia el ticket.
- **Auditoría:** cada paso deja su entrada (`ticket_create`, `ticket_claim`, `ticket_transfer`, `ticket_resolve`, `duty.in`, `duty.out`).
- **Duty:** entrada, doble entrada rechazada, salida con segundos acumulados (export `SetDuty`).
- **Export off-box:** completa la cadena hasta `anchor_every` y comprueba que la última línea de `audit_export.log` sea el head y que el webhook reciba el anchor. El script apunta `staff_suite_webhook` a un receptor HTTP del propio resource de test, así que no se usa Discord.
- **Verify:** `Verify()` íntegro, `seq` secuencial, hashes SHA-256 de 64 hex, `prev_hash` encadenado.
- **Persistencia:** `Flush()` fuerza el guardado, `GetPersistence()` lo confirma y el JSON en disco tiene la cadena completa (mismo largo y mismo head).
- **Métricas** (informativas, no fallan):
  - `record_avg_ms`, `getstate_avg_ms`: costo por llamada de los exports, incluida la serialización entre resources. No es costo por tick: staff_suite no tiene ningún loop en el server.
  - `server_frame_avg_ms`, `server_frame_max_ms`: intervalo entre frames del scheduler del server. En reposo FXServer corre a ~20 Hz, así que ~50 ms es lo normal y **no** mide a staff_suite.
  - `server_cpu_ms_per_frame`: CPU de todo el proceso FXServer por frame. Es una cota superior, no el costo de staff_suite.

El tamper (modificar una entrada y que `Verify` lo detecte) se prueba en los unit tests. Los exports de FiveM devuelven copias, así que desde otro resource no se puede tocar la cadena viva.

### Salida

Cada línea empieza con `[SSTEST]`, así que se puede filtrar con `grep`:

```
[SSTEST] PASS ticket.claim -> claimed
[SSTEST] FAIL <nombre> :: <detalle>
[SSTEST] SKIP export webhook :: staff_suite_webhook vacío
[SSTEST] METRIC record_avg_ms=0.716
[SSTEST] RESULT status=PASS passed=30 failed=0 skipped=0
[SSTEST] DONE
```

Al terminar, el resource ejecuta `quit` (`set staff_suite_e2e_autoquit false` para dejar el server vivo).

## Correrlo en Linux

```bash
export FIVEM_LICENSE_KEY=cfxk_...      # https://portal.cfx.re/servers/registration-keys
scripts/e2e-fxserver.sh                       # resource desde la carpeta del repo
scripts/e2e-fxserver.sh --resource dist/staff_suite-0.2.0.zip   # o el ZIP de release
scripts/e2e-fxserver.sh --edition lite                        # compila y prueba el ZIP Lite
scripts/e2e-fxserver.sh --edition lite --resource dist/staff_suite_lite-0.2.0.zip
```

Lite prueba los comandos y eventos del adapter con un reportante y un miembro del staff simulados. Verifica el ciclo del ticket, la cadena SHA-256, el JSON escrito por FXServer y la ausencia de handlers y exports de Core. El runner carga el código de prueba únicamente en la copia temporal que extrae del ZIP.

El script:

1. Consulta `https://changelogs-live.fivem.net/api/changelog/versions/linux/server`, descarga el artifact **recomendado** y lo cachea en `.cache/fxserver/<build>`. Para fijar una build, usá `FXSERVER_ARTIFACT_URL`.
2. Arma un `server-data` temporal con `staff_suite` (carpeta o ZIP) y `staff_suite_tests`, y un `server.cfg` mínimo con OneSync.
3. Escribe la license key en un `secrets.cfg` con permisos `600`, lo carga con `exec` y lo borra al salir. La key nunca va al repo ni a la línea de comandos.
4. Levanta FXServer headless, espera el `RESULT` y apaga el server.
5. Mide el presupuesto **de staff_suite** con `profiler record 300` + `profiler saveJSON`: suma la duración de los eventos de `staff_suite` (sin `staff_suite_tests`), la divide por los 300 frames y la compara con `E2E_MAX_TICK_MS` (por defecto `0.05`). Si el profile tiene eventos pero ninguno de staff_suite, el costo es 0. Si el profile está vacío, lo informa y no falla.

Sin license key podés verificar la descarga y el armado del server:

```bash
scripts/e2e-fxserver.sh --download-only
E2E_WORK_DIR=/tmp/e2e scripts/e2e-fxserver.sh --dry-run
```

### Variables

| Variable | Default | Uso |
|---|---|---|
| `FIVEM_LICENSE_KEY` | — | Obligatoria para correr el server. |
| `FXSERVER_ARTIFACT_URL` | artifact recomendado | URL de un `fx.tar.xz` concreto. |
| `E2E_CACHE_DIR` | `.cache/fxserver` | Cache del artifact. |
| `E2E_WORK_DIR` | directorio temporal | `server-data`, `fxserver.log` y `profile.json`. |
| `E2E_PORT` | `30120` | Puerto local del server. |
| `E2E_TIMEOUT` | `180` | Segundos máximos de corrida. |
| `E2E_MAX_TICK_MS` | `0.05` | Presupuesto por tick de staff_suite según el profiler. |

### Códigos de salida

| Código | Significado |
|---|---|
| `0` | Todos los asserts pasaron. |
| `1` | Falló algún assert o hubo un `SCRIPT ERROR`. |
| `2` | Error de entorno: plataforma, dependencias, descarga o license key. |
| `3` | El server terminó sin imprimir `RESULT`. |
| `4` | staff_suite superó `E2E_MAX_TICK_MS`. |

## CI

`.github/workflows/e2e.yml` corre en cada PR y en cada push a `main`, y también se puede lanzar a mano (`workflow_dispatch`). Si el repo no tiene el secret `FIVEM_LICENSE_KEY`, el job deja un aviso y no hace nada más. Si lo tiene, empaqueta el ZIP con `scripts/build-release.sh`, corre el E2E contra ese ZIP y sube `fxserver.log` y `profile.json` como artifact.

Para activarlo: **Settings → Secrets and variables → Actions → New repository secret**, con el nombre `FIVEM_LICENSE_KEY`. Los PRs desde forks no reciben el secret, así que ahí el job se omite.

## resmon en cliente

El presupuesto de `ARCHITECTURE.md` (<0.05 ms en reposo) es de **cliente**, y `resmon` solo existe en el cliente de FiveM. El E2E headless no conecta jugadores, así que eso se mide a mano: entrá al server, abrí la consola (F8), escribí `resmon 1` y mirá `staff_suite` con el panel cerrado y abierto. Una medición automática de cliente queda **(próximamente)**.
