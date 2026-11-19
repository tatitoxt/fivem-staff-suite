# Ranks and permissions

Staff Suite uses **capabilities** (atomic permissions) grouped into **ranks**, following least privilege. Everything is validated server-side; the client never decides.

## Status in 0.1.0

> **Read this before using it in production.** In 0.1.0 every player gets the rank set in `Config.StandaloneRank` (default `'owner'` = all capabilities). Framework/ACE rank mapping is not wired yet **(coming soon)**. Until then, use it on a test server or with trusted players only.

Lowering `Config.StandaloneRank` (e.g. to `'helper'`) restricts **everyone** equally, including you.

## Ranks

| Rank | Summary |
|---|---|
| `helper` | Views and handles reports, chat, duty. |
| `moderator` | + resolve reports, basic moderation (goto/bring/spectate/freeze/heal/kick/warn), view audit log. |
| `admin` | + revive, ban, verify the chain, staff analytics. |
| `senior_admin` | + export audit log, configuration. |
| `owner` | All capabilities. |

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

## What each capability controls today

| Capability | Used in 0.1.0 for |
|---|---|
| `staff.duty` | `/duty` |
| `audit.view` | in-game `/audit` |
| `audit.verify` | the panel's "Verify chain" button (records an `audit_verify` entry) |
| `report.claim` | every ticket action from the panel (claim, transfer, resolve, close, reopen) |
| `mod.<action>` | moderation actions from the panel |
| `report.view`, `report.resolve`, `report.message`, `audit.export`, `staff.analytics`, `admin.config`, `admin.permissions` | defined in the model; fine-grained enforcement comes with the panel **(coming soon)** |

`/report` requires no capability: any player can report.

## Moderation

Every moderation action goes through: capability check → mandatory reason (when `Config.Moderation.require_reason` is on and the action is `kick`, `ban` or `warn`) → execution → audit entry (`mod_<action>`).

| Action | Status in 0.1.0 |
|---|---|
| `goto`, `bring`, `freeze`, `heal`, `kick` | Working. |
| `ban`, `warn`, `spectate`, `revive` | Validated and recorded in the audit log, but they do nothing in game yet **(coming soon)**. |
| Unfreeze | **(coming soon)** |

Staff Suite does **not** replace txAdmin: noclip, god mode, spawning, etc. stay in txAdmin.

## Per-person overrides (coming soon)

The core already supports granting or revoking a single capability for an identifier (`license:...`) on top of their rank (`revoke` beats `grant`, and `grant` beats the rank). There is no command or screen to manage them yet **(coming soon)**.

## Framework / ACE mapping (coming soon)

Once wired, the existing bridges will map as follows:

| Source | Mapping |
|---|---|
| ESX | player group → `Config.RankMap` |
| QBCore / Qbox | `god` permission → `owner`, `admin` → `admin`, `mod` → `moderator` |
| Standalone (ACE) | `staff_suite.owner`, `staff_suite.senior_admin`, `staff_suite.admin`, `staff_suite.moderator`, `staff_suite.helper` |
