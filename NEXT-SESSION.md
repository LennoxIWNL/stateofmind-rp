# Next session handoff

Written 2026-08-12, replacing the previous handoff wholesale. Everything the
old one described is either done or explicitly cancelled; the record of those
decisions lives in git history and in `AUDIT.md`, not here.

**Read first:** `AUDIT.md` sections 16.2 (the re-apply list), 18.4, 19.2, 21.2
and 21.3. Then `ICON-AUDIT.md`, `VEHICLE-AUDIT.md` and
`DEALERSHIP-RESEARCH.md` at the repo root. Do not re-derive what is in them.

**Standing rules.** Commit AND push to main every time and verify the remote
head matches local. Commit as Lennox only: no `Co-Authored-By` trailer, no
mention of Claude in any commit message. Never invent a native, and check which
SIDE it exists on. No em dashes. Never show raw ledger slugs on bank UI.

---

## THE ONE THING THAT MATTERS MOST

**A very large amount was built and NONE OF IT HAS BEEN RUN.** Not once. The
inventory, the HUD, the incident roles, som-props, som-traffic, the wardrobe
and every fix in between typecheck and build, and that is the entire extent of
what is known about them.

**Do not start the next feature before the test pass below.** Every layer built
on an untested one multiplies the cost of the bug underneath it, and this
session found three defects by review that a passing manual test would not have
caught, plus a fourth that a review raised and left unverified.

---

## STEP 0: BLOCKING

**Reimport `setup.sql`.** It is idempotent. It gained `som_incident_people`
this session and nothing role-related in the MDT will work without it.

`som.cfg` gained `som-props`, `som-inventory`, `som-lorefriendly` and
`som-traffic`. The two vehicle resources are ~274MB of streamed content that is
**gitignored and must be copied to the server by hand**, along with
`som-lorefriendly/fxmanifest.lua`. A committed copy of that manifest is at
`[som]/som-traffic/som-lorefriendly.fxmanifest.lua`, because the live one sits
inside the ignored tree and would otherwise be lost.

---

## STEP 1: THE TEST PASS, in this order

Ordered so a failure early invalidates as little later work as possible.

### 1. Does the server boot and does everything start

`som-props`, `som-inventory`, `som-lorefriendly`, `som-traffic`. A missing
stream folder shows here rather than later.

### 2. The inventory, because it is the most-touched surface on the server

- **Does it appear at all.** If not, first suspect is the `ui_page` repoint in
  `[standalone]/ox_inventory/fxmanifest.lua` and its `web/som/*` files entries.
- Move an item between two slots, close, reopen. Did it stick.
- Split with shift-drag. Stack. Use something. Open a stash, a trunk, a
  glovebox and a shop.
- **Then the dupe checks, which matter more than everything above.** Verify
  against the server's item count, not the screen: give, throw, drop-to-world,
  basket checkout, take-all. **Disconnect mid-drag and mid-throw.**
- Right-click context menu, hover tooltip, category pills.

### 3. The HUD

- Does it appear. Does it stand down in the pause menu and while downed.
- `/sethud`: move something, scale with the wheel, toggle a panel off, save,
  reconnect, confirm it stuck. Then Reset.
- Get in a car (speedometer), then a helicopter (the aviation panel should
  REPLACE it, not sit beside it).
- **Seatbelt: drive into a wall at speed with the belt off, then on.** The
  ejection is the feature; the indicator is not.

### 4. The MDT, which is where the last session started

- Open an incident, **search a citizen by ID** (this is exactly what was
  broken), add them under Associated, right-click their holder to add a charge,
  set fine and sentence.
- The new **People & Roles** panel: add someone, change their role, reopen the
  incident, confirm it persisted. It needs the incident SAVED first and says so.
- Attach two officers to a dispatch call, detach one, confirm the right one
  left and the list is not empty.

### 5. The rest

- Place a cone from the inventory, pick it back up. **Then restart som-props and
  confirm the leftover cone is inert rather than duplicating.**
- Clothing tab: take a jacket off, relog, confirm you are dressed as you left.
  **This is the one most likely to still be wrong.** The shape bug behind it was
  caught by review, not by reasoning, and the fix has never run.
- Drive around and confirm the lore-friendly cars appear in traffic.

---

## STEP 2: THE BUILD QUEUE, in the order I would do it

### 1. Barber and clothing zones. Phase 1, and it is a HOLE not a feature

**`som-appearance`'s editor has no world entry point.** `openEditor` is called
by `som-multichar` for character creation and by **nothing else anywhere in the
tree**. So a player builds a face once and can then **never change it, or their
clothes, again**.

The resource is built. The scopes, the pricing and now the wardrobe are all
built. What is missing is a zone at a barber and a zone at a clothing store
calling `exports['som-appearance']:openEditor('barber' | 'clothing')`.

Cheapest large win left, and it is what makes the inventory's clothing tab worth
having.

### 2. The remaining ox_lib shims

`lib.progressBar` and `lib.registerContext` are shimmed (`som-ui/client/
progressbar.lua` and `context.lua`). **`lib.skillCheck`, `lib.inputDialog` and
`lib.alertDialog` are not.** AUDIT 20.2 and 21.4 explain the pattern and why it
is the highest-leverage NUI work available; each is smaller than the context
menu was.

**`skillCheck` first, because `som-lockpick` is waiting on it** and is currently
not even ensured.

### 3. The dealership

Fully researched in `DEALERSHIP-RESEARCH.md`. Built on
`som-garage/server/fleet.lua`'s purchase flow, which is already correct.
**This unblocks two other things:** the civilian vehicle pool has nowhere to be
sold from without it, and `ex-cars` (87 cars, on disk, unensured) waits on the
same.

**Owner's decisions already recorded:** financing runs through a **Properties**
phone app; test drives and a browsable catalogue are both wanted. **Still
unanswered:** free-use, managed, or both. My recommendation is both, with
free-use on a limited cheap range so a new player is never stuck.

### 4. The Properties phone app

Recorded in `AUDIT.md` 18.4 and extended in 18.7. Vehicle finance payments are
bills, and bills are paid in the phone. **Named Properties, not Finance,
because phase 7 extends the same app to housing**, so rent lands beside the car
payment rather than in a second app.

None of the machinery needs inventing: `som_phone_bills` already carries
`auto_collect` and `due_at`, and `som_transactions` is a real ledger. Storing a
balance on the vehicle row is the mistake AUDIT 8.5 records against
`som-banking`.

### 5. The smaller open items

- **Task 13: a licensed HUD icon set.** The condition glyphs are inline SVG
  authored here and consistent with each other, so this is a swap in one file.
- **61 inventory icons still missing**, 40 of them weapon tints. The other 21
  are clothing slots, surgical tools and forensic kits with nothing on disk or
  in the vendored repos that resembles them. See `ICON-AUDIT.md`.
- **The vehicle indicator panel** (State Bags, so nearby players see signals)
  and **three HUD performance modes**. Both additive.
- **The inventory's drawn throw arc.** Currently a number. The arc is drawn in
  the WORLD, which is client Lua; the page has no camera to project against.

---

## WHAT IS DONE. DO NOT REBUILD ANY OF IT

This section exists because **the previous handoff twice told me to build
something that already existed**, and I nearly did both.

| Thing | State |
|---|---|
| MDT person search | Fixed. `AND jobtype` bound tighter than the `OR`; the schema was never the problem |
| MDT charges, fine, sentence, plea | **Already ships in ps-mdt.** Never build `som-charges` |
| Per-person incident roles | Built. `som_incident_people` + `som-police/server/incidents.lua` |
| Reports page | Removed from the MDT nav |
| CitizenID renumber | **Cancelled by the owner.** Do not reopen |
| Icon audit and realistic pass | Done. 71 cartoon weapon icons replaced |
| Vehicle add-on audit | Done. **Owner keeps everything**; removal list closed |
| NPC traffic | Built. `som-lorefriendly` + `som-traffic` |
| LCPDFR pack | Removed. Singleplayer build, and its terms forbid extraction |
| Item prop/icon binder | Done. `som-props`, and `data/animations.lua` extended |
| Dispatch attach | Fixed in three ps-mdt handlers |
| Dispatch NUI | Built |
| Inventory | Built, full feature set |
| HUD | Rebuilt on React, with `/sethud` and seatbelt |

---

## TRAPS AND LESSONS. These cost real time to learn

**On handoffs and notes, including this one.** The previous handoff was
confidently wrong twice: it said the MDT search failed because the `players`
view did not exist (it does, with the exact shape it claimed was missing), and
it told me to build a charges system that already shipped. **Read the code
before trusting any note about it, this file included.**

**On reviews.** Three adversarial reviews have now died on session limits
mid-run (AUDIT 21.9, and twice more). A review returning zero findings because
its agents errored is **"not reviewed", not "clean"**. Worse: the most serious
defect of the last session, a drop-pickup button wired to the `/steal` path
that opens a nearby **player's pockets**, came back as an *unverified claim*
because its verifier died. **Confirming it by hand took one grep.**

**On shapes.** The wardrobe was written against `components` as a map keyed by
id. It is an **array of records** carrying `component_id`, and `ApplyApparel`
skips any record without that field. Indexing an array by id hits a *position*.
`removeAll` would have permanently emptied a character's appearance. **Write
against what the code produces, not what the name suggests.**

**On natives.** `FreezeEntityPosition` is client-only and was being called
server-side; ox_lib avoids it and passes `dynamic = false` instead. Same class
as `SetDispatchServiceActive`, which does not exist at all (AUDIT 19.2).
**Confirm a native exists AND which side it lives on.**

**On event names.** `mdt:server:deleteIncidents` is plural for a single id. A
handler on the singular registers fine and never fires. **Check the emitter, not
the memory of it** (AUDIT 21.2).

**On ps-mdt.** It calls `FreezeEntityPosition` server-side, renders dispatch
calls as interpolated HTML, and reads a constant defined nowhere. **It is not a
correctness signal.** Never copy a pattern because ps-mdt uses it.

**On anti-dupe ordering.** Remove the item BEFORE granting or dropping it, and
claim ownership BEFORE any call that might yield. Claiming next to the delete
reads more naturally and is wrong.

**On NUI frame ownership.** `fetchNui` posts to whichever resource SERVED the
page, and a `RegisterNUICallback` only answers for the resource owning the
frame. That is why som-inventory's build lands inside ox_inventory, and why the
bridge file has to live there too.

---

## THE ox_inventory RE-APPLY LIST

An ox_inventory upgrade drops all of these. Adds to AUDIT 16.2 rather than
replacing it.

- `fxmanifest.lua`: `ui_page 'web/som/index.html'`, the three `web/som/*` files
  entries, and `client_script 'som_bridge.lua'`
- `som_bridge.lua` itself, a NEW file rather than an edit to theirs
- the `web/som/` build output
- `data/items.lua`: the 8 `prop_*` placeables, `sandwich`'s client block, and
  the `client.image` pointers on `nikon`, `rental_papers`, `fingerprintreader`,
  `mdtcitation`, `cash_bag`, `inked_cash_bag`, `gauze`, `bandageg` and
  `dirty_orange`
- `data/weapons.lua`: `WEAPON_BATTLERIFLE`'s image pointer
- `data/animations.lua`: extended from 2 entries to 11
- `web/images/`: 71 replaced weapon icons plus the new art

**The contract all of this speaks is pinned in
`ui/apps/som-inventory/src/contract.ts` against v2.45.0.** Re-enumerate against
it after any upgrade; nothing upstream is versioned, so a changed payload
renders blank with nothing in any console to explain why.

---

## OPEN DECISIONS FOR THE OWNER

1. **Dealership: free-use, managed, or both.** Needed before that build starts.
2. **HUD layout persistence is KVP**, so per machine rather than per character.
   One word and it becomes a column on `som_characters`.
3. **`ex-cars` is kept but still not ensured.** 87 civilian cars, 365MB into
   streaming, waiting on the dealership.
4. **The remaining 21 non-tint icons need sourcing or drawing.** A wrong icon is
   worse than none, which is why they are still blank.
5. **Cartoon icons exist outside the weapon set.** `advancedkit.png` is one,
   found by accident. Nobody has looked at all 750 by eye; a full sweep is its
   own task.

---

## PROMPT: how to start the next session

Continue State of Mind RP. Read `AUDIT.md` 16.2, 18.4, 19.2, 21.2 and 21.3, and
this file end to end. **Do not trust either without reading the code it
describes.**

Nothing built in the last session has been run. **Do the STEP 1 test pass before
building anything**, and report what actually failed rather than what should
have worked. Then take the STEP 2 queue in order, starting with the barber and
clothing zones, which is a hole rather than a feature: the appearance editor
currently has no way into it after character creation.

Standing rules as above: push every time and verify the remote, commit as me
only with no Claude mention, never invent a native, no em dashes.
