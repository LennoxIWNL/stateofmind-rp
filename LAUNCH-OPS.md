# Launch operations

What is automated, what is only planned, and what needs the owner. Nothing here
replaces one manual pass on the beta server.

## Backups (built, `tools/`)

- `tools/backup.sh <dir> [keep-days]`: gzip dump of the database (single transaction), copies of `server.cfg` and `som.cfg`, a checksum file, and pruning of folders older than the retention (default 14 days). Files are written mode 600 because `server.cfg` holds secrets.
- `tools/restore-check.sh <backup-folder> [container]`: verifies the checksums, restores into a throwaway database and fails if any table in `setup.sql` is missing.
- Verified here against the dev MariaDB container: backup written, restore check passed with 76 tables. The backup that ran had no `server.cfg` because the dev machine keeps it outside the repo tree.
- Cron example on the host: `15 4 * * * DB_HOST=127.0.0.1 DB_USER=backup DB_PASS=... /srv/som/tools/backup.sh /var/backups/som 14`. Use a database user with only SELECT, LOCK TABLES, SHOW VIEW, TRIGGER and EVENT rights. Copy the folder off the machine as well; a backup on the same disk is not one.
- Run `restore-check.sh` on the newest backup weekly and before every promotion.

## Concurrency check (built, `tools/load-claims.sh` and `tools/load-claims-all.sh`)

`tools/load-claims-all.sh` runs the plant harvest, trade accept, turf claim, lab start and chop shop claims with 30 parallel connections on the real MariaDB and requires exactly one winner each time. Result on the dev database: one winner in every round, every claim.

Fires many parallel connections at the heist site claim query (the conditional insert) on a real MariaDB and checks exactly one wins per site. Result on the dev container: 15 rounds of 40 parallel claimers, one winner each. This covers the claim query only. The property buy, mortgage and vehicle purchase claims are plain conditional UPDATEs (`Properties.Claim` pattern) and have not been put under this kind of load.

## Full boot out of DEV MODE (not done; the step by step checklist and the 42 test flows are in `TEST-SCRIPT.md`)

Run `somhealth` first after every boot; `set som_debug 1` logs every server callback for bug reports.

`som.cfg` still boots the framework only. To leave it:
1. On the beta server, comment out the DEV MODE block and enable FULL BOOT.
2. The resources the DEV MODE comment lists (elixir-base, elixir-hud, elixir-petshop, r14-evidence, som-spray, ox_doorlock, Lennox-DoorCreator) still call QBCore members `som-compat` does not implement. Expect errors from them; fix or leave them out one at a time.
3. `r14-evidence` stays out (see `LAUNCH-TODO.md`).
4. Boot, read the console for errors, then walk the in-game checklists in `LAUNCH-TODO.md`.

This needs the 5 GB of streamed assets and a game client, so it cannot be done from the dev machine.

## Whitelist and staff tools (basic versions built in `som-staff`)

Built: the connection gate (`som_whitelist` convar, `/whitelist`), player reports with a staff queue, goto, bring, spectate and a staff audit table. Still open: the items below.

Designed in AUDIT.md section 18, Phase 6. Not built because it needs decisions only the owner can make:
- Discord application form: the questions, who reviews, how a decision reaches the game (a bot command that inserts the identifier into an allow table, read by the connect handler). The `[discord]` bot's source is not in this repo, so the bot half cannot be edited here.
- Staff tools: teleport, spectate, noclip, a report queue and a staff action audit. Existing pieces are `/removepost`, `/givedongle` and the police and court tools. A single staff resource with an audit table is the next build once the permission groups are agreed.
- Anti-cheat: coverage reviewed on paper in `ANTICHEAT-REVIEW.md`; a live false positive pass is still needed.
- Rules: `RULES-DRAFT.md` is a draft in enforceable terms; the owner approves it.

## Load test with real players (not done)

The two harnesses are single process. A real load test needs the beta server and bots or testers: join/leave churn, many phone actions per second, and the job board with several groups queueing. Success criteria to agree before the run: server thread under 8 ms with N players, no database errors in the console, no duplicate rows in `som_heist_runs`, no negative treasury.
