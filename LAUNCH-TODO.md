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
- [ ] Fishing rod (120) and bait (15) are sold at every General store; fish sell prices are 40 to 180, so a bait costs about a third of an average catch. Untuned.
- [ ] Never run in a client: the cast progress bar, zone, sell option.

## Hunting (som-outdoors)

- [ ] The game buyer (`Config.buyers.hunt`, venison 60, deer pelt 120, antlers 150, cap 6000 an hour) ships disabled with no coordinates, and pays from the treasury like the fish buyer.
- [ ] Hunting has no zones: any deer or boar (`a_c_deer`, `a_c_boar`) killed by the player can be skinned anywhere, with a `hunting_knife`. Decide whether to restrict it to a hunting area. The knife (150) is sold at YouTool.
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

## Skills (som-progress)

- [ ] Import the `som_skills` table (end of `setup.sql`) on an existing database.
- [ ] Six tracks (fishing, hunting, growing, chemistry, mechanic, scrapping). Level n needs 120 * (n-1)^2 experience, level 10 is the cap, and a track earns at most 1500 experience a day. Effects are small and meant to reward weeks of play: fishing and hunting find rare things more often, growing and scrapping give one extra per three levels, chemistry shaves 3% per level off a cook. Mechanic currently only earns experience. All numbers are untuned defaults.
- [ ] A read only `Skills` phone app lists the tracks (reuses the briefcase icon). Courier, heists and gang work do not earn experience yet.
- [ ] Never run in a game; the experience cap SQL was run on the dev database only.

## Skill unlocks

- [ ] Gates (all server side, same numbers shown in the Skills app under "Coming up"): deep water fishing needs fishing 4, boar needs hunting 3, OG Kush growing 5 and Amnesia 7, refining coca leaves needs chemistry 2 and cooking meth chemistry 4, body repairs need mechanic 2. A new `crafting` track exists for the benches (next PR). Levels and numbers are untuned defaults. The unlock list in `som-progress/shared/config.lua` is display only and must be kept in step with each resource's `minLevel`.
- [ ] A deep water fishing spot (`deep_1`) ships disabled with no coordinates.

## Shop stock (ox_inventory shops)

- [ ] General stores now also sell water bottles (8), fishing bait (15), fishing rods (120) and empty weed bags (5); YouTool sells the hunting knife (150), screwdriver set (60), electronic kit (90) and plant nutrition (25). Payment is charged to the buyer's bank through the existing SOM currency bridge and is a pure sink. Prices are untuned.
- [ ] Repair kits and advanced lockpicks are deliberately not in any NPC shop: they are for player mechanics to craft and sell (later in this update), with a fallback when no mechanic is on duty. Until that lands, nobody can buy them.

## Crafting benches

- [ ] The old `debug_crafting` bench is now the `mechanic_workshop` bench (same two real locations, restricted to the mechanic job). Recipes: lockpick, repair kit, tire repair kit, advanced repair kit, advanced lockpick and electronic kit, all from chop shop parts and shop goods. The ledger-less `trojan_usb` recipe was removed, so dongles only come from the launder ledger.
- [ ] A rule hook in `som-inventory` requires the mechanic job on duty and a crafting level (repair and tire kits 2, advanced kit and advanced lockpick 5) and grants crafting experience. Experience is granted when the craft is allowed, not when it finishes, because ox_inventory has no after-craft hook.
- [ ] Not built yet: the public DIY bench (needs coordinates) and the no-mechanic fallback desk, both in the mechanic shop PR.
- [ ] Never run in a game: the bench UI, group gating through the SOM bridge, and the hook payload (`recipe.name`) were read from ox_inventory source only.

## Seeds and the economy map

- [ ] Seeds had no source in the world. The gang-only supplier (disabled, no coordinates) now sells all five strains (60, 60, 80, 200, 300), and a harvest returns its own seed 25% of the time. The level gates (OG Kush 5, Amnesia 7) still apply when planting. If seeds should come from somewhere less gang-flavoured, move them.
- [ ] A hammer (80) is now sold at YouTool because the lockpick recipe wears one.
- [ ] `ECONOMY-MAP.md` is generated (`node tools/economy-map.mjs`); CI fails if it is stale or if an item a recipe, lab, plant, fishing, hunting, repair or buyer needs has no source. Intentional gaps go in `tools/economy-known.json`. The generator reads configs with patterns, so a new recipe shape may need a line in the script.

## Mechanic sales and the roadside fallback (som-mechanic)

- [ ] Import the `som_trade_offers` table (end of `setup.sql`) on an existing database.
- [ ] A mechanic on duty gets an "Offer a kit" option on nearby players: repair kit ($120 to $450), tire kit ($80 to $300), advanced repair kit ($400 to $1200), advanced lockpick ($250 to $900); the price is theirs inside the limits. The customer accepts in the phone's "Offers" app within 2 minutes. The money goes to the shop's business account (`lscustoms`), the mechanic keeps the job's 12% commission, and every step rolls back on failure. Limits are untuned defaults.
- [ ] The roadside desk (`Config.fallback`, a repair kit for $700 once an hour, paid to the treasury) ships disabled with no coordinates. It only sells while NO mechanic is on duty, so it never undercuts the trade. Decide where it goes and whether $700 is right (the price should stay well above the top of the mechanic range).
- [ ] The "Offers" app reuses the receipt icon. A DIY public crafting bench is not built (needs coordinates). The lscustoms business needs a real owner and bank account for sales to land in.
- [ ] Never run in a game: the ped target, dialog, phone app and the sale itself between two players.

## Placing content in game (som-staff)

- [ ] Import the `som_placements` table (end of `setup.sql`) on an existing database.
- [ ] `/place <resource> <path> [value]` (admin or console), `/unplace`, `/places`. Stand where the thing goes and run, for example, `/place som-turf zones.grove.tag`, `/place som-turf zones.grove.center`, `/place som-turf zones.grove.radius 40`, `/place som-outdoors buyers.fish.coords`, `/place som-heists sites.store_1.terminal`, `/place som-heists sites.store_1.lootPoints+` (once per loot point). A placed point also switches its entry on. Then `restart <resource>` to load it. Resources that can be placed: som-turf, som-outdoors, som-heists, som-mechanic, som-launder.
- [ ] Not placeable this way: courier routes (a route is a list of drops, still edited in config), heist door names (config), and anything outside those five resources. A typo'd path is reported in the console when the resource starts ("no such place").
- [ ] Verified on the headless server only through the console (a radius): placing, restart and apply. Positions need an in-game admin and have not been run with a client.

## Health check and trace

- [ ] `/somhealth` (staff or console) reports resources, database, tables, items and convars. Its first run found two real defects, now fixed: the shops sold `cola` and `medikit`, which had no item definition (they were lost with the QBCore removal). `medikit` is defined but has no use effect: decide how medics use it (the treatment flow is in `som-medical`).
- [ ] Set `som_phone_pepper` in the real `server.cfg` (the check fails without it) and the webhook convars you want. `set som_debug 1` turns on a one line trace of every server callback while testing; leave it off in production.
- [ ] `health_lists.lua` is generated (`node tools/gen-health-lists.mjs`); CI fails if it is stale.

## EMS revive

- [ ] `som-ems`: an on-duty `ambulance` medic gets a "Treat" option on a downed player, spends one `firstaid` kit and the patient is billed 600 to the `ems` business. Price, 15 second treatment and 60 second cooldown are untuned defaults in `som-ems/shared/config.lua`.
- [ ] Not verified live: the player target option, the CPR animation (`mini@cpr@char_a@cpr_str`), the `som:downed` state read on the medic's client, the bill arriving on the patient's phone.
- [ ] Place the EMS supply locker (`Config.locker` in `som-ems`, ships disabled): it issues a free `firstaid` kit from the department (`firstaid = 0` in `Config.Armoury.departmentIssue`), up to 3 carried. Medics are `whitelisted`. No heal or bandage treatment, stretcher or hospital check-in in this version.
- [ ] Paychecks, MDT incident delete and status changes got server-side guards (a failed pay step no longer stops everyone's pay and returns the business money, repeat MDT deletes for one incident are ignored, client status changes are capped at 100 per minute). Never run in a game: an hourly paycheck with a real database error, and the 100 per minute status budget against real eating, drinking and stress items (untuned).

## Money writes

- [ ] Business and city treasury balances are now changed with one conditional add, and a failed player money save is noticed and rolled back. Only the mock suite and the dev MariaDB have run them. In game: a shop sale, a seizure and a heist payout at the same moment, then check `som_transactions` against the balances. Whether oxmysql returns `false` (not an error) for a failed transaction is assumed from how it is documented, not run.

## Player shops (som-shops)

- [ ] Every shop ships disabled with no coordinates. Place each (staff `/place som-shops shops.alta.coords`, or set `Config.shops` coordinates and `enabled = true`) and decide the real shop list and prices. The two entries (`alta`, `strawberry`) are placeholders.
- [ ] `setup.sql` gets three tables (`som_shops`, `som_shop_stock`, `som_shop_staff`). On start the resource creates one bank account (`SHOP-<ID>`) and one business row (`shop_<id>`) per configured shop; these are separate from the job businesses, so core paychecks never touch them.
- [ ] Decide `Config.items` (what a shop may sell and the price range), the tax rate, the sell-back share, the withdrawal cap and cooldown, and the staff pay cap. They are first guesses, not tuned.
- [ ] Not verified in a live server: the counter menu and the owner management menu (som-ui context and dialog shims), the hire offer dialog, the phone app, hourly payroll over a real restart, and concurrent sales. Only the mock suite and a scratch MariaDB ran the queries.
- [ ] Shop ownership never expires: a shop whose owner stops playing stays owned, and there is no way for staff to take it back except in the database. Decide an inactivity rule later.
- [ ] Left out on purpose: supplier ordering, several shops per owner, handing a shop to another player, staff grades or commission, shop robbery.
## EMS hospital transport

- [ ] Sink and faucet change for staff: the hospital respawn fee (350, `Config.RespawnFee` in `som-medical`) is now paid into the `ems` business account instead of vanishing. If the credit fails the player is refunded and treated free.
- [ ] Place the hospital in `som-ems` (`Config.hospital`, ships closed): front `desk` point and a `bed` point (vec4). Admission charges the patient 250 into `ems` first, then pays the medic 60 percent (150) from `ems`, only after the charge went through. A patient who cannot pay is still admitted and the medic gets nothing. Needs at least 30 s down and a 60 s per-patient cooldown. All numbers untuned.
- [ ] Not verified live: server side `SetPedIntoVehicle` on a downed player (seats 1 and 2 of an `ambulance`), the medic's "Load into ambulance", "Unload patient", "Check patient" and desk "admit patient" options, the bed animation (`missarmenian2` / `drunk_loop`) and fade, and that a loaded patient is not pulled back by the down anchor. Cause on "Check patient" is only "hurt by another person" or "an accident" (the server's own death classification).
- [ ] Cut on purpose: bleeding and injury states (nothing tracks them), a second hospital, a stretcher prop, medic XP.
## Licences and driving school (som-licences)

- [ ] Existing databases: `ALTER TABLE som_licenses ADD COLUMN suspended_until TIMESTAMP NULL DEFAULT NULL;` and import the new `som_licence_attempts` table (`setup.sql` section 7m).
- [ ] The school ships closed. In `som-licences/shared/config.lua` set `school.coords` (the counter), `school.spawn` (a vec4 for the test car) and `practical.route` (a list of vec3 checkpoints on public roads), then `school.enabled = true`. Fee, pass mark, retry wait, speed limit and fault count are untuned defaults.
- [ ] **Run the legacy backfill before this ships to a database with players** (commented SQL at the end of `setup.sql`, section 7m). Weapon licences bought from the old shop exist only as character metadata, and login now rebuilds metadata from `som_licenses`, so without the two `INSERT IGNORE` statements existing holders lose the licence.
- [ ] `ox_inventory/data/licenses.lua` is now empty: the $5000 weapon licence shop is gone. A weapon licence comes from an officer of grade `Config.approveGrade` (3) with the buyer agreeing on screen within `Config.weapon.offerSeconds` (the officer's duty, rank and distance are checked again when they agree), fee `Config.weapon.fee` to the `lspd` account.
- [ ] Review the 15 theory questions in `som-licences/server/questions.lua` (road rules are written for a generic left/right-agnostic setting; question 12 assumes driving on the right).
- [ ] The school car is locked with the server-side `SetVehicleDoorsLocked(entity, 2)` and the test taker is seated by the client; not run live, so confirm others cannot get in and the taker can.
- [ ] Never run in a game: the theory menus, the school car appearing and the player being put in it, the checkpoint blip, officer options on a player (check, suspend, revoke, issue), and the ps-mdt licence revoke button turning into a revoke in `som_licenses` (it is assumed to write `metadata.licences.<type> = false` through som-compat).
- [ ] A suspension that ends while the player stays online leaves `metadata.licenses` false until their next login; the table is correct at once, so a police check and the licence card are right and only the ox_inventory weapon gate lags.
- [ ] Not built, on purpose: other licence classes, licence points, an automatic fine for driving unlicensed (officers use the existing "Driving without a licence" fine), a background check before a weapon licence, and a record of which officer suspended or revoked.
## Money write follow-ups

- [ ] Gang, business and treasury ledger writes undo the balance change if the ledger row cannot be written (two separate statements, not one transaction). Needs a live database check that a single `MySQL.transaction` with a `ROW_COUNT()` guard behaves the same before replacing it.
- [ ] Heist clean cash payouts now wait for the previous payout instead of paying nothing; the wait loop is only provable in a live server with two crews looting together.
- [ ] Buyer sales and heist clean payouts now record the payout before paying, so a database failure refuses the sale instead of paying without counting it against the hourly cap.

## Garbage round

- [ ] Import the new seed rows on an existing database (they are `INSERT IGNORE`, section 9 of `setup.sql`): the `GOV-SAN` bank account and the `sanitation` business row (funding `treasury`, category `government`). The business cache loads at start, so restart `som-economy` after importing. Without the row the Jobs app says "the sanitation department is not set up".
- [ ] `som-garbage/shared/config.lua` `Config.routes` is empty, so the job is refused. Add a depot (vec4), the landfill and recycling centre (vec3) and stops with bins (`id`, `kind` general or recycle, `coords`).
- [ ] Funding: Sanitation pays crews from its own account, which starts at 0. Short payouts are topped up from the city treasury (`fundFromTreasury`, now exported by `som-economy`), at most `monthlyBudget` (150000) per 30 days, counted from the treasury ledger rows with reason `budget:sanitation`. The treasury starts at 0 and fills from taxes, so until it holds money every round is refused at the board ("the city cannot fund a round right now") and nothing is created. Staff decide the monthly figure and whether to seed the treasury or the account.
- [ ] A job is only offered when the account plus the allowed top-up covers a full round, so a crew is never sent out unpaid at the start; a round can still go unpaid if other payouts drain the account meanwhile.
- [ ] Hourly cap per citizen (2000) is held in memory and resets on restart. Untuned defaults: 12 per bag, +10 for a correctly sorted recycling bag, 15 minute lockout after abandon (`/abandonround`), expiry or disband.
- [ ] The `trash` model, the blip sprite 318, the `anim@heists@narcotics@trash` throw animation and the bin positions are unchecked guesses. The sort is read from the bin colour label, by design.
- [ ] Not detected: a dead or jailed member keeps the round until it expires (40 minutes plus 15) and then the truck is removed.
- [ ] Not verified live: the server spawned truck, bin interaction zones, a crew of three, a real payout from the treasury.
## Clock in and out, and taxi

- [ ] `som-duty` adds a "Clock in or out" entry to the F1 radial under Work for every job except police and unemployed. Before it, only police could go on duty, so ambulance, dispatcher, judge, prosecutor, defender, cardealer and realtor (all `defaultDuty = false`) could never use anything gated on duty. Never run in a game: the radial entry appearing, the five second cooldown, and each of those jobs reaching its duty-gated features.
- [ ] `som-ems` is now listed for `/place` (for example `/place som-ems locker.coords`). The hospital desk and bed (once that branch is merged) are not placeable points yet; edit their coordinates in `som-ems/shared/config.lua`. `som-licences` is not placeable (its manifest does not load the placements script): edit `school.coords`, `school.spawn` and `practical.route` in config.
- [ ] Taxi (`som-taxi`): the `taxi` job already exists and starts on duty. Cabs: add a shared job garage to `som-garage` `Config.Garages` (`type = 'job'`, `groups = { taxi = 0 }`, `shared = true`, `business = 'downtowncab'`, with real coords, like `lscustoms`) and put `taxi` model vehicles in it through the business vehicle path. Nothing hands out a cab today. The meter runs in any model listed in `som-taxi/shared/config.lua` `vehicles` (default `taxi`).
- [ ] Taxi fares are untuned: base $20, $60 per km, $10 per waiting minute, cap $1500, driver share 20 percent, at most $1500 of commission per driver per hour (read from `som_transactions`), nothing charged under 400 m. The Downtown Cab Co. account (`BUS-CAB`) starts at 100000 and pays the commissions, so watch it.
- [ ] Not verified in a game: the F1 "Cab meter" entry, the driver seat check, passenger detection in a real vehicle, the fare readout on both screens, the passenger's pay dialog, and server vehicle speed and position under load.
- [ ] Left out on purpose: NPC fares, a phone booking app, taxi stands, tipping and rentals.
## Server-owned hunger, thirst and stress

- [ ] Item use now changes the needs on the server: som-core listens for the server event `ox_inventory:usedItem` and applies `Config.ItemStatus` (the 8 food and drink items, same numbers as before). `som:server:adjustStatus` and its stopgap budget are gone, and the ox bridge no longer has `client.setPlayerStatus`. Not run in a live server: eat and drink each of the 8 items and confirm the bar moves, that cancelling the progress bar changes nothing, and that the HUD (som-hud and ps-hud) still follows. A new food item in `ox_inventory/data/items.lua` needs an entry in `Config.ItemStatus` (a test fails until it has one).
- [ ] Stress has no passive decay (it never had); only items lower it.

## ANPR (som-anpr)

- [ ] Exact config change: `ps-mdt/shared/config.lua` now has `Config.UseWolfknightRadar = false` (it was `true`). That turns off ps-mdt's own `wk:onPlateScanned` handler, which showed the stock QBCore popup to any client and leaked registered owner names for any plate. It also turns off ps-mdt's `ps-mdt:client:trafficStop` hook, which called `ps-dispatch` (not installed).
- [ ] `som-anpr` is ensured after `wk_wars2x`. An on duty police officer in the driver or front passenger seat of a listed model (`Config.vehicles`, a guess: police, police2, police3, police4, policeb, pranger, fbi, fbi2, pitbullbb, sheriff, sheriff2) gets a toast and the reader locks when the scanned vehicle (a real vehicle within 80 m) has a stolen mark in `mdt_vehicleinfo`, an open `mdt_bolos` row for `police`, or an open `som_police_plates` flag. Plain text only: the plate and the reason, no owner. Unregistered plates are out on purpose (every NPC car is unregistered).
- [ ] Dispatch type `flaggedVehicle` (10-29, police, priority 2): one call per plate per 5 minutes, at most 6 calls a minute overall. No wanted level and no automatic fine.
- [ ] Not verified live: wk firing for our cruisers, `wk:togglePlateLock` as a local event (it toggles, so a second hit on an already locked reader would unlock it), the reader's plate text matching `GetVehicleNumberPlateText`, the blip and toast. Check the real model names of the police fleet.
## Trucking

- [ ] `som-trucking/shared/config.lua` `Config.routes` is empty, so no freight contract is offered. Add routes: `{ id, label, depot = vec4, trailer = vec4, dropoff = vec3, base, minutes }`, at least `minDistance` (1500) apart. Each route is its own entry in the Jobs app after a restart.
- [ ] Trucking and courier draw from the same Post OP account, so heavy trucking can leave couriers unpaid. Staff decide who funds Post OP (or whether freight gets its own business account) before launch.
- [ ] Pay comes from the `postop` business, the same account `som-courier` uses; nothing new funds it (no mint, no treasury top-up). Its balance is whatever Post OP earns from sales, so a broke company means unpaid hauls: check the balance against `base` and the `hourlyCap` (2500 per citizen per hour, held in memory, reset by a restart).
- [ ] Untuned defaults: damage takes at most 50%, a late drop 25%, the floor is 25% of base, two drivers get +20% on the pool, abandon or timeout locks the crew out for 15 minutes.
- [ ] Models `phantom` and `trailers` are vanilla GTA names assumed to spawn; the blip sprites 477 and 479 are unchecked guesses.
- [ ] Not detected: a member who is dead or in jail keeps the run until it expires (route minutes plus 15) and then the truck is removed. The trailer being hooked to the truck is not checked, only that it sits in the yard.
- [ ] Not verified live: server spawned vehicles, trailer body health read on the server in OneSync, a real crew of two, the unhook progress bar, `/abandonhaul`.
- [ ] Trucking: if the game errors (not just refuses) while crediting a driver right after the company was debited, that one payment is lost by the company and nobody is paid; the run ends so nobody is paid twice. Rare, but staff should know the Post OP balance can drift by one payment.

## Fuel (som-fuel)

- [ ] Existing databases: import the new seed from `setup.sql` (account `BUS-FUEL` and business `fuelco`, both `INSERT IGNORE`, opening balance 0). Without the `fuelco` business every fuel sale refunds the player. The account only ever holds what players paid at the pump, no seeded float and no treasury money. Decide who may withdraw from it.
- [ ] Place the gas stations: `/place som-fuel stations.station_1.coords` (up to `station_8`; add more entries in `som-fuel/shared/config.lua`). None is open until placed, and a station may set its own `price` (default 4 a litre). Stand within 15 m of the point; pumps are detected by prop model (`prop_gas_pump_*`, `prop_vintage_pump`).
- [ ] Numbers are untuned defaults: 100 unit tank, drain 0.012 per second plus 0.0016 per m/s, jerry can 120 for 25 units, 5 units per pour.
- [ ] Not verified live: `SetVehicleFuelLevel` moving the ps-hud gauge (ps-hud reads it through `som-compat`'s `GetFuel`) and cutting the engine at zero, the pump model names, the `WEAPON_PETROLCAN` metadata (`durability` and `ammo` as 0 to 100, written by the server only), the state bag `fuel` handler on the other clients, drain balance. Known limit: the drain runs on the driver's client, so a cheater can avoid draining, but no fuel can be minted: every increase is a server approved sale or can pour.
- [ ] Cut on purpose: player owned stations, electric charging, fuel types, siphoning. cdn-fuel stays unensured.

## Process serving (som-serving)

- [ ] Import the new `som_court_service` table on an existing database (section 7n of `setup.sql`, `CREATE TABLE IF NOT EXISTS`). Run on the dev database already; not on production.
- [ ] Fees are paid by the `doj` business (funding `fines`, so only the fines share fills it, see `setup.sql` seed rows). Until fines have been issued its balance may be too low and the Papers app says "The courts cannot pay for service right now". Check the balance against the fee (250) and the hourly cap (1000 per citizen); staff decide who tops DOJ up.
- [ ] Anti-farm numbers are untuned: one paper held at a time for 30 minutes, a hearing must be 15 or more minutes away, the same defendant earns a fee at most once per 24 hours across all cases, 6 second serving bar within 3 metres. The server, filer, judge, prosecutor and defender on a case never see it.
- [ ] Service is shown in the court docket as "served" or "not served". It is not enforced: a judge can still declare a failure to appear on an unserved case.
- [ ] The `Papers` phone app uses the `note` icon, and the `mp_common` / `givetake1_a` animation is an unchecked guess.
- [ ] Not verified live: the player target option, the progress bar and cancelling by moving, the phone app list, a real defendant being notified. Only the mock suite and the dev MariaDB (claim insert, cap and cooldown on a rolled back transaction) have run.
