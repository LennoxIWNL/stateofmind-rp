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

**53. MDT delete guard** (PR #58; the status half of this flow is replaced by flow 65)
- Steps: in the MDT delete an incident, then try to trigger the delete for the same incident several times fast (double click the delete).
- Expect: the incident deletes once, with no repeated work in the console.
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

### Round two: flows 59 to 68

Merged after flows 43 to 58 were written: clock in and out (#68), the taxi meter (#68), player shops (#67), ANPR plate readers (#66), trucking (#65), server owned hunger and thirst (#69), fuel (#70) and garbage rounds (#71). The EMS hospital (#62) and licences (#63) are merged now, so flows 45 to 51 no longer wait on anything. The boot fix branch (#72) was not merged when this was written and has no flow.

Same rules as before: nothing here has run with a client. Extra commands used, all checked against the code: `/place <resource> <path>` for `som-shops` (for example `/place som-shops shops.alta.coords`) and `som-fuel` (`/place som-fuel stations.station_1.coords`), then `restart <resource>`; `/abandonhaul`; `/abandonround`; `/setjob <id> <job> [grade]`. There is no vehicle spawn command in our code, so spawn vehicles with the tool staff already use (txAdmin menu or similar). Trucking and garbage routes are not placeable: edit `routes` in each resource's `shared/config.lua` and restart it.

#### Jobs and duty

**59. Clock in and out** (PR #68)
- Needs: three testers with `/setjob <id> mechanic 0`, `/setjob <id> ambulance 1`, `/setjob <id> police 1`.
- Steps:
  1. Each holds F1 and looks under Work for "Clock in or out". The mechanic picks it, then picks it again within 5 seconds, then again after 6 seconds.
  2. The paramedic picks it once.
  3. The police officer picks it.
  4. As the paramedic, go on duty and check the "Treat" option on a downed player (flow 43) now appears.
- Expect: the mechanic goes off duty ("You are off duty"), the second press at once says "one moment", the third puts them back on duty. The paramedic is on duty after one press, which was impossible before. The police officer gets "your job has no clock in" and keeps using the station desk (flow 30). Unemployed players have no Work section entry.
- Check: while off duty a mechanic is not paid at the next paycheck (`offDutyPay` is false): confirm there is no `paycheck:mechanic` row for that tick in `som_transactions`.

**60. Taxi meter and fare** (pair, PR #68)
- Needs: driver D: `/setjob <D> taxi 0` (taxi starts on duty). Passenger P with at least 500 in the bank. A vehicle of model `taxi` spawned next to them. Nothing hands out a cab yet (see `LAUNCH-TODO.md`), so staff spawn it.
- Steps:
  1. D sits in the driver seat, holds F1, Work, "Cab meter", "Start the meter". P sits in a back seat.
  2. D drives about 300 m and then picks "Charge the passenger". Then keeps driving to more than 600 m total from where P sat and picks it again.
  3. P gets a "Cab fare" dialog. First decline, then repeat step 2 and accept. Try waiting 40 seconds before answering a third fare.
  4. Stop the meter. Drive off without a passenger and try "Charge the passenger".
  5. As P, try the "Cab meter" menu.
- Expect: a fare text shows on both screens while the ride runs. At 300 m the charge says "too short to charge, the ride is free". At 600 m or more P sees the distance and fare (base $20 plus $60 per km plus $10 per waiting minute). Declining takes nothing and tells D. Accepting takes the fare from P's bank. A 40 second old fare says the request ran out. With no passenger D gets "nobody has ridden yet". P has no Cab meter entry.
- Check: `SELECT reason, direction, amount, flow, counterparty FROM som_transactions WHERE reason LIKE 'taxi:%' ORDER BY id DESC LIMIT 6;` shows the fare debit on P, the credit on the `downtowncab` account, then the commission (20 percent, below the fare) debit on the company and credit on D, all with flow `transfer` and counterparty `downtowncab`. The `downtowncab` balance is fare minus commission higher. D cannot earn more than 1500 in commission per hour: repeat long rides and check that the commission row shrinks and then stops once the hour total reaches 1500 (the passenger still pays the full fare).

#### Shops

**61. Buy a shop, stock it, sell to a customer** (pair, PR #67)
- Needs: place a shop with `/place som-shops shops.alta.coords` while standing at the counter, then `restart som-shops`. Owner O has at least 60000 in the bank (`/givemoney <O> bank 70000`) and items to stock (`/giveitem <O> water 20`, `burger`, `cola`, `sandwich`). Customer C has money in the bank.
- Steps:
  1. O uses "Alta Street Store" at the counter, picks "Buy this shop for $60000" and confirms.
  2. O opens the shop again, Manage the shop, "Stock an item": water, 10, price $5. Try price 1 and price 500, and a second item kind.
  3. C opens the shop, picks water, buys 3. Then buys 30.
  4. O uses "Change a price" to $6 while C has the menu open, then C buys at the old price.
  5. O uses "Take stock back" for 2 water.
  6. Both try to buy the same shop at once with two owners (second player is a second buyer, pair).
  7. O opens the phone: "My Shop" app.
- Expect: the shop is O's and the money is gone from the bank. Prices outside the allowed range ($3 to $30 for water) are refused with the range. C pays from the bank for 3 water and receives them. 30 is refused (at most 20 per purchase). A stale price fails with "not enough in stock, or the price changed". The second buyer is told "this shop is not for sale, or you already own one". The phone app shows the shop.
- Check: `SELECT * FROM som_shops;` has `owner` set. `SELECT * FROM som_shop_stock;` quantities match. `SELECT reason, direction, amount FROM som_transactions WHERE reason LIKE 'shop:%' ORDER BY id DESC LIMIT 12;` shows `shop:buy:alta` (taken from O, paid to the treasury), `shop:sale:water` (C debit, shop credit), `shop:tax` (8 percent from the shop to the treasury). The treasury rose by the shop price plus the tax: `SELECT balance FROM som_treasury WHERE id = 1;`.

**62. Shop money, staff and selling back** (pair, PR #67)
- Needs: flow 61 done, with some takings in the shop.
- Steps:
  1. O picks "Take money out" for more than 2000, then 500, then 500 again straight away.
  2. O picks "Hire the person next to you" with W standing close, pay 100 an hour. W accepts. Then try hiring W again, and a hire of pay 500.
  3. Wait an hour (or set `payIntervalMinutes = 1` in `som-shops/shared/config.lua` and restart) and watch W get paid. Set the pay to 0 on W's line to let them go. Have W use quit.
  4. O tries "Sell the shop back" with stock still inside, then with money still in the shop, then after clearing both.
- Expect: over 2000 is refused ("you can take $1 to $2000 at a time"), the repeat says "you took money out recently, try again later" (30 minute wait). W sees a hire offer dialog and is paid hourly from the shop account, never more than the shop holds. A second hire of W is refused (one job per character). Sell back is refused until stock and money are cleared, then pays half the price from the treasury (the dialog shows the amount) and the shop is for sale again.
- Check: `SELECT * FROM som_shop_staff;` row appears and goes. `som_transactions` has `shop:withdraw:alta`, `shop:payroll:alta` (flow `transfer`) and `shop:sellback:alta` rows. Rapid double clicking withdraw or sell back moves money once.

#### Police

**63. ANPR plate readers** (pair, PR #66)
- Needs: `wk_wars2x` and `som-anpr` running (both are in `som.cfg`). Officer O on duty (`/setjob <O> police 1`, station desk). A police cruiser of a listed model (`police`, `police2` and others in `som-anpr/shared/config.lua`), O in the driver or front passenger seat. A target car with a known plate T, driven or parked within 80 m. In wk_wars2x bind or run `radar_remote` (Open Remote Control) once and `radar_fr_cam` (Front Plate Reader Lock) to know the keys.
- Steps:
  1. O flags the plate: stand at the target car, use "Flag or clear the plate" with a reason. Then drive near it and let the front reader pass it.
  2. Mark the plate as a BOLO in the MDT, or set stolen: `UPDATE mdt_vehicleinfo SET stolen = 1 WHERE plate = 'T';`. Clear the police flag. Pass it again.
  3. Pass the same plate again within 5 minutes.
  4. Repeat the scan as a civilian in a normal car, and as O off duty, and from a non police model.
  5. Pass six different flagged plates within a minute.
- Expect: O gets a red notification "Plate <PLATE>: police flag" (later "stolen", "BOLO") for about 8 seconds and the reader locks on the plate. Dispatch receives a "flaggedVehicle" alert "Flagged vehicle <PLATE>: <reasons>" at the target's position, with no owner name. The same plate does not repeat for that officer for 5 minutes and dispatch gets one call per plate per 5 minutes. A civilian, an off duty officer or a non police vehicle gets nothing. After six calls in a minute extra plates still alert the officer but not dispatch.
- Check: nothing is written to the database by a scan; `som_police_plates` has the flag row with `cleared_at` NULL until cleared. The console has no errors from `som-anpr`.

#### Freight and sanitation

**64. Trucking haul** (two testers, PR #65)
- Needs: edit `routes` in `som-trucking/shared/config.lua` with at least one real route (`id`, `label`, `depot` vec4, `trailer` vec4, `dropoff` vec3, `base`, `minutes`), at least 1500 m between depot and drop, restart `som-trucking`. Tester A and B in a group (Groups app, flow 9). The `postop` account must hold enough to pay (`SELECT balance FROM som_bank_accounts WHERE account_no = 'BUS-POSTOP';`).
- Steps:
  1. The leader queues the contract "trucking_<id>" (shown by the route label) in the Jobs app, accepts when drawn.
  2. A truck (`phantom`) and a trailer (`trailers`) appear. Hook up and drive. Try handing in right away, then after driving.
  3. At the drop use "Hand in the trailer" with the trailer inside the yard, and once outside it.
  4. Run a second haul and damage the trailer, then a third late (past the time plus 15 minutes grace).
  5. Start another and use `/abandonhaul`, confirm, then try queueing again.
  6. Complete several hauls to pass 2500 in an hour.
- Expect: handing in too soon says "you have not driven that far yet", outside the yard says "bring the trailer into the yard", far away "you are too far away". The pay is base times (1 minus damage) with a late penalty, never below a quarter of base; two crew members each get paid, with a group bonus. Past the hourly cap: "You have hauled enough for this hour". After abandoning, the crew is told a crew member abandoned recently for 15 minutes. Penalties never bill the player.
- Check: `som_transactions` has the payroll debit on `postop` and the credit on each player, equal amounts, flow `transfer`. No haul pays twice if the hand in is double clicked.

**65. Hunger and thirst are decided by the server** (PR #69, replaces the status half of flow 53)
- Needs: a tester with low hunger and thirst, items `burger`, `sandwich`, `water`, `cola`, `mustard` and one with no status effect such as `coffee` (give with `/giveitem <id> <item> <count>`).
- Steps:
  1. Use a burger, a water, and a sandwich. Read the bars before and after.
  2. Start using a burger and cancel the progress bar.
  3. Use ten burgers quickly.
  4. Use `coffee` or `bandage`.
- Expect: a burger or sandwich adds 20 to hunger, water or cola adds 20 to thirst, `mustard` adds 2.5 to both. A cancelled use changes nothing and does not consume the item. Using many in a row is limited only by the items you hold and the 100 maximum, with no hidden per minute cap. Coffee and bandage do nothing to the bars (they are not in `Config.ItemStatus`); that is expected, not a bug.
- Check: the character metadata hunger value in `som_characters.metadata` after a relog matches the bar. A client cannot raise a bar by sending an event: the old `som:server:adjustStatus` event no longer exists, so firing it from a client console does nothing.

**66. Fuel** (pair optional, PR #70)
- Needs: `/place som-fuel stations.station_1.coords` standing at a pump (placing also switches it on), `restart som-fuel`. A tester with money in cash and bank. `/giveitem <id> WEAPON_PETROLCAN 1` for an empty can test.
- Steps:
  1. Drive a car and watch the fuel bar over a few minutes at idle and at speed. Let it fall below 10. Let it run empty.
  2. Stop at the pump, use "Refuel vehicle", pick litres and cash, then do it again paying by bank.
  3. Try to refuel with the engine far away (more than 6 m) and a vehicle that is full.
  4. At the pump use "Buy jerry can ($120)", then "Refill jerry can" holding it, then walk to an empty car and "Pour jerry can" (out of the car).
  5. Click refuel twice quickly.
- Expect: fuel falls faster at speed. Below 10 you get a warning, at 0 the engine cuts. Refuelling takes 0.4 seconds per litre with a bar, charges $4 per litre and fills only the room in the tank. A full tank or a can that is empty or full says so ("the tank is full", "the can is empty", "the can is full"). Pouring takes 4 seconds and moves 5 units from the can to the car. A second click inside 1.5 seconds says "one moment". The fuel level of a car that is not being driven does not change.
- Check: `fuelco` (`BUS-FUEL`) balance rose by exactly what the player paid, matching `som_transactions` rows for the purchase (debit on the player, credit on `fuelco`). The jerry can's `durability` metadata in the inventory matches its fill. Restart `som-fuel` mid drive and check the fuel level stays (it is meant to be held in the vehicle state bag; this is untested).

**67. Garbage round** (crew of 1 to 3, PR #71)
- Needs: edit `routes` in `som-garbage/shared/config.lua` with at least one route (depot vec4, `dump`, `recycle`, stops with bins that each have an `id`, a `kind` of `general` or `recycle`, and coords), restart `som-garbage`. The `sanitation` business (`GOV-SAN`) exists; the city tops it up from the treasury within `monthlyBudget`. A group of 1 to 3 in the Groups app.
- Steps:
  1. Queue "Garbage round" in the Jobs app and accept. A `trash` truck appears.
  2. At each stop, walk to a bin within 4 m of it with the truck close and pick "Black bin: general waste" or "Blue bin: recycling". Try the wrong choice on a recycling bin. Try a bin twice and a bin far from the truck.
  3. Finish the stops, drive to the dump and pick "Tip the general waste" and "Tip the recycling". Try tipping early and twice.
  4. Use `/abandonround` on another round.
  5. Run rounds until 2000 has been paid in one hour.
- Expect: each bag takes about 2.5 seconds. A bag put in the wrong compartment says "Wrong bin: that bag is general waste now" and pays the general rate. Each recycled bag pays 12 plus 10, a general bag 12. A bin cannot be emptied twice ("already emptied"). Tipping before the stops are done says to finish the stops; after tipping once, "already tipped". After abandoning, the crew waits 15 minutes. At the hourly cap you are told so. If the city cannot fund a round, the job board says so instead of starting.
- Check: `som_transactions` has `sanitation` payroll debits and the player credits (equal), plus a treasury top up row when the account needed it; nothing is paid twice for one tip.

**68. Boot health, round two**
- Steps: `/somhealth` after a full restart; read the console for `som-duty`, `som-taxi`, `som-shops`, `som-anpr`, `som-trucking`, `som-fuel` and `som-garbage`.
- Expect: no FAIL lines. `som_shops`, `som_shop_stock`, `som_shop_staff` and `som_police_plates` present. `fuelco`, `sanitation` and `downtowncab` exist in `som_businesses`. `wk_wars2x` started before `som-anpr`. Repeat flows 59 to 67 once after a restart to prove nothing was only in memory.

### Round three: flows 69 to 91 (everything merged in the jobs and services update and the game clock)

Written for the owner's first in-game pass of the update that added mining, vehicle insurance, new player onboarding, estate agent sales, Weazel News, the fire department, the EMS person-down call, car boosting, tow tickets, the combat log watch, the economy watch, street racing, house burglary, player-run restaurants and the server game clock. Nothing here has run with a client. A flow marked "pair" needs two testers, "police" needs an officer on duty, "EMS" needs a paramedic on duty. Run the smoke test first, then the setup, then any flow in any order unless a flow says it needs another.

Names in this round were read from the code, not from memory. Staff commands used: `/setjob <id> <job> [grade]` (admin), `/giveitem <id> <item> [count]` (ox_inventory, `group.admin`), `/givemoney <id> <cash|bank|crypto> <amount>` (god), `/settime <hour> [minute]` and `/freezetime [hour] [minute]` (admin), `/gametime` (mod), `/place <resource> <path>` and `/places` (admin), `/pdcoords` (admin, prints a position formatted for a config file), `/startfire` and `/stopfires` (admin), `/insurerfund <amount>` (admin), `/removestory <id>` (mod), `/combatlogs [hours]` (mod), `/economyreport [hours]` (admin), `/boostpay <run> <id>` (admin), `/giveracedongle <id> <creator|racer>` and `/voidracedongle <uid>` (admin), `/dispatch` (opens the dispatch board for on-duty police, EMS, fire and dispatchers). Going on duty: F1, Work, "Clock in or out" for every job except police, which uses the station desk (flow 30). There is no vehicle spawn command in our code, so spawn vehicles with the tool staff already use. There is no command to knock a player down: a second tester has to shoot or run them over, so give them a weapon with `/giveitem`. Console commands run without a player and need no permission.

#### Smoke test first (about ten minutes, before any flow)

This tells you whether the beta server even booted this update. Stop at the first red result and fix it before testing anything else.

- **S1. Boot log.** After a full restart read the whole server console. Expect no `SCRIPT ERROR` and no red line from `som-tow`, `som-restaurants`, `som-racing`, `som-burglary`, `som-fire`, `som-news`, `som-insurance`, `som-welcome`, `som-boosting`, `som-loans` or `som-core`. A line saying `som_vehicle_insurance is missing`, `som_tow_tickets is missing` or `som_* tables are missing` means `setup.sql` was not imported on this database.
- **S2. Resources started.** In the server console run `somhealth`. Expect `[somhealth] 0 problems that stop a launch` and no `FAIL` row. The resource list in the health check includes `som-burglary`, `som-racing`, `som-restaurants` and `som-tow`, and the table list includes every table below, so a missing one shows up as a FAIL row here.
- **S3. The new tables are there.** In the database run `SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name IN ('som_vehicle_insurance','som_insurance_claims','som_welcome_claims','som_welcome_jobs','som_news_stories','som_news_payouts','som_boost_runs','som_tow_tickets','som_restaurants','som_restaurant_orders','som_burglary_runs','som_burglary_loot','som_race_dongles','som_race_aliases','som_race_tracks','som_races','som_race_entries','som_race_times');` Expect 18. Then `SHOW INDEX FROM som_transactions WHERE Key_name = 'idx_time';` Expect one row (an older database needs the `ALTER` in setup step 1).
- **S4. The new businesses.** `SELECT name FROM som_businesses WHERE name IN ('insurer','weazel','fire','burgershot','lspd','dynasty8');` Expect six rows. `insurer` and `burgershot` are created when `som-insurance` and `som-restaurants` start, so a missing one points at that resource not starting.
- **S5. The game clock answers.** In the console run `gametime`. Expect `[som-core] Game time HH:MM`; run it again a minute later and the time has moved on by about 30 minutes (a game day is 48 real minutes). In game, as a moderator, run `/gametime` and compare it with the HUD clock. They agree to the minute.
- **S6. The phone lists the new apps.** Open the phone as an ordinary character. Expect the apps Getting Started, Insurance, Weazel News, Street Racing and Tow (plus Bank loans from earlier). Weazel News shows "No news right now", Street Racing shows "Street racing is closed", Insurance shows your vehicles or "You have no vehicles to insure", Tow shows nothing useful until you are a tow driver on duty.
- **S7. Dispatch and placement work.** `/dispatch` opens a board as an on-duty officer ("No open calls" is fine). `/places` as admin prints a count or "Nothing placed yet".
- **S8. No console spam.** Wait two minutes with nobody doing anything. Expect no repeating error line.

#### Setup for round three (do once, in this order)

1. **Database.** Import `setup.sql` (it is safe to import twice). On a database older than this update also run `ALTER TABLE som_transactions ADD KEY IF NOT EXISTS idx_time (created_at);` (MariaDB). A database created before the fire department also needs the two `INSERT IGNORE` statements for `GOV-FIRE` and `fire` quoted in `LAUNCH-TODO.md` under "Fire department", then `restart som-economy`.
2. **Switches to flip in config** (not placeable, edit the file and restart the resource): `som-news/shared/config.lua` `enabled = true` (flow 73); `som-racing/shared/config.lua` `enabled = true` (flows 81 to 83). Everything else ships in the state the flow expects. `som-burglary` ships `night.enabled = true`, which is what flow 84 tests.
3. **Treasury seed (beta server only, never production).** The treasury starts at 0 and many payouts come from it. Run `UPDATE som_treasury SET balance = 300000 WHERE id = 1;` Remember it is an unledgered seed: reset it (`UPDATE som_treasury SET balance = 0 WHERE id = 1;`) before the promotion to main is even discussed.
4. **Placements.** `/place <resource> <path>` stores the position where you stand and switches the entry on, then `restart <resource>`. The resources it accepts are listed in `som-staff/shared/config.lua` under `placeableList`: `som-turf`, `som-outdoors`, `som-heists`, `som-mechanic`, `som-launder`, `som-shops`, `som-fuel`, `som-ems`, `som-dmv`, `som-welcome`, `som-boosting`. **`som-restaurants` and `som-burglary` are not in that list, so `/place som-restaurants ...` and `/place som-burglary ...` answer "unknown resource" (see the bug list at the end of this round).** Until that is fixed, add `['som-restaurants'] = true, ['som-burglary'] = true` to `placeable` and the two names to `placeableList` in `som-staff/shared/config.lua`, then `restart som-staff`. Mining nodes cannot be placed at all (`/place som-outdoors mining.sites.copper_1.nodes+` answers "this field cannot be placed"): edit `nodes = { vec3(x, y, z) }` of the site by hand and `restart som-outdoors`. `/pdcoords` prints the text to paste.
5. **Testers.** Staff: A (`group.god`, to use `/givemoney`), plus B, C and D as ordinary characters. Keep two of them with a bank balance. `/givemoney <id> bank 100000` is fine on beta.
6. **Report format.** Same as above: copy the `[som-trace]` lines and say which flow and step.

---

**69. Mining** (pair optional)
- Needs: placements per setup step 4. For `mining.sites.copper_1` put one or two real `vec3` positions in `nodes` by hand, then `/place som-outdoors mining.smelter.coords` at a spot for the furnace and `/place som-outdoors buyers.quarry.coords` at the buyer, then `restart som-outdoors`. Treasury seeded (setup step 3). A miner with `/giveitem <A> pickaxe 2` (the pickaxe is also sold in the general shops for $150) and, for the friend bonus, a second miner with a pickaxe.
- Steps:
  1. Stand within 3 m of the node and pick "Mine: Copper vein". A bar "Mining" runs for 8 seconds. Cancel it once and start again, then let it finish.
  2. Strike the same node again straight away.
  3. A second tester with a pickaxe tries the same node.
  4. Drop the pickaxe from your inventory and try again on a different node or after the rest.
  5. At the smelter pick "Smelt copper" with fewer than 3 `copperore`, then with 3 or more. A bar "Smelting" runs for 10 seconds.
  6. At the quarry buyer pick "Sell: Quarry buyer" holding `copper`. Then do it again with the treasury at 0 (`UPDATE som_treasury SET balance = 0 WHERE id = 1;`).
  7. With two miners both holding a pickaxe within 6 m of a vein, strike it once from one of them.
- Expect: step 1 a cancelled bar gives nothing and the vein is not spent. A finished bar gives 1 to 3 `copperore` (weight 1000 each, so check the carry weight). Step 2 says "this vein is spent for now" (10 minute rest, for everybody). Step 3 says the same, or "someone else is working that vein" if the first swing is still running. Step 4 says "you need a pickaxe". Step 5 without enough ore says "you do not have enough ore"; with 3 `copperore` it gives 2 `copper`. Step 6 pays 30 per `copper` from the treasury into the bank, capped at 6000 an hour server wide; at a treasury of 0 it says "the city cannot pay right now" and the metal comes back to you. Step 7 gives one more ore (up to 2 helpers).
- Check: `SELECT citizenid, amount, reason FROM som_transactions WHERE reason LIKE 'buyer:quarry%' ORDER BY id DESC LIMIT 3;` shows the player credit (flow `faucet`). The sale moves money out of `som_treasury` by exactly what the player received: compare `SELECT balance FROM som_treasury WHERE id = 1;` before and after.
- Most likely wrong: the swing animation or interaction zone not appearing, and a vein that never rests or rests for everybody after a restart (the rest timer and the 40 strikes an hour are in memory and reset on `restart som-outdoors`).

**70. Vehicle insurance** (single player, EMS not needed)
- Needs: the player owns a car bought at the dealership (flow 34) so it has a recorded purchase price of at least $1000; a staff spawned car has none and cannot be insured. Fund the insurer with at least 80 percent of the car's price: for a $40000 car `/insurerfund 40000` (admin, takes the amount from the treasury into `BUS-INSURER`, at most $100000 a use). Bank of at least $2000.
- Steps:
  1. Open the Insurance app. The car shows "Not insured, $<premium> every 7 days. Cover starts 2 days after you pay". Tap to insure.
  2. Tap the policy again to cancel, then insure again.
  3. To skip the 2 day waiting period run `UPDATE som_vehicle_insurance SET covered_from = NOW() - INTERVAL 3 DAY WHERE vehicle_id = <id>;` and take the car out of the garage so it is "out".
  4. Make the car old enough: `UPDATE som_vehicles SET taken_at = NOW() - INTERVAL 20 MINUTE WHERE id = <id>;`
  5. Delete the car from the world with your usual staff tool so nothing carries its plate, then tap "Claim for <plate>" in the app.
  6. Try the claim with the car still in the world, and again immediately after step 5 succeeded.
- Expect: step 1 takes the premium (1 percent of the price, at least $25) from the bank and the row reads "Covered for 7 more days, tap to cancel". Step 2 cancel then insure charges again and restarts the waiting. Step 5 takes the excess (10 percent of the price, at least $250) from the bank and the car is back in the garage, undamaged and with full fuel. A claim with the car still out there says "this vehicle is still out there". A second claim says "only a vehicle that is out can be claimed". A claim before the waiting period says "this vehicle is not covered for this"; before 15 minutes out, "it has not been gone long enough".
- Check: `SELECT * FROM som_insurance_claims ORDER BY id DESC LIMIT 1;` shows status `paid`, cost 80 percent of the price. `som_transactions` has `insurance:premium:<id>`, `insurance:claim:<n>:excess` and `insurance:claim:<n>:payout` and `:replacement` rows, and the insurer balance (`SELECT balance FROM som_bank_accounts WHERE account_no = 'BUS-INSURER';`) fell by the cost and rose by the excess and premium. With the insurer at 0 the claim says "the insurer cannot pay out right now" and nothing moves.
- Most likely wrong: `GetAllVehicles` not seeing a garage-spawned car that nobody is near (a parked car far from every player can be culled, so it counts as gone and a claim could succeed on a car that still exists), and the Insurance app rows not refreshing after a tap.

**71. New player onboarding and the settling-in payment** (single player)
- Needs: `/place som-welcome desk.coords` at a counter, `restart som-welcome`, treasury seeded. A brand new character on a licence that has never claimed (check `SELECT COUNT(*) FROM som_welcome_claims;`). To skip the 30 minute job step: `UPDATE som_welcome_jobs SET minutes = 30 WHERE citizenid = '<id>';` after step 3.
- Steps:
  1. Open the Getting Started app on the new character. Read the guide rows and the three "Settling in" rows (all "Not yet").
  2. Pass the theory and driving tests (flows 47 and 48) so a driver licence exists. Own or rent a home (flow 33; a rented place from a lease counts).
  3. At the job centre desk pick "Cab driver, Downtown Cab Co." (the desk offers `taxi` and `delivery` only, grade 0). Then try a job that is whitelisted: set `/setjob <id> police 1`, then at the desk try to leave it.
  4. Wait the 30 minutes in the city holding the job (or run the SQL above), then reopen the app.
  5. Tap "Claim $1000". Tap it again and open it as a second character on the same licence.
- Expect: the three steps tick "Done" one at a time and "Claim $1000" only appears when all three are done. A character on a whitelisted job gets "you cannot leave that job here". The payment is $1000 from the treasury into the bank and the app shows "Received". A repeat says "you have already had it". A second character on the same licence is refused. The desk does not change duty: a new job starts with that job's default duty.
- Check: `SELECT * FROM som_welcome_claims;` has one row for the character with its licence. `som_transactions` has `welcome:settling-in` credit on the player and debit on the treasury. Claim until the daily cap ($2000) is reached with other new licences to see "the city cannot pay any more settling-in payments right now, try again tomorrow".
- Most likely wrong: the job minutes counter (it only counts while the character is loaded and holds a job, and a character who already had a job starts at zero), the desk zone and menu on a real client, and the "home" step not recognising a rented place (it looks for a `tenant` or `owner` row in `som_property_owners`).

**72. Estate agent sales** (pair)
- Needs: agent A `/setjob <A> realtor 1` and on duty (F1, Work, Clock in or out); buyer B with `/givemoney <B> bank 1600000`. Properties come from `som-housing/shared/config.lua`: "Grove Street House" ($95,000, ordinary) and "Vinewood Hills Estate" ($1,450,000, luxury, agent only). Both for sale at the start.
- Steps:
  1. A and B stand at the Grove Street House door. A picks "Show this property", chooses B in the dialog. B sees "<A> would like to show you this property, listed at $95000. You can go inside together." and accepts.
  2. Both walk in through the door with no key. Wait past 10 minutes outside and try the door again.
  3. A picks "Sell outright" for B. B sees "<A> offers you Grove Street House for $95000, paid from your bank." and accepts.
  4. Repeat at the Vinewood Hills Estate as agent grade 0 (`/setjob <A> realtor 0`), then as grade 1.
  5. As B, try to buy the luxury house the ordinary way (the buy you used in flow 33).
  6. Try to sell with A not on duty, with B standing far away, and to yourself.
- Expect: step 3 takes $95000 from B's bank into the Dynasty 8 account, A receives 3 percent ($2850) as a bank credit with "Grove Street House sold. Your commission is $2850." and B owns the house. Step 4 at grade 0 says "a more senior agent has to close this one"; at grade 1 it works and the commission is $43500. Step 5 stays refused (a luxury house is only sold by an agent). After the 10 minute window the door refuses a buyer who has no key ("you do not have a key"). Selling before showing says "show them the property first"; off duty "only an estate agent on duty can do this"; far away "both of you must be at the property"; to yourself "you cannot sell to yourself".
- Check: `som_transactions` has `property:<slug>` (B debit, `dynasty8` credit), `commission:<A citizenid>` (`dynasty8` debit) and `property-commission:<slug>` (A credit). `SELECT * FROM som_property_owners WHERE role = 'owner' ORDER BY id DESC LIMIT 2;` shows B. Dynasty 8 balance rose by price minus commission.
- Most likely wrong: the three new door menu entries ("Show this property", "Sell outright", "Sell on finance") not showing for an agent on duty, the buyer's dialogs, and two people walking through the door together on a real client.

**73. Weazel News** (pair)
- Needs: `som-news/shared/config.lua` `enabled = true`, `restart som-news`. Reporter A `/setjob <A> news 0` and on duty (Clock in or out). Reader B, any job. Treasury seeded.
- Steps:
  1. A opens Weazel News and picks "Publish story", types `Docks closed | The harbour authority closed the docks after a collision this morning and expects a reopening tomorrow afternoon.` Then types a short one (`Hi | too short`).
  2. Publish another story within 2 minutes. Publish exactly the same text later.
  3. A picks "Breaking alert" with a headline of at least 8 characters and a body of at least 60. B has the phone open or in a pocket.
  4. B opens the app and reads the feed. A civilian B tries to publish (it must show no buttons).
  5. A reporter goes off duty and tries again.
  6. A moderator runs `/removestory <id>` for one story.
- Expect: step 1 pays $150 to A's bank from the treasury ("Latest" shows the story with the author and age). A short body says "a story needs more than that", a short headline "the headline is too short", text without a `|` says "write it as: headline | story". Step 2 inside 2 minutes says "slow down"; an identical text says "you already published that". Step 3 appears under "Breaking" for 2 hours, pays nothing, and every online phone gets a notification with the headline. Another breaking alert within 5 minutes by anyone says "slow down". Step 4 B sees the feed only. Step 5 says "only reporters on duty can publish". Step 6 removes it from the feed; the $150 already paid is not taken back.
- Check: `SELECT id, kind, headline, status FROM som_news_stories ORDER BY id DESC LIMIT 5;` and `som_transactions` rows with reason `news:story:<id>` (treasury debit, A credit, flow `transfer`). After four paid stories in one hour ($600 per reporter an hour, one story per 2 minutes) the fifth still publishes but pays 0.
- Most likely wrong: the one-line prompt (`Headline | story text`, the phone host view takes a single line), the breaking banner reaching every phone, and the new SQL (`TIMESTAMPDIFF`, `INSERT ... SELECT ... FROM DUAL WHERE NOT EXISTS`) which has only run against the mock.

**74. Fire department** (pair, EMS optional)
- Needs: firefighter F `/setjob <F> firefighter 0` and on duty. `/giveitem <F> WEAPON_FIREEXTINGUISHER 1` (nothing sells it yet). Admin A. A second player B who will be knocked down near the fire by a third tester (or B just stands in as the victim for step 5, see flow 32 for how to get downed).
- Steps:
  1. A stands where a fire should start and runs `/startfire`. Check police, EMS and fire get a "10-70 Fire" call on `/dispatch`.
  2. F equips the extinguisher, stands within 8 m of a flame and sprays at it until it goes out. Spray from further than 8 m, then without the extinguisher.
  3. A runs `/startfire` four times in a row.
  4. Let one fire burn without anyone fighting it for 12 minutes (or note the time).
  5. With B downed within 8 m of a flame and F within 3 m of B, F picks "Pull clear of the fire" on B.
  6. A runs `/stopfires`.
- Expect: step 1 flames appear for every client and the call shows. Step 2 each accepted spray takes 10 off a flame (100 hp), at least 3 sprays are needed to be paid; a flame out pays $40 split between the firefighters who sprayed it. Too far says "you are too far from the fire", no extinguisher "you need an extinguisher". Step 3 the fourth says "too many fires burning" (3 at a time). Step 4 the fire burns out after 720 seconds and nobody is paid. Step 5 a "Pulling them clear" bar runs 5 seconds and B is moved about 12 m away from the flame; someone who is not a downed player or not near a flame says "nobody here needs to be pulled out". Step 6 clears every flame.
- Check: `som_transactions` rows `fire-pay` (the `fire` business debit, F credit); `SELECT balance FROM som_bank_accounts WHERE account_no = 'GOV-FIRE';` fell by what was paid and when it is empty it is topped up from the treasury within $4000 an hour. A firefighter is paid at most $1500 an hour. The console must never print `[som-fire] MONEY LOST`.
- Most likely wrong: flames drawing and clearing for every client, whether the game's own extinguisher puts the flame out before the server counts the hits, spread positions inside walls, and a fire call that never closes on the board (it leaves with the normal call lifetime).

**75. EMS person-down call** (pair, EMS)
- Needs: paramedic E `/setjob <E> ambulance 1` on duty. Victim V (any character) who is not jailed or on remand. A third tester or an NPC to down V.
- Steps:
  1. V is downed and stays down. Watch E's `/dispatch` for 30 seconds.
  2. Open the call. Note the position and the blip.
  3. E treats V (flow 43) or V respawns at the hospital. Reopen the board.
  4. V is downed again straight away and stays down for more than 30 seconds.
  5. Have V downed while cuffed by police but not booked, and again while serving a jail sentence (flow 30).
- Expect: about 30 seconds after V goes down E sees "P2 10-52 Person Down" with a blip (sprite 61). Treating, respawning or V leaving the server closes the call. A second down inside 120 seconds does not raise a second call for the same character. A cuffed, not yet booked V is still called; a V with a sentence or remand row is not. Police and fire do not receive this call.
- Check: if you have several downed players, each gets its own call (they are not merged).
- Most likely wrong: the 30 second delay, that revive, respawn and hospital admission all really close the call on a live server, and the call showing as closed on the MDT. Kill switch if it spams: `Config.EmsCall.enabled = false` in `som-medical/shared/config.lua`.

**76. Car boosting** (police, pair)
- Needs: `/place som-boosting pickups.pickup_1.coords` at a street spot where a car can appear, `pickups.pickup_2.coords` elsewhere, `/place som-boosting dropoffs.dropoff_1.coords` at a yard, then `restart som-boosting`. Optionally set a pickup `heading` in the config. Boosters A (leader) and B in a group (Groups app, flow 9). Police P `/setjob <P> police 1` on duty (class C needs 1, class B needs 2).
- Steps:
  1. The leader queues "Class C contract" in the Jobs app and accepts the draw. Check class A is absent ("not taking contracts yet").
  2. The crew gets a blip circle (150 m) around the car. Find a `blista`, `asea` or `premier` with a locked door.
  3. At the car pick "Pick the lock" (a bar about 13 seconds). Try it from 8 m away and on a car that is not the contract's.
  4. Drive the car to the drop-off at least 45 seconds after the unlock. Try handing it over early, and from outside 8 m.
  5. At the drop-off pick "Hand over the car" while driving it. Both crew within 60 m share the pay.
  6. Wash the bills at a launder front (flow 27).
  7. Let a second contract run out (40 minutes) or abandon it.
- Expect: step 3 "you are not at the car" far away, "that is not the car" for another vehicle, "it is already open" the second time. Step 4 early says "give it a few minutes before you hand it over", outside 8 m "bring it to the drop-off", not driving "you need to be driving it". Police should get a dispatch alert when the car is taken. Step 5 pays 4 `markedbills` worth 250 each (class C) as items to the crew members within 60 m of the drop-off, no cash and no treasury movement. A pickup that already ran cools down for 30 minutes.
- Check: `SELECT * FROM som_boost_runs ORDER BY id DESC LIMIT 1;` shows `done` with `paid` equal to the face (4 x 250 = 1000 for class C). `SELECT worth, status, source_tag FROM som_marked_bills WHERE source_tag LIKE 'boost:%' ORDER BY id DESC LIMIT 4;` shows the bills. If a run is `done` with `paid` 0 or `unpaid`, an admin pays it with `/boostpay <run> <id>` five minutes after the delivery.
- Most likely wrong: the spawn and the lock (`SetVehicleDoorsLocked`), the plate on a server-created vehicle, the unlock bar and the hand-over zone, the police call on a real police client, and the model names (`blista`, `asea`, `premier`, `sultan`, `jackal`, `fugitive`) not checked against the streamed vehicle list.

**77. Tow tickets: the whole job** (pair, police)
- Needs: tow driver T `/setjob <T> tow 0` and on duty (Clock in or out). Officer P `/setjob <P> police 1` on duty. Owner O with a car bought at the dealership (a row in `som_vehicles`), parked on a street with a tow truck model spawned for T (any vehicle works, `flatbed` is natural). The `lspd` account holds $750000 at start. To keep the waiting short set `ticketMinutes = 2` and `claimMinutes = 1` in `som-tow/shared/config.lua` and `restart som-tow` (the sweep runs every 60 seconds).
- Steps:
  1. With no tow driver on duty (T off duty) P uses the Impound option on the car, picks "Ask for a tow truck" and a reason. Then repeat with T on duty.
  2. T gets "Tow request for <PLATE>. Check your phone." T opens the Tow app and taps "Tow <PLATE>". Check the waypoint.
  3. A second driver D (`/setjob <D> tow 0`, on duty) tries to take the same ticket.
  4. T gets the car to the impound lot (407.9, -1633.5, 29.29), within 40 m, with T standing within 40 m of the car, and taps "Deliver <PLATE>". Try first from far away.
  5. Repeat with a street car nobody owns, and run seven paid tows in an hour.
  6. As P pick "Impound now" on another car that has an open ticket.
- Expect: step 1 with nobody on duty the car is impounded at once ("<PLATE> impounded"); with T on duty the officer sees "Tow requested for <PLATE>" and the car stays. Step 3 says "someone else took it". Step 4 far away says "the car is not at the impound lot" or "you have to be with the car"; in place it impounds the car, removes it and pays T $400 from `lspd` into T's bank. Step 5 a street car is impounded but pays nothing; the 7th paid tow in an hour pays nothing and T is told so. If the `lspd` account cannot pay, T is told the department could not pay. Step 6 the open ticket is closed.
- Check: `SELECT id, plate, state, driver, paid FROM som_tow_tickets ORDER BY id DESC LIMIT 5;`, `SELECT * FROM som_police_impound WHERE released_at IS NULL ORDER BY id DESC LIMIT 3;` (one open row per plate), `som_transactions` rows `tow:<id>` (`lspd` debit, T credit). The owner pays the usual $2500 release fee to get the car back (flow 34 style).
- Most likely wrong: the new impound menu on a real client, the phone app and waypoint, a car arriving at the lot on a flatbed being seen by `GetAllVehicles`, and the lot position (it must be the same place as the police impound, within 40 m).

**78. Tow sweep must NOT take a moved car** (pair, police)
- Needs: flow 77 setup (`ticketMinutes = 2`, `claimMinutes = 1`), T on duty, P on duty, two cars with owners (a row in `som_vehicles` each).
- Steps:
  1. P asks for a tow on car 1 and car 2. T does not take either.
  2. The owner drives car 1 away more than 25 m, or puts it in a garage. Leave car 2 exactly where it was.
  3. Wait 3 minutes.
  4. Separate run: T takes a ticket (tap "Tow <PLATE>"), does not deliver, wait 70 seconds, then check the board again.
- Expect: step 3 car 1's ticket is closed (`cancelled`) and the car and its `som_vehicles` row are left alone (still `out` or `garaged`, no impound row, the car still in the world). Car 2 is impounded (removed, row `impounded`, an open `som_police_impound` row). Step 4 the ticket goes back on the board after `claimMinutes` ("Tow <PLATE>" again) and is never impounded while T holds it.
- Check: `SELECT state FROM som_vehicles WHERE plate = '<car 1>';` is not `impounded`, `SELECT COUNT(*) FROM som_police_impound WHERE plate = '<car 1>';` is 0 and car 2 has exactly one open row.
- Most likely wrong: that `GetEntityCoords` on the car near the stored position matches within 25 m on a live server, and a driver who holds a ticket past `claimMinutes` losing it once (by design).

**79. Combat log watch** (pair, police optional)
- Needs: two testers L (the one who leaves) and K (to knock L down). Staff moderator M with the console open. Optional `set som_combatlog_webhook` in `server.cfg` for the Discord post.
- Steps:
  1. L is downed by K, then L closes the game (not a relog through the menu).
  2. A different L is cuffed by police P, then closes the game.
  3. A different L stands within 150 m of an open crime call (shoot a gun, `/dispatch` shows the shots call) while an on-duty officer stands within 40 m, then closes the game. Then L quits with none of these.
  4. L repeats step 1 within 5 minutes, then a third time.
  5. M runs `/combatlogs 24` in game and in the console.
- Expect: steps 1 to 3 each write a row, step 3's quit with no signal writes nothing. Step 4 inside 5 minutes does not write a second row for the same character. `/combatlogs` prints lines like `[som-staff] combat log <time> <citizenid> | downed | live x,y,z | <disconnect reason>` in the server console and says "<n> combat logs in 24 hours, listed in the server console" in game. With the webhook set the Discord post carries only the citizenid, the signals and the position and says "repeat x3" once three rows exist in 24 hours. Nothing punishes anyone.
- Check: `SELECT target, detail, created_at FROM som_staff_audit WHERE action = 'combatlog' ORDER BY id DESC LIMIT 5;`. A row ending `saved` instead of `live` means the position was from the last save (soft signals unreliable).
- Most likely wrong: whether the player's ped still exists at the drop (`live` against `saved`), that the disconnect reason arrives, and the radii (150 m, 40 m) against real play. A crash looks the same as a quit; staff judge each one.

**80. Economy watch** (single tester plus an admin with console)
- Needs: to see an alert quickly, set `checkMinutes = 1` and `citizenFaucetLimit = 1000` in `Config.Watch` in `som-economy/shared/config.lua` and `restart som-economy` (the first check runs about 2 minutes later). Optional `set som_economy_webhook "<url>"` in `server.cfg`; without it everything prints to the console.
- Steps:
  1. As admin run `/economyreport 24` in game and in the console.
  2. `/givemoney <B> bank 5000` (an admin faucet row), wait for the next check.
  3. Wait for the same alert again inside 120 minutes.
  4. `/economyreport 999` and `/economyreport 0`.
  5. As a moderator (not admin) try `/economyreport`.
- Expect: step 1 prints a digest: `Economy, last 24 h`, `faucet <n>, sink <m>, ratio <r> (target <t>)`, `treasury <n>`, `top faucets: ...`, `top sinks: ...`, `top earners: <citizenid> <amount> (<reason prefix>), ...`, and a `WARNING: the ratio is outside the target band` line when the ratio is off. Only citizenids, amounts and reason prefixes appear. Step 2 prints `ALERT <citizenid> received 5000 from faucets in 1 min, mostly admin`. Step 3 is not repeated inside the cooldown. Step 4 an hours value outside 1 to 168 falls back to 24. Step 5 is refused. The digest counts only player-facing faucets and sinks (business and treasury rows are left out).
- Check: the digest total for faucets includes the 5000. `SHOW INDEX FROM som_transactions WHERE Key_name = 'idx_time';` has a row. After the test put `Config.Watch` back to `checkMinutes = 60` and `citizenFaucetLimit = 50000`.
- Most likely wrong: a real HTTP post to Discord (only the console path is proven), the hourly loop after a real hour, and the limits ($50000 faucet income and $100000 incoming transfers per character per hour, $250000 for one faucet payment), which are first guesses.

**81. Street racing: dongle, alias and recording a track** (pair)
- Needs: `Config.enabled = true` in `som-racing/shared/config.lua` and `restart som-racing`. Creator A and racer B, both with a car, `/givemoney <id> cash 2000` each. Admin issues the dongles.
- Steps:
  1. Without a dongle A opens Street Racing: it reads "You need a racing dongle".
  2. `/giveracedongle <A> creator` and `/giveracedongle <B> racer`. The admin is told "Issued dongle <uid>" (note the uid; `SELECT uid, tier, status, holder_cid FROM som_race_dongles;` shows them). A `racing_dongle` item is in each inventory.
  3. A opens the app, picks "Pick an alias" and types a 3 to 16 character alias. B does the same, with A's alias, then a different one.
  4. A, sitting in a car, taps "Record a track". Drive a loop of at least 800 m and press Page Up at 6 to 40 points about 40 to 800 m apart. Try Page Up on the spot twice and too far apart, then Page Down before 6 points.
  5. Finish a good loop (the last point within 800 m of the first) and press Page Down. A save dialog asks for a name (4 to 32 characters). Press End on another attempt.
  6. B opens the app and looks at Tracks. B taps "Record a track".
- Expect: step 1 "You need a racing dongle". Step 3 B's duplicate alias says "that alias is taken"; the app then shows the alias under "You" with "Creator dongle" or "Racer dongle". Step 4 shows "Recording a track: N checkpoints, M m. Page Up drops one, Page Down saves, End cancels"; refusals are "too close to the last checkpoint", "too far from the last checkpoint, drop more on the way", "that track is too short", "you need to be in a car"; a sixth saved track says "you have as many tracks as you can keep" (the limit is 5 each). Step 5 the track appears under Tracks with its length. End cancels without saving. Step 6 B sees the track but no Record button.
- Check: `SELECT id, name, length_m, creator_cid FROM som_race_tracks;` and `som_race_aliases` (one alias per character). The console prints `[som-racing] ... dongle <uid>` lines when a dongle is used to host or save.
- Most likely wrong: the recording keys (Page Up, Page Down, End, rebindable in the key settings), the text hint, the save dialog, and a dongle copy: a second character holding a copy of A's item must get "You need a racing dongle" (the first character to use a dongle owns it).

**82. Street racing: host, join with a buy-in, finish order and payout** (pair, three is better)
- Needs: flow 81 done (a saved track). A, B and C with racing dongles and aliases (`/giveracedongle <C> racer`), all with at least $1000 cash, all in cars. Optional police on duty to see the `streetRace` dispatch call (chance 0.25 per race, set `Config.dispatch.chance = 1.0` to force it).
- Steps:
  1. A opens the app, taps the track under Tracks, then "Host on <track>" and types `2 500` (2 laps, $500 buy-in). A must be within 60 m of the start line, in a car.
  2. B and C drive to the start line, open the app and tap the race under "Open races". Try joining from far away, without a car and with under $500 cash.
  3. A taps "Start now". Wait the 5 second countdown and race the two laps. Make B drive the whole track and C cut a checkpoint.
  4. Watch the ring and GPS route. Finish A first, B second.
  5. Reopen the app after the race.
- Expect: step 1 takes $500 cash from A and the app shows "Your race: <name>, 1 racers, $500 each, 2 laps, open". Step 2 from far away says "get to the start line first", on foot "you need to be in a car", short of cash "you need $500 on you". Step 3 with fewer than two racers the start says "a race needs two racers"; with two or more it counts down 5 seconds and shows the checkpoint ring. Cutting a checkpoint (more than 90 m/s between rings, or a skipped ring) is refused, and after 5 refused reports the racer is out ("You are out of the race"). Step 4 finishers see "Finished in place N"; the pot (stakes of everyone who joined) is split 70 and 30 for two finishers (100 for one, 55/30/15 for three, 50/30/15/5 for four) and paid as cash with "Race money: $N". The rest finish within 90 seconds after the first.
- Check: `SELECT race_id, citizenid, stake, state, owed, position, total_ms FROM som_race_entries ORDER BY id DESC LIMIT 6;` shows `paid` with the positions. `som_race_times` has each racer's best time for the track. `som_transactions` has `street-race` debits for each buy-in and credits for the winnings, cash account, nothing minted: the winners' credits add up to the buy-ins. A winner who is offline when the race ends is paid when they next open the app.
- Most likely wrong: the checkpoint ring (`DrawMarker` type 1), the GPS route, the 12 m ring and 10 m slack against real tracks, the server judging checkpoints from the car position, and the countdown.

**83. Street racing: cancel refund and void dongle** (pair)
- Needs: flow 81 done.
- Steps:
  1. A hosts a race with a $500 buy-in. B joins. Then B taps "Leave race" before it starts.
  2. A taps "Cancel race" before it starts (B joined again first).
  3. Host again, join with B, and `restart som-racing` in the console while the race is open.
  4. Void B's dongle: `/voidracedongle <uid of B's dongle>`. B opens the app and tries to join or host.
  5. A tries to host a second race while one is open, and B tries to join two.
- Expect: step 1 B's $500 is returned at once. Step 2 everyone's stakes are returned and the race disappears. Step 3 the restart cancels every open or running race and refunds the held stakes the same way. Step 4 the command says "Voided"; B's app reads "You need a racing dongle" and joining or hosting is refused, even though the item is still in the bag. Step 5 says "you cannot open another race right now" and "you are already in a race".
- Check: `SELECT status FROM som_races ORDER BY id DESC LIMIT 4;` shows `cancelled`. Cash totals before the race equal after it. `SELECT status FROM som_race_dongles WHERE uid = '<uid>';` is `void`. The console must never print `[som-racing] MONEY LOST`.
- Most likely wrong: a crash between taking a buy-in and marking it held (it prints `MONEY LOST` and does not refund), so watch for that line.

**84. House burglary at night** (pair, police)
- Needs: the clock and the placement work first.
  - `/place som-burglary houses.house_1.coords` at a house door, then give the shell a search spot. Spots cannot be placed: edit `som-burglary/shared/config.lua` and put two spots at the shell's doorway so they are always reachable on a first pass: `shell_frankaunt = { spots = { { offset = vec3(-0.36, -5.89, 1.7), label = 'Search the drawers' }, { offset = vec3(-0.36, -5.89, 1.7), label = 'Search the wardrobe' } } }` (the offset is the doorway position from `som-housing/shared/shells.lua`; real spots are an owner decision). `restart som-burglary`. If `/place som-burglary` answers "unknown resource", see setup step 4.
  - `/place som-outdoors buyers.fence.coords` at the fence, `restart som-outdoors`, treasury seeded.
  - Burglar A (leader) and B in a group (Groups app, flow 9). `/giveitem <A> lockpick 3`. Police P `/setjob <P> police 1` on duty. Admin sets the hour: `/settime 12` then later `/settime 23`.
  - To make the neighbour call certain set `noise = { fail = 25, search = 8, run = 3, runSpeed = 4.5, perPoint = 1.0, maxChance = 1.0 }` in the config and `restart som-burglary` for step 7 only.
- Steps:
  1. At noon (`/settime 12`) the leader queues "House burglary" in the Jobs app. Then `/settime 23` and queue again. Queue without a lockpick, and with no police on duty.
  2. At the door pick "Pick the lock". Complete the lock puzzle, or fail it twice.
  3. After success pick "Go inside". Inside look at the two search options.
  4. Pick "Search the drawers" and let the bar (8 seconds) finish. Try to search it again, and try to finish earlier than 8 seconds.
  5. Search the second spot. The job ends. On a separate run pick "Leave" before searching anything.
  6. Try the same house again straight away, and again after the cooldown (2 hours; shorten by `UPDATE som_burglary_runs SET created_at = NOW() - INTERVAL 3 HOUR WHERE house = 'house_1';`).
  7. Run inside past 4.5 m/s, fail a pick, or search to raise the noise.
  8. Sell the loot at the fence ("Sell: Fence").
- Expect: step 1 at noon the Jobs app says "wait for dark"; at 23:00 it starts; with no `lockpick` "the leader needs lockpick"; with no police "the city is too quiet for this"; with the house unplaced or no spots "no houses are open yet". The night window is 22:00 to 05:00 game time (7 game hours, 14 real minutes of every 48). Step 2 a won puzzle opens the door; two failures end the run ("the lock beat you and the street is awake"); each failure can break the pick (30 percent). Step 3 you are inside the shell in its own bucket (40000 and up) and the leave option is next to you. Step 4 takes 8 seconds and gives 1 roll from the loot table (low house: silver ring, silver chain, gold ring, tablet, laptop); a second try says "there is nothing left here"; a finish under 8 seconds says "you were too quick". Step 5 the last spot ends the run as done. Step 6 straight away the contract does not start (the house is cooling down; with a second placed house it would pick that one), and works after the cooldown. Step 7 with the raised chance police get a "burglary" call (a neighbour reports someone breaking in at <house label>) on `/dispatch`, once per run. Step 8 the fence pays the market price for the item (silver ring, silver chain, gold ring, gold chain, diamond ring, rolex, laptop, tablet), capped at $3000 an hour, from the treasury.
- Check: `SELECT id, house, status FROM som_burglary_runs ORDER BY id DESC LIMIT 3;` (`active`, `done` or `failed`) and `SELECT run_id, spot FROM som_burglary_loot ORDER BY run_id DESC LIMIT 4;` (one row per looted spot, the spot cannot repeat). Put `perPoint` and `maxChance` back afterwards.
- Most likely wrong: entering the shell and the arrival offset on a real client, being stuck in the void if a player disconnects inside (the saved position would be the shell), the lock puzzle started from this resource, the sampled running speed, and whether the 8 second bar feels right.

#### Restaurants (flows 85 to 87)

Setup for the three flows: place Burger Shot (setup step 4 first). Stand at the counter and run `/place som-restaurants restaurants.burgershot.coords`, then at each station `restaurants.burgershot.stations.prep.coords`, `.grill.coords`, `.fryer.coords`, `.drinks.coords`, `.assemble.coords`, the self-serve machine `restaurants.burgershot.selfServe.coords`, the fridge `restaurants.burgershot.fridge.coords` and the wholesaler `supplier.coords` (placing a point switches it on, so the separate `supplier.enabled` is not needed), then `restart som-restaurants`. The restaurant bank account `REST-BURGERSHOT` starts at 0 and the wholesaler is paid from it, so there is no way to buy ingredients until it holds money: on the beta server seed it with `UPDATE som_bank_accounts SET balance = 5000 WHERE account_no = 'REST-BURGERSHOT';` (see the bug list at the end of this round). Owner O is unemployed with `/givemoney <O> bank 200000`; crew W and customer C have bank balances. The `burgershot` job is not whitelisted and has four grades: Crew 120, Cook 160, Manager 200, Owner (an hour, paid by taking money out).

**85. Restaurants: buy, hire and the wholesaler** (pair)
- Steps:
  1. O stands at the counter, uses "Burger Shot" and picks "Buy this restaurant for $150000" and confirms. Try buying with a whitelisted job such as police first, and try to buy a second time.
  2. O stands next to W and picks "Hire the person next to you" (the owner can hire and withdraw without being on duty). W accepts the dialog "You are offered a job here. The pay comes with the normal paycheck." Try hiring W again, a hire with W far away, and more than 6 staff.
  3. O clocks in (Clock in or out), or W is on duty, then opens the Supplier and buys `frozenmeat` x2, `bread`, `tomato`, `cheddar`, `sauce` for a Big King. Try more than 20 in one purchase.
  4. O takes $500 out with "Take money out", then $500 again at once, then more than $3000.
  5. O lets W go with "Let the person next to you go". An admin sets O to unemployed (`/setjob <O> unemployed`) and O walks back to the counter.
- Expect: step 1 takes $150000 from O's bank into the treasury and O becomes Owner (a police officer says "leave your current job first"; a second purchase says "this restaurant is not for sale, or you already own one"). Step 2 a hire needs W within 5 m ("they need to be next to you"), W with another job says "they have a job they would have to leave first", an extra hire past 6 says "you have all the staff you can have". Step 3 each purchase is paid from the restaurant account into the treasury ("the restaurant account cannot pay for that" when it is empty); more than 20 is "bad request". Step 4 the second withdrawal says "you took money out recently, try again later" (30 minutes), over $3000 says "you can take $1 to $3000 at a time", and money owed on unserved orders cannot be withdrawn ("that money is needed for unserved orders"). Step 5 W is jobless, and after the admin change the counter offers O "Go back to work here" (O still owns the restaurant).
- Check: `SELECT restaurant_id, owner FROM som_restaurants;` shows O. `som_transactions` rows `restaurant:buy:burgershot` (O debit, treasury credit), `restaurant:supplier:burgershot` (restaurant debit, treasury credit) and `restaurant:withdraw:burgershot` style rows for the withdrawal.
- Most likely wrong: the interact zones and menus on a real client, the stash (the fridge opens an ox_inventory stash `restaurant_burgershot`), and a boss who quits the job still owning the restaurant.

**86. Restaurants: cook, take an order, pay and serve** (pair)
- Needs: flow 85 done, O (or W) on duty at the restaurant with the ingredients from the wholesaler, customer C standing at the counter with enough bank balance, and nobody else on a competing station.
- Steps:
  1. At the prep station pick "Thaw and shape meat" (4 seconds), at the grill "Grill a patty" twice (8 seconds each), at the fryer "Fry big fries", at the drinks "Pour a big cola", at the assemble station "Assemble a Big King". Cancel one bar halfway and start again. Try cooking with missing ingredients.
  2. The cashier stands next to C and picks "Take an order", adds Big King x1 and Big Fries x1, and picks "Send the order (2 lines)".
  3. C accepts the dialog (the total is $28 + $9 = $37). Try declining another one, and answering after 60 seconds.
  4. The cashier sees "Ticket <n>" with the items and picks it to hand it over.
  5. Repeat the order with the cashier missing one of the dishes, and with C standing far from the counter.
- Expect: step 1 each station shows only its own recipes (prep: Thaw and shape meat; grill: Grill a patty; fryer: Fry big fries and Fry small fries; drinks: Pour a big cola, Pour a small cola, Make a coffee; assemble: Assemble a Big King, Assemble a Bleeder). A cancelled bar keeps the ingredients; a finished one swaps them for the dish; missing ingredients say "you are missing ingredients". Step 3 takes $37 from C's bank into the restaurant account, and a stale or declined offer says "that order is gone". Step 4 hands the food to C and the restaurant pays 8 percent tax of the order to the treasury; "you do not have everything for that order" or "the customer is not at the counter" or "they cannot carry all that" otherwise.
- Check: `SELECT id, state, total FROM som_restaurant_orders ORDER BY id DESC LIMIT 3;` (`offered`, `paid`, `served`). `som_transactions` has `restaurant:sale:burgershot` (C debit, restaurant credit) and `restaurant:tax:burgershot` (restaurant debit, treasury credit). Eating the food gives the status values in `Config.ItemStatus` (Big King hunger 45 and stress -3, Bleeder 35 and -2).
- Most likely wrong: the cook animation and progress bar, the dish props and eating animations on the existing burgershot items, a missing icon for `burgershot_patty` (it reuses the meat icon), and an order stuck in `paying` after a crash (staff fix by hand from the customer's bank ledger).

**87. Restaurants: the 15 minute refund and self-serve** (pair)
- Needs: flow 86 done up to step 3 (a paid order not served) and the restaurant account holding enough to refund it.
- Steps:
  1. C pays an order and the cashier does not serve it. Make 15 minutes pass quickly: `UPDATE som_restaurant_orders SET paid_at = NOW() - INTERVAL 16 MINUTE WHERE id = <order>;` and wait up to one minute (the refund tick is 60 seconds).
  2. Empty the restaurant account and repeat step 1: `UPDATE som_bank_accounts SET balance = 0 WHERE account_no = 'REST-BURGERSHOT';` then refill it.
  3. Everyone goes off duty (Clock in or out) and C walks to the self-serve machine.
  4. C picks "Self-serve" and buys a burger, then tries while a staff member is on duty.
- Expect: step 1 the order becomes `refunded`, the customer gets "Your $<n> order was never served and has been refunded" and the bank credit (also when C is offline). Step 2 with an empty account the order stays `paid` and is retried every minute; it is refunded once the account holds the money. Step 3 the counter reads "Nobody is working. Self-serve food is available at the machine". Step 4 the machine sells burger $32, sandwich $26, cola $14, water $10 (at most 3 at a time) and pays the treasury, so the restaurant earns nothing; with a staff member on duty it says "the kitchen is open, order at the counter".
- Check: `som_transactions` rows `restaurant:order_refund:burgershot` (restaurant debit, customer credit). `SELECT state FROM som_restaurant_orders WHERE id = <order>;` is `refunded`. The self-serve sale debits C and credits the treasury (reason `restaurant:selfserve:burgershot` style).
- Most likely wrong: an owner who pays out wages leaving a refund waiting, the offline refund path (`creditCitizen`), and the self-serve machine zone on a real client.

**88. Game clock: set, freeze and persist** (admin, then moderator)
- Needs: nothing else. Console access helps.
- Steps:
  1. `/gametime` as a moderator. Note the HUD clock.
  2. As admin run `/settime 23 30`. Check the HUD and the sky. Then run `/settime 24`, `/settime 7 61` and `/settime x`.
  3. `/freezetime` with no arguments. Wait a real minute and read the HUD and `/gametime`. Run `/freezetime` again.
  4. `/freezetime 4 15` (freezes at a named time), then `/settime 9` while frozen.
  5. As a moderator or a plain player try `/settime 12` and `/freezetime`.
  6. Restart the whole FXServer (not one resource, everything depends on `som-core`) and read `/gametime` again.
  7. Optional: put `set som_clock_freeze "22:00"` in `som.cfg`, restart, and check the HUD shows 22:00 and does not move. Then try a bad value such as `noon`.
- Expect: step 2 the HUD jumps to 23:30 for every connected player within a few seconds and keeps running (30 game minutes per real minute); invalid input is refused with "Use /settime <hour 0-23> [minute 0-59]". Step 3 frozen shows "Game time is frozen at HH:MM" and `/gametime` says `(frozen)` with a time that does not move; the second `/freezetime` says "Game time runs again" and carries on from the held time. Step 4 `/freezetime 4 15` freezes at 04:15; `/settime 9` while frozen moves the frozen time to 09:00 and stays frozen. Step 5 is refused with "You do not have permission to do that". Step 6 after a restart the time is back on the config schedule (a pure function of the real clock and `Config.Clock`), not where staff left it. Step 7 a bad convar prints `som_clock_freeze "noon" is not HH:MM, the clock runs` in the console.
- Check: the console prints `[som-core] game time set to 23:30 by <name>` and `game time frozen at ...`. Nothing is written to the database.
- Most likely wrong: `NetworkOverrideClockMillisecondsPerGameMinute` with 99999999 for a freeze (the sky must not creep), and any other resource that sets the clock (vMenu time sync, a weather resource, an admin menu): the clock then flickers, so only one controller may exist.

**89. Game clock: two clients agree, and the character select scene is unaffected** (pair)
- Needs: two testers on two real clients, one of them able to relog. `/settime 20 0` as admin first.
- Steps:
  1. Both testers stand still in game. Compare the HUD clock on both screens at the same moment, then again after a real minute and after 5 minutes. Look at the sky, not only the numbers.
  2. One tester relogs (leaves and reconnects). Watch the character select scene, then pick the character and spawn.
  3. While one tester sits at character select run `/settime 3` as admin.
  4. Walk through the first minute after spawn: watch the HUD clock and the sky for jumps.
  5. Both open `/gametime` (as moderators) at the same instant and compare it with the HUD.
- Expect: step 1 the two HUD clocks agree to within a minute (the client uses `GetCloudTimeAsInt` while the server uses `os.time`, so a second or two can differ) and move at the same speed. Step 2 the character select scene keeps its own fixed lighting (20:15, clear weather) for as long as the player is on that screen; at spawn the sky changes to the server's time once and then follows it. Step 3 the player at character select does not see the change until they spawn. Step 4 one correction at spawn is expected. After that the client re-applies the same time every 15 seconds, which must not be visible as a jump. Step 5 server and HUD agree.
- Check: `/gametime` for the server value; the console shows no client error from `som-core`.
- Most likely wrong: the 15 second resync colliding with the scene on a real client, the clock jumping backwards at spawn, and drift between clients over a long session.

**90. The four new icons** (one tester, owner accepts the art)
- Needs: `/giveitem <id> deer_pelt 1`, `/giveitem <id> noscan 1`, `/giveitem <id> rollcage 1` and `/giveitem <id> externals 1` (the "Exterior Cosmetics" item uses `mirror.png`).
- Steps: open the inventory and look at each item at normal size, in the hotbar and in the tooltip. Then skin a deer (flow 14) and look at the pelt there.
- Expect: Deer Pelt, Empty NOS Bottle, Roll Cage and Exterior Cosmetics each show a clear, realistic picture in the same style as the rest of the inventory (no star badges on the pelt). No broken image placeholder.
- Check: the owner accepts or rejects each icon; a rejected one goes back to the icon list in `LAUNCH-TODO.md`. `python3 tools/check-item-icons.py` lists items still without an icon.
- Most likely wrong: an icon that looks fine large but unreadable at the hotbar size, and the `externals` item showing a mirror when it is a set of cosmetics.

**91. Boot health, round three**
- Steps: `somhealth` and the smoke test after a full restart of the server (not just a resource); read the console for `som-tow`, `som-restaurants`, `som-racing`, `som-burglary`, `som-fire`, `som-news`, `som-insurance`, `som-welcome` and `som-boosting`. Then repeat flows 69 to 90 once after the restart to prove nothing was only in memory.
- Expect: no FAIL lines, the 18 tables present, `insurer`, `weazel`, `fire`, `burgershot` in `som_businesses`, the placements still applied (`/places`), and the game time on schedule. Things that are in memory by design and reset on a restart: mining vein rests and the 40 strikes an hour, fire spray counts, fire payout draws, the staff `/settime` and `/freezetime`, and open races (cancelled with refunds).

### Bugs and mismatches found while writing round three

Read from the code, not fixed here. The first three block the setup steps above.

1. **`/place` refuses `som-restaurants` and `som-burglary`.** `Config.placeable` and `placeableList` in `som-staff/shared/config.lua` lack both resources, so the `LAUNCH-TODO.md` instructions for them ("Player-run restaurants", "House burglary") answer "unknown resource". Workaround in setup step 4.
2. **Mining nodes cannot be placed with `/place`.** `/place som-outdoors mining.sites.copper_1.nodes+` ends in the field `nodes`, which is not in `POINT_FIELDS` in `som-staff/server/placements.lua`, so it answers "this field cannot be placed". The `SomPlacements.ApplyOne` side accepts it (a test covers only that half). Workaround: edit `nodes` by hand.
3. **Restaurants cannot buy their first ingredients.** The wholesaler is paid from the restaurant's own account (`som-restaurants/server/kitchen.lua`), the account starts at 0 and there is no deposit path, so a freshly bought restaurant cannot stock until something pays into `REST-BURGERSHOT`. Workaround: the SQL seed in the restaurants setup. A real fix needs a deposit (or an opening float).
4. **`som_economy_webhook` is documented only in `LAUNCH-TODO.md`.** It is missing from `server.cfg.example` and `DISCORD_WEBHOOKS.md`, so the owner cannot find it where the other webhooks are listed.
5. **`LAUNCH-TODO.md` restaurant line says to set `supplier.enabled = true`.** Placing `supplier.coords` already switches it on (`SomPlacements.ApplyOne`), so the extra step is harmless but unnecessary.
6. **Burglary spots cannot be placed.** `Config.shells.<model>.spots` has no placement path and no tool records offsets inside a shell, so a house cannot be picked until an owner decision supplies offsets. Flow 84 uses the doorway as a stand-in for a first test only.

## After the session
Fix in small branches, one logical fix each, merge as a batch (see CLAUDE.md). Add every bug's regression test to `tests/run.lua` before closing it, and tick or add lines in `LAUNCH-TODO.md`.
