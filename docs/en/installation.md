# Installation

> Documented version: **0.1.0**. Anything marked **(coming soon)** is planned but not implemented yet.

## Requirements

| Requirement | Required? | Notes |
|---|---|---|
| Recent FXServer with Lua 5.4 | Yes | The resource uses `fx_version 'cerulean'` and `lua54 'yes'`. |
| [oxmysql](https://github.com/overextended/oxmysql) + MySQL/MariaDB | No | Only if you want to store data in a database. Without oxmysql a JSON file is used. |
| Framework (ESX / QBCore / Qbox) | No | The resource runs standalone. See [Frameworks](#frameworks). |
| ox_lib | No | Not used in 0.1.0. |

## 1. Copy the resource

Copy the folder into your resources directory **named exactly `staff_suite`**:

```
resources/
└── [staff]/
    └── staff_suite/
        ├── fxmanifest.lua
        ├── config.lua
        ├── core/  locales/  server/  client/  shared/
        └── ui/dist/        ← built NUI panel
```

The name matters: the panel callbacks (`https://staff_suite/...`) and the exports (`exports.staff_suite`) use it.

## 2. Choose persistence

### Option A — JSON file (no database)

This is the default (`Config.Persistence = 'json'`). Nothing else is needed. Data is saved to `staff_suite_data.json` inside the resource folder.

### Option B — oxmysql + MySQL/MariaDB

1. Install and configure oxmysql following its documentation (`mysql_connection_string` convar in your `server.cfg`).
2. In `config.lua`:
   ```lua
   Config.Persistence = 'oxmysql'
   ```
3. On start, Staff Suite creates the `staff_state` table by itself (no manual SQL import).

**Automatic fallback:** if `Config.Persistence = 'oxmysql'` but oxmysql is not started when Staff Suite starts, the JSON file is used. That is why oxmysql must be ensured **before** `staff_suite`.

## 3. server.cfg

```cfg
# database (optional)
set mysql_connection_string "mysql://user:password@localhost/my_server?charset=utf8mb4"
ensure oxmysql

# your framework (optional): es_extended / qb-core / qbx_core
ensure qb-core

ensure staff_suite
```

Order: oxmysql → framework → `staff_suite`.

## 4. First start

The server console should show:

```
[StaffSuite] iniciado · 0 entradas de auditoría · persistencia=json
```

(or `persistencia=oxmysql`; in 0.1.0 this console line is always in Spanish). Check the chain from the console:

```
audit
```

→ `[StaffSuite] audit OK: N entries`.

## Frameworks

| Framework | Status in 0.1.0 |
|---|---|
| Standalone | Works. This is the current mode for every server. |
| ESX Legacy | Bridge written (`server/bridges/esx.lua`), **not wired into the resource yet** **(coming soon)**. |
| QBCore | Bridge written (`server/bridges/qbcore.lua`), **not wired yet** **(coming soon)**. |
| Qbox (`qbx_core`) | Bridge written (`server/bridges/qbox.lua`), **not wired yet** **(coming soon)**. |

You can run any of these frameworks alongside Staff Suite without conflicts, but in 0.1.0 it does not read their groups or use their kick/ban functions yet.

> **Important (0.1.0):** every player currently gets the rank set in `Config.StandaloneRank`, which defaults to `'owner'` (all capabilities). Use this version on a test server until framework/ACE rank mapping ships. Details in [Ranks and permissions](permissions.md).

## Commands

| Command | Who | What it does |
|---|---|---|
| `/report <category> <description>` | Any player | Creates a report. E.g. `/report bug fell through the map`. |
| `/duty` | `staff.duty` capability | Toggles on/off duty and records the shift. |
| `/audit` | `audit.view` capability (or console) | Verifies the chain. The console prints the result; in game it is sent to the panel. |
| `/staffsuite` or `F6` key | Staff | Opens the NUI panel. |

The names of `/report`, `/duty` and `/audit` can be changed in `Config.Commands`. See [Configuration](configuration.md).

## Next

- [Configuration](configuration.md)
- [Ranks and permissions](permissions.md)
- [Audit: export and verification](audit.md)
- [FAQ and troubleshooting](faq.md)
