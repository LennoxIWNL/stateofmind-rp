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

### Added since the first script (flows 43 to 58)

Everything below was merged after flows 1 to 42 were written. Same rules: nothing here has run with a client. A flow marked "after #62" or "after #63" needs that pull request merged and the beta server updated first. "Admin" means a tester with `group.admin`; `/givemoney` needs `group.god`. Ids in commands are server ids from the player list. Two testers are needed wherever a flow says "patient" or "buyer".

Commands used below, all checked against the code: `/setjob <id> <job> [grade]`, `/giveitem <id> <item> [count]`, `/givemoney <id> <cash|bank|crypto> <amount>`, `/givedongle <id>`, `/somhealth`. There is no command to put a player into the downed state: another tester has to knock them down (shoot or run them over), so give the attacker a weapon with `/giveitem` first.

SQL checks use the names in `setup.sql`. Ledger rows are in `som_transactions` (`citizenid`, `account`, `amount`, `direction`, `flow`, `reason`, `resource`, `business_id`). The treasury is `SELECT balance FROM som_treasury WHERE id = 1`. Business and gang balances are `som_bank_accounts.balance`.

#### EMS and hospital

**43. EMS revive** (pair, PR #59)
- Needs: tester A as a paramedic: `/setjob <A> ambulance 1`, `/giveitem <A> firstaid 2`. Ambulance ships with `defaultDuty = false`, so A must go on duty. I found no duty toggle for ambulance in the code (only police has the station desk), so if A cannot go on duty, record that as the first bug and stop. Tester B is a civilian with a bank balance of at least 600.
- Steps:
  1. B is knocked down. Check B lies on the ground and can still talk.
  2. A stands within 3 m of B. A sees a "Treat" option on B. B (still on the ground) must not see it on A.
  3. A picks Treat and a "Treating the patient" bar runs for 15 seconds. Try cancelling once and treating again.
  4. Let the bar finish.
  5. A tries Treat on B again straight away.
- Expect: B gets up, A has one `firstaid` fewer, B receives a phone bill of 600 titled "Emergency treatment" from the `ems` business. Step 5 says "give them a moment" (60 second cooldown). A civilian or an off duty A never sees Treat. A with no `firstaid` is refused ("you need 1 firstaid") and B stays down.
- Check: `SELECT * FROM som_phone_bills WHERE to_citizenid = '<B>' ORDER BY id DESC LIMIT 1;` shows 600 pending. After B pays, `ems` balance in `som_bank_accounts` rose by 600 and `som_transactions` has a matching row. The kit is gone from A's inventory only once.

**44. EMS supply locker** (PR #59)
- Needs: `Config.locker` in `resources/[som]/som-ems/shared/config.lua` set to `enabled = true` with `coords = vec3(...)` at a real spot (som-ems is not in `/place`'s list, so edit the file and `restart som-ems`). A is a paramedic on duty.
- Steps: walk to the locker, use "EMS supply locker" three times, then a fourth time. Repeat as a civilian and as a paramedic off duty.
- Expect: three `firstaid` kits arrive free, the fourth is refused ("you already carry enough"). Civilians and off duty medics do not see the locker or are refused. Too far away is refused.
- Check: no money moved for the player. The department account is not charged for the free issue (`departmentIssue.firstaid = 0`); confirm there is no stray `ems` or `lspd` debit row.

**45. Hospital transport and admission** (pair, after #62)
- Needs: in `som-ems/shared/config.lua` set `hospital.enabled = true`, `hospital.desk` and `hospital.bed` (vec3 and vec4 at the hospital front desk and a bed), restart `som-ems`. An ambulance vehicle model `ambulance` (spawn one as admin with your usual vehicle tool). A is a paramedic on duty, B has at least 250 in the bank.
- Steps:
  1. B is knocked down and stays down at least 30 seconds.
  2. A stands near B and uses "Check patient". Read the down time and cause.
  3. A brings the ambulance to within 5 m of B and uses "Load into ambulance". Look at where B is seated.
  4. A drives to the hospital desk. A stands at the desk and uses "Pillbox Hill Medical Center: admit patient" (the label is `hospital.label`).
  5. Separate run: load B, then use "Unload patient" away from the hospital.
  6. Separate run: load B and have B's player disconnect, then another run where A is demoted with `/setjob <A> unemployed`.
- Expect: step 3 seats B in the ambulance and B cannot slide out or run the down animation fighting the seat. Step 4 revives B and B appears on the bed for about 8 seconds. B pays 250 and A is paid 150 (60 percent). Admitting before 30 seconds down says "they only just went down, treat them first". Admitting far from the desk says "bring the ambulance to the front desk". Step 5 puts B on the ground next to the ambulance, still down. Step 6 releases B where the ambulance or A stands, never at the map origin.
- Check: `ems` balance is +250 then -150 (net +100) and `som_transactions` has `hospital-admission` and `ems-transport` rows for the right citizens. If B had under 250, A is not paid. Try admitting twice quickly: only one charge.

**46. Respawn fee funds EMS** (after #62)
- Needs: a civilian C who respawns at the hospital through the normal downed flow with enough money.
- Steps: let the down timer run out, respawn, note the hospital fee message.
- Expect: the fee is taken from C and credited to the `ems` account. Before #62 it was only taken, with no credit anywhere.
- Check: `ems` balance rose by the fee and a `hospital-treatment` row exists in `som_transactions`. If C could not pay, nothing is credited and C is treated free.

#### Licences and driving school (after #63)

Needs for flows 47 to 51: in `resources/[som]/som-licences/shared/config.lua` set `school.enabled = true`, `school.coords` (a vec3 at the counter), `school.spawn` (a vec4 on a clear road next to it) and `practical.route` (3 to 5 vec3 checkpoints on public road, 100 m or more apart), then `restart som-licences`. som-licences is not in `/place`'s list. Test players need a bank balance of at least 400 (`/givemoney <id> bank 2000`). Run `/somhealth`: `som_licence_attempts` must show as present.

**47. Theory test** (single player)
- Steps: at the counter pick "Take the theory test", answer all 10 questions, deliberately failing the first run (choose the first option every time).
  Then try again at once. Then wait out the retry time (30 minutes, or temporarily set `theory.retryMinutes = 1`) and answer correctly.
- Expect: questions show text and options only. A fail says you scored X of 10 and blocks a retry ("wait 30 minutes after a failed test"). A pass of 8 or more says to speak to the desk for the driving test. Starting without 400 in the bank says what the licence costs. Walking away mid-test and coming back after 15 minutes works again.
- Check: `SELECT * FROM som_licence_attempts WHERE citizenid = '<id>';` has a `theory` row per finished test, `passed` 0 then 1. Disconnecting mid-test also writes a failed row.

**48. Practical drive and issue** (single player)
- Steps: after a theory pass, pick "Start the driving test". Drive to every checkpoint. On the next attempt (redo the theory first) deliberately speed over 90 km/h, ram a wall, step out of the car for over 15 seconds, and try teleporting or driving a shortcut far faster than possible.
- Expect: a school car appears locked to others and you are seated in it. A route blip leads checkpoint to checkpoint. Faults show "Too fast" or "You hit something" with a count; more than 3 faults, leaving the car or 12 minutes fails the test and removes the car. Finishing issues the licence, takes 400 from the bank, and adds a `driver_license` card to the inventory. Another player cannot get in the school car.
- Check: `SELECT * FROM som_licenses WHERE citizenid = '<id>' AND type = 'driver';` has one row, `revoked = 0`, `suspended_until` NULL. `som_licence_attempts` has a `practical` row. Bank down 400, `som_treasury` up 400, and `som_transactions` has `licence:driver` debit and credit rows. The card opens from the inventory and shows the licence as valid. A holder cannot start the theory test again.

**49. Police check, suspend, revoke, reinstate** (pair)
- Needs: officer O: `/setjob <O> police 3` and on duty (police station desk, see flow 30). Civilian D holds a driver licence from flow 48. Also `/setjob <low> police 1` for a low rank officer L.
- Steps:
  1. O stands within 4 m of D and picks "Check licences".
  2. O picks "Suspend, revoke or reinstate a licence", Driver licence, Suspend, 3 days. Then repeat with 99 days.
  3. D opens the licence card. O checks again.
  4. O revokes the driver licence, then reinstates it.
  5. L tries step 2. O goes off duty and tries step 1.
- Expect: step 1 lists both licences and their state. A 3 day suspension shows "suspended until <date>" and D gets a notification; 99 days is refused (the cap is 14). The card shows suspended or revoked rather than missing. Reinstate restores it. L is refused ("your rank cannot do that"), and an off duty O is refused.
- Check: `SELECT type, revoked, suspended_until FROM som_licenses WHERE citizenid = '<D>';` after each step. To test lapsing, run `UPDATE som_licenses SET suspended_until = NOW() - INTERVAL 1 MINUTE WHERE citizenid = '<D>' AND type = 'driver';` and check again: it reads as valid with no timer involved.

**50. Weapon licence offer** (pair)
- Needs: O as in flow 49, buyer W with at least 5000 in the bank. The old $5000 shop spot is removed from ox_inventory, so confirm the spot is gone.
- Steps: O stands next to W and picks "Issue a weapon licence". W gets a confirm dialog: first decline, then ask again and accept. Then repeat with O going off duty (or walking 10 m away) before W answers, and once more letting 30 seconds pass before W answers.
- Expect: decline charges nothing. Accept takes 5000 from W, puts it in the `lspd` account, gives a `weaponlicense` card, and W can then use a licensed weapon. Off duty, moved away or timed out offers do nothing. A second offer to a holder is refused.
- Check: `som_licenses` has a `weapon` row with `issued_by` = O's citizenid. `lspd` balance +5000 and a `licence:weapon` row. W's bank down exactly 5000 once.

**51. MDT revoke and login mirror** (pair)
- Needs: D holds a driver licence. Officer O has the ps-mdt open on D's profile.
- Steps: revoke the driver licence from the MDT profile button. Check D's licence card. Then D disconnects and reconnects.
- Expect: the revoke lands in `som_licenses` (`revoked = 1`) and the card shows revoked. After relog it still shows revoked and a licensed weapon check for a revoked weapon licence fails. This is the one part I could only assume: ps-mdt is believed to write `metadata.licences.<type> = false` through `som-compat`. If the row does not change, that assumption is wrong, record it.
- Check: `SELECT * FROM som_licenses WHERE citizenid = '<D>';`. Existing beta characters who bought the old weapon licence need the one-time backfill (end of `setup.sql`) before this ships; test it on a copy by running the commented `INSERT IGNORE` and confirming `weapon` rows appear with `issued_by = 'legacy'` and the holder keeps the licence after login.

#### Money and payout fixes

**52. Paycheck keeps flowing** (needs two or more players with different jobs, PR #58)
- Needs: temporarily set `paycheckInterval = 2` (minutes, under `Config.Money`) in `som-core/shared/config.lua` and restart `som-core`. Put player P1 on duty as police (`/setjob <P1> police 1`) and P2 on duty in another job that has a wage and a business (for example `mechanic`). Freeze the police business account: `UPDATE som_bank_accounts SET frozen = 1 WHERE account_no = 'GOV-LSPD';`.
- Steps: wait for two paycheck ticks. Then unfreeze (`frozen = 0`) and wait for another.
- Expect: while frozen, P1 is not paid (the console says "could not cover payroll" for P1 only when `Config.Debug` is on), P2 is still paid, and the loop keeps running on the next tick. An error inside one player's pay prints `[som-core] paycheck failed for <citizenid>` and the loop still pays the rest. After unfreezing P1 is paid again.
- Check: `SELECT citizenid, direction, amount, reason FROM som_transactions WHERE reason LIKE 'paycheck:%' OR reason LIKE 'payroll:%' ORDER BY id DESC LIMIT 10;` and the business balances. Every `payroll:<job>` business debit has a matching `paycheck:<job>` player credit, or a `payroll:<job>:refund` row. Put the interval back to 60 afterwards.

**53. MDT delete and status budget** (PR #58)
- Steps: in the MDT delete an incident, then try to trigger the delete for the same incident several times fast (double click the delete). Separately eat and drink about 10 items in a row as fast as possible, then eat one more after a minute.
- Expect: the incident deletes once, with no repeated work in the console. Fast eating changes hunger and thirst normally for the first few and then stops changing past about 100 points in a minute; one item a minute later works again. Normal play is never blocked.
- Check: the console for repeated errors during the delete spam, and `resmon` for `som-core` staying low.

**54. Heist crews both get paid** (two players in one crew, PR #60)
- Needs: one heist site placed and enabled (see section 0 step 7), `/givedongle <id>` for the crew leader, police on duty for the alarm, and a treasury balance high enough (`SELECT balance FROM som_treasury WHERE id = 1;`).
- Steps: two crew members loot the same site at the same time and finish together. Then a second crew finishes a site while the first payout is still happening.
- Expect: every crew member present is paid their clean cash share, and the second crew waits briefly instead of getting nothing. Payouts stop at the site's `hourlyCleanCap` (4000 for a store) and the tester is told when the cap is reached.
- Check: `SELECT id, clean_paid FROM som_heist_runs ORDER BY id DESC LIMIT 5;` equals the total actually paid out. `som_treasury.balance` fell by that same total and `som_transactions` has matching treasury debits and player credits. A refused or failed payout leaves `clean_paid` unchanged.

**55. Buyer payouts and hourly cap** (PR #60)
- Needs: a buyer placed and enabled (fish, scrapyard or game, `hourlyCap = 6000`).
- Steps: sell goods to the same buyer repeatedly until the hourly cap is reached; try once more.
- Expect: sales pay from the treasury and stop at the cap with a clear refusal. A sale that fails halfway returns the goods and does not count against the cap.
- Check: `SELECT buyer, SUM(amount) FROM som_buyer_payouts WHERE created_at > NOW() - INTERVAL 1 HOUR GROUP BY buyer;` equals what the player was paid and is never above the cap. No payout row without a matching treasury debit.

**56. Concurrent payments do not lose money** (pair or more, PR #57)
- Steps: three testers buy or pay the same business account at the same moment (for example all three buy from the same shop, or pay bills to the same business) and repeat quickly several times. Also have two testers raise a gang deposit together.
- Expect: no error, every purchase works.
- Check: for the business, `SELECT balance FROM som_bank_accounts WHERE account_no = '<business account>'` equals the starting balance plus the sum of its `som_transactions` rows (credits minus debits for that `business_id`). A mismatch is the bug this fix was meant to remove. Do the same for the treasury and the gang account.

#### Inventory icons

**57. New item icons** (PR #61 and the icon commits before it)
- Steps: as admin run `/giveitem <id> drugtestkit`, `/giveitem <id> forceps`, `/giveitem <id> surgical_staple`, `/giveitem <id> clothing`. Open the inventory.
- Expect: each shows a photo icon, not a blank tile. The forceps icon is see-through inside the ring handles, not white. Items `arms`, `ears`, `emp_ammo`, `jeans`, `luxuryfinish_attachment`, `torso` and `tshirt` still have no icon (`tools/item-icons-baseline.txt`); that is known, not a new bug.
- Check: no 404 for an image file in the NUI console.

**58. Boot health after all of the above**
- Steps: `/somhealth`, then read the console after a full restart of `som-licences`, `som-ems` and `som-core`.
- Expect: no FAIL lines, no repeated errors, `som_licence_attempts` and the `suspended_until` column present. Run the checks in flows 47 to 56 again after one restart to prove nothing was stored only in memory.

## After the session
Fix in small branches, one logical fix each, merge as a batch (see CLAUDE.md). Add every bug's regression test to `tests/run.lua` before closing it, and tick or add lines in `LAUNCH-TODO.md`.
