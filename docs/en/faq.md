# FAQ and troubleshooting

## FAQ

**Does it replace txAdmin?**
No. It sits on top: txAdmin is still used for noclip, god, spawning, bans, etc. Staff Suite covers the staff workflow (reports, in-ticket moderation, duty) and audits all of it.

**Can my staff delete or edit the logs?**
Anyone with access to the database or the JSON file can modify them, but verification detects it (the chain breaks at the first tampered entry). To also detect a full rewrite or deletions at the end, enable off-box export. See [Audit](audit.md).

**Does it capture everything that happens on the server?**
It captures Staff Suite actions, supported events from ESX, QBCore, Qbox and txAdmin, and what other resources send through the `Record` export.

**Do I need a database?**
It uses a JSON file by default. To use oxmysql with MySQL or MariaDB, apply the [installation migration](installation.md).

**Does it work with ESX, QBCore or Qbox?**
Yes. `Config.Framework = 'auto'` detects Qbox, QBCore or ESX and reads groups/permissions according to `Config.RankMap` and `Config.JobRankMap`. Without a framework it uses `staff_suite.<rank>` ACEs. See [Ranks and permissions](permissions.md).

**How do I give someone a rank in standalone?**
With ACE in `server.cfg` (`add_ace group.admin staff_suite.admin allow` + `add_principal identifier.license:... group.admin`) or in `Config.StandaloneRanks` in `server/config.lua`.

**Where do I put the Discord webhook?**
In `server.cfg`: `set staff_suite_webhook "URL"`, before `ensure staff_suite`. Use `set`, not `setr`.

**How do I change the language?**
`Config.Locale = 'es'` or `'en'` in `config.lua`. Texts are edited in `locales/`.

**Does it hurt performance?**
There are no per-tick loops: the server has a single thread that saves every 60 seconds and the client has no loops. Measuring with `resmon` is still pending.

**Which parts can I edit if I buy the escrowed version?**
`config.lua`, `server/config.lua`, `locales/`, `sql/` and the panel (`ui/`) stay open. The rest (core and adapter) is encrypted by Cfx escrow **(coming soon)**.

**What is the difference between Lite, Core and Integrity Pro?**
See the editions table in the [README](../../README.md#editions).

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `[StaffSuite] module not found: core.xxx` | A folder is missing or the resource is nested too deep. | Make sure `core/`, `server/`, `shared/` are directly inside `staff_suite/`. |
| `Config.Framework inválido` on start | Value other than `auto`, `qbox`, `qbcore`, `esx`, `standalone`. | Fix `Config.Framework`. |
| Console says `framework=qbcore` on a Qbox server (or vice versa) | More than one framework is started. | Force `Config.Framework = 'qbox'` (or the right one). |
| An admin has no permissions | Their group/permission/ACE is not in `Config.RankMap`, they have not loaded a character yet, or in standalone they lack the `staff_suite.<rank>` ACE. | Add the mapping; in standalone, the ACE or `Config.StandaloneRanks`. |
| `Config.StandaloneRanks` or `staff_suite.*` ACEs do nothing | A framework is active: in that mode only the framework counts. | Map it in `Config.RankMap`/`Config.JobRankMap`, or force `'standalone'`. |
| `persistence=oxmysql` but data goes to the JSON file | oxmysql was not started when Staff Suite started. | Put `ensure oxmysql` **before** `ensure staff_suite` and check it connects to the database. |
| `exports.staff_suite` does not exist / the panel does not respond | The folder is not named `staff_suite`. | Rename it to `staff_suite`. |
| Pressing `F6` shows nothing, or the cursor gets stuck | The built panel in `ui/dist/` is missing. | Build it with `cd ui && npm ci && npm run build` or use a release package that includes it. See [Panel](panel.md#building-the-panel). |
| `/audit` in game shows nothing | The result is sent to the panel, not the chat. | Use `audit` in the server console or the panel. |
| A key name (e.g. `report_created`) shows instead of the text | The key is missing from the locales. | Add it to `locales/es.lua` **and** `locales/en.lua` and run `lua5.4 tests/run_all.lua`. |
| Nothing arrives at the webhook | Empty convar, `set` after `ensure`, invalid URL, or the next anchor has not been reached. | Check `set staff_suite_webhook` comes before `ensure staff_suite`. Anchors go out every `anchor_every` entries. |
| Verification reports the chain broken at N | Someone edited, deleted or reordered entries (also happens if you edited the JSON/DB by hand). | See "If the chain shows as broken" in [Audit](audit.md). |
| `kick` replies "A reason is required." | `Config.Moderation.require_reason = true`. | Give a reason, or disable it (not recommended). |
| "The selected player is not connected." | The target disconnected or the id does not exist. | Pick an online player. |
| A ticket transfer fails | The recipient is offline or lacks `report.claim` + `report.view`. | Transfer to an online staff member with that rank. |

## Known limitations in 0.2.0

- In Core, open the ticket queue from the panel. Lite also registers `/reports`.
- `audit_export.log` stays on the same machine: copy it elsewhere for it to count as independent proof.
