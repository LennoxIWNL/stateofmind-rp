# Launch register

Everything that must be set, installed or verified before `BetaRelease` is promoted
to `main` and players are let in. Each feature PR adds to this file when it leaves
something unset. Tick an item off when it is done on the server that will be promoted,
not when the code is merged.

Nothing listed under "Verify in game" has ever run in a live FXServer. All of it is
covered by the mock harness only (`lua5.4 tests/run.lua`).

## Server and repo

- [ ] `som.cfg` is still in DEV MODE (framework only). Leave it, boot the full resource set once, and fix what breaks.
- [ ] GitHub branch protection on `main` and `BetaRelease` (require CI, no force push, no direct push).
- [ ] The beta server's git webhook runs with `BRANCH=BetaRelease`; the production server stays on `main`.
- [ ] Backups: scripts exist (`tools/backup.sh`, `tools/restore-check.sh`, see `LAUNCH-OPS.md`). Still to do on the real host: install the cron job, a restricted backup DB user, an off-machine copy, and run a restore check on a real backup (include `server.cfg`).
- [ ] `r14-evidence` stays out of `som.cfg`. Its server accepts client-supplied evidence data (AUDIT 18.1); `som-evidence` replaces it.

## Database

Import `setup.sql` on a fresh database. A database created from an older version needs these once:

- [ ] `ALTER TABLE som_jail_sentences ADD COLUMN release_pending TINYINT(1) NOT NULL DEFAULT 0;`
- [ ] `ALTER TABLE som_jail_sentences CHANGE conviction_id case_id BIGINT UNSIGNED DEFAULT NULL, ADD COLUMN kind ENUM('sentence','remand') NOT NULL DEFAULT 'sentence';`
- [ ] `ALTER TABLE som_court_cases ADD COLUMN service_tasks SMALLINT UNSIGNED NOT NULL DEFAULT 0 AFTER sentence_months;`
- [ ] New sections present: 7e (jail), 7f (court), 7g (community service), 7h (evidence), and the `doj` rows in the seed section.
- [ ] The `lspd` business has a bank account (bail and seizures are credited to it) and the `doj` business exists.
- [ ] The treasury balance is a decision, not an accident: it starts at 0 and fills from fines and business tax.

## Convars in `server.cfg` (never committed)

- [ ] `som_jail_webhook`, `som_court_webhook`, `som_evidence_webhook` (see `DISCORD_WEBHOOKS.md`).
- [ ] The Discord webhooks that were once committed in plaintext have been regenerated in Discord.

- [ ] `som_phone_webhook` (optional): a Discord webhook that receives new Chirp reports.
- [ ] `som_phone_pepper` set to a long random string (passcodes are hashed with it; changing it later resets every passcode).

## Phone

- [ ] `setup.sql` section 4b imported (new `som_phone_devices` and `som_phone_audit`; nothing existing changes).
- [ ] The phone item is non-stacking in `ox_inventory` (it is today); each phone gets an imei written by the server on first use.
- [ ] `ui/` rebuilt output is committed (`html/assets`); a change to `ui/apps/som-phone` needs `npm run build` there.
- [ ] Not verified live: NUI focus and cursor, the hold animation, a banner arriving with the phone closed, unique phone metadata with real items.

- [ ] pma-voice hardening: its `pma-voice:setPlayerCall` net event lets a client join any call channel. Calls use random channels so this is hard to exploit, not closed. Decide whether to patch or replace pma-voice before launch.
- [ ] Not verified live: the ring sound and loop, the Y and N key bindings, the call hold animation, a call with two real clients through pma-voice, `voice_enableCalls` is on.

- [ ] Chirp and Pages: `setup.sql` 4b has six more tables (`som_phone_handles`, `_posts`, `_likes`, `_reports`, `_adverts`, `_pages_optin`).
- [ ] `Config.Social.imageHosts` is empty, so posts cannot carry images. Pick one host (the same one the camera needs) and list it.
- [ ] `Config.Social.reserved` is the handle blocklist (departments, staff words). Add the server's real department and business names.
- [ ] Staff who moderate have the `som.mod` permission; `/removepost` is untested in game.
- [ ] Nobody has chosen a Chirp moderation routine yet: reports only land in `som_phone_reports` and the optional webhook.
- [ ] Not verified live: Chirp and Pages in a game client, the supporter handle and colour perks with a real entitlement.

- [ ] Garage, Services, Notes: `setup.sql` 4b adds `som_phone_notes`. `Config.City.services` lists the jobs shown with a count; check they match the real jobs.
- [ ] 911 from the phone uses `som-dispatch`'s `emergencyCall`; confirm in game that the call arrives with the caller's name and number and the right position.
- [ ] Camera and Gallery are not built. They need the image host (same one as `Config.Social.imageHosts`) and a `screenshot-basic` upload endpoint.
- [ ] Garage cannot locate or recall a vehicle yet.

## Groups

- [ ] `som-groups` is in `som.cfg` after `som-launder`; confirm the boot order with the new resource.
- [ ] Group size (6) and invite time (120 s) are my defaults, not from a real server. Adjust in `som-groups/shared/config.lua`.
- [ ] Not verified live: the Groups app with two real clients (invite banner, accept, ready, kick, leave on disconnect).

## Job board

- [ ] `som-jobboard` is in `som.cfg` after `som-groups`.
- [ ] The lottery numbers (draw every 20 s, 3 minute offer, weight up to 4 after 30 minutes, lock 15 minutes after 2 refusals) are my defaults. Tune after playtests.
- [ ] A refusal lock follows the group id, so leaving and regrouping clears it.
- [ ] No provider ships yet, so the Jobs app lists nothing until the courier run branch lands.

## Courier run

- [ ] `som-courier/shared/config.lua` `Config.routes` is empty, so the run is disabled. Add real pickup and drop coordinates.
- [ ] Pay (`payPerDrop` 120) comes from the `postop` business. Check its balance and the number are sensible; a broke company means unpaid drops.
- [ ] The carry animation and the blip sprite 478 are unchecked guesses.
- [ ] Not verified live: a crew doing a full run, the zone and progress bar, pay arriving per member.

## Heists

- [ ] `setup.sql` 7j: `som_heist_dongles` and `som_heist_runs`.
- [ ] EVERY site in `som-heists/shared/config.lua` is disabled with no coordinates. For each of store, small bank and vault: terminal, loot points, `ox_doorlock` door names, then set `enabled = true` and test a full run.
- [ ] Tier numbers (police 1 / 3 / 5, cooldowns 45 / 90 / 240 min, clean cash and hourly caps, marked bill counts) are my defaults. Tune them against the real economy.
- [ ] The treasury balance starts at 0, so clean cash pays nothing until it holds money.
- [ ] Dongles only come from `/givedongle` and `exports['som-heists']:mintDongle`. Decide the in-world source (fence, crafting with a ledger row, drug economy). ox_inventory's own crafting recipe for `trojan_usb` produces a copy with no ledger row, so it does nothing: remove or repoint it.
- [ ] Check `ox_doorlock`'s `setDoorState` works when called from another resource's server code (it reads the event `source`).
- [ ] Optional convar `som_heist_webhook` for heist start and end logs.
- [ ] Not verified live: any part of a heist in a game.
- [ ] Not built: intel rows and per-heist custom stages (hack then loot is the only shape).

## Jobs to whitelist and assign

- [ ] `judge`, `prosecutor`, `defender` (court), `dispatcher` (dispatch). All four are `whitelisted`.
- [ ] Confirm `som-core` accepts the four new jobs at boot (never checked).

## Coordinates and places (all UNVERIFIED, from other scripts or estimates)

Use `/pdcoords` in game to print a position formatted for a config file.

- [ ] Courthouse desk: `som-court/shared/config.lua` `Config.Desk`.
- [ ] Evidence locker and lab: `som-evidence/shared/config.lua` `Config.Stations.mrpd`.
- [ ] Community service area, spawn, release point and the six task spots: `som-jail/shared/config.lua` `Config.Service`.
- [ ] Prison yard, cell spawns, freedom and gate points: `som-jail/shared/config.lua` `Config.Cell` (Bolingbroke defaults from qb-prison).
- [ ] The community service scenarios (`WORLD_HUMAN_JANITOR`, `WORLD_HUMAN_GARDENER_PLANT`) look right on the chosen spots.

## Verify in game

- [ ] Jail: book, relog mid-sentence (no escape flag), die in the yard, walk out (escape flag and a dispatch blip), bail pays the department, a sentence served while offline, held items come back.
- [ ] Court: file, accept, schedule, a ruling is refused before the hearing, a guilty ruling, booking takes the months from the case, a fine lands in the `doj` account, a lawyer cannot act as judge.
- [ ] Community service: tasks need their progress time, cannot be done from afar, leaving the area adds tasks, a downed worker is not penalised, ps-mdt's button works for police and fails for a civilian client.
- [ ] Evidence: shoot (casing), `/scene`, collect, lock up, analyse, match against a sample, link to a case. Dispatch's detection really reaches `som:server:crimeReported`, and `ox_inventory`'s weapon lookup works with real weapon items.
- [ ] Dispatch: repeat reports merge, a fight shows as a search area, attach and assign, a major incident, ps-mdt still renders merged and offset calls.
- [ ] The two evidence kit icons look right in the inventory.

## Assets

- [ ] `gsrtestkit.png` and `dnatestkit.png` are placeholders drawn for this repo; replace them with proper art.
- [ ] 18 inventory items have no icon (`tools/item-icons-baseline.txt`).
- [ ] From AUDIT 22.5: the duplicate `minimap.gfx` (karma-minimap and ps-hud), a PDM map (Gabz recommended), the inventory panel proportions, four literal colours in `som-inventory/app.css`.

## Heists (planned; add to this list as each branch lands)

- [ ] Every heist tier and location ships disabled. Enable one only after its map is installed and its coordinates are walked.
- [ ] Bank maps are not installed: Pacific Bank Extended and Fleeca (`som.cfg` lists them as a Phase 6 asset).
- [ ] `ox_doorlock` door names for any vault or cage door are created and put in the config.
- [ ] Laundering fronts (where marked bills are washed) are chosen and set.
- [ ] After the first week of play, read the economy sink/faucet report: heists and laundering are a measured faucet.

## Launch ops

- [ ] Whitelist and application flow, staff tools, anti-cheat coverage review and written rules are not built (`LAUNCH-OPS.md`). They need owner decisions.
- [ ] Full boot out of DEV MODE has not been attempted (needs the streamed assets and a client).
- [ ] Load test with real players has not been run. `tools/load-claims.sh` covers the heist claim query only.

## Turf and the drug market (som-turf)

- [ ] All three zones (`grove`, `vespucci_canals`, `davis`) are disabled with no coordinates. Set `center`, `radius`, `tag` and `enabled` per zone in `som-turf/shared/config.lua`, and rename or add zones. `som_turf` rows are seeded at boot.
- [ ] Import section 7k of `setup.sql` (`som_drug_market`) on an existing database.
- [ ] Prices, `dropPerUnit`, `floor`, `recoverPerHour`, `ownerBonus`, `holdMinutes`, `claimGrade` and `policeMin` are defaults, not tuned numbers. Marked bills from sales feed the launder fronts' hourly budget, so check the two together.
- [ ] Gang members come from `/setgang`-style admin tools or the boss app; there is no application flow yet.
- [ ] Never run in a game: sphere zones, the tag progress bar, the sell dialog, two gangs contesting. The marked bill mint needs a real ox_inventory pass.
- [ ] Not built: passive gang payments, a phone or HUD view of turf, growing and processing, NPC buyers.

## Whitelist (som-staff)

- [ ] The gate is off until `set som_whitelist 1` is in the real `server.cfg`. Before turning it on, whitelist every staff licence with `/whitelist add license:<hex> <note>` from the console, or nobody can get in.
- [ ] Import section 7l of `setup.sql` (`som_whitelist`) on an existing database.
- [ ] The Discord application form and review are not built (the bot source is not in this repo). The bot can drive the list over RCON (`whitelist add <identifier> <note>`) or insert into `som_whitelist` directly. Decide the form, the reviewers and the notification.
- [ ] The connect gate itself has never run with a real client; only the command and SQL were exercised on the headless server.

## Staff tools (som-staff)

- [ ] Import the `som_reports` and `som_staff_audit` tables (section 7l of `setup.sql`) on an existing database.
- [ ] Grant staff in `server.cfg` (`add_ace group.mod som.mod allow`, `group.admin` for `som.admin`). `/goto`, `/bring`, `/spectate` and `/reports` need `som.mod`; `/whitelist` needs `som.admin`.
- [ ] Built: `/report` for players (one open, 200 characters, 60 s gap), a staff queue menu (`/reports`, claim and close), `/goto`, `/bring`, `/spectate`, and an audit row for each staff action. Staff v2 (below) added kick, ban, freeze and an audit viewer. Not built: noclip, a staff duty toggle, Discord logging of reports.
- [ ] The spectate native, the reports menu and teleports via OneSync have never run with a client.
- [ ] Anti-cheat: read-only review done (`ANTICHEAT-REVIEW.md`), staff immunity fixed. Still needs a live false positive pass, the `lac_webhook_*` convars, and a decision on wiring money events.
- [ ] Rules: a draft exists (`RULES-DRAFT.md`). The owner must approve it, set the penalty ladder, and choose where it is published.

## Gang management (som-turf, phone app `gang`)

- [ ] Import the `som_gang_log` table (end of `setup.sql`) on an existing database. Gang bank accounts are created on first use (`GANG-<NAME>`).
- [ ] Nobody is a boss until you make them one: set the first boss of each gang with the existing admin path (`/setgang`-style tool or a database update of `som_characters.gang` and `gang_grade`). From there the boss runs the roster in the phone.
- [ ] `Config.gang` (max 30 members, 10 m invite distance, 120 s invite, 50000 deposit cap) are defaults. The deposit comes from the boss's bank, so the gang account is funded by washed money only.
- [ ] Ranks are changed one step at a time, never above the boss's own rank, and never for someone at or above it. The last boss cannot leave.
- [ ] The app has never been opened in a real phone UI; the view is the same host format as Groups.
- [ ] `Money.GangTransact` (som-core) exercised on the real database only as plain SQL, not through a running player.

## Gang payroll and the turf app (som-turf)

- [ ] Payroll runs hourly (`Config.payrollMinutes`), pays online members of gangs that hold a zone the `payment` of their grade from `som-core/shared/gangs.lua` (20 to 75 an hour as shipped), capped at `Config.payrollCap`. The money comes out of the gang account, which only boss deposits fill. Decide whether those pay figures are right for your economy.
- [ ] The `turf` phone app is read only: zone owners and contests for everyone, street prices and recent gang activity for gang members. It reuses the `briefcase` icon; a dedicated icon needs a UI rebuild.
- [ ] Payroll never ran with a real player and the real `gangTransact`; only SQL and the mock harness.

## Weed growing (som-turf)

- [ ] Import the `som_plants` table (end of `setup.sql`) on an existing database.
- [ ] Every grow spot (`Config.grow.spots`) and bagging table (`Config.grow.bagTables`) ships disabled with no coordinates. Without a spot, plants can still go inside a zone a gang holds, so enable zones with care.
- [ ] Uses existing items: the five `weed_*_seed` seeds, `water_bottle`, `weed_nutrition`, `weedbud`, `empty_weed_bag` and the `weed_*` baggies (all have icons). Grow time 60 min, wither after 120 min without water, yield 3 to 6 buds (+2 fed), 3 buds per bag, 6 plants per character: defaults, untuned. Baggies are what the street sale already buys.
- [ ] Planting raises the low-chance `drugDeal` dispatch call. The prop `prop_weed_01` and the progress bars have never been seen in a client.

## Labs (som-turf)

- [ ] Import the `som_lab_jobs` table (end of `setup.sql`) on an existing database.
- [ ] `Config.labs` ships disabled with no coordinates. Enable and place one or more.
- [ ] Recipes: `press_brick` (coke_brick to 3 coke_small_brick, 15 min) and `cut_coke` (coke_small_brick to 4 cokebaggy, 10 min) use existing items. Nothing in the game hands out `coke_brick` yet (not a heist payout, not a shop), so decide the source, or the chain starts only from admin-issued items.
- [ ] `cook_meth` is now enabled (2 ephedrine, acetone, lithium, hydrochloric acid for 5 meth, 30 min) and `refine_leaf` (4 coca leaves and sulfuric acid for a brick, 20 min). The six new items are in `ox_inventory/data/items.lua` with community-pack icons. The recipes only run at a lab you place.
- [ ] One cook per lab at a time and one per character; a cook is collected only by whoever started it. Starting raises the low-chance `drugDeal` dispatch call.
- [ ] Never run in a client: the lab zone, dialog and progress bar.

## Chemical supplier (som-turf)

- [ ] `Config.supplier` ships disabled with no coordinates. It is the only source of coca leaves and precursors, so place it deliberately (it is a gang-only shop). Prices (40 to 150 each) and `maxQty` 5 are defaults. Payment is from the buyer's bank into the treasury (a sink), so nothing is minted; the treasury then funds heists and city budgets.
- [ ] Still no source for `coke_brick` other than `refine_leaf`; the old note about it is superseded.
- [ ] Not run in a client: the supplier dialog and zone.

## Mechanic job (som-mechanic)

- [ ] The `mechanic` job (Los Santos Customs, whitelisted) already existed; `som-mechanic` adds the work. A mechanic on duty gets a "Repair" option on any vehicle: engine (1 `repairkit`, $250) and body (2 `steel`, $180). Prices, parts and the 30 s per-vehicle cooldown are defaults in `Config`. The driver, if a player, is billed to `lscustoms` through the phone (so the shop earns, not the mechanic); an unbilled repair only costs the mechanic parts.
- [ ] Mechanics have no way to get `repairkit` or `steel` in the world yet (no shop, no recycle link). Decide the supplier (an ox_inventory shop at the garage, or `jim-recycle`).
- [ ] Not built: tyres, tuning/mod shop (that is `som-garage`'s modshop), mechanic commission (`jobs.lua` has `commission = 0.12`, unused), tow integration with `som-towtruck`. `jim-mechanic` (paid) stays off.
- [ ] Health is read on the server but applied by the mechanic's client (setting vehicle health is a client native), so the effect is cosmetic-trust only; the parts and the bill are decided server side. Never run in a client.

## Fishing and buyers (som-outdoors)

- [ ] Import the `som_buyer_payouts` table (end of `setup.sql`) on an existing database.
- [ ] Fishing spots (`Config.fishing.spots`) and the fish buyer (`Config.buyers.fish`) ship disabled with no coordinates. Place them.
- [ ] Buyers pay from the **treasury**, capped per rolling hour (fish: 6000 for the whole server). The treasury starts at 0, so until fines and taxes fill it a buyer says "the city cannot pay right now". That is deliberate; decide whether the treasury needs a seeded balance.
- [ ] Catch table (codfish 50, bass 30, fishingloot 15, fishinglootbig 5), prices (40, 55, 90, 180), bite wait 8 to 20 s, rod and bait items are defaults. Fish items and icons already existed.
- [ ] Nothing hands out `fishingrod` or `fishbait` in the world yet (no shop). Decide the supplier.
- [ ] Never run in a client: the cast progress bar, zone, sell option.

## Hunting (som-outdoors)

- [ ] The game buyer (`Config.buyers.hunt`, venison 60, deer pelt 120, antlers 150, cap 6000 an hour) ships disabled with no coordinates, and pays from the treasury like the fish buyer.
- [ ] Hunting has no zones: any deer or boar (`a_c_deer`, `a_c_boar`) killed by the player can be skinned anywhere, with a `hunting_knife`. Decide whether to restrict it to a hunting area. Nothing hands out the knife in the world yet.
- [ ] `requireLicense` is off. A `hunting_license` item exists but nothing issues it (the `som-id` licence flow is not built for it).
- [ ] The server reads the carcass itself (model, health, killer ped, a `skinned` flag on the entity), so the client cannot invent a kill. Never run in a client: the ped target, skinning bar, and `GetPedSourceOfDeath` behaviour with real peds.

## Chop shop (som-outdoors)

- [ ] Import the `som_chop_log` table (end of `setup.sql`) on an existing database.
- [ ] `Config.chop.dropoffs` and the scrap buyer (`Config.buyers.scrap`, prices 8 to 30, cap 6000 an hour from the treasury) ship disabled with no coordinates.
- [ ] A vehicle whose plate is in `som_vehicles` is refused, so players cannot lose an owned car; that also means a stolen player car cannot be chopped (a deliberate cut). Rental plates are NOT checked: confirm rentals use plates that never reach a chop, or add a check against `som-rentals`.
- [ ] The VIN scrub is a progress bar with a server-enforced minimum time (25 s), not a skill check: the server cannot trust a client's skill result. 10 minute drop-off cooldown and 24 hour plate cooldown are defaults.
- [ ] Calls dispatch `chopShop` at the shop with a 40% chance. Parts reuse existing items and icons. Never run in a client.

## New life rule (som-medical)

- [ ] Import the `som_new_life` table (end of `setup.sql`) on an existing database.
- [ ] Respawning at the hospital after being killed by **another player** records a 15 minute new life at the place of death and tells the player; any other death (fall, vehicle, NPC, environment) has no restriction. `Config.NewLife` has the minutes and a 200 m radius (the radius is only shown in text; nothing is enforced). A medic revive is not a new life.
- [ ] Not built: more classes (execution, hostage), enforcement near the death place, a ban on returning. Staff read it with `/nlr <id>` (needs `som.mod`) or the `getNewLife` export. The rules text in `RULES-DRAFT.md` (new life, 15 minutes) should match whatever you set here.
- [ ] Cause is derived on the server from the killer ped (`GetPedSourceOfDeath`, `IsPedAPlayer`); never run with real players, so check it classifies a player kill correctly.

## Backstory at creation (som-core, som-multichar)

- [ ] Creating a character now needs a written backstory of 100 to 1000 characters (`Config.Characters.backstoryMin/Max` in `som-core/shared/config.lua`). The server cleans and checks it; the form field and the client check are only feedback. It is stored in `som_characters.metadata.backstory`. Existing characters have none (metadata default is an empty string).
- [ ] Staff have no screen for it yet: read it from `metadata` in the database. Showing it in the `/reports` menu is not built.
- [ ] The creation form was edited (a textarea) and has not been seen in a client; check its layout in the multichar screen.
- [ ] The backstory is free text and nobody reviews it automatically. The whitelist application (not built) is where review belongs.

## Staff tools v2 (som-staff)

- [ ] Import the `som_bans` table (end of `setup.sql`) on an existing database.
- [ ] `/kick` (som.mod), `/ban <id> <hours> [reason]` and `/unban <identifier>` (som.admin or the server console), `/freeze` (som.mod), `/staffaudit` (a menu of the audit table, som.mod). Hours 0 is a permanent ban. A ban covers every licence, discord and steam identifier the player had; bans are checked at connect **even when the whitelist is off**, and a failed ban check refuses the connection rather than letting it through.
- [ ] Not built: noclip (the anti-cheat treats `som.mod` as immune, so a client noclip would need its own server notice) and a staff duty toggle. Bans lift only per identifier; there is no ban search or appeal list.
- [ ] None of it has run with a client: the connect gate, `DropPlayer`, freezing a real ped.
