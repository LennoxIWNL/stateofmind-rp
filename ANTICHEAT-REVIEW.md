# Anti-cheat coverage review

Static review of `[anticheats]/Lennox-Anticheat` against SOM, read from source. Nothing here was run with a client or an actual cheat.

## What it covers (by reading the modules)
| Exploit class | Module | Notes |
|---|---|---|
| Tamper / resource kill | heartbeat with challenge | 30 s interval, 3 misses |
| Weapon spawn / damage | weapon damage filter, blacklisted weapons, weapon give monitoring | per-second event cap and max damage in config |
| Explosions | explosion filter | cap per 5 s |
| Entity spam | entity creation rate limiting, mass deletion detection | |
| Teleport / speed / noclip-like movement | server position tracking, vehicle teleport, movement analysis | see finding 1 |
| God mode | client detectors, server health/armor monitoring, server-instrumented health test, vehicle god mode | |
| Ped model swaps | server-side ped model validation | |
| Resource injection / runtime start-stop | resource monitoring | |
| Honeypot events | instant ban on events no legitimate client fires | list is QBCore/admin-menu names |
| Event flooding, chat spam, connection flood | global rate limiter, chat and connect trackers | |
| Permission escalation | dangerous command watch | |
| Money injection | economy module (signed transactions, source validation, duplicate hash, inventory snapshots, serial tracking) | see finding 2 |

## Findings
1. **Staff were not immune (fixed in this PR).** `AdminAces` listed `qbcore.god` and `command`, not SOM's `som.admin` and `som.mod`. `/goto`, `/bring` and `/spectate` would look like teleports and a staff member could be kicked or banned by the position tracker. `som.admin` and `som.mod` are added. Consequence: every mod is exempt from all detection, so keep `som.mod` for trusted people and review `som_staff_audit`. The hard coded identifiers in the same file belong to the owner and are kept.
2. **The economy module is not wired to SOM.** Nothing in `[som]` calls `IssueTransactionNonce`, `validateMoneySource` or `recordEarning`, so signed transactions, source validation and earnings analysis do nothing for SOM money. This is acceptable only because SOM does not trust clients with money (CLAUDE.md rule 1 and 8: the server moves money, the client sends ids). The honest position: money injection is prevented by the framework, not detected by the anti-cheat. Wiring `som-core` money moves into `recordEarning` would add after-the-fact anomaly alerts; it is not built.
3. **QBCore specific rules do nothing.** `ExploitableEvents` and the built-in event schemas target `qb-inventory`/`qb-shops` events and only register when `qb-core` is started. SOM has no such events. The framework check falls back to a delayed session token, so token issuing works (verified by reading `playerJoining` fallback), but the QBCore rules are dead weight.
4. **Honeypot names are generic.** They catch common mod-menu triggers but know nothing about SOM's own events. SOM events are already validated server side; adding a few decoy names that do not exist in SOM (for example `som-core:server:setMoney`) would cost nothing and is a cheap upgrade. Not done.
5. **Detection data stays in a JSON ban store** (see `Ban Store`). Back it up with the database (`tools/backup.sh` does not copy it yet).

## Not checked
- False positive rate with real players: vehicle speed, fast travel, ragdoll, parachutes, heavy RP animations.
- Whether any detector bans on `ox_inventory` weapon handling or `som-medical` revive health jumps. These need a live pass with staff and testers before launch.
- Client-side detectors against actual cheat tools.
- The screenshot-on-ban dependency (`screenshot-basic`) being installed.

## Before launch
- Run the server with two testers and a staff account; do a revive, teleport, vehicle spawn, weapon give and a high speed drive; read the anti-cheat console and webhook output; tune thresholds.
- Set the `lac_webhook_*` convars in the real `server.cfg`.
