# Owner checklist

The single page of things only the owner can do before launch. Sources: `LAUNCH-TODO.md`
(the full register, every item and every number), the boot tests on a headless FXServer
(`origin/BetaRelease` boots 69 resources with no script errors and `/somhealth` passes 46 of
46 resources, 76 tables and 54 items), and `server.cfg.example`. Test flows live in
`TEST-SCRIPT.md` and are not repeated here.

What a headless boot cannot show: anything that needs a connected game client (NUI, client
natives, interactions between two players). Every feature has only run against mocks and the
dev database until someone plays it. Tick items here when done on the server that goes live.

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
| `lac_webhook_bans`, `_kicks`, `_flags`, `_events`, `_connections` | `[anticheats]/Lennox-Anticheat/config.lua` | Anti-cheat |
| `psmdt_webhook_mugshot`, `psmdt_webhook_clockin` | `ps-mdt/server/main.lua` | MDT mugshots and clock in (ps-mdt prints "A webhook is missing" at boot until set) |
| `qbsmall_webhook_economy`, `_inventory`, `_crime`, `_player_staff`, `_comms`, `_system` | `qb-smallresources/server/logs.lua` | Central log hub |

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
- [ ] **Licences backfill, before this version meets a database with players** (commented SQL at the end of `setup.sql`, section 7m): weapon licences bought from the old shop exist only as character metadata, and login now rebuilds metadata from `som_licenses`. Without the two `INSERT IGNORE` statements existing holders lose the licence.

Seed rows and tables to confirm exist after the import (all in `setup.sql`):

- [ ] Sections 7e jail, 7f court, 7g community service, 7h evidence, 7j heists (`som_heist_dongles`, `som_heist_runs`), 7k `som_drug_market`, 7l `som_whitelist`, `som_reports`, `som_staff_audit`, `som_bans`, 7m licences (`som_licence_attempts`).
- [ ] Phone section 4b (devices, audit, handles, posts, likes, reports, adverts, pages opt-in, notes), `som_gang_log`, `som_plants`, `som_lab_jobs`, `som_buyer_payouts`, `som_chop_log`, `som_new_life`, `som_skills`, `som_trade_offers`, `som_placements`, `som_shops`, `som_shop_stock`, `som_shop_staff`.
- [ ] Businesses with a bank account: `lspd` (bail and seizures are credited to it), `doj`, `ems`, `postop`, `lscustoms`, `downtowncab`, `pdm`, `dynasty8`, plus the new `sanitation` (account `GOV-SAN`, restart `som-economy` after importing or the Jobs app says the department is not set up) and `fuelco` (account `BUS-FUEL`; without it every fuel sale refunds the player). `som-shops` creates its own `SHOP-<ID>` account and `shop_<id>` business per configured shop on start.
- [ ] The treasury balance is a decision: it starts at 0 and fills from fines and business tax. Fish, game and scrap buyers, sanitation top-ups and heist clean cash are paid from it, so they all refuse to pay until it holds money. Decide whether to seed it.
- [ ] Fuel, trucking and courier pay from business accounts that start empty or low (`fuelco` 0, `postop` shared by courier and trucking). Decide who funds them.

Run `/somhealth` afterwards: it checks resources, the database, every table, every item and the convars above.

## 4. Placements and coordinates staff must set in game

Almost everything ships disabled with no coordinates, so a freshly started server has no
courier routes, heists, turf, labs, shops or stations until this is done. In game, stand at the
spot and run `/place <resource> <path> [value]` (admin or console), then `restart <resource>`.
`/pdcoords` prints a position formatted for a config file. `/places` lists, `/unplace` removes.
Placeable resources: `som-turf`, `som-outdoors`, `som-heists`, `som-mechanic`, `som-launder`,
`som-ems`, `som-shops`, `som-fuel` (check `som-staff/shared/config.lua` `placeable` for the
current list). A typo'd path is reported at resource start ("no such place").

| Resource | Place with `/place` | Edit in config instead |
|---|---|---|
| `som-turf` | `zones.<name>.center`, `.tag`, `.radius <n>` for `grove`, `vespucci_canals`, `davis`; grow spots and bag tables; `labs`; `supplier` | Prices, payroll, `claimGrade`, `policeMin` |
| `som-outdoors` | `buyers.fish.coords`, `buyers.hunt`, `buyers.scrap`; fishing spots and `deep_1`; `chop.dropoffs` | Catch tables and prices |
| `som-heists` | `sites.<id>.terminal`, `sites.<id>.lootPoints+` (once per loot point) | `ox_doorlock` door names; every site stays disabled until its map is installed and a full run was tested |
| `som-mechanic` | Roadside desk `fallback.coords` | Prices and limits |
| `som-launder` | Each front (a placed front is marked set) | Front choice |
| `som-ems` | `locker.coords` | Hospital `desk` and `bed` (not placeable yet) in `som-ems/shared/config.lua` |
| `som-shops` | `shops.alta.coords`, `shops.strawberry.coords` (two placeholders) | The real shop list, `Config.items`, tax, payroll caps |
| `som-fuel` | `stations.station_1.coords` to `station_8` (add entries for more) | Per station `price` |
| `som-courier` | not placeable | `Config.routes` is empty, so the run is disabled |
| `som-trucking` | not placeable | `Config.routes` is empty, so no contract is offered |
| `som-garbage` | not placeable | `Config.routes` is empty: depot, landfill, recycling, stops with bins |
| `som-licences` | not placeable | `school.coords`, `school.spawn`, `practical.route`, then `school.enabled = true` |
| `som-court`, `som-evidence`, `som-jail` | not placeable | Courthouse desk, evidence lab (`Config.Stations.mrpd`), community service area, prison yard, cell spawns, gate and freedom points; all coordinates are estimates |

Gameplay decisions that need an owner call before launch:

- [ ] First gang boss for each gang (set with the admin path); nobody is a boss until you do it.
- [ ] Taxi cabs: add a shared job garage in `som-garage` `Config.Garages` for the `taxi` job with real coordinates and put cab vehicles in it. Nothing hands out a cab today.
- [ ] Jobs set to `whitelisted` (`judge`, `prosecutor`, `defender`, `dispatcher`, `ambulance`): decide who is whitelisted. A job cannot be used on duty until assigned; clock in and out is in the F1 radial under Work (`som-duty`).
- [ ] Mechanics have no source for `repairkit` and `steel` beyond crafting benches and the roadside fallback; check the supply loop plays out.
- [ ] Heist dongles come only from `/givedongle` and the launder ledger; pick the in-world source.
- [ ] `Config.Social.imageHosts` (phone posts with images) and the handle blocklist `Config.Social.reserved` with real department and business names.
- [ ] Rules text (`RULES-DRAFT.md`): approve, set the penalty ladder, publish. The new life minutes in `RULES-DRAFT.md` must match `Config.NewLife`.
- [ ] Whitelist application flow (Discord form and reviewers) is not built; decide who drives `whitelist add`.
- [ ] `pma-voice:setPlayerCall` lets a client join any call channel: patch or replace before launch.
- [ ] Every number marked untuned in `LAUNCH-TODO.md` (prices, pay, cooldowns, fuel drain, taxi fares, trucking pay) is a first guess.

## 5. Go-live sequence

1. Production host: Linux box with the FXServer artifact, MariaDB, Node and PM2. `server.cfg` from `server.cfg.example` with every row of section 1 filled in.
2. Database: create it, import `setup.sql`, run the ALTERs and the licences backfill from section 3 if it is an older database.
3. Copy the asset packs (section 2) to the host. Without them the boot works but the map, police, clothes and vehicles are wrong.
4. Start the server. In the console read the boot log: expect `Couldn't find resource` only for packs you chose to leave out, and no `SCRIPT ERROR`.
5. Run `/somhealth` (console): everything must PASS. WARN rows are the optional webhooks and the whitelist.
6. Staff: put the real licences in the ACE lines and the anti-cheat admin list, restart, check `/somhealth` and a staff command with a real account.
7. Place the content (section 4) in game, restart each resource, and walk the flows you intend to open at launch (`TEST-SCRIPT.md`). Leave a feature disabled rather than half placed.
8. Fund the accounts you decided on (treasury, `postop`, `fuelco`, `sanitation`).
9. Switch the whitelist on (`set som_whitelist 1`) after whitelisting all staff, with the real server restarted so the convar applies.
10. Take a backup, run `tools/restore-check.sh` on it, and install the backup cron.
11. Promote: the owner opens the PR `BetaRelease` into `main` (merge commit, never squash). Production auto-pulls `main` through the Discord bot's webhook.
12. First week: read the economy sink and faucet report (`node tools/economy-map.mjs`, `ECONOMY-MAP.md`), watch heists and laundering as measured faucets, and run a real load test (`tools/load-claims.sh` only covers one query).
