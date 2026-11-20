# Audit: off-box export and chain verification

## How the chain works

Every action becomes an entry with `seq`, `ts`, `actor`, `action`, `target`, `reason`, `payload`, `prev_hash` and `hash`. Each `hash` includes the previous entry's `hash`:

```
hash = SHA-256( seq ␟ ts ␟ actor ␟ action ␟ target ␟ reason ␟ payload ␞ prev_hash )
```

- `␟` = byte `0x1F`, `␞` = byte `0x1E`; output is lowercase hex (64 characters).
- The first entry uses 64 zeros as `prev_hash` (genesis).

If someone edits a field, deletes an entry in the middle or reorders entries, the hashes stop matching and verification reports the first broken entry.

## What gets recorded (0.2.0)

| Action | Source |
|---|---|
| `ticket_create`, `ticket_claim`, `ticket_unclaim`, `ticket_transfer`, `ticket_start`, `ticket_resolve`, `ticket_close`, `ticket_reopen` | reports (`/report`, panel and the `TicketAction` export) |
| `ticket_message` | ticket messages (the `payload` says whether it is an internal note, not the text) |
| `mod_<action>` | moderation from the panel (`goto`, `bring`, `freeze`, `unfreeze`, `heal`, `kick`, `ban`, `warn`, `spectate`, `revive`) |
| `mod_ban_failed` | ban attempt that failed to take effect because of a persistence error |
| `duty.in`, `duty.out` | `/duty` and the `SetDuty` export |
| `audit_verify` | verification from the panel (result in `reason`) |
| `framework_job`, `framework_group`, `framework_item_added`, `framework_money` | events from the active framework when `Config.Audit.capture_framework = true` |
| `txadmin_ban`, `txadmin_kick`, `txadmin_warn`, `txadmin_heal` | txAdmin events controlled by the same setting |
| whatever another resource sends | `Record` export (see below) |

External coverage depends on the events emitted by the resource and its version. Framework events may identify the affected player without identifying the person who made the change. Use the `Record` export to log operations from other resources.

## Verifying the chain

| Where | How | Requires |
|---|---|---|
| Server console | `audit` → `[StaffSuite] audit OK: N entries` or `audit BROKEN at entry <seq>` | console access |
| In game | `/audit` (result goes to the panel) | `audit.view` |
| Panel | "Verify chain" button | `audit.verify` |
| Panel (alert) | if the chain is broken, the panel shows an alert | `staff.analytics` |
| Another resource (server) | `local ok, seq = exports.staff_suite:Verify()` | — |

`verify` recomputes the whole chain from genesis. On its own it does **not** catch two cases: deleting the last entries, or rewriting the whole chain and recomputing every hash. That is what off-box anchors are for.

## Off-box export (anchors)

Every `Config.Export.anchor_every` entries (default 20, i.e. `seq` 20, 40, 60…; set in `server/config.lua`) Staff Suite anchors the current entry:

- **File** (`Config.Export.file = true`): appends a line to `audit_export.log` in the resource folder:
  ```
  seq|hash|prev_hash|action
  40|9f2c…e1|51ab…07|ticket_resolve
  ```
  This file lives on the same machine: for it to count as evidence, copy it off the server (backup, another host, cloud). A copy that staff with server access cannot touch is the one that matters.
- **Discord** (`set staff_suite_webhook "URL"` in `server.cfg`, read by `server/config.lua`): posts a message with the `seq` and the first 16 characters of the hash. Discord messages are timestamped and live outside your server. Use `set`, not `setr`, so the URL never reaches clients.

### Checking against an anchor

For each anchor (`seq`, `hash`) stored off-box, the `hash` of the entry with that `seq` in the current chain must be **identical** (for Discord, it must start the same). If it differs, or the chain has fewer entries than the last anchored `seq`, history was rewritten or truncated.

Example check from your own resource (server-side):

```lua
RegisterCommand('ss_checkanchor', function(src, args)
  if src ~= 0 then return end -- console only
  local seq, expected = tonumber(args[1]), args[2]
  local e = exports.staff_suite:GetChain()[seq]
  if not e then print('entry ' .. seq .. ' missing: chain truncated'); return end
  print(e.hash:sub(1, #expected) == expected and 'anchor OK' or 'anchor MISMATCH')
end, true)
```

Console usage: `ss_checkanchor 40 9f2c1a...`.

Automatic comparison against anchors (the core already has `verify_head`) and an offline verification tool are **(coming soon)**.

## Exports for other resources (server-side)

**Return contract:** on success an export returns its value; on failure it returns `false, code` (for example `false, 'already_claimed'`). It never returns `nil` as the first value: cross-resource calls serialize returns with msgpack, and a leading `nil` drops the error code. Until persistence finishes loading, every export returns `false, 'persistence_starting'`.

```lua
local ticket, err = exports.staff_suite:TicketAction(id, 'claim', 'license:abc', { ts = os.time() })
if not ticket then print('failed: ' .. err) end
```

| Export | Description |
|---|---|
| `Record(action, actor, target, reason, payload)` | Appends an entry. `payload` is a table (stored as JSON). Returns the entry. |
| `Verify()` | `ok, broken_seq` |
| `GetChain()` | Copy of all entries. |
| `CreateTicket(data)` | Creates a ticket (`reporter`, `category`, `priority`, `description`, `ts`). Returns the id. |
| `TicketAction(id, action, actor, extra)` | Ticket transition (`claim`, `unclaim`, `transfer`, `start`, `resolve`, `close`, `reopen`) plus its audit entry. Returns `ticket, event` or `false, error`. For `transfer`, `extra.to` is the recipient's identifier. |
| `GetState()` | Full state (chain, tickets, permissions, duty). |
| `SetDuty(actor, onDuty)` | Clock in (`true`) or out (`false`) with its `duty.in`/`duty.out` entry. Returns the event or `false, error`. |
| `Flush()` | Saves now instead of waiting for the deferred batch (~1 s). Returns the revision number to confirm. |
| `GetPersistence()` | `{ revision, saved, pending }`: the `Flush()` save is confirmed once `saved >= revision`. |

Example:

```lua
exports.staff_suite:Record('grant_money', 'license:abc', 'license:def', 'event prize', { amount = 5000 })
```

The chain proves an entry was **not modified after it was written**, not that what the other resource reported is true. Only call `Record` from trusted scripts.

## If the chain shows as broken

1. Do not touch anything else. Write down the `seq` reported by verification.
2. Compare with your latest off-box copy of `audit_export.log` and the webhook messages.
3. Check who had access to the database or `staff_suite_data.json` during that period.
4. To keep operating, restore the most recent intact backup. Hand-editing the file to "fix" it leaves the chain broken anyway: that is by design.
