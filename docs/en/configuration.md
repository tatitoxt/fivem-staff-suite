# `config.lua` reference

`config.lua` stays open (outside escrow) so you can edit it. Documented version: **0.1.0**.

> **Security:** `config.lua` is loaded as a `shared_script`, which means it is also sent to clients. Do not put anything there that players must not see. See the note on `Config.Export.webhook` below.

## General

| Key | Default | Description |
|---|---|---|
| `Config.Locale` | `'es'` | Language of server messages: `'es'` or `'en'`. Unknown values fall back to `'en'`. |
| `Config.PanelKey` | `'F6'` | Default key to open the panel. Each player can rebind it in *Settings → Key Bindings → FiveM*. |

## `Config.Commands`

| Key | Default | Description |
|---|---|---|
| `report` | `'report'` | Player command to create a report. |
| `duty` | `'duty'` | Staff command to go on/off duty. |
| `audit` | `'audit'` | Command to verify the chain (console or game). |
| `reports` | `'reports'` | Ticket queue command **(coming soon)**: not registered yet. |

## Reports

| Key | Default | Description |
|---|---|---|
| `Config.Categories` | `{ 'bug', 'player', 'staff', 'question', 'other' }` | Report categories. Each one needs a `cat_<name>` label in `locales/`. In 0.1.0 `/report` accepts any word as category; filtering by this list comes with the panel **(coming soon)**. |
| `Config.Priorities` | `{ 'low', 'normal', 'high', 'urgent' }` | Priorities. Each one needs `pri_<name>` in `locales/`. Reports created by command get `normal`. |

## Ranks

| Key | Default | Description |
|---|---|---|
| `Config.StandaloneRank` | `'owner'` | Rank given to **every** player in 0.1.0. See [Ranks and permissions](permissions.md). |
| `Config.RankMap` | `helper/mod/moderator/admin/superadmin/owner` | Maps framework groups to Staff Suite ranks. Applied once the bridges are wired **(coming soon)**. |

## Persistence

| Key | Default | Description |
|---|---|---|
| `Config.Persistence` | `'json'` | `'json'` (file) or `'oxmysql'` (MySQL/MariaDB). With `'oxmysql'` and oxmysql stopped, it falls back to JSON. |
| `Config.JsonFile` | `'staff_suite_data.json'` | File inside the resource folder. |

Data is saved after every audit entry, every 60 seconds and when the resource stops. With oxmysql the whole state is stored in one row of the `staff_state` table.

## `Config.Export` (off-box anchoring)

| Key | Default | Description |
|---|---|---|
| `webhook` | `''` | Discord webhook URL. Empty = disabled. |
| `file` | `true` | Writes each anchor to `audit_export.log` (resource folder). |
| `anchor_every` | `20` | Anchor the current hash every N entries. |

> **Webhook in 0.1.0:** since `config.lua` reaches the client, a savvy player could read the URL. Use a dedicated webhook in a channel used only for this, and regenerate it if it leaks. Moving the URL to a server-only convar is **(coming soon)**.

Full details in [Audit: export and verification](audit.md).

## `Config.Audit`

| Key | Default | Description |
|---|---|---|
| `capture_commands` | `true` | Registers restricted commands `ban`, `kick`, `warn`, `giveitem`, `givemoney`, `setjob` and records each use in the audit log as `cmd_<command>`. If it clashes with same-name commands from another resource, set it to `false`. |
| `capture_framework` | `true` | Framework event capture (grants, bans) **(coming soon)**: no effect yet. |

## `Config.Moderation`

| Key | Default | Description |
|---|---|---|
| `require_reason` | `true` | Requires a reason for `kick`, `ban` and `warn`. |

## Locales

Texts live in `locales/es.lua` and `locales/en.lua` (open). If you add or change a key, put it in **both** files and run the tests:

```
lua5.4 tests/run_all.lua
```

The `test_locales` test fails if a key is missing in any language, a text is empty, or placeholders (`%{id}`, `%{name}`…) do not match.
