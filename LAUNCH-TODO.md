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
- [ ] Backups of the database and `server.cfg`/`som.cfg` exist and a restore has been tried (AUDIT section 18, Phase 6).
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
