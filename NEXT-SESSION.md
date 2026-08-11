# Next session handoff

Everything outstanding, in the order I would do it. Prompts A and B at the
bottom are self-contained and can be run in their own session; the numbered
work above them is one session's worth and shares context.

**Read first:** `AUDIT.md` sections 19, 20 and 21, and
`C:\Users\tweet\.claude\plans\i-m-unifying-the-visual-crispy-crescent.md`.
Do not re-derive what is written there.

**Standing rules.** Commit AND push to main every time and verify the remote
head matches local. Commit as Lennox only: no `Co-Authored-By` trailer and no
mention of Claude in any commit message. Never invent a native. No em dashes.
Never show raw ledger slugs on bank UI.

**No SQL has been changed yet.** `setup.sql` is untouched, so nothing needs
reimporting until item 2 or 3 below lands, and both of those say so explicitly.

---

## 1. MDT person search is broken. Fully diagnosed, just needs writing

`[custom]/ps-mdt/server/main.lua:819`, and a second occurrence in the same
file, query QBCore's stock schema, which does not exist on this server.

Two independent mismatches:

- **Table.** som-core stores characters in `som_characters`, not `players`.
- **Shape.** ps-mdt expects a `charinfo` JSON blob. `som_characters` has flat
  columns, so `json.decode(result[i].charinfo)` fails even against the right
  table.

Corrected query:

```sql
SELECT c.citizenid, c.firstname, c.lastname, c.gender, c.metadata, md.pfp
FROM som_characters c LEFT JOIN mdt_data md ON c.citizenid = md.cid
WHERE (LOWER(c.firstname) LIKE :firstname AND LOWER(c.lastname) LIKE :lastname)
   OR LOWER(c.citizenid) LIKE :citizenid
LIMIT 30
```

The result loop must read flat columns instead of decoding `charinfo`.

Two things you will hit immediately after: `gender` here is a TINYINT (0/1) but
`ProfPic()` compares it to the string `"f"`, so every profile picture falls
back to male. And the original `AND jobtype = :jobtype` has no parentheses
around the OR branch **and** `jobtype` is not a column on that table at all,
which is a latent bug that shipped with ps-mdt.

This is the same class as AUDIT 16.6 item 1, which fixed the Profiles search.
This is a second, separate search that was never touched.

Verify: open an Incident, click Officers Involved, Civilians Involved and
Criminals Involved in turn, and search by both a name and a citizen ID.

## 2. CitizenID becomes a counting number. DROPPED, do not restart it

Mapped, costed, put to the owner, and **cancelled by the owner on 2026-08-11.**
Do not reopen this without a fresh instruction.

The handoff scoped it as "three foreign keys". That was wrong by an order of
magnitude. The real surface:

- **14 SOM tables carry `citizenid`**, and only three of them have a foreign
  key (`som_character_money`, `som_vehicles`, `som_licenses`). The other
  eleven cascade nothing, so a renumber orphans them silently rather than
  failing loudly: `som_transactions`, `som_bank_access`, `som_fines`,
  `som_job_applications`, `som_turf_events`, `som_market_sales`,
  `som_phone_accounts`, `som_phone_settings`, `som_appearance_log`,
  `som_police_custody`, `som_police_impound`.
- **312 references across 13 `som-*` resources**, led by som-core (88),
  som-police (64), som-phone (50) and som-garage (38).
- **ps-mdt's `cid` columns have no constraint** (`mdt_data` VARCHAR(20),
  `mdt_convictions` varchar(50)).
- **ox_inventory keys every per-player stash as `stashname:citizenid`** in the
  `owner` column of its own table (`modules/inventory/server.lua:195`, and the
  table is created at `modules/mysql/server.lua:64`). A renumber orphans every
  owned stash. The handoff missed this.
- **Weapon serials are already engraved into item metadata**
  (`som-police/server/main.lua:370`). No migration reaches an item sitting in
  someone's bag, so old serials would keep pointing at ids that no longer
  exist. The handoff missed this too.

**The owner's actual problem was ergonomic, not structural:** typing
`AB12345678` into the MDT or a form is painful. That is worth remembering,
because it does not require renumbering the primary key. Adding a
`citizen_no INT AUTO_INCREMENT UNIQUE` column to `som_characters` and
displaying that on the ID card, the MDT and the phone solves the stated pain
with no join changes, no orphans and no FK churn, and it is reversible. It was
offered and declined for now. If the complaint resurfaces, that is the cheap
answer and this section is the reason not to do the expensive one.

**No SQL changed. Nothing needs reimporting for this item.**

## 3. Charges, time and fine in the MDT. ALREADY BUILT, do not build som-charges

**Do not build `som-charges`. AUDIT 16.6 item 2 was right and this section was
wrong to contradict it.** The entire charging system already ships in ps-mdt
and is complete. Verified by reading it, 2026-08-11:

- `getPenalCode` (`ui/app.js:4706`) renders all 181 offences grouped under the
  10 `Config.PenalCodeTitles`, each carrying class, penal code number, months,
  fine, colour and description.
- Right-clicking a person's holder (`ui/app.js:1776`) opens that picker and
  appends the charge as a tag.
- Each person on an incident gets a card (`ui/app.js:4865-4894`) with
  **Recommended Fine, Fine, Recommended Sentence, Sentence**, Warrant, Guilty,
  Processed and Associated toggles, and Jail, Fine and Community Service
  buttons.
- It all saves to `mdt_convictions`, which already has `charges`, `fine`,
  `sentence`, `recfine`, `recsentence` and `guilty`.

**Why the owner could not find it.** The charges card only exists for a person
who has been added to the incident, and every one of the six person-add buttons
routes through the single search fixed in item 1. Searching by citizen ID
returned nothing, so nobody could be added, so no card and no charges. Fixing
the search is what makes this reachable. That is exactly the chain AUDIT 16.6
item 2 predicted.

**Test it rather than build it:** open an incident, click the Associated tags
add button, search a citizen, then right click their holder to add a charge and
set the fine and sentence.

The one genuinely missing piece is **per-person roles**. `officersinvolved` and
`civsinvolved` are JSON blobs with no role field, so victim versus suspect
versus witness cannot be expressed. That still needs a table, and it should key
on the INCIDENT, not on a report, because item 4 removes reports. Not built
yet, and it is small.

**No SQL changed. Nothing needs reimporting for this item.**

## 4. Remove Reports, make Incidents the single write surface. DONE

Owner's call: Incidents is where an officer writes everything.

Done as one deleted line in `ui/dashboard.html` plus one rule at the end of
`ui/style.css`. The nav markup is repeated once per page container, so 12 of
the 13 copies carry `data-page` and fall to a single attribute selector rather
than 12 separate deletions. That also makes it one line to re-apply after a
ps-mdt upgrade, so it goes on the AUDIT 16.2 list as such.

The page container, its handlers and the `mdt_reports` table are all left
intact. The nav was the only way in: the only other two call sites are a click
on a row inside the Reports page itself and the nav loader's own fetch, neither
reachable once the entry is gone. Nothing in the JS `.show()`s it either, since
that only ever targets specific nav classes and Reports has none. So this hides
a surface rather than deleting data, and reverting restores it whole.

## 5. Task 8: the icon audit. DONE, see `ICON-AUDIT.md`

Full result in `ICON-AUDIT.md` at the repo root. Summary: 804 registered items,
**730 already resolve**, 0 case-only mismatches, 7 ambiguous (all false
positives, nothing renamed), 67 with no art, 42 orphan files.

Three things worth carrying forward:

- **The casing trap did not bite.** The weapon art on disk is already uppercase
  and matches the keys, so there were zero case-only mismatches. The resolution
  rule is `` `${imagepath}/${itemName}.png` `` at
  `web/src/helpers/index.ts:156-159`, with the name used verbatim and never
  lowercased. That is written down at the top of `ICON-AUDIT.md`.
- **`ifak` was the wrong lead and is already fixed.** The item is `ifaks` and
  carries an explicit `image = 'ifak.png'` pointing at art that exists.
  Whatever the owner saw, it was not that.
- **One rename performed**, `at_muzzle_precision'.png` to
  `at_muzzle_precision.png`, a stray apostrophe. Not a judgement call.

**Still needs your call before anything else is renamed:** `nikon` has no art,
`camera.png` is orphan, and pairing them is probably right but is still a guess
about intent. Section B of `ICON-AUDIT.md`.

**The three missing icons that are live on this server** are `ammo-taser`
(ours, added per AUDIT 16.2 and shipped with no art), `rental_papers`
(som-rentals) and `mdtcitation` (ps-mdt, wants `citation.png`). Everything else
missing is either unused stock or cosmetic weapon tints.

## 6. Task 9, the rest

Done already: the PD motor pool, cert gated, on Zerofour04's pack. Still open:

- Audit every vehicle add-on against what configs actually reference, and show
  the removal list before deleting. Candidates already identified: `TIG-PACK`,
  `c321defender`, `veh_lykan`, `tesla`, `New_Truck`, `npwpdcar`.
- The 158 car civilian pack from `Aweetumn-LLC/FiveM-Lorefriendly-Vehicles`,
  checking `LNWK-CARS` for a packaged bundle first.
- A dealership. **None exists anywhere in the tree**, so the civilian pool has
  nowhere to live until one does. It gets the shop NUI from task 3 for free.
- NPC traffic: 15 to 20 sedate models into popgroups with weighting. No
  handling.meta edits.
- Streaming and memory impact, measured rather than asserted. `ex-cars` is
  already ~97 models and `assets_vehicles` streams ~5000 `.yft` of parts.

Streamed binaries stay gitignored and are copied to the server by hand. Two
`dlc.rpf` files in the old LCPDFR pack are 479MB and 295MB, and GitHub hard
rejects anything over 100MB, which is why that route was abandoned.

## 7. Task 12: the item prop, icon and animation binder

Clone `allyaminou/Ox_Inventory-ItemsTemplate`, `Andyyy7666/itemcollection` and
`Branqueador/GGC-Weapons`. Food, drink and alcohol from allyaminou's template
where names match ours, melee props and icons from GGC-Weapons,
`ai.swisser.dev/fivem-inventory-icons` as a free fallback before anything is
flagged as needing a custom icon. Check each licence before vendoring and
record it; a pack with no licence file does not get copied in.

Deliver three lists: full prop plus icon plus animation coverage, icon only,
and still missing.

## 8. Verify the attach fix actually took. DONE, and the prediction was right

som-dispatch's own coercion was already correct (`callById` at
`server/main.lua:449`). The predicted second half was real: **three** handlers
inside ps-mdt still indexed the call store with the raw string.

- `mdt:server:attachedUnits` (`:1467`) and `mdt:server:getCallResponses`
  (`:1595`) went further than returning nothing. `calls["3"]` is nil, so
  `nil['units']` **threw**, which is why Attached Units rendered empty rather
  than showing a short list.
- `mdt:server:setWaypoint` (`:1411`) passed nil instead, so it failed as a
  waypoint that silently never set.
- `mdt:server:setDispatchWaypoint` (`:1514`) was already correct and is left
  alone. It is the model the other three now follow.

Each also gained a nil guard, separate from the coercion and worth keeping:
`callid` arrives from a client, so an id for a call that has since closed has
to return quietly rather than error in the server console.

Goes on the AUDIT 16.2 re-apply list.

**Still worth testing in game**, since none of this has been run: attach two
officers to one call, detach one, and confirm the remaining unit is the right
one and that the list is not empty.

---

## Before EITHER prompt below: ask for the reference images

**Owner's instruction, 2026-08-11.** Both prompts below describe their layout
by pointing at reference images in the plan's "Reference images" section. Those
images are not in the repo and cannot be read from the plan text alone.

**Stop and ask the owner for the HUD and inventory reference images before
starting either reskin.** Do not begin building from the written description
and do not infer the layout. This applies to task 10, task 11 and task 13.

Continue State of Mind RP. Read AUDIT.md sections 20 and 21, and the plan at
`C:\Users\tweet\.claude\plans\i-m-unifying-the-visual-crispy-crescent.md`.
Standing rules as above: push every time and verify the remote, commit as me
only with no Claude mention, never invent a native, no em dashes.

Build `som-inventory`: our own React NUI that **speaks ox_inventory's existing
NUI message contract**, with ox_inventory's `ui_page` repointed at it. This is
decided, do not re-open it. We are NOT forking ox_inventory: its Lua stays
stock and upgradeable, our code lives in `[som]`, and the revert is one line.
The same shim pattern already replaced ox_lib's progress bar and context menus,
documented in AUDIT 16.6 item 4 and 21.4.

Use the shared kit at `ui/packages/som-ui-kit` (Card, Button, IconTile,
StatusBadge, Meter, Modal, Drawer, ContextMenu, Input, Select, Stepper, Tabs,
plus fetchNui/useNuiEvent). Add the app under `ui/apps/som-inventory` with
`somApp({ outDir })` from `@som/ui-kit/vite`. Colour and type come only from
`som-assets/tokens.css`; a hex value in a component is a bug.

**Order of work, and do not skip step 1:**

1. Enumerate ox_inventory's NUI contract from
   `[standalone]/ox_inventory/web/src` and its client modules: every `action`
   it sends and every `RegisterNUICallback` it accepts. Write it into the
   resource header the way `som-ui/client/progressbar.lua` documents its own,
   and pin the ox_inventory version you read it from. The contract is not
   versioned upstream, so that header is the only thing that makes a future
   upgrade diagnosable.
2. Build the shell and grid to **parity with stock**: move, split, stack, use,
   shops, stashes, trunks, glovebox. Parity before any new feature.
3. Repoint `ui_page`.
4. Only then add the features below.

Layout and feature set from the Overflow reference in the plan's "Reference
images" section, recoloured to our tokens: clothing toggle with a native
animation and chat commands, physics throwing with a charge bar and trajectory
arc, drag-to-give with nearby-player highlighting, rarity tiers, side-by-side
secondary panels with transfer-all, a drag-to-discard zone lit only while
dragging, a cursor-anchored context menu, category tabs driven by real item
categories, and panel animations (main from the right, secondary from the
left).

Rarity uses the accent family plus neutrals, NOT the reference's
green/purple/orange: a screen with four unrelated hues has no accent.

**The one thing worth being slow about:** every action stays server-validated.
Give, throw, discard and transfer go through ox_inventory's existing server
checks, or through a NEW som-inventory server event with its own validation
where no stock path exists. The NUI never moves an item on its own authority.
Test dupes explicitly, including disconnecting mid-drag and mid-throw.

Note the item key casing trap in item 5 above.

---

## PROMPT B: Task 11, the custom HUD, plus task 13

Continue State of Mind RP. Read AUDIT.md 21.5 and the same plan. Standing rules
as above.

Replace `[som]/som-hud` with a React build on `ui/packages/som-ui-kit`, app
under `ui/apps/som-hud`, wired to SOM's existing player and vehicle state.
**Read the current som-hud first**: it already solves things worth keeping,
including that GTA player health runs 100 to 200 (so the raw value shows a
corpse at 50%), that pma-voice's range comes from `LocalPlayer.state.proximity`
as `{index, distance, mode}`, and that both loops must send only on change or
the NUI feels heavy in a way profiling will not show.

Feature set from the HUD reference sheets in the plan, recoloured to tokens as
a single fixed theme with no switcher: a `/sethud` drag, scale and toggle
editor with per-player persistence and JSON export/import; health, armour,
hunger, thirst, oxygen and stress; digital and analog speedometers for land,
bike and air with fuel versus electric detection; an aviation panel that
auto-activates on a plane or helicopter and clears on exit; seatbelt with
speed-based ejection physics configured per vehicle class; a vehicle control
panel on a key with indicator state synced through State Bags so nearby players
see signals; a 360 degree compass and live street plus cross-street; custom
minimap textures; three performance modes; and pma-voice mic range and radio
channel indicators.

**Two carried constraints.** The fuel gauge is built now and wired only when a
fuel resource exists, because none runs here (cdn-fuel fails at load, ox_fuel
is not installed) and a gauge stuck at one number teaches players to ignore the
HUD. And the minimap swap needs packed `.ytd` textures, which needs OpenIV or a
texture packer that is not installed, so author the artwork and hand that one
file back.

Task 13 belongs here: source free HUD icon sets first, and author original SVG
matching the set's style for anything missing, the way som-hud's five ring
glyphs already are. No placeholders, no mismatched styles.
