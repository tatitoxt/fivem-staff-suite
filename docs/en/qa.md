# QA and FXServer E2E

Staff Suite has two layers of automated tests:

| Layer | What it tests | How to run it | Requirements |
|---|---|---|---|
| Unit | `core/`, bridges and locales with mocked natives | `lua5.4 tests/run_all.lua` | Lua 5.4 |
| E2E | The real resource inside a headless FXServer with OneSync | `scripts/e2e-fxserver.sh` | Linux x86_64, `FIVEM_LICENSE_KEY` |

The NUI has its own tests (`cd ui && npm ci && npm test`).

## What the E2E tests

`tests/e2e_resource` is a resource (`staff_suite_tests`) that starts after `staff_suite`, fires simulated events through the exports and runs asserts:

- **Tickets:** create, claim, double claim rejected, transfer to another staff member, resolve, invalid transition rejected, and a network event without permissions that leaves the ticket unchanged.
- **Audit:** every step writes its entry (`ticket_create`, `ticket_claim`, `ticket_transfer`, `ticket_resolve`, `duty.in`, `duty.out`).
- **Duty:** clock in, double clock-in rejected, clock out with accumulated seconds (`SetDuty` export).
- **Off-box export:** fills the chain up to `anchor_every`, then checks that the last line of `audit_export.log` is the head and that the webhook receives the anchor. The script points `staff_suite_webhook` at an HTTP receiver inside the test resource, so Discord is not used.
- **Verify:** `Verify()` passes, `seq` is sequential, hashes are 64-hex SHA-256, `prev_hash` links up and the persistence JSON is current.
- **Metrics:** average time of `Record` and `GetState`, and the server tick interval while staff_suite is idle.

Tampering (editing an entry and having `Verify` catch it) is covered by the unit tests. FiveM exports return copies, so another resource cannot touch the live chain.

### Output

Every line starts with `[SSTEST]`, so you can filter it with `grep`:

```
[SSTEST] PASS ticket.claim -> claimed
[SSTEST] FAIL <name> :: <detail>
[SSTEST] SKIP export webhook :: staff_suite_webhook vacío
[SSTEST] METRIC record_avg_ms=0.716
[SSTEST] RESULT status=PASS passed=27 failed=0 skipped=0
[SSTEST] DONE
```

When it finishes, the resource runs `quit` (`set staff_suite_e2e_autoquit false` keeps the server running).

## Running it on Linux

```bash
export FIVEM_LICENSE_KEY=cfxk_...      # https://portal.cfx.re/servers/registration-keys
scripts/e2e-fxserver.sh                       # resource from the repo folder
scripts/e2e-fxserver.sh --resource dist/staff_suite-0.1.0.zip   # or the release ZIP
scripts/e2e-fxserver.sh --edition lite                        # builds and tests the Lite ZIP
scripts/e2e-fxserver.sh --edition lite --resource dist/staff_suite_lite-0.1.0.zip
```

Lite exercises the adapter's commands and events with a simulated reporter and staff member. It verifies the ticket lifecycle, the SHA-256 chain, the JSON written by FXServer, and the absence of Core handlers and exports. The runner loads the test code only in the temporary copy extracted from the ZIP.

The script:

1. Queries `https://changelogs-live.fivem.net/api/changelog/versions/linux/server`, downloads the **recommended** artifact and caches it in `.cache/fxserver/<build>`. To pin a build, set `FXSERVER_ARTIFACT_URL`.
2. Builds a temporary `server-data` with `staff_suite` (folder or ZIP) and `staff_suite_tests`, plus a minimal `server.cfg` with OneSync.
3. Writes the license key to a `secrets.cfg` with `600` permissions, loads it with `exec` and deletes it on exit. The key never goes into the repo or the command line.
4. Starts FXServer headless, waits for `RESULT` and shuts the server down.
5. Measures performance with `profiler record 300` + `profiler saveJSON`. If the profiler recorded `staff_suite` events, it compares the per-tick average against `E2E_MAX_TICK_MS` (default `0.05`). If there is no data, it says so and does not fail.

Without a license key you can still check the download and the server setup:

```bash
scripts/e2e-fxserver.sh --download-only
E2E_WORK_DIR=/tmp/e2e scripts/e2e-fxserver.sh --dry-run
```

### Variables

| Variable | Default | Purpose |
|---|---|---|
| `FIVEM_LICENSE_KEY` | — | Required to start the server. |
| `FXSERVER_ARTIFACT_URL` | recommended artifact | URL of a specific `fx.tar.xz`. |
| `E2E_CACHE_DIR` | `.cache/fxserver` | Artifact cache. |
| `E2E_WORK_DIR` | temporary directory | `server-data`, `fxserver.log` and `profile.json`. |
| `E2E_PORT` | `30120` | Local server port. |
| `E2E_TIMEOUT` | `180` | Maximum run time in seconds. |
| `E2E_MAX_TICK_MS` | `0.05` | Per-tick budget for staff_suite according to the profiler. |

### Exit codes

| Code | Meaning |
|---|---|
| `0` | All asserts passed. |
| `1` | An assert failed or there was a `SCRIPT ERROR`. |
| `2` | Environment error: platform, dependencies, download or license key. |
| `3` | The server exited without printing `RESULT`. |
| `4` | staff_suite exceeded `E2E_MAX_TICK_MS`. |

## CI

`.github/workflows/e2e.yml` runs on every PR and every push to `main`, and can also be started by hand (`workflow_dispatch`). If the repo has no `FIVEM_LICENSE_KEY` secret, the job leaves a notice and does nothing else. If it does, it packages the ZIP with `scripts/build-release.sh`, runs the E2E against that ZIP and uploads `fxserver.log` and `profile.json` as an artifact.

To enable it: **Settings → Secrets and variables → Actions → New repository secret**, named `FIVEM_LICENSE_KEY`. PRs from forks do not get the secret, so the job is skipped there.

## Client resmon

The `ARCHITECTURE.md` budget (<0.05 ms idle) is a **client** budget, and `resmon` only exists in the FiveM client. The headless E2E does not connect players, so this is measured by hand: join the server, open the console (F8), type `resmon 1` and watch `staff_suite` with the panel closed and open. Automated client measurement is **(coming soon)**.
