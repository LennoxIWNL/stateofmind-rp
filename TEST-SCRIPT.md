# First real test: boot checklist and flow script

For the first session with a real client and two testers. Nothing in the game has been run with a client yet, so the goal is to find and fix bugs quickly, in the open, with a log line for every report.

## 0. Before anyone connects

1. Back up (`tools/backup.sh`), then `tools/restore-check.sh` on the backup.
2. Import `setup.sql` on a fresh database (or run the new sections on the existing one).
3. In `server.cfg` (never committed): `set som_phone_pepper "<long random>"`, the webhook convars you want, `set som_debug 1` for the test, and whitelist every tester and staff licence first (`whitelist add license:<hex> tester`), then `set som_whitelist 1`.
4. Grant staff: `add_ace group.mod som.mod allow`, `add_ace group.admin som.admin allow`.
5. Comment out the DEV MODE block in `som.cfg` and enable the FULL BOOT block. Boot. Record every console error per resource BEFORE changing anything, then fix or exclude them one at a time. `r14-evidence` stays out.
6. Run `somhealth` in the server console. It must report no FAIL lines. Fix those first.
7. Place content (until the placement tool exists, edit coordinates in each resource's `shared/config.lua` and set `enabled = true`): at least one heist site, one turf zone, one lab, one fishing spot, one grow spot, the supplier, the buyers, a chop drop-off, the roadside desk and courier routes. Every place ships disabled.
8. Give testers a mechanic job, a gang and a grade 4 boss in the database so every flow is reachable.

## How to report a bug
Copy the `[som-trace]` line(s) from the server console for the action (name, source, result, time) plus what you saw on screen. An `ERROR` trace line is the bug. A `refused:` line is usually a rule working and the real question is why it refused.

## Flows (tick each; two players where marked "pair")

### Account and basics
1. Connect, pass the whitelist, create a character with a backstory, spawn.
2. HUD shows health, hunger, thirst; minimap loads; chat works.
3. Open the inventory, move, drop, stack and split items; use water and a burger.
4. Open the phone with the keybind; lock and unlock with a passcode; close it. Phone item is required.
5. Bank app: balance, transfer to a contact (pair), pay a bill.
6. Contacts and Messages: add a contact, send a message (pair), unread count.
7. Calls (pair): ring, answer, voice both ways, hang up, decline, busy.
8. Settings: change ringtone/background; Notes: create, edit, delete.

### Jobs, groups and the board
9. Groups app (pair): create, invite by number, accept, ready, leave, kick.
10. Jobs app: queue as a group, wait for the draw, accept, decline twice and see the lockout.
11. Courier run: routes load, blip appears, deliver, get paid from Post OP, timeout cancels.

### Economy and crafts
12. Shops: General and YouTool purchases take money and give items (bait, rod, knife, hammer, nutrition, bags).
13. Fishing: cast, wait, reel, catch; deep water refused below level 4; sell to the fish buyer; hourly cap holds.
14. Hunting: kill a deer, skin it with a knife, drops arrive, boar refused below level 3, sell to the game buyer.
15. Growing: plant (spot or own turf), water, feed, harvest, bag; strain gates (OG Kush level 5).
16. Chop shop: bring an ambient car, wait the scrub, parts arrive, plate cooldown, owned car refused.
17. Labs: supplier buys, cook coke and meth (level gates), collect, cooldown per lab.
18. Skills app: levels rise, "Coming up" lists the next unlock, daily cap stops experience.
19. Mechanic: repair an engine and body with the target, bill arrives for the driver (pair), cooldown per vehicle.
20. Workshop bench: craft repair kit as a mechanic on duty; refused off duty and below level.
21. Offers (pair): mechanic offers a kit, customer accepts in the phone, money and commission move; decline; expiry.
22. Roadside desk: closed while a mechanic is on duty, opens when none, one kit per hour.

### Crime and gangs
23. Gang app: invite, rank, kick, deposit (pair); last boss cannot leave.
24. Turf: tag an unowned zone, rival contests, owner defends, takeover after the window (pair).
25. Street sale in owned turf pays marked bills; market price falls with sales and recovers.
26. Gang payroll pays online members hourly from the gang account.
27. Launder front washes marked bills within the hourly budget.
28. Heist store, bank and vault: dongle starts, hack puzzle, alarm reaches police dispatch, doors open, loot pays treasury cash and marked bills; sites cool down (needs a crew and police on duty).

### Justice, medical, staff
29. Dispatch: a gunshot or 911 reaches police; MDT opens.
30. Arrest, booking, jail timer, bail, release, community service; court case and warrant.
31. Evidence: collect at a scene, custody log, analysis.
32. Downed player (pair): medic revive, new life rule note, medikit use (note: medikit has no effect yet).
33. Property: view, buy (pair for the race), mortgage, furniture.
34. Garage: store and retrieve, dealership purchase, rentals, mod shop.
35. Staff: `/report`, queue menu, `/goto`, `/bring`, `/spectate`, kick, ban, freeze, audit rows.
36. Whitelist: an unlisted account is turned away at connect.

### Robustness
37. Relog mid-job, mid-cook, mid-call; nothing is lost or duplicated.
38. Rapid repeat of every button (double click a buy, a harvest, an accept); no duplicate payout.
39. Two players hit the same claim at once (property, turf tag, heist site, plant harvest); one wins.
40. Restart a resource under load (`restart som-turf`); clients recover without a rejoin.
41. Leave the server idle for 30 minutes; check CPU, memory, the console for repeated errors.
42. 20 minutes of normal play with everyone moving; read `resmon` for any own resource above 0.3 ms.

## After the session
Fix in small branches, one logical fix each, merge as a batch (see CLAUDE.md). Add every bug's regression test to `tests/run.lua` before closing it, and tick or add lines in `LAUNCH-TODO.md`.
