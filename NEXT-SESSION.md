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

### Per-person roles: BUILT

The one genuinely missing piece. `officersinvolved` and `civsinvolved` are JSON
blobs of **display strings with no citizen id**, so not only is there no role
field, the person's identity is gone the moment they become a tag and cannot be
recovered by reopening the incident. That is why the panel does not read those
tags.

- **`som_incident_people`** in `setup.sql`, keyed on the INCIDENT (not a report,
  since item 4 removed reports). Five roles as an ENUM: victim, suspect,
  witness, complainant, reporting. UNIQUE on (incident_id, citizenid), so
  assignment is an upsert and one person holds one role.
- **No foreign key onto `mdt_incidents`**, deliberately: nothing in ps-mdt's
  schema has one, and that table can be dropped and recreated by its own SQL on
  upgrade. Rows are cleaned by a listener on `mdt:server:deleteIncidents`
  instead. **Note the plural** in that event name; the singular would have
  registered and never fired.
- **`som-police/server/incidents.lua`** owns it. Three ox_lib callbacks, job
  re-checked server side on every read and write, role validated against the
  server's own list, and the citizen id checked against `som_characters` before
  insert so a typo or a crafted id cannot hold a role.
- **ps-mdt is append-only**: three NUI relays at the end of `client/main.lua`
  and a self-contained panel at the end of `ui/app.js` and `ui/style.css`, the
  same shape as the certifications panel. It injects its own markup and polls
  the incident id rather than hooking ps-mdt's three separate paths for setting
  it, which is the trade the certs panel already documents.

**Roles need the incident saved first.** A new incident has id 0 and the panel
says so rather than pretending. That avoids a fragile pending-flush path.

**This adds a table. `setup.sql` needs reimporting.** It is idempotent.

### Review status of som-props and the roles code: SELF-REVIEWED ONLY

**A four-lens adversarial review was launched and all four agents died on a
session limit before returning anything.** It reported zero findings, which
means "nothing was reviewed", not "nothing was found". This is the second time
this has happened on this project; AUDIT 21.9 records the same thing killing
the review of the context menu shim and som-hud.

A manual review was done instead and found four real defects, all now fixed:

- **`FreezeEntityPosition` is client-only** and was being called server-side.
  ox_lib never calls it from its server path and instead passes `dynamic =
  false` to the constructor, which is what actually makes a prop static.
  ps-mdt does call it server-side, but this session has shown ps-mdt is not a
  correctness signal. Same class as the `SetDispatchServiceActive` mistake in
  AUDIT 19.2.
- **`CreateObject` was the wrong constructor.** ox_lib's server-side prop
  helper uses `CreateObjectNoOffset`, because the offsetting variant shifts the
  object relative to the coordinate given and makes ground placement guesswork.
- **The anti-dupe claim sat below a call that can yield.** It is now taken
  immediately after the ownership read, with every rejection path restoring it.
  Claiming next to the delete reads more naturally and is wrong.
- **`mdt:server:deleteIncidents` was a griefing vector.** Any client can fire
  ps-mdt's event with any id; ps-mdt checks rank before deleting the incident,
  but our second listener on the same event got no such protection and would
  have wiped the role rows off any incident. It now treats the incident's
  actual disappearance as the authorisation, rather than duplicating ps-mdt's
  permission table.

**Still worth running the review properly when limits allow.** Nothing here has
been run on a live server.

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

**`nikon` is done.** The owner approved the pairing, so it now carries
`client = { image = 'camera.png' }` rather than the file being renamed. Same
pattern `ifaks` already uses, and it is non-destructive: `camera.png` keeps its
own name if a second camera item ever wants it.

**`ammo-taser` is done** and now has art, taken from GGC-Weapons.

### The realistic-style pass, 2026-08-11. DONE

Owner: some icons were cartoon and some realistic, and all of them should be
realistic.

**The weapon set was the whole problem.** Ours was a cel-shaded cartoon pack
with black outlines. The ItemsTemplate set is rendered and realistic. Verified
on a pistol, a rifle, a knife and the taser before touching anything, all four
the same, so it is one pack rather than a few odd files. **71 replaced**, plus
`WEAPON_TACTICALRIFLE` added.

**The non-weapon overlap was deliberately NOT a blanket swap**, because the
instruction was to leave anything already realistic alone. All nine checked by
eye: `bandage`, `black_money`, `lockpick`, `money`, `parachute`, `phone` and
`sandwich` are already realistic photos and are untouched. Two were not:
`cigarette` was flat cartoon, and `wallet` was a real photo of a branded
designer wallet with a cartoon character printed on it.

Fills, each checked for style before use: `rental_papers` to
`printerdocument.png` (the folder-or-file that was asked for), `mdtcitation`
to `heist_papers.png` (**it was pointed at `citation.png`, which does not exist
and never has, so every citation ever issued showed the fallback**),
`fingerprintreader` to `finger_scanner.png`, `WEAPON_TEARGAS` to the BZ gas
canister, `cash_bag` and `inked_cash_bag` to `moneybag.png`, `gauze` and
`bandageg` to the bandage roll, `dirty_orange` to the orange, and
`WEAPON_BATTLERIFLE` to the military rifle.

**Coverage 730 to 751 of 812.** Every fill is a `client.image` pointer, never a
rename, so art keeps its own name and existing users are unaffected.

**Of the 61 still missing, 40 are weapon tints and attachments** needing
bespoke swatches. The other 21 are clothing slots (`tshirt`, `torso`, `arms`,
`jeans`, `ears`, `clothing`, `glasses`), surgical tools (`surgical_tray`,
`syringe`, `forceps`, `surgical_gloves`, `surgical_staple`), forensic kits
(`gsrtestkit`, `dnatestkit`, `drugtestkit`, `breathalyzer`, `accesstool`),
plus `spikespack`, `emp_ammo`, `luxuryfinish_attachment` and
`WEAPON_SNOWLAUNCHER`. **Nothing on disk or in the three repos resembles any of
them**, and a wrong icon is worse than none, so they need sourcing or drawing.

**Known and not addressed:** cartoon icons exist outside the weapon set too.
`advancedkit.png` is one, found while looking for something else. Nobody has
looked at all 750 by eye. If a full sweep is wanted it is its own task.

## 6. Task 9, the rest. AUDIT DONE, see `VEHICLE-AUDIT.md`. Awaiting sign-off

The add-on audit is complete and in `VEHICLE-AUDIT.md`. **Nothing deleted**, the
removal list is there for sign-off. Three things change the rest of this task:

- **Only 6 of 22 vehicle resources are ensured.** ~4.7 GB sits on disk and never
  loads. Verified: the only group ensures in `som.cfg` are `[anticheats]` and
  `[voice]`, so an unnamed resource does not start. **Nothing on the removal
  list is costing any streaming memory**, so the memory worry was misplaced and
  the real budget is ~349 MB with plenty of headroom.
- **Every model our configs reference resolves to an ensured resource.** The PD
  fleet is correctly wired, checked model by model, and som-rentals is entirely
  vanilla. No dangling references.
- **`ex-cars` is 87 complete civilian vehicles already on disk, just switched
  off.** Look at that before downloading the 158-car pack, which may be
  partly or wholly redundant.

**Owner's decision, 2026-08-11: KEEP EVERYTHING. The removal list is closed.**
Groups 1 and 2 stay, `ex-cars` stays. Do not re-propose deleting any of it.
Sound call on the evidence: none of it is ensured, so none of it costs
streaming memory, and deleting would only have bought tidiness.

Still open:

- **`ex-cars` is kept but still not ensured.** Keeping is not switching on.
  Enabling it is one line in `som.cfg` and hands over 87 civilian vehicles, but
  it puts 365 MB into streaming and there is nowhere to sell them from yet, so
  it waits on the dealership.
- A dealership. **Still none in the tree.** This is the blocker for the
  civilian pool, not the pool itself.
- NPC traffic: 15 to 20 sedate models into popgroups with weighting. No
  handling.meta edits. **`assets_vehicles` carries `popgroups.ymt` and
  `popcycle.dat`**, which is the mechanism, and it is staying on disk, so the
  files are there when this is picked up.

### The LCPDFR pack has landed, and is blocked on LICENSING not tooling

871 MB is at `Vehicles/`, now gitignored (the 96 MB of templates beside the
archives were untracked and unignored, one `git add -A` from a rejected push).

It is the **LSPDFR/singleplayer build, not a FiveM release**. All 38 vehicles
are sealed in two `dlc.rpf` files, the install path is `dlcpacks` plus a
`dlclist.xml` edit, and the lighting is ELS VCF XML with no ELS resource here.

**Its terms say "Do not rip, modify, or alter the contents of this archive."**
Extracting the `.rpf` to loose files is exactly that and is the only way to
make it stream in FiveM, so this is not an OpenIV problem to solve. Ask the
author (BlueGhost, LCPDFR) for a FiveM release. Nothing has been extracted.

## 7. Task 12: the item binder. DONE. Owner accepted the licences

Owner's call, 2026-08-11: the missing licence is acceptable, take what benefits
us from all three. What that turned out to be, and what it deliberately was not:

**Taken:**
- **`som-props`**, a new resource. The 8 placeable prop items (cones, barriers,
  worklights) and their icons, adapted from itemcollection. All vanilla models,
  so it streams nothing. **Its Lua was NOT taken**, for cause: see
  `som-props/README.md`. Its pickup event took a model name from the client and
  handed over the matching item, skipping the entity lookup entirely, so
  sending it in a loop minted unlimited items.
- **`ammo-taser` art** from GGC-Weapons, the one image of 122 that covered
  anything on the missing list, and it happens to be an item we added ourselves
  and shipped blank.
- **`sandwich`** gained a client block. It had none, so eating it did nothing.
  Values matched to `burger`, NOT to the template, whose sandwich quenched
  thirst.
- **`data/animations.lua` extended from 2 entries to 11.** That file already
  was the prop and animation binder this task asked for.

**Not taken, and why:** GGC-Weapons' 115 models and 25 weapon icons. We have
none of those weapons, so vendoring 492 MB of AGPL content would be a new
weapon roster decision rather than a binder. Available if wanted, as its own
call.

## 7b. Original licence findings, kept for the record

All three repos cloned and inspected. **Nothing has been copied into the tree**,
because two of the three need a decision from the owner and the third is
excluded by this plan's own rule.

| Repo | Licence | Contents | Verdict |
|---|---|---|---|
| `Andyyy7666/itemcollection` | **NONE** | 8 images | **Excluded.** No licence file means all rights reserved, and the rule here is that a pack with no licence does not get copied in |
| `allyaminou/Ox_Inventory-ItemsTemplate` | **GPL-3.0** | 20 items, 96 images, 3 MB | Owner's call. Copyleft |
| `Branqueador/GGC-Weapons` | **AGPL-3.0** | 115 weapon models, 26 images, 492 MB | Owner's call, and the harder one. **AGPL's network clause** is a real question for a game server, which is precisely a piece of software users interact with over a network |

**The yield is much smaller than this plan assumed, which is the important
part.** Measured rather than estimated:

- Of the **122 images** across all three repos, exactly **one**
  (`WEAPON_TACTICALRIFLE.png`) covers anything on the 67-item missing list from
  `ICON-AUDIT.md`.
- `Ox_Inventory-ItemsTemplate` carries only **20 items**, of which **9 match
  ours** by name: `sandwich`, `burger`, `phone`, `wallet`, `bandage`,
  `parachute`, `lockpick`, `money`, `black_money`. Those 9 are the real prize,
  since they would gain prop and animation bindings.

So the honest trade is: **492 MB of AGPL content for melee props, and a GPL
repo for 9 items' worth of prop and animation bindings.** That is worth doing
only if the copyleft terms are acceptable, and that is not my call to make.

Clones are in the session scratchpad, not the repo. `ai.swisser.dev` was not
reached, and should be checked as a free fallback before anything is flagged as
needing custom art.

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

## 9. Task 10, the inventory. PARITY BUILT, features partly. NOT TESTED

Reference images received from the owner 2026-08-11 (eight in-game shots: shop
with basket, inventory alone, dumpster, items-dropped-nearby, context menu,
category filter with hotbar, clothing tab, nearby-player highlight).

**Source** `ui/apps/som-inventory`. **Build lands in**
`[standalone]/ox_inventory/web/som/`. Typechecks and builds clean.

### The three contract findings, which are the durable part

Step 1 was done first and is pinned in `src/contract.ts` against **v2.45.0**.
Re-enumerate after any ox_inventory upgrade; nothing upstream is versioned.

- **`move`, `swap`, `stack` and `give` are NOT NUI actions.** They read like
  them and appear as `action = '...'` in `modules/inventory/server.lua`, but
  they are the SERVER HOOK payload's action field. Listeners for them never
  fire.
- **`setInventoryVisible` is a dead listener.** The stock React app waits for
  it and **no Lua in ox_inventory ever sends it** (zero hits across every
  `.lua`). `setupInventory` is what opens the UI. Waiting for the former is an
  inventory that never opens.
- **`refreshSlots` carries `items` as EITHER one payload OR an array**, from
  two different call sites in `client.lua`. Treating it as always an array
  drops every single-item refresh silently.

### Why the build lands inside ox_inventory, which looks backwards

`fetchNui` posts to whichever resource served the page, and a
`RegisterNUICallback` only answers for the resource owning the frame. Served
from a `som-*` resource, **all eleven of ox_inventory's callbacks would go
unanswered** and nothing could be moved, used or bought. There is no forwarding
trick. The source stays in git; only the output goes there. Their `web/build`
is untouched and the revert is one `ui_page` line.

### Built

Move, split (shift-drag and the menu), stack, use, give, drop-to-world, shops,
crafting, stashes, trunks, glovebox. Secondary panel left and main panel right
with their entry animations, derived category pills, a drop zone lit only while
dragging, a cursor-anchored context menu with the quantity stepper, the
detached hotbar, item notifications, and rarity as a single accent ramp.

Dragging is pointer events, not react-dnd: a fixed grid needs a hit test and a
ghost, pointer capture survives the cursor leaving the window, and a drag
ending outside the panel is exactly the drop-to-world case.

### The bridge, and the three features that needed it. BUILT

`som-inventory` is a **server-only resource**: no client script, no `ui_page`.
The page is served by ox_inventory, so a callback registered in som-inventory is
unreachable from it however it is written. The bridge is
**`ox_inventory/som_bridge.lua`, a NEW file** (not an edit to theirs) that
registers the extra NUI callbacks and relays them. It and the `ui_page` line are
on the AUDIT 16.2 re-apply list.

- **Throw.** Hold to charge, release to throw. The page sends a slot and a 0..1
  charge; the server re-reads the slot, re-reads the ped, clamps the charge and
  computes the landing point itself. **It removes the item BEFORE creating the
  drop**, because the other order creates a drop and then discovers the item was
  already gone, which is what a duplication bug looks like from outside. A
  thrown item becomes a real ox_inventory drop via `CustomDrop`, so it is
  pickupable by anyone and no second item-holding concept enters the codebase.
  12m at full charge with a per-player cooldown, deliberately: an underarm toss
  across a room, not a way to move contraband down a street without walking it.
- **Drag-to-give to a NAMED player**, which stock `giveItem` cannot express: it
  gives to whoever the client decided was in front of it. Distance measured
  server side between both peds, target must be loaded, `CanCarryItem` checked
  first, and **the item goes back if the add fails after the remove succeeded**.
  The nearby list is client-derived and read only: it answers what to draw, not
  what is allowed.
- **The shop basket needed no bridge and no new server code**, which is the good
  result here. It is staging, not state: lines live on the page and checkout
  replays them through ox_inventory's **own `buyItem`** one line at a time, so
  the server re-prices and re-validates each exactly as for a stock drag-to-buy.
  Sequential rather than parallel because ox_inventory holds a per-slot mutex.
  Two pay buttons rather than a toggle, so the account that pays is an explicit
  choice made at the moment of paying.

### Also built, via the bridge

The bridge is a CLIENT script, which turned out to unblock three things the
first pass had written off as impossible against this contract.

- **The bottom status strip.** Not in ox_inventory's contract and never will
  be, but it does not have to be: the bridge reads the ped itself and pushes a
  `somStatus` message into the same frame. Two things copied from som-hud
  rather than rediscovered: **GTA player health runs 100 to 200**, so the raw
  value shows a corpse at 50%, and it **sends only on change**, because a
  payload per tick makes the NUI feel heavy in a way profiling will not show.
  Armour at zero stands the row down rather than showing an empty bar.
- **The hover tooltip**, on the stock `getItemData`, fetched on hover rather
  than held for the whole grid. Only prints metadata keys the server named in
  `displayMetadata`; anything else is an internal key and printing it raw is
  how a UI leaks implementation. Suppressed mid-drag.
- **Take all** on a container, one `swapItems` per item into whatever is free,
  so the server decides each and a full inventory stops accepting part way.
  Not offered on shops, where taking is buying.
- **Basket persistence** across a close, held in the bridge keyed by shop id
  because the page is destroyed when the inventory closes. Still never an
  authority: checkout replays every line through stock `buyItem`.

### Clothing and nearby drops. BUILT, and both landed outside som-inventory

- **Clothing lives in `som-appearance`**, not the inventory. The inventory is
  where a player asks, but appearance is what changes, and keeping the mutation
  next to the data means **there is still exactly one writer of
  `som_characters.appearance`**, which is the property that makes that
  resource's scope system worth anything. New `server/wardrobe.lua` and
  `client/wardrobe.lua`.
  - **Removing is not destructive.** The garment moves into an
    `appearance.hidden` map and the live component is set nude, so the original
    is never overwritten and wearing it again is a move rather than a guess.
    **`Appearance.Apply` needed no change**: it applies components as stored,
    which are already nude, and `hidden` is an extra key every other reader
    ignores, including any fivem-appearance compatible tool.
  - **Hair is excluded from remove-all.** It is a component like any other and
    stripping it would make somebody bald, which is not what taking a coat off
    means.
  - The rail re-reads after every change rather than flipping a local flag,
    because the server may have refused.
- **Nearby drops shows THAT drops are there and how far, not what is in them.**
  Deliberate: knowing the contents of a container you have not opened is not
  something the stock inventory grants, and reading it out would be a new
  capability rather than a new surface. Opening goes through ox_inventory's own
  `openNearbyInventory`, so its distance and access rules apply.
  - It tracks `ox_inventory:createDrop` and `:removeDrop` rather than reaching
    into ox_inventory's private drop table. If those names change it stops
    finding drops instead of erroring on a nil table, which is the difference
    between reading a contract and reading an implementation.

**Caught while writing it:** `lib.callback.await` yields, and a NUI callback
handler is not a context to assume that is legal in. The wardrobe state read
answers from its own thread.

### The adversarial review, and the three defects it cost

Run against the throw/give paths, the wardrobe and the bridge. **Seven of its
eleven agents died on a session limit again** (third time on this project; see
AUDIT 21.9 and item 3 above), so it is a PARTIAL review: 2 confirmed, 6
refuted, and one claim that came back unverified because its verifier died.

All three are fixed. Each is worth keeping, because each is a class rather than
a one-off:

- **CRITICAL: the wardrobe was written against a shape this codebase never
  produces.** `components` and `props` are **ARRAYS OF RECORDS**
  (`{ component_id = 11, drawable, texture }`), built that way by
  `Appearance.Get` and read that way by `ApplyApparel`, which does
  `tonumber(c.component_id)` and **skips any record without one**. Indexing them
  as maps keyed by id hits an array POSITION, so component 3 read component 4's
  record, and writing a fresh `{drawable, texture}` table dropped
  `component_id`. `removeAll` would have silently emptied a character's stored
  appearance of every component and prop **permanently**, since `wearAll` wrote
  the same field-less shape back. Records are mutated IN PLACE now. Props also
  take -1 for none, not 0, since 0 is a real hat.
- **CRITICAL, and it came from the review's FAILED half: opening a drop was
  pickpocketing.** `openNearbyInventory` reads like the export for this and is
  not: it is `client.openInventory('player')` (`client.lua:709`), the function
  behind `/steal`, which opens the nearest **player's pockets**. Now
  `openInventory('drop', id)`. The review raised it and its verifier died before
  confirming, so it arrived as an unverified claim rather than a finding.
  **Checking it by hand took one grep.** The failed half of a review is not the
  same as the clean half.
- **HIGH: nearby drops only ever saw drops it watched happen.** Drops that
  already exist when a client connects never fire `createDrop`; the server hands
  the set over once in the first argument of `setPlayerInventory`, and
  ox_inventory's own client registers them by calling its local `createDrop`
  directly rather than re-emitting. So after any relog the list was empty while
  standing on a bag.

### The only thing deliberately not done

The throw readout is a NUMBER, not a drawn arc. The arc in the reference is
drawn in the world, which is client Lua: the page has no camera to project
against. Building it means a world-space trajectory preview in the bridge,
which is a rendering feature rather than an inventory one.

### NOTHING HERE HAS BEEN RUN

Not once. It typechecks and builds, and that is all that is known. First test
should be: open the inventory, confirm it appears at all, then move an item
between two slots and confirm it survives a reopen.

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
