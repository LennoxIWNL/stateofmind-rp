# Owner checklist

The single page of things only the owner can do. Sources: `LAUNCH-TODO.md` (the full
register, every item and every number, never repeated here), `server.cfg.example` and
`som.cfg`. Test flows live in `TEST-SCRIPT.md` and are not repeated here. Whether the server
is healthy is answered by `somhealth` in the console, not by a number in this file.

Nothing merged so far has run with a game client (NUI, client natives, two players
interacting): every feature has only run against mocks and the dev database until someone
plays it. The in-game pass is the owner's, and the script for it is `TEST-SCRIPT.md`.

The order of work:

1. **Before the beta pass** (sections 1 to 3): secrets and convars, the asset packs, the database import and the seeds.
2. **The beta pass** (section 4): the smoke test at the top of `TEST-SCRIPT.md` round three (about ten minutes), then placement (section 5), then flows 69 to 91 for what merged in the jobs and services update and the game clock. Flows 1 to 68 cover everything merged before it and still apply.
3. **Still blocked on an owner decision** (section 6): nothing below it can be finished by anyone else.

Tick items here when done on the server that goes live.

## 1. Secrets and convars (`server.cfg`, never committed)

Copy `txData/FiveMBasicServerCFXDefault_3A7DA0.base/server.cfg.example` to `server.cfg` and fill it in.
`som.cfg` (tracked) is executed from its last line.

| Convar | Read by | If missing |
|---|---|---|
| `sv_licenseKey` | FXServer | Server will not authenticate with Cfx |
| `mysql_connection_string` | oxmysql | No database: nothing works |
| `steam_webApiKey` | FXServer | Only matters if you use steam identifiers |
| `som_phone_pepper` (long random string) | `som-phone/server/device.lua` | `/somhealth` FAILS. Passcodes are only salted. Changing it later resets every phone passcode, so set it once before launch |
| `set som_whitelist 1` | `som-staff/server/whitelist.lua` | The whitelist is OFF and anyone can join. Whitelist every staff licence first with `/whitelist add license:<hex> <note>` from the console |
| `set som_debug 0` | `som-core/shared/trace.lua` | Leave 0 in production (1 logs every server callback) |

Discord webhook convars (all optional, each unset one only turns that log off; see `DISCORD_WEBHOOKS.md`):

| Convar | Read by | Logs |
|---|---|---|
| `som_phone_webhook` | `som-phone/server/social.lua` | Chirp reports |
| `som_heist_webhook` | `som-heists/server/main.lua` | Heist start and end |
| `som_launder_webhook` | `som-launder/server/ledger.lua` | Laundering |
| `som_evidence_webhook` | `som-evidence/server/evidence.lua` | Evidence actions |
| `som_court_webhook` | `som-court/server/cases.lua` | Court cases |
| `som_jail_webhook` | `som-jail/server/jail.lua` | Jail bookings |
| `som_combatlog_webhook` | `som-staff/server/combatlog.lua` | A character leaving while downed, cuffed or in a crime scene (citizenid, signals, position). In `server.cfg.example` and `DISCORD_WEBHOOKS.md` |
| `som_economy_webhook` | `som-economy/server/watch.lua` | Economy alerts and the daily digest. Not yet in `server.cfg.example` or `DISCORD_WEBHOOKS.md`, so add the line yourself; unset, they only print to the console |
| `lac_webhook_bans`, `_kicks`, `_flags`, `_events`, `_connections` | `[anticheats]/Lennox-Anticheat/config.lua` | Anti-cheat |
| `psmdt_webhook_mugshot`, `psmdt_webhook_clockin` | `ps-mdt/server/main.lua` | MDT mugshots and clock in (ps-mdt prints "A webhook is missing" at boot until set) |
| `qbsmall_webhook_economy`, `_inventory`, `_crime`, `_player_staff`, `_comms`, `_system` | `qb-smallresources/server/logs.lua` | Central log hub |

One optional convar that is not a webhook: `set som_clock_freeze "HH:MM"` (a commented example is in `som.cfg`) freezes the game clock at that time from boot. Leave it unset for a running clock. Staff can also use `/settime` and `/freezetime`, which last until a restart.

Also:

- [ ] Webhooks that were once committed in plaintext are regenerated in Discord (an old URL stays valid until you delete it there).
- [ ] `r14-evidence/server/nikon.lua` still carries two hardcoded webhooks from the original server. Overwrite or blank them (`DISCORD_WEBHOOKS.md` section 2), or camera photos go to a stranger.
- [ ] Staff permissions: `som.cfg` grants `som.god`, `som.admin`, `som.mod` to a hard-coded licence (lines 111 and 128 to 131) and `Lennox-Anticheat/config.lua` lists admin identifiers (a licence and a steam id). Replace or extend them with the real staff before launch. Moderators come from `add_ace group.mod som.mod allow` plus `add_principal` lines in `server.cfg`.
- [ ] The Discord bot (`[discord]/`, PM2) needs its own environment: `DISCORD_TOKEN`, `FIVEM_CFX_CODE`, `FIVEM_RESTART_SCHEDULE`, `FIVEM_RULES_URL`, `FIVEM_STORE_URL`, `BRANCH`, `BOT_DATA_DIR` (see `[discord]/README.md`). The beta server runs with `BRANCH=BetaRelease`, production with `main`.
- [ ] GitHub: branch protection on `main` and `BetaRelease` (require CI, no force push, no direct push).
- [ ] Backups: install the cron job for `tools/backup.sh`, a restricted backup DB user, an off-machine copy, and run `tools/restore-check.sh` on a real backup that includes `server.cfg` (`LAUNCH-OPS.md`).
- [ ] `r14-evidence` stays out of `som.cfg` (it trusts client evidence data; `som-evidence` replaces it).

## 2. Asset packs that are not in git

These are binary or paid packs, gitignored on purpose. A fresh clone cannot start them: FXServer
prints `Couldn't find resource <name>` at boot. Copy them to the host (`resources/[assets-streams]`
and neighbours) before launch.

| Resource | Needed by | Symptom if missing |
|---|---|---|
| `karma-minimap` | HUD (`ps-hud` must start AFTER it, see the comment in `som.cfg`) | Plain minimap, and the frame ps-hud draws no longer matches |
| `jordqn_free_shells` | Character select scene in `som-multichar` | Falls back to the plain world scene |
| `cfx-gabz-mapdata`, `mrpd`, `cfx-gabz-davispd`, `cfx-gabz-pdprops` | Police station interior; every `som-police`, `som-evidence` and `som-jail` coordinate assumes the Gabz MRPD | Vanilla MRPD, so every coordinate lands in the wrong building |
| `cfx-gabz-lscustoms` | `som-garage` Los Santos Customs garage | Vanilla building, garage points misplaced |
| `origen_police` | Police map and props (folder has no manifest in git) | Missing station props |
| `lspd-Police-Cars`, `lspd-Police-Bike`, `lspd-Police-SWAT` | Police fleet models in `som-garage` and `som-police` | Police vehicles do not spawn |
| `rd-vehicleconfig`, `ro-VehicleConfig` | Handling overhaul for base game cars (deliberate, see `som.cfg`) | Vanilla handling |
| `som-custom_weapons`, `_melee`, `_thrown`, `som-gunmetas` | Weapon models and stats | Vanilla weapons |
| `rd_clothes`, `rd_clothes_new`, `rd_clothes_props`, `assets_peds`, `assets_peds_p2` to `p5`, `assets_peds_other`, `assets_peds_other_p2` | Character creation and clothing | Limited or broken clothing in creation |
| `som-lorefriendly` | Traffic composition (see its comment in `som.cfg`) | Stock traffic |
| Bank maps: Pacific Bank Extended, Fleeca | Heists (every site ships disabled until its map and coordinates exist) | Heists cannot be enabled |
| PDM dealership map (Gabz recommended) | `som-garage` dealership | Vanilla showroom |

Smaller loose ends seen at boot (harmless, listed so they are not mistaken for new bugs):
`som-assets` finds no `img/vehicles/*.png`, `qb-interior` lacks `stream/starter_shells_k4mb1.ytyp`,
`ox_doorlock` lacks `audio/dlc_oxdoorlock/oxdoorlock.awc`, `cityhallv1` has no manifest, and
`baseevents` exists in two places (the `[system]` copy is used). `screenshot-basic` fails on the very
first boot while its webpack build runs and starts on the next.

Artwork still to replace or add: `gsrtestkit.png` and `dnatestkit.png` are placeholders; run
`python3 tools/check-item-icons.py` for items without an icon (`tools/item-icons-baseline.txt`).

## 3. Database on an existing server

A fresh database: import `setup.sql`. Verified: it imports with no errors on an empty MariaDB and
can be imported a second time with no errors (every statement is `CREATE ... IF NOT EXISTS` or
`INSERT IGNORE`), so on an existing database re-importing it adds the new tables and seed rows. These
statements are not covered by that and need to be run once on a database created from an older version:

- [ ] `ALTER TABLE som_jail_sentences ADD COLUMN release_pending TINYINT(1) NOT NULL DEFAULT 0;`
- [ ] `ALTER TABLE som_jail_sentences CHANGE conviction_id case_id BIGINT UNSIGNED DEFAULT NULL, ADD COLUMN kind ENUM('sentence','remand') NOT NULL DEFAULT 'sentence';`
- [ ] `ALTER TABLE som_court_cases ADD COLUMN service_tasks SMALLINT UNSIGNED NOT NULL DEFAULT 0 AFTER sentence_months;`
- [ ] `ALTER TABLE som_licenses ADD COLUMN suspended_until TIMESTAMP NULL DEFAULT NULL;`
- [ ] `ALTER TABLE som_transactions ADD KEY IF NOT EXISTS idx_time (created_at);` (MariaDB; the economy watch queries need it, fresh databases get it from `setup.sql`; run it off peak on a big ledger).
- [ ] Only if the database predates the fire department: the two `INSERT IGNORE` statements for `GOV-FIRE` and `fire` quoted under "Fire department" in `LAUNCH-TODO.md`, then restart `som-economy`. Also `ALTER TABLE som_welcome_claims` / `som_welcome_jobs` only if the first version of section 7p was imported (see "New player onboarding" in `LAUNCH-TODO.md`).
- [ ] **Licences backfill, before this version meets a database with players** (commented SQL at the end of `setup.sql`, section 7m): weapon licences bought from the old shop exist only as character metadata, and login now rebuilds metadata from `som_licenses`. Without the two `INSERT IGNORE` statements existing holders lose the licence.

Seed rows and tables to confirm exist after the import (all in `setup.sql`):

- [ ] Sections 7e jail, 7f court, 7g community service, 7h evidence, 7j heists (`som_heist_dongles`, `som_heist_runs`), 7k `som_drug_market`, 7l `som_whitelist`, `som_reports`, `som_staff_audit`, `som_bans`, 7m licences (`som_licence_attempts`).
- [ ] The tables added by the jobs and services update (18, counted by smoke test S3 in `TEST-SCRIPT.md`): `som_vehicle_insurance`, `som_insurance_claims`, `som_welcome_claims`, `som_welcome_jobs`, `som_news_stories`, `som_news_payouts`, `som_boost_runs`, `som_tow_tickets`, `som_restaurants`, `som_restaurant_orders`, `som_burglary_runs`, `som_burglary_loot`, `som_race_dongles`, `som_race_aliases`, `som_race_tracks`, `som_races`, `som_race_entries`, `som_race_times`. Plus `som_loans`.
- [ ] Phone section 4b (devices, audit, handles, posts, likes, reports, adverts, pages opt-in, notes), `som_gang_log`, `som_plants`, `som_lab_jobs`, `som_buyer_payouts`, `som_chop_log`, `som_new_life`, `som_skills`, `som_trade_offers`, `som_placements`, `som_shops`, `som_shop_stock`, `som_shop_staff`.
- [ ] Businesses with a bank account: `lspd` (bail, seizures and the tow fee come from and go to it), `doj`, `ems`, `postop`, `lscustoms`, `downtowncab`, `pdm`, `dynasty8`, `weazel` (`BUS-WEAZEL`, starts at 0), `fire` (`GOV-FIRE`, seeded with an opening float of 100000 that is minted money, your call), `insurer` (`BUS-INSURER`, created when `som-insurance` starts, starts at 0, fund it with `/insurerfund <amount>`) and `burgershot` (`REST-BURGERSHOT`, created when `som-restaurants` starts, starts at 0 and nothing can fund it yet, see the bug list in `TEST-SCRIPT.md`), plus `sanitation` (account `GOV-SAN`, restart `som-economy` after importing or the Jobs app says the department is not set up) and `fuelco` (account `BUS-FUEL`; without it every fuel sale refunds the player). `som-shops` creates its own `SHOP-<ID>` account and `shop_<id>` business per configured shop on start.
- [ ] The treasury balance is a decision: it starts at 0 and fills from fines and business tax. Fish, game and scrap buyers, sanitation top-ups and heist clean cash are paid from it, so they all refuse to pay until it holds money. Decide whether to seed it.
- [ ] Fuel, trucking and courier pay from business accounts that start empty or low (`fuelco` 0, `postop` shared by courier and trucking). Decide who funds them.

Run `/somhealth` afterwards: it checks resources, the database, every table, every item and the convars above.

## 4. The beta pass: what to run, in order

Everything below is in `TEST-SCRIPT.md`; this is only the order and who has to be there.

- [ ] **Smoke test first** (S1 to S8 at the top of "Round three", about ten minutes): the server booted this update, `somhealth` has no FAIL, the 18 new tables and the new businesses exist, `/gametime` answers and the phone lists the new apps. Do not start the flows until this is green.
- [ ] **Setup for round three** (same place): the import, the two switches to flip (`som-news` `enabled`, `som-racing` `Config.enabled`), the treasury seed on the beta database only, and the placements from section 5.
- [ ] **Flows 69 to 91**, one per feature that merged in the jobs and services update plus the game clock. Who has to be there:

| Needs | Flows |
|---|---|
| One tester (an admin for the staff commands) | 70 insurance, 71 onboarding, 80 economy watch, 88 game clock, 90 icons, 91 boot health |
| Two testers | 69 mining, 72 estate agent, 73 Weazel News, 74 fire, 79 combat log, 81 to 83 street racing, 85 to 87 restaurants, 89 two clients on one clock |
| A police officer on duty as well | 76 car boosting, 77 and 78 tow tickets, 84 house burglary |
| A paramedic on duty as well | 75 EMS person-down call |

- [ ] Flows 1 to 68 still stand for everything merged before this update; round three does not replace them.
- [ ] Three things in the bug list at the end of "Round three" block parts of the setup (`/place` for restaurants and burglary, mining nodes, the first restaurant stock). Read that list before you start; each has a workaround in the script.
- [ ] After the pass: tick or add lines in `LAUNCH-TODO.md`, reset the treasury seed (`UPDATE som_treasury SET balance = 0 WHERE id = 1;`) and take a backup.

## 5. Placements and coordinates staff must set in game

Almost everything ships disabled with no coordinates, so a freshly started server has no
courier routes, heists, turf, labs, shops, stations, desks or contract spots until this is done.
In game, stand at the spot and run `/place <resource> <path> [value]` (admin or console), then
`restart <resource>`. `/pdcoords` prints a position formatted for a config file. `/places`
lists, `/unplace` removes. A placed point also switches its entry on. A typo'd path is reported
at resource start ("no such place").

The resources `/place` accepts are the `placeableList` in `som-staff/shared/config.lua`:
`som-turf`, `som-outdoors`, `som-heists`, `som-mechanic`, `som-launder`, `som-shops`, `som-fuel`,
`som-ems`, `som-dmv`, `som-welcome`, `som-boosting`. `som-restaurants` and `som-burglary` are
not on it yet, so `/place` refuses them until they are added there.

| Resource | Place with `/place` | Edit in config instead |
|---|---|---|
| `som-turf` | `zones.<name>.center`, `.tag`, `.radius <n>` for `grove`, `vespucci_canals`, `davis`; grow spots and bag tables; `labs`; `supplier` | Prices, payroll, `claimGrade`, `policeMin` |
| `som-outdoors` | `buyers.fish.coords`, `buyers.hunt`, `buyers.scrap`, `buyers.quarry`, `buyers.fence`; fishing spots and `deep_1`; `chop.dropoffs`; `mining.smelter.coords` | Mining vein positions: `nodes = { vec3(...) }` per site (`/place` cannot do them), catch tables and prices |
| `som-heists` | `sites.<id>.terminal`, `sites.<id>.lootPoints+` (once per loot point) | `ox_doorlock` door names; every site stays disabled until its map is installed and a full run was tested |
| `som-mechanic` | Roadside desk `fallback.coords` | Prices and limits |
| `som-launder` | Each front (a placed front is marked set) | Front choice |
| `som-ems` | `locker.coords` | Hospital `desk` and `bed` in `som-ems/shared/config.lua` |
| `som-shops` | `shops.alta.coords`, `shops.strawberry.coords` (two placeholders) | The real shop list, `Config.items`, tax, payroll caps |
| `som-fuel` | `stations.station_1.coords` to `station_8` (add entries for more) | Per station `price` |
| `som-dmv` | `desk.coords` | Fees |
| `som-welcome` | `desk.coords` (the job centre) | `Config.guide` text with the real places |
| `som-boosting` | `pickups.pickup_1.coords`, `pickup_2`, `dropoffs.dropoff_1.coords` | Each pickup's `heading`, class numbers |
| `som-restaurants` | `restaurants.burgershot.coords` and its five stations, `selfServe`, `fridge`, and `supplier.coords` (once `/place` accepts the resource) | Prices, recipes, the first stock float for the restaurant account |
| `som-burglary` | `houses.house_1.coords`, `house_2` (once `/place` accepts the resource) | The search spots of each shell (`Config.shells.<model>.spots`), numbers |
| `som-tow` | not placeable | `Config.yard` must stay the same place as the police impound lot |
| `som-fire` | not placeable | `Config.ambient.locations` (fires without staff); staff start one with `/startfire` |
| `som-news`, `som-racing` | nothing to place | Flip `enabled` in their config once ready |
| `som-courier` | not placeable | `Config.routes` is empty, so the run is disabled |
| `som-trucking` | not placeable | `Config.routes` is empty, so no contract is offered |
| `som-garbage` | not placeable | `Config.routes` is empty: depot, landfill, recycling, stops with bins |
| `som-licences` | not placeable | `school.coords`, `school.spawn`, `practical.route`, then `school.enabled = true` |
| `som-court`, `som-evidence`, `som-jail` | not placeable | Courthouse desk, evidence lab (`Config.Stations.mrpd`), community service area, prison yard, cell spawns, gate and freedom points; all coordinates are estimates |

## 6. Still blocked on an owner decision

Nothing here can be finished by anyone else. Each line says what is waiting; the detail and
the numbers are in `LAUNCH-TODO.md`.

- [ ] **Who sells racing dongles.** Today only staff issue them (`/giveracedongle`); heist dongles come only from `/givedongle` and the launder ledger. Pick the in-world source for both.
- [ ] **Burger Shot.** No Burger Shot interior map is installed or started in `som.cfg`. Choose where the counter, five stations, fridge, self-serve machine and wholesaler go (a vanilla spot or a map to install), and how the restaurant account gets its first stock money (nothing funds it today).
- [ ] **Burglary search spots.** Offsets inside `shell_frankaunt` and `shell_michael` must be measured and put in `Config.shells`; until then no house can be picked. Also which two houses are real.
- [ ] **Icons.** Accept or reject the four new ones (Deer Pelt, Empty NOS Bottle, Roll Cage, Exterior Cosmetics, flow 90) and replace the placeholders: `gsrtestkit.png`, `dnatestkit.png`, `racing_dongle` (reuses `usb_device.png`) and `burgershot_patty` (reuses `burgershot_meat.png`).
- [ ] **Who is hired and whitelisted.** `judge`, `prosecutor`, `defender`, `dispatcher`, `ambulance`, `firefighter`, `realtor` and `news` are whitelisted and nobody holds the last four until you hire them; `tow` is not whitelisted and has no salary, so decide whether it should be. A job cannot be used on duty until assigned; clock in and out is in the F1 radial under Work (`som-duty`). First gang boss for each gang (admin path).
- [ ] **Who pays.** The treasury starts at 0 and pays the buyers (fish, game, scrap, quarry, fence), news stories, the settling-in payment, fire top-ups and the insurer's replacement cost; decide whether and how much to seed it. Decide the same for `BUS-INSURER`, the minted `GOV-FIRE` float, `fuelco`, `postop` (courier and trucking), `weazel` and the restaurant account, and whether `lspd` should keep paying the $400 tow fee.
- [ ] **Fire station.** A station, trucks in `som-garage` and a source for the fire extinguisher (nothing sells `WEAPON_FIREEXTINGUISHER`).
- [ ] **Taxi cabs.** Add a shared job garage in `som-garage` `Config.Garages` for the `taxi` job with real coordinates and put cab vehicles in it. Nothing hands out a cab today.
- [ ] Mechanics have no source for `repairkit` and `steel` beyond crafting benches and the roadside fallback; check the supply loop plays out.
- [ ] The "Getting Started" phone app text (`Config.guide` in `som-welcome`) with where the DMV, driving school, job centre and estate agent really are.
- [ ] `Config.Social.imageHosts` (phone posts with images) and the handle blocklist `Config.Social.reserved` with real department and business names.
- [ ] Rules text (`RULES-DRAFT.md`): approve, set the penalty ladder, publish. The new life minutes in `RULES-DRAFT.md` must match `Config.NewLife`.
- [ ] Whitelist application flow (Discord form and reviewers) is not built; decide who drives `whitelist add`.
- [ ] `pma-voice:setPlayerCall` lets a client join any call channel: patch or replace before launch.
- [ ] Every number marked untuned in `LAUNCH-TODO.md` (prices, pay, cooldowns, fuel drain, taxi fares, trucking pay, tow fee, insurance rates, news pay, boosting and racing numbers) is a first guess; tune them after the first week against the economy digest.
- [ ] Anything else that sets the game clock (a weather resource, vMenu time sync) must stay off, because it fights the server clock; weather itself is not synced yet.

## 7. Go-live sequence

1. Production host: Linux box with the FXServer artifact, MariaDB, Node and PM2. `server.cfg` from `server.cfg.example` with every row of section 1 filled in.
2. Database: create it, import `setup.sql`, run the ALTERs and the licences backfill from section 3 if it is an older database.
3. Copy the asset packs (section 2) to the host. Without them the boot works but the map, police, clothes and vehicles are wrong.
4. Start the server. In the console read the boot log: expect `Couldn't find resource` only for packs you chose to leave out, and no `SCRIPT ERROR`.
5. Run `somhealth` in the console: no FAIL row. WARN rows are the optional webhooks and the whitelist. Then the smoke test at the top of "Round three" in `TEST-SCRIPT.md`.
6. Staff: put the real licences in the ACE lines and the anti-cheat admin list, restart, check `/somhealth` and a staff command with a real account.
7. Place the content (section 5) in game, restart each resource, and walk the flows you intend to open at launch (`TEST-SCRIPT.md`, section 4 above). Leave a feature disabled rather than half placed.
8. Fund the accounts you decided on (section 6: treasury, `postop`, `fuelco`, `sanitation`, `BUS-INSURER`, the restaurant account). Never carry the beta treasury seed over.
9. Switch the whitelist on (`set som_whitelist 1`) after whitelisting all staff, with the real server restarted so the convar applies.
10. Take a backup, run `tools/restore-check.sh` on it, and install the backup cron.
11. Promote: the owner opens the PR `BetaRelease` into `main` (merge commit, never squash). Production auto-pulls `main` through the Discord bot's webhook.
12. First week: read the economy sink and faucet report (`/economyreport`, the daily digest in the `som_economy_webhook` channel, `node tools/economy-map.mjs`, `ECONOMY-MAP.md`), watch the `/combatlogs` list, watch heists, boosting and laundering as measured faucets, and run a real load test (`tools/load-claims.sh` only covers one query).
