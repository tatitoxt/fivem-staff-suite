# Installation

> Documented version: **0.1.0**. Anything marked **(coming soon)** is planned but not implemented yet.

## Requirements

| Requirement | Required? | Notes |
|---|---|---|
| Recent FXServer with Lua 5.4 | Yes | The resource uses `fx_version 'cerulean'` and `lua54 'yes'`. |
| [oxmysql](https://github.com/overextended/oxmysql) + MySQL/MariaDB | No | Only if you want data in a database. Without oxmysql a JSON file is used. |
| Framework (ESX / QBCore / Qbox) | No | Auto-detected. Without a framework it runs standalone with ACE. See [Frameworks](#frameworks). |
| Node.js 18+ | Only from source | To build the panel (`ui/dist/`). Release packages ship it prebuilt. |
| ox_lib | No | Not used in 0.1.0. |

## 1. Copy the resource

Copy the folder into your resources directory **with the exact name `staff_suite`**:

```
resources/
└── [staff]/
    └── staff_suite/
        ├── fxmanifest.lua
        ├── config.lua          ← public config (client + server)
        ├── server/config.lua   ← private config (server only)
        ├── core/  locales/  server/  client/  shared/
        └── ui/dist/            ← built NUI panel
```

The name matters: panel callbacks (`https://staff_suite/...`) and exports (`exports.staff_suite`) rely on it.

If you downloaded the source code rather than a release package, `ui/dist/` is not included: build it with Node.js 18+ (`cd ui && npm ci && npm run build`). See [Panel](panel.md#building-the-panel).

## 2. Choose persistence

### Option A — JSON file (no database)

This is the default (`Config.Persistence = 'json'`). Nothing else is needed. Data is stored in `staff_suite_data.json` inside the resource folder.

### Option B — oxmysql + MySQL/MariaDB

1. Install and configure oxmysql following its docs (`mysql_connection_string` convar in your `server.cfg`).
2. In `config.lua`:
   ```lua
   Config.Persistence = 'oxmysql'
   ```
3. On start, Staff Suite creates the `staff_state` table itself (no manual SQL import).

**Automatic fallback:** if `Config.Persistence = 'oxmysql'` but oxmysql is not started when Staff Suite starts, the JSON file is used. That is why oxmysql must be `ensure`d **before** `staff_suite`.

## 3. server.cfg

```cfg
# database (optional)
set mysql_connection_string "mysql://user:password@localhost/my_server?charset=utf8mb4"
ensure oxmysql

# your framework (optional): es_extended / qb-core / qbx_core
ensure qb-core

# Discord webhook for audit anchors (optional). Use set, not setr.
set staff_suite_webhook "https://discord.com/api/webhooks/..."

# standalone: ranks via ACE (see Ranks and permissions)
add_ace group.admin staff_suite.admin allow

ensure staff_suite
```

Order: oxmysql → framework → Staff Suite convars → `staff_suite`. The webhook is read when the resource loads, so `set` must come before `ensure`.

## 4. First start

The server console should show:

```
[StaffSuite] started · 0 audit entries · persistence=json · framework=standalone
```

`persistence` shows the configured value (`json` or `oxmysql`) and `framework` the selected bridge. Test the chain from the console:

```
audit
```

→ `[StaffSuite] audit OK: N entries`.

## Frameworks

`Config.Framework = 'auto'` (default) picks the first one that is started, in this order: **Qbox → QBCore → ESX → standalone**. If you run more than one (e.g. Qbox with its qb-core compatibility layer), force it with `'qbox'`, `'qbcore'`, `'esx'` or `'standalone'`.

| Framework | Resource | Where the rank comes from | Display name |
|---|---|---|---|
| Qbox | `qbx_core` | ACE named after each `Config.RankMap` key (`IsPlayerAceAllowed(src, 'admin')`), plus `Config.JobRankMap.qbox` | character first and last name |
| QBCore | `qb-core` | `QBCore.Functions.HasPermission(src, <RankMap key>)`, plus `Config.JobRankMap.qbcore` | character first and last name |
| ESX Legacy | `es_extended` | xPlayer group (`getGroup()`) matched against `Config.RankMap` keys, plus `Config.JobRankMap.esx` | `getName()` |
| Standalone | — | ACE `staff_suite.<rank>` and `Config.StandaloneRanks` (in `server/config.lua`) | FiveM name |

How the rank is built is detailed in [Ranks and permissions](permissions.md).

With a framework active, a player who has not loaded a character yet has no rank (only `/report`) until they load.

## Commands

| Command | Who | What it does |
|---|---|---|
| `/report <category> <description>` | Any player | Creates a report. The first word is the category; if it is not in `Config.Categories`, it becomes `other`. E.g. `/report bug I fell through the map`. |
| `/duty` | `staff.duty` capability | Clocks in/out and records the shift. |
| `/audit` | `audit.view` capability (or console) | Verifies the chain. Console prints the result; in game it goes to the panel. |
| `/staffsuite` or `F6` | Anyone | Opens the NUI panel. Each player only sees what their capabilities allow. |

`/report`, `/duty` and `/audit` names can be changed in `Config.Commands`. See [Configuration](configuration.md).

## Next

- [Configuration](configuration.md)
- [Ranks and permissions](permissions.md)
- [Panel (NUI)](panel.md)
- [Audit: export and verification](audit.md)
- [FAQ and troubleshooting](faq.md)
