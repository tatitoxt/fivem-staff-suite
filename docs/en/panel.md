# Panel (NUI)

> Documented version: **0.2.0**. Anything marked **(coming soon)** is planned but not implemented yet.

Open the panel with `/staffsuite` or the `F6` key (`Config.PanelKey`) and close it with `Esc`. It is built with React 18 + TypeScript + Vite (source in `ui/`) and the resource loads the compiled build from `ui/dist/`.

## Building the panel

`ui/dist/` is not in the repo. If you install from source (not from a release package), build it once with Node.js 18 or later:

```bash
cd ui && npm ci && npm run build
```

It produces `ui/dist/index.html` and `ui/dist/assets/*`, which is what `fxmanifest.lua` lists. The server only needs `ui/dist/`; `ui/src` and `ui/node_modules` are not used at runtime.

## Who sees what

The server only sends the data the player's capabilities allow (see [Ranks and permissions](permissions.md)) and the panel hides views without permission. If the current view is not allowed, it jumps to the first one that is.

| View | Capability | What it shows |
|---|---|---|
| Audit | `audit.view` | Entry timeline with filters and details (actor, action, target, reason, hash). "Verify chain" button with `audit.verify`. If the chain is broken, it marks the first mismatching entry and the following ones as unverified. |
| Reports | `report.view` | Ticket queue, ticket chat, internal notes and the moderation rail. |
| My reports | none | Your open reports and their public conversations with staff. |
| Dashboard | `staff.analytics` | KPIs (open, resolved, response time, staff on duty), leaderboard and alerts, such as a broken audit chain. |
| Duty | `staff.duty` | Button to go on or off duty (same as `/duty`), your hours and sessions, and the team's status. |
| Settings | none | Panel language (ES/EN), open key, export status (webhook, file, anchor every N entries), version, your rank and persistence. |

Create reports with `/report`. In My reports, you can read and reply to the public thread of each open report. You get a notification when staff replies. Public chat is available in Core and Lite.

## Reports

| Panel action | Capability | States where it shows |
|---|---|---|
| Claim | `report.claim` | open, reopened |
| Transfer to another online staff member | `report.resolve` | claimed |
| Resolve (with resolution text) | `report.resolve` | claimed, in progress |
| Close | `report.resolve` | any except closed |
| Reopen | `report.resolve` | resolved, closed |
| Public message | `report.message` | open, claimed, in progress, reopened |
| Internal note (Core) | `report.message` | any except closed |

The server sends the list of transfer recipients: online staff who can claim reports. Unclaiming a ticket and moving it to "in progress" have no button yet **(coming soon)**; use the `TicketAction` export.

## Moderation

The ticket's moderation rail acts on the player who filed the report. Freeze and Unfreeze share `mod.freeze`. The other buttons need `mod.<action>`. With `Config.Moderation.require_reason = true`, kick requires a reason.

- Ban and warn always require a reason. Bans can be temporary or permanent, and warned players get an in-game notification.
- Spectate requires the target to be in the same instance. Press Backspace to exit.
- Revive uses the framework's medical integration when available, with a standalone implementation for other setups.

In Core, **Settings → Ban list** shows who issued each ban, its status, expiry and the number of linked identifiers. `ban.view` grants access to admins and above. `ban.revoke` allows senior admins and above to revoke a ban with a reason. Legacy bans can be revoked when the audit history identifies their aliases.

## Language

The initial language is `Config.Locale`. From Settings each player changes it for their own panel only; it is not saved between sessions. Strings come from `locales/es.lua` and `locales/en.lua` (`ui_*` keys), so you can edit them without rebuilding.

## Development

`cd ui && npm run dev` serves the panel in the browser with demo data and a mocked backend. See `ui/README.md`.
