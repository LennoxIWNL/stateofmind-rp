# som-phone

The phone. Primary interface for anything without a physical anchor, per
`AUDIT.md` 14.5.

**Phase 4b-1: shell, app framework, bank, settings.** Messages, contacts, calls
and Twitter are 4b-2.

## Setup

Import `sql/som_phone.sql` after `som_schema.sql`.

Uses ox_inventory's stock `phone` item, so nothing needs adding to
`data/items.lua`. Set `Config.RequireItem = false` to make the phone always
available instead.

## Why it was built rather than adopted

Reviewed npwd, lb-phone, qs-smartphone and qb-phone. npwd's app-registry idea is
taken directly; the rest was not adopted because:

- The flagship app is a **view over `som_transactions` and `som_bank_accounts`**,
  tables the framework already owns. Any third-party phone inserts its own
  account model in between.
- npwd brings ~30 tables, a TypeScript build chain and a framework bridge.
- lb-phone and qs-smartphone are escrowed: unreadable, unextendable, and never
  matching the palette.

## The app registry

Other resources ship their own apps rather than this resource knowing about
every feature. This is how `som-jobs`, `som-gangs` and the Twitter app arrive.

```lua
exports['som-phone']:registerApp({
    id = 'dispatch',
    label = 'Dispatch',
    icon = '!',
    colour = '#4a9eff',
    order = 20,
    perk = nil,          -- or a supporter perk name to gate it
})
```

`perk` is filtered **server side**. Sending an app and hiding it in the UI would
let the client decide what it is entitled to.

## Bank

**Full history, own account only.** The citizenid comes from `source`, never
from the request, so a player cannot read anyone else's ledger.

Every character gets a shareable account number (`SOM-0000-0000`) created lazily
on first open. Collisions are retried, not assumed away.

### Sharing

One tap broadcasts your number to players within `Config.Bank.shareRadius`, who
receive it as a notification and keep it in their saved list. **Distance is
checked server side**, since a client could otherwise broadcast to the whole
server.

### Bills are requests, never withdrawals

A bill arrives as a notification with Pay and Decline. **Money only moves when
the recipient accepts.** Anything else would make a leaked account number a way
to empty somebody's balance without consent.

Two further guards:

- No more than `maxPendingPerSender` outstanding bills from one person, so
  billing cannot be used as harassment.
- If the sender is **on duty at a business**, the bill is raised on its behalf
  and payment lands in the business account, so an employee cannot pocket what
  the shop charged.

Transfers exist separately and are instant and irreversible, which is why the
UI points people at bills instead.

## Settings

Theme selection. `default` is free, the rest are supporter perks validated
against `som-core` entitlements server side. The selected accent overrides
`--accent` at runtime; everything else comes from `som-assets/tokens.css`.

## Known gaps

- **No messages, contacts or calls.** 4b-2. Calls need pma-voice channel work,
  which is the least predictable part.
- **No Twitter**, so the custom handle and colourway perks in `patreon.md` are
  still unbuildable.
- **No camera or gallery.** Deferred; `screenshot-basic` is already kept.
- Apps registered by other resources appear on the home screen but have no view
  container yet, so tapping one returns home. 4b-2.
- **Custom phone numbers** (an Insider perk) are not implemented;
  `som_characters.phone` is still auto-generated.
- No replacement shop, so `Config.Replacement` is unused and a lost phone
  currently has no recovery path. Needs a vendor location.
- Not verified against a live server.
