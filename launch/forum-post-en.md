# forum.cfx.re → FiveM Releases — post (EN)

> Posting notes (from the [Releases Rules and FAQ](https://forum.cfx.re/t/releases-rules-and-faq/240725)):
> - Two topics, 48 h apart: **(A) Lite** with the `free` tag (GitHub download), then **(B) Core** with the `paid` + `escrow` tags (Tebex). Each topic links to the other.
> - The first image **uploaded to the forum** (not an external link) becomes the preview → `cover-1280x720.png`.
> - Performance numbers are required: don't post until every `[RESMON PENDIENTE]` has the real client resmon.
> - Allowed links: Tebex, GitHub, YouTube, Discord, docs. No X/TikTok links.
> - Don't paste it as is: rewrite it in your own voice (the rules ask not to paste LLM output).
> - Don't say "open source" in the Core topic. Don't ask for reviews.
> - Before posting: re-check every feature against the claims matrix in `launch/README.md`.

---

## Topic titles
- Lite: `[FREE] Staff Integrity Suite Lite | Reports + tamper-evident audit log (SHA-256) | Standalone | EN/ES`
- Core: `[PAID] Staff Integrity Suite Core | Reports, in-ticket moderation & verifiable staff audit | Standalone / ESX / QBCore / Qbox | EN/ES`

---

## (A) Lite topic body

```markdown
![cover|690x388](upload://...)

Staff Integrity Suite Lite is a free report system with one twist: **every action taken from the panel goes into a SHA-256 hash chain, so nobody can quietly edit the history.**

Players report with `/report`. Your staff opens the panel with F6, claims the ticket, resolves it and closes it. Each step is written as an entry that contains the hash of the previous one. Click "Verify chain" (or run `/audit` in the console) and you'll know if someone edited, deleted or reordered anything, and which entry it was.

## Preview
{{YOUTUBE_EN}}

## Features
* `/report <category> <description>`, up to 3 open reports per player.
* Ticket queue in the panel (F6 or `/reports`): claim (no double claims), reply to the player, resolve with a note, close, reopen.
* Players see their open reports in "My reports", reply there and get a notification when staff answers.
* Audit viewer with filters and a "Verify chain" button. The broken entry turns red.
* Standalone: one ACE permission, JSON storage, no database.
* Rate limits and text limits so nobody floods your queue.
* Spanish and English.
* MIT license: the Lua is yours to read and change.

## Performance
* Client resmon: [RESMON PENDIENTE]
* Tested on a real FXServer: 32/32 E2E checks.
* No per-tick loops on the server.

## Installation
1. Download from {{GITHUB_URL}} and drop the folder into `resources/` as `staff_suite`.
2. Add `add_ace group.admin staff_suite.lite allow` and `ensure staff_suite` to `server.cfg`.

## Want more?
Core adds moderation from the ticket (ban, warn, spectate, revive and more), duty and per-staff stats, player ratings, screenshot evidence, framework and txAdmin event logging, oxmysql and a hash anchor in Discord. It keeps your Lite tickets and chain. → {{CORE_TOPIC_URL}}

## Links
* **Download:** {{GITHUB_URL}}
* **Docs:** {{DOCS_URL}}
* **Support (EN/ES):** {{DISCORD_URL}}

[details="En español"]
(paste section (A) of forum-post-es.md here)
[/details]

|                             |                                          |
|-----------------------------|------------------------------------------|
| Code is accessible          | Yes (MIT)                                |
| Subscription-based          | No                                       |
| Lines (approximately)       | ~700 Lua + UI                            |
| Requirements & dependencies | Up-to-date FXServer                      |
| Support                     | Yes                                      |
```

---

## (B) Core topic body

```markdown
![cover|690x388](upload://...)

Staff Integrity Suite Core handles your staff's workflow (reports, moderation, duty) and keeps **a record of what your staff does that can't be quietly edited.**

Every report, claim, ban, warning, shift and verification is written to a SHA-256 hash chain. Each entry contains the hash of the previous one. Verify it from the panel or with `/audit`: if someone edited, deleted or reordered an entry, you'll see exactly which one. Every 20 entries the current hash also goes to a Discord webhook and a separate file, so even a full rewrite shows up.

It runs next to txAdmin, not instead of it. Noclip, god mode and spawning stay in txAdmin.

## Preview
{{YOUTUBE_EN}}
If the video doesn't load, [click here]({{YOUTUBE_EN}}).

## Features

**Audit log**
* Who, what, to whom, when and why, each entry chained to the previous one.
* Viewer with filters by staff member, action and date. The altered entry turns red and everything after it is flagged.
* Off-server anchor: Discord webhook + append-only file.
* Logs ESX (job, group, items, money), QBCore/Qbox (job, money, groups) and txAdmin (ban, kick, warn, heal) events.
* `exports.staff_suite:Record(...)` so your own scripts can write to the same chain.

**Tickets**
* Claim, unclaim, transfer to another online staff member, priorities and internal notes.
* Chat with the player: they read and reply in "My reports" and get notified when staff answers. Internal notes stay hidden from them.
* Canned replies you define in `config.lua`.
* The player rates the help from 1 to 5 when the ticket is resolved.
* Evidence with screenshot-basic: the hash of the capture goes into the chain and the panel checks it again when you open it.

**Moderation from the ticket**
* Goto, bring, freeze, unfreeze, heal, kick, warn, ban, spectate, revive, each behind its own permission. The panel shows who's frozen.
* Temporary or permanent bans across license, license2, FiveM, Steam, Discord, Xbox and hardware tokens. If the player comes back on a new account that shares one of them, the ban follows. No IP bans.
* Bans and warnings require a reason. Kicks too, unless you turn it off.
* Nobody can bring, freeze, kick, warn or ban a higher rank. This is checked on the server.
* Revive uses your framework's medical system, or a standalone fallback.

**Duty and stats**
* `/duty` or the panel button. Hours and sessions per staff member.
* Dashboard and leaderboard: resolved tickets, first-response time, average rating.

**Setup**
* Standalone (ACE), ESX, QBCore or Qbox, detected automatically. Nobody is staff by default: 5 ranks, 20 permissions, per-person overrides.
* JSON, or oxmysql with automatic migrations on start.
* Per-player rate limits and text limits.
* Spanish and English.

## What it does NOT do
* It's not an anticheat and it doesn't stop every abuse. It makes abuse visible and hard to erase.
* It only sees what goes through it, the supported framework/txAdmin events and whatever you send through `Record`.
* It's not an admin menu. Keep txAdmin.

## Performance
* Client resmon: [RESMON PENDIENTE]
* Server, per call (measured in the E2E on a real FXServer): `Record` 0.09 ms, `GetState` 0.30 ms. No per-tick loops on the server.
* E2E on a real FXServer: 30/30 checks.

## Installation
1. Buy on {{TEBEX_URL}}. The resource shows up in your cfx.re account (Granted Assets).
2. Drop `staff_suite` into `resources/` and add `ensure staff_suite` to `server.cfg`.
3. In `config.lua`: language, framework (`auto`) and rank mapping. Standalone: `add_ace group.admin staff_suite.admin allow`.
4. Optional Discord anchor: `set staff_suite_webhook "URL"` in `server.cfg` (server-only, don't use `setr`).
5. Optional: `ensure oxmysql` before the resource and the tables are created on start. `ensure screenshot-basic` for evidence.
Coming from Lite? Replace the files and keep the name `staff_suite`: your tickets and chain stay.
Full docs: {{DOCS_URL}}

## Links
* **Core:** {{TEBEX_URL}}
* **Lite (free):** {{LITE_TOPIC_URL}}
* **Docs:** {{DOCS_URL}}
* **Support (EN/ES):** {{DISCORD_URL}}

[details="En español"]
(paste section (B) of forum-post-es.md here)
[/details]

|                             |                                          |
|-----------------------------|------------------------------------------|
| Code is accessible          | Partial (config, locales and SQL open; the rest escrowed) |
| Subscription-based          | No                                       |
| Lines (approximately)       | ~2,400 Lua + UI                          |
| Requirements & dependencies | Up-to-date FXServer with OneSync; optional: oxmysql, ESX/QBCore/Qbox, screenshot-basic |
| Support                     | Yes                                      |
```

> Line counts: non-comment Lua without tests or locales, measured on 19/11/2026. Recount when packaging.
