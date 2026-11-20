# Configuration reference

Documented version: **0.2.0**. There are two files:

| File | Loaded on | Purpose |
|---|---|---|
| `config.lua` | client **and** server (`shared_script`) | Public options: language, commands, categories, framework, ranks, persistence. |
| `server/config.lua` | server only | Private options: webhook and anchors (`Config.Export`) and per-identifier ranks (`Config.StandaloneRanks`). |

Do not put secrets in `config.lua`: every player downloads it.

## `config.lua`

### General

| Key | Default | Description |
|---|---|---|
| `Config.Locale` | `'es'` | Message language: `'es'` or `'en'`. If the language does not exist, or a key is missing, the English text is used. |
| `Config.PanelKey` | `'F6'` | Default key to open the panel. Each player can rebind it under *Settings → Key Bindings → FiveM*. |

### `Config.Commands`

| Key | Default | Description |
|---|---|---|
| `report` | `'report'` | Player command to create a report. |
| `duty` | `'duty'` | Staff command to clock in/out. |
| `audit` | `'audit'` | Command to verify the chain (console or in game). |
| `reports` | `'reports'` | Command to open the ticket queue in Lite. In Core, open it from the panel. |

### Reports

| Key | Default | Description |
|---|---|---|
| `Config.Categories` | `{ 'bug', 'player', 'staff', 'question', 'other' }` | Valid categories. A category not in the list is stored as `other`. Each one needs a `cat_<name>` label in `locales/`. |
| `Config.Priorities` | `{ 'low', 'normal', 'high', 'urgent' }` | Valid priorities (from the panel). An unknown priority, or a `/report`, comes in as `normal`. Each one needs `pri_<name>` in `locales/`. |

### Framework and ranks

| Key | Default | Description |
|---|---|---|
| `Config.Framework` | `'auto'` | `'auto'` detects Qbox → QBCore → ESX → standalone. Force `'qbox'`, `'qbcore'`, `'esx'` or `'standalone'` if you run more than one. Any other value stops startup with `Config.Framework inválido`. |
| `Config.RankMap` | see below | ESX group, QBCore permission or Qbox ACE object → Staff Suite rank. |
| `Config.JobRankMap` | `{ esx = {}, qbcore = {}, qbox = {} }` | Active job → rank, per framework. E.g. `esx = { staff = 'helper' }`. |

Default `Config.RankMap`:

```lua
Config.RankMap = {
  helper = 'helper', support = 'helper',
  mod = 'moderator', moderator = 'moderator',
  admin = 'admin',
  superadmin = 'senior_admin',
  owner = 'owner', god = 'owner',
}
```

If a player matches several groups, permissions or jobs, the highest rank wins. Valid ranks: `helper`, `moderator`, `admin`, `senior_admin`, `owner`. See [Ranks and permissions](permissions.md).

### Persistence

| Key | Default | Description |
|---|---|---|
| `Config.Persistence` | `'json'` | `'json'` (file) or `'oxmysql'` (MySQL/MariaDB). With `'oxmysql'` and oxmysql not running, it falls back to JSON. |
| `Config.JsonFile` | `'staff_suite_data.json'` | File inside the resource folder. |

Changes are saved in batches, with a JSON checkpoint for pending changes when the resource stops. With oxmysql, each batch uses a transaction and keeps a JSON backup. Ban and warn wait for the save before dropping or notifying the player.

### `Config.Audit`

| Key | Default | Description |
|---|---|---|
| `capture_framework` | `true` | Enables event capture for the active framework and txAdmin. |

### `Config.Moderation`

| Key | Default | Description |
|---|---|---|
| `require_reason` | `true` | Requires a reason for `kick`. Ban and warn always require a reason. |
| `ban_duration` | `86400` | Default ban duration in seconds. Use `0` for a permanent ban. |
| `ban_tokens` | `true` | Also bans the client hardware tokens (`token:*`). Besides `license`, a ban covers `license2`, `fivem`, `steam`, `discord`, `xbl` and `live`; if a banned player returns with a new account sharing any of them, the ban is extended to the new ones (`mod_ban_extended`). IPs are not used. |

### `Config.Limits` and `Config.RateLimit`

| Key | Default | Description |
|---|---|---|
| `Limits.ticket_body` / `message_body` / `reason` | `1000` / `1000` / `300` | Maximum bytes accepted by the server; control characters are stripped. |
| `Limits.open_tickets_per_player` | `3` | Simultaneous open reports per player. `nil` disables the cap. |
| `Limits.evidence_bytes` | `3 MiB` | Maximum size of a `screenshot-basic` capture. Anything that is not a JPEG data URI is rejected. |
| `RateLimit[event]` | see `config.lua` | Per-player token bucket: `burst` actions in a row, then `per_second`. `default` applies to events without their own rule and to commands. |

## `server/config.lua`

### `Config.Export` (off-box anchoring)

| Key | Default | Description |
|---|---|---|
| `webhook` | `GetConvar('staff_suite_webhook', '')` | Discord webhook URL. Set it in `server.cfg` with `set staff_suite_webhook "URL"`. Empty = disabled. |
| `ticket_webhook` | `GetConvar('staff_suite_ticket_webhook', '')` | Text channel webhook URL at `https://discord.com/api/webhooks/…`. Set `set staff_suite_ticket_webhook "URL"` in `server.cfg`. Enables **Export thread to Discord** for staff with `report.export`. The transcript includes the ticket description and public messages in a text file of up to 64 KiB. |
| `file` | `true` | Writes each anchor to `audit_export.log` (resource folder). |
| `anchor_every` | `20` | Anchor the current hash every N entries. |
| `webhook_retries` | `5` | Webhook attempts per anchor on 429, 5xx or no response. |
| `webhook_backoff_ms` / `webhook_backoff_max_ms` | `2000` / `60000` | Delay before the first retry, doubled on each attempt up to the cap (honors `Retry-After`). |

Use `set`, **not** `setr`: `setr` replicates the convar to clients and anyone could read the URL. Full details in [Audit: export and verification](audit.md).

### `Config.StandaloneRanks`

Ranks by stable identifier, standalone mode only:

```lua
Config.StandaloneRanks = {
  ['license:1234abcd...'] = 'admin',
}
```

Combined with `staff_suite.<rank>` ACEs: the highest wins. Ignored when a framework is active.

## Locales

Texts live in `locales/es.lua` and `locales/en.lua`. If you add or change a key, put it in **both** files and run the tests:

```
lua5.4 tests/run_all.lua
```

The `test_locales` test fails if a key is missing in either language, a text is empty, or placeholders (`%{id}`, `%{name}`…) do not match.
