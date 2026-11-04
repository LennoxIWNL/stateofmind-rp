# som-phone

The phone. Primary interface for anything without a physical anchor, per
`AUDIT.md` 14.5.

**Phase 4b-1: shell, app framework, bank, settings.** Messages, contacts, calls
and Twitter are 4b-2.

## Setup

Its tables live in `setup.sql` at the repo root, which is the single import
for the whole server.

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

## Visuals

Everything is CSS or inline SVG. NUI has no network access, so there are no
webfonts, no icon packs and no wallpaper images to ship: the wallpaper is four
offset radial gradients and the icons are drawn paths.

`icon` on a registered app is now a **name** from the `ICONS` table in
`html/app.js`, not a glyph. Letter glyphs in coloured squares were what made the
home screen read as a placeholder. Unrecognised names still render as text, so
a third-party app passing an emoji keeps working.

The phone opens **locked**. One click, and it is the difference between a menu
and something that reads as a phone.

## Architecture

One door. Every request from the page is `(app, action, payload)` through a single
client callback to `som-phone:server:action`, and `Phone.Action` in `server/core.lua`
is the only place that decides whether it may run: the player is loaded, the phone
item is in the bag, the player is not downed, the phone is not locked, the app is
allowed for their job and perks, the payload is small and shallow, the per-action rate
limit holds, and only then does the app handler run. A change leaves a row in
`som_phone_audit`. Handlers are local functions, so there is no per-app net event a
client could call directly, and a handler that errors is a refusal, not a crash.

- `server/device.lua`: each phone item carries an `imei` the server writes and reads
  back; `som_phone_devices` is the truth. An optional four digit passcode is a salted
  hash with a pepper from the `som_phone_pepper` convar; five wrong tries lock it for 30 s.
- `server/apps.lua`: the built-in apps (Bank, Properties, Settings).
- The page is React in `ui/apps/som-phone`, built into `html/`. Apps import only
  `@som/phone-sdk`, which a test enforces.

## The app registry

Another resource ships an app with `registerApp`, and its handler answers the phone's
actions. The page shows it with a view description: plain data, no markup.

```lua
exports['som-phone']:registerApp({
    id = 'jobs', label = 'Jobs', icon = 'briefcase', colour = '#4a9eff', order = 30,
    jobs = nil,            -- or { 'police' } to hide it from everyone else
    perk = nil,            -- or a supporter perk, checked on the server
    reads = { view = true },  -- actions that only read are not audited
    handler = function(source, action, payload)
        if action == 'view' then
            return { view = { sections = { { title = 'Open', rows = { { title = 'A job', action = 'take', payload = { id = 3 } } } } } } }
        end
        return { success = true }
    end,
})
```

`handler` is called with a source the pipeline has already checked. `notifyApp` and
`billCitizen` keep their signatures.

## Bank

**Full history, own account only.** The citizenid comes from `source`, never
from the request, so a player cannot read anyone else's ledger.

Every character gets a shareable account number created lazily on first open.
Collisions are retried, not assumed away.

**Identifiers are digits only.** Account numbers (`48271930`) and phone numbers
(`555-1234`) carry no branded prefix. They get read aloud over voice, printed on
yellowpages adverts and saved as contacts, and a `SOM-` in front reads as a
script artefact rather than a number. This applies to every app added later.

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
- **Custom phone numbers** (an Insider perk) are not implemented;
  `som_characters.phone` is still auto-generated.
- No replacement shop, so `Config.Replacement` is unused and a lost phone
  currently has no recovery path. Needs a vendor location.
- Not verified against a live server.
