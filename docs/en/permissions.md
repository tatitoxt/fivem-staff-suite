# Ranks and permissions

Staff Suite uses **capabilities** (atomic permissions) grouped into **ranks**, following least privilege. Everything is checked on the server; the client never decides.

## How the rank is assigned

Every time a player does something, the server resolves their rank with the bridge chosen by `Config.Framework` (see [Installation](installation.md#frameworks)). A player **without a rank** has no capabilities: they can use `/report` and nothing else.

### With a framework (Qbox / QBCore / ESX)

Staff Suite walks `Config.RankMap` and asks the framework about each key:

| Framework | Check |
|---|---|
| Qbox | `IsPlayerAceAllowed(src, key)`. E.g. `add_ace group.admin admin allow` → `admin`. |
| QBCore | `QBCore.Functions.HasPermission(src, key)`. |
| ESX | `xPlayer.getGroup() == key`. |

On top of that, if the player's active job is in `Config.JobRankMap.<framework>`, that rank also counts. If several match, **the highest wins**. With a framework active, `staff_suite.<rank>` ACEs and `Config.StandaloneRanks` are **not** used.

### Standalone

Two sources, the highest wins:

1. `staff_suite.<rank>` ACE in `server.cfg`:
   ```cfg
   add_ace group.admin staff_suite.admin allow
   add_principal identifier.license:1234abcd... group.admin
   ```
2. `Config.StandaloneRanks` in `server/config.lua`, by `license:...` identifier.

Valid ranks: `helper`, `moderator`, `admin`, `senior_admin`, `owner`. Any other rank name is ignored.

## Ranks

| Rank | Summary |
|---|---|
| `helper` | Sees and handles reports, chat, duty. |
| `moderator` | + resolve/transfer reports, basic moderation, view audit log. |
| `admin` | + verify the chain, staff analytics. |
| `senior_admin` | + capabilities reserved for export and configuration. |
| `owner` | Every capability. |

## Capability matrix

| Capability | helper | moderator | admin | senior_admin | owner |
|---|:-:|:-:|:-:|:-:|:-:|
| `report.view` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `report.claim` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `report.message` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `report.resolve` | | ✓ | ✓ | ✓ | ✓ |
| `mod.goto` / `mod.bring` / `mod.spectate` | | ✓ | ✓ | ✓ | ✓ |
| `mod.freeze` / `mod.heal` | | ✓ | ✓ | ✓ | ✓ |
| `mod.kick` / `mod.warn` | | ✓ | ✓ | ✓ | ✓ |
| `mod.revive` / `mod.ban` | | | ✓ | ✓ | ✓ |
| `audit.view` | | ✓ | ✓ | ✓ | ✓ |
| `audit.verify` | | | ✓ | ✓ | ✓ |
| `audit.export` | | | | ✓ | ✓ |
| `staff.duty` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `staff.analytics` | | | ✓ | ✓ | ✓ |
| `admin.config` | | | | ✓ | ✓ |
| `admin.permissions` | | | | | ✓ |

Source: `core/permissions.lua`.

## What each capability controls

| Capability | Controls |
|---|---|
| `report.view` | receiving the ticket queue in the panel |
| `report.claim` | claiming, starting and unclaiming a ticket; being able to receive a transfer |
| `report.resolve` | transferring, resolving, closing and reopening |
| `report.message` | writing in a ticket (together with `report.view`), including internal notes |
| `mod.<action>` | moderation actions from the panel |
| `audit.view` | seeing audit entries in the panel and `/audit` in game |
| `audit.verify` | the panel's "Verify chain" button (adds an `audit_verify` entry) |
| `staff.duty` | `/duty` |
| `staff.analytics` | staff duty stats and alerts (e.g. broken chain) |
| `audit.export`, `admin.config`, `admin.permissions` | defined in the model, not used yet **(coming soon)** |

The panel only receives the data the player's capabilities allow. `/report` needs no capability.

A transfer is only accepted if the recipient is online and has `report.claim` and `report.view`.

## Moderation

Every action goes through: capability check → online target (by server id or identifier) → mandatory reason for `ban` and `warn`, and for `kick` if `Config.Moderation.require_reason` → execution → audit entry (`mod_<action>`).

| Action | Status in 0.1.0 |
|---|---|
| `goto`, `bring`, `freeze`, `heal`, `kick` | Working. |
| `ban`, `warn`, `spectate`, `revive` | Available in the panel to staff with the corresponding capability. |
| Unfreeze | **(coming soon)** |

Noclip, god mode and spawning remain in txAdmin or your framework.

## Per-person overrides (coming soon)

The core already supports granting or revoking a single capability for an identifier on top of their rank (`revoke` beats `grant`, `grant` beats the rank). There is no command or screen to manage them yet **(coming soon)**.
