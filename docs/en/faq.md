# FAQ and troubleshooting

## FAQ

**Does it replace txAdmin?**
No. It sits on top of it: txAdmin keeps noclip, god, spawning, etc. Staff Suite covers the staff workflow (reports, in-ticket moderation, duty) and audits all of it.

**Can my staff delete or edit the logs?**
Anyone with access to the database or the JSON file can modify them, but verification detects it (the chain breaks at the first modified entry). To also catch a full rewrite or a deletion at the end, enable the off-box export. See [Audit](audit.md).

**Does it capture everything that happens on the server?**
No, and we do not claim it does. It captures 100% of what goes through Staff Suite, the commands in `Config.Audit.capture_commands`, and whatever other resources send through the `Record` export. Framework event capture and txAdmin log parsing are **(coming soon)**.

**Do I need a database?**
No. Without oxmysql it uses a JSON file. With oxmysql + MySQL/MariaDB it stores data in the `staff_state` table.

**Does it work with ESX, QBCore or Qbox?**
It runs on servers with those frameworks, but in 0.1.0 it does not read their groups yet: everyone gets `Config.StandaloneRank`. The bridges are written and will be wired **(coming soon)**. See [Ranks and permissions](permissions.md).

**How do I change the language?**
`Config.Locale = 'es'` or `'en'` in `config.lua`. Texts are edited in `locales/`.

**Does it affect performance?**
There are no per-tick loops: the server has a single thread that saves every 60 seconds and the client has no loops. `resmon` measurement is pending.

**What can I edit if I buy the escrow version?**
`config.lua`, `locales/` and the panel (`ui/`) stay open. The rest (core and adapter) is encrypted by Cfx escrow.

**What is the difference between Lite, Core and Integrity Pro?**
See the editions table in the [README](../../README.md#editions).

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `[StaffSuite] módulo no encontrado: core.xxx` | A folder is missing or the resource is nested too deep. | Make sure `core/`, `server/`, `shared/` sit directly inside `staff_suite/`. |
| Console says `persistencia=json` even though I set oxmysql | oxmysql was not started when Staff Suite started. | Put `ensure oxmysql` **before** `ensure staff_suite` and check oxmysql connects to the database. |
| `exports.staff_suite` does not exist / panel does not respond | The folder is not named `staff_suite`. | Rename it to `staff_suite`. |
| Pressing `F6` shows nothing, or the cursor stays on screen | The built panel in `ui/dist/` is missing. | Use a release package that includes `ui/dist/`. Meanwhile, use the commands. |
| In-game `/audit` shows nothing | In 0.1.0 the result is sent to the panel, not to chat. | Use `audit` in the server console, or the panel. |
| A key name (e.g. `report_created`) shows instead of the text | The key is missing in the selected locale. | Add it to `locales/es.lua` **and** `locales/en.lua` and run `lua5.4 tests/run_all.lua`. |
| A command from another resource (`ban`, `kick`, `warn`, `giveitem`, `givemoney`, `setjob`) stopped working | It clashes with command capture. | `Config.Audit.capture_commands = false`. |
| Captured commands are not recorded | They are restricted commands: they need the `command.<name>` ACE. | Grant the ACE to your staff group in `server.cfg`, e.g. `add_ace group.admin command.kick allow`. |
| No webhook messages | Empty/invalid URL, or the next anchor has not been reached. | Check `Config.Export.webhook`. Anchors go out every `anchor_every` entries, not on every action. |
| Verification says `BROKEN at N` | Someone edited, deleted or reordered entries (also happens if you hand-edited the JSON/DB). | See "If the chain shows as broken" in [Audit](audit.md). |
| `kick`/`ban`/`warn` replies "A reason is required." | `Config.Moderation.require_reason = true`. | Provide a reason, or disable it (not recommended). |
| `ban`/`warn`/`spectate`/`revive` show up in the audit log but nothing happens in game | In 0.1.0 they do not execute yet **(coming soon)**. | For now, ban through txAdmin or your framework. |

## Known limitations in 0.1.0

- Every player gets `Config.StandaloneRank` (default `owner`).
- `config.lua` reaches the client: the webhook URL is visible to savvy players.
- The panel requests the full state (tickets and audit log) without a permission check; the check is **(coming soon)**.
- `audit_export.log` stays on the same machine: copy it off-box for it to count as independent evidence.
