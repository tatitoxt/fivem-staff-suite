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
| Players | `player.online.view` | ID, name, ping and playtime. Search by name or ID. Staff with `report.view` also see open ticket counts. Quick actions use their existing moderation permissions. |
| Weekly activity | `staff.analytics` | Last seven days of duty time, shift starts, resolutions and ratings from the audit chain. Senior admins and owners can prepare a copyable CSV with `staff.analytics.export`. |
| Duty | `staff.duty` | Button to go on or off duty (same as `/duty`), your hours and sessions, and the team's status. |
| Settings | none | Panel language (ES/EN), open key, export status (webhook, file, anchor every N entries), version, your rank and persistence. In Core, `staff.chat` enables staff chat. |

Open **Staff chat** from **Settings** or with **Ctrl+K**. Staff messages appear in the FiveM chat for connected players with `staff.chat`. A notification also appears when their panel is open or the `chat` resource is stopped. The audit chain stores each request and result without the message text. Messages follow `Config.Limits.message_body` and `Config.RateLimit['staff_suite:staffChat']`.

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
- In Core, enable `Config.WarnEscalation` in the server configuration to use automatic kicks. When saved warnings reach the threshold within the window, a warning from staff with `mod.warn_escalate`, `mod.warn` and `mod.kick` can kick the player once per window. The rule is disabled by default. It uses the verifiable audit history and the panel shows when it can apply.
- Spectate requires the target to be in the same instance. Press Backspace to exit.
- Revive uses the framework's medical integration when available, with a standalone implementation for other setups.

With `staff.waypoint`, set a point on the map and use **Settings → Go to waypoint** or **Ctrl+K → Go to waypoint** to move your own character on foot. The audit log stores the server authorization and the result reported by the client.

In Core, open **Ban list** from **Settings** or with **Ctrl+K** to see who issued each ban, its status, expiry and the number of linked identifiers. `ban.view` grants access to admins and above. `ban.revoke` allows senior admins and above to revoke a ban with a reason. Legacy bans can be revoked when the audit history identifies their aliases.

## Language

The initial language is `Config.Locale`. From Settings each player changes it for their own panel only; it is not saved between sessions. Strings come from `locales/es.lua` and `locales/en.lua` (`ui_*` keys), so you can edit them without rebuilding.

In Core, **Player profile** in the ticket actions shows up to 20 recent entries of each kind for the reporter, including warnings, bans, reports, and notes. This requires `report.view` and `player.profile.view`. `player.profile.note` allows staff to add notes up to `Config.Limits.message_body` bytes. Profile views and notes are recorded in the audit chain.

The profile also shows the time connected since this version was installed, including time spent AFK. Totals are saved every minute, on disconnect and on resource shutdown. An abrupt shutdown can lose the time since the last save.

In Core, **Sanction templates** appear in ticket moderation for staff with `mod.template` and the corresponding sanction permission. The server-side `Config.SanctionTemplates` defines an action, an ES/EN reason key and, for bans, a duration in seconds. The confirmation shows the reason and duration. The audit entry includes the template ID.

## Development

`cd ui && npm run dev` serves the panel in the browser with demo data and a mocked backend. See `ui/README.md`.

### Ranks and ACE permissions (Core)

The owner can open **Ranks and ACE permissions** from Settings or Ctrl+K and choose a connected player. **Inherit** restores the bridge rank or, for an individual permission, access from the rank and native `staff_suite.cap.<capability>` grants. **Allow** and **Deny** save an exception for that account in Staff Suite. Each change requires a reason and is saved with its audit entry. Configure owner rank in the server or framework.
# Panel (NUI)
