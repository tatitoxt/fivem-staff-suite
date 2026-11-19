# forum.cfx.re → FiveM Releases — post (EN)

> Posting notes (from the [Releases Rules and FAQ](https://forum.cfx.re/t/releases-rules-and-faq/240725)):
> - Two topics, published 48 h apart: **(A) Lite** with the `free` tag, then **(B) Core** with the `paid` + `escrow` tags. Or a single Core topic with the `paid` + `escrow` tags and a link to the free Lite.
> - The first image **uploaded to the forum** (not an external link) becomes the preview → `cover-1280x720.png`.
> - Mandatory table at the end for paid/escrow releases. Performance numbers (resmon) are required → fill `{{RESMON_*}}` after #19.
> - Allowed links: Tebex, GitHub, YouTube, Discord, docs. No X/TikTok links.
> - Don't paste it as is: rewrite it in your own voice (the rules ask not to paste LLM output).
> - Don't say "open source" in the paid topic. Don't ask for reviews.
> - Before posting: re-check every feature against the claims matrix in `launch/README.md`.

---

## Topic title
- Lite: `[FREE] Staff Integrity Suite Lite | Reports + tamper-evident staff audit log (SHA-256) | Standalone / ESX / QBCore / Qbox | EN/ES`
- Core: `[PAID] Staff Integrity Suite | Reports, in-ticket moderation & verifiable staff audit | Standalone / ESX / QBCore / Qbox | EN/ES`
- The bridges are tested with mocks. Confirm them on a real server with each framework (#19) before posting.

## Body (Core topic; for Lite, drop the "Core adds" section and use the Lite table)

```markdown
![cover|690x388](upload://...)

Staff Integrity Suite is a report and staff-workflow resource with one specific focus: **a record of what your staff does that can't be quietly edited.**

Every report, claim, moderation action and duty shift is written to a SHA-256 hash chain. Each entry contains the hash of the previous one. Run `/audit` and the server recomputes the whole chain: if someone edited, deleted or reordered an entry, it tells you exactly which one.

It works next to txAdmin, not instead of it. Noclip, god mode and spawning stay in txAdmin.

## Preview
{{YOUTUBE_EN}}
If the video doesn't load, [click here]({{YOUTUBE_EN}}).

## Features

**Audit log (the reason this exists)**
* **Hash-chained entries:** who, what, to whom, when and why, each one linked to the previous one with SHA-256.
* **Tamper detection:** edited, deleted or reordered entries are detected, and the broken entry is reported.
* **Off-server anchor:** every N entries (default 20) the current hash goes to a Discord webhook and an append-only log file. If someone rewrites the whole chain, it won't match the anchor.
* **On-demand verification:** `/audit` from the server console or in-game. The verification itself is logged.
* **API:** `exports.staff_suite:Record(action, actor, target, reason, payload)` lets your other scripts write to the same chain.

**Reports**
* `/report <category> <description>`, with configurable categories.
* Claim, unclaim, transfer, resolve, close and reopen. Double claims are blocked.
* Every ticket step goes into the audit chain.

**Core adds**
* **Moderation from the ticket:** goto, bring, freeze, heal, kick. Kicks require a reason. Every action goes into the chain.
* **Rank permissions:** 5 ranks, 20 capabilities, per-person grants and revokes.
* **Ranks from your framework:** detects Qbox, QBCore or ESX (or force it with `Config.Framework`) and maps groups, permissions and jobs to ranks (`Config.RankMap`, `Config.JobRankMap`). Standalone uses ACE (`staff_suite.<rank>`). Nobody gets staff permissions until you configure them.
* **Admin command logging (best-effort):** `ban`, `kick`, `warn`, `giveitem`, `givemoney`, `setjob`.
* **Duty:** `/duty` on/off, shift length logged.
* **Storage:** JSON with no database, or oxmysql.

**Coming soon** (no dates; announced here when tested)
* In-game panel (F6) with ticket queue, audit timeline and team view. Staff messages, internal notes and priorities already work server-side; they need the panel
* Chat with the player and player ratings
* ban / warn / spectate / revive actions
* Staff analytics: hours, resolved tickets, response time, leaderboard

## What it does NOT do
* It's not an anticheat and it doesn't stop abuse. It makes abuse visible and hard to erase.
* It can't intercept everything other resources do on their own. It logs what goes through it, the listed commands, and whatever you send through `Record`.
* It's not an admin menu. Keep txAdmin.

## Performance
* Idle: {{RESMON_IDLE}} ms · Active (panel open): {{RESMON_ACTIVO}} ms (resmon, server with {{N}} players)
* No per-tick loops on the server. State is saved every 60 s and on resource stop.

## Installation
1. Download from {{TEBEX_URL}} (Core) / {{GITHUB_URL}} (Lite).
2. Drop `staff_suite` into `resources/` and add `ensure staff_suite` to `server.cfg`.
3. In `config.lua`: language, commands, framework (`auto` by default) and rank mapping. Standalone: `add_ace group.admin staff_suite.admin allow` in `server.cfg`.
4. Optional Discord anchor: `set staff_suite_webhook "URL"` in `server.cfg`. It stays server-side (don't use `setr`).
Full docs: {{DOCS_URL}}

## Links
* **Lite (free):** {{GITHUB_URL}}
* **Core:** {{TEBEX_URL}}
* **Docs:** {{DOCS_URL}}
* **Support (EN/ES):** {{DISCORD_URL}}

[details="En español"]
(paste the body of forum-post-es.md here)
[/details]

|                             |                                          |
|-----------------------------|------------------------------------------|
| Code is accessible          | Partial (config, locales and UI open; core escrowed) |
| Subscription-based          | No                                       |
| Lines (approximately)       | ~{{LINEAS}}                              |
| Requirements & dependencies | Up-to-date FXServer, OneSync (moderation actions); oxmysql optional; ESX/QBCore/Qbox optional |
| Support                     | Yes                                      |
```

## Table for the Lite topic (if it's published via GitHub with no escrow, the table isn't mandatory but helps)
```markdown
|                             |                                          |
|-----------------------------|------------------------------------------|
| Code is accessible          | Yes                                      |
| Subscription-based          | No                                       |
| Lines (approximately)       | ~{{LINEAS}}                              |
| Requirements & dependencies | Up-to-date FXServer; oxmysql optional    |
| Support                     | Yes                                      |
```

> `{{LINEAS}}`: on 19/11/2026 the resource has ~1,000 Lua lines without comments, blank lines or tests. Recount when packaging.
