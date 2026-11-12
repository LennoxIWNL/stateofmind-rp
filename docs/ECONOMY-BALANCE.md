# Economy balance sheet

Built from the real configs on `chore/economy-balance` (the full jobs and services update). Every number comes from a
config file named in the tables; every estimate says what it assumed. This is a launch audit, not a simulation: nothing
here was measured in a game. Where a config is still empty (routes, spots, coordinates) the figure is a bound taken
from the caps, and says so.

`ECONOMY-MAP.md` (generated) covers where every item comes from and goes. This file covers money.

## 1. Reading this sheet

- All figures are dollars per hour of play for one player, rounded. "Gross" is before the player's own costs, "net"
  after bait, seeds, fuel and similar.
- Paychecks are HOURLY (`Config.Money.paycheckInterval = 60`, `som-core/shared/config.lua`), only while on duty, paid
  from the job's business account, and capped at `maxHourlyPaycheck = 5000`. The older comment in
  `som-economy/shared/config.lua` that talks about 10 minute paychecks is stale and now says so.
- Assumed efficiency: a player works about 70 percent of the hour at the theoretical rate. Where the code enforces a
  minimum time (swing, cook, grow) the code number is used.
- Driving assumptions: city speed 12 m/s (43 km/h), a taxi loaded 55 percent of the time, a courier run (pickup plus
  three drops) 12 minutes, a fishing cast 22 seconds (average 14 second bite plus cast and reel), a theft contract
  20 minutes. These are the softest inputs and the first to re-measure in game.
- Wash: marked bills lose 30 percent at the front, 20000 face value a day per character, 40000 an hour for all fronts
  (`som-launder`). Marked bills are minted; the wash is the faucet.
- "Legal reference" below is the median of the typical legal solo figures in section 3: about **$1,400 an hour**.
  "Twice the median" is therefore about $2,800.

## 2. Paychecks (retainers, on duty only)

From `som-core/shared/jobs.lua`. A grade list is lowest to highest, dollars an hour.

| Job | Grades | Paid from | Account opens with | Funding rule |
|---|---|---|---|---|
| Unemployed | 150 | minted (no business) | n/a | `offDutyPay = true`: paid whether or not anyone is playing it |
| Police | 1200, 1600, 2000, 2400, 2900, 3500, 4200 | lspd | 750,000 | fines (70 percent of each) and impound fees |
| Dispatcher | 1500, 2200, 2800 | lspd | shared with police | as above |
| Ambulance | 1200, 1800, 2400, 3200, 4200 | ems | 500,000 | treasury funded, nothing calls the top-up for EMS |
| Fire | 1200, 1700, 2200, 2900, 3800 | fire | 100,000 | treasury top-up, at most 4000 an hour server wide |
| Judge / Prosecutor / Defender | 1400 to 5200 / 2400 to 4500 / 2000 to 3800 | doj | 300,000 | fines |
| Mechanic | 250, 300, 380, 450 | lscustoms | 150,000 | repairs billed to the shop plus trade sales |
| Car dealer | 200, 250, 300, 350 | pdm | 250,000 | sales |
| Realtor | 200, 250, 320, 400 | dynasty8 | 200,000 | mortgage deposits and instalments |
| Taxi | 250, 300, 400 | downtowncab | 100,000 | 80 percent of every fare |
| Delivery | 250, 300, 400 | postop | 100,000 | nothing flows in (see outlier 7) |
| News | 150, 200, 250 | weazel | 0 | nothing flows in: wages never pay |
| Burger Shot | 200, 260, 320, owner 0 | burgershot | 0 | the restaurant's own takings |
| Tow | 0 | n/a | n/a | 400 a tow from lspd |

Sustainability of the opening floats, at an assumed staff on duty and average grade wage:

| Account | Float | Assumed staff and wage | Hours of payroll it holds |
|---|---|---|---|
| lspd | 750,000 | 8 at 2000 | 47 |
| ems | 500,000 | 5 at 2000 | 50 |
| doj | 300,000 | 5 at 3000 | 20 |
| fire | 100,000 | 4 at 1700 | 15 (plus 4000 an hour treasury top-up while the treasury has it) |
| postop | 100,000 | 4 crews drawing job pay | about 14 at the courier rate in section 3 |
| downtowncab, lscustoms, pdm | 100,000, 150,000, 250,000 | small crews | 100 to 500, and they earn income |

The floats are minted at database creation: 2,450,000 in total. Nothing refills the public ones except fines and fees,
so payroll quietly stops once a float is gone (`PayCheck` only prints in debug).

## 3. What a player earns

Typical = realistic solo per hour. Crew = per person when the config splits or multiplies pay. Payer says which account
the money leaves, and whether that account can hold it.

### Legal work

| Activity | Typical solo | Crew each | What limits it | Pays from |
|---|---|---|---|---|
| Unemployed paycheck | 150 | 150 | nothing: AFK works | minted |
| Restaurant crew (new) | 200 | 200 | the restaurant's takings | restaurant account |
| News | 400 (cap 600) | same | 600 an hour per reporter, 3000 network, 120 s between stories | treasury (0 at launch) |
| Mechanic | 350 | n/a | wage plus 12 percent of a trade (a 450 kit pays 54) | lscustoms |
| Taxi | 560 gross, about 110 net of fuel | n/a | wage 250 plus 20 percent of fares (about 310) capped 1500 an hour | downtowncab |
| Garbage | 1,200 (cap 2000) | pool split by bags | 12 a bag, 2000 an hour per person, 150,000 a month for the whole city | sanitation, topped up from treasury |
| Tow | 1,200 (cap 2400) | n/a | 400 a tow, 6 paid tows an hour, only player cars | lspd |
| Hunting | 1,500 | n/a | about 5 animals an hour at 307 a deer, buyer cap | treasury via buyer |
| Courier | 2,050 (1800 plus wage 250) | 2,050 | 360 a run, no split, new cap 2000 an hour | postop |
| Trucking | 2,250 (cap 2500 plus wage) | split plus 20 percent group bonus | route `base` unplaced, cap 2500 an hour | postop |
| Mining, copper or iron | 1,300 to 1,600 | plus 1 ore per strike with a partner | 40 strikes an hour, vein rests 600 s | treasury via quarry buyer |
| Mining, silver | 1,400 | 2,800 with a partner | as above | as above |
| Mining, gold | 2,400 | 4,800 with a partner | as above | as above |
| Fishing | 4,300 net (cap 6000 gross) | shares the cap | 59 expected a catch, bait 15, no per-person cap | treasury via buyer |
| Fire | 960 plus wage 1200 | split per flame | 40 a flame, 1500 an hour per person | fire |
| Ambulance | wage 1200 to 4200 plus 150 a transport | n/a | no cap on transports, patient pays 250 | ems |
| Police, dispatch, courts | wage only | n/a | wage is paid on duty with no activity needed | lspd, doj |
| Car dealer sale | 8 percent of price | n/a | a 31,000 car pays 2,480, a 105,000 car 8,400 | pdm |
| Realtor sale | 3 or 5 percent of price | n/a | a 185,000 house pays 5,550 to 9,250, the 1,450,000 villa up to 72,500 | dynasty8 |

Median of the typical legal figures above (16 values from 150 to 4,300): about 1,400 an hour.

### Crime

| Activity | Typical solo (clean) | Crew each | What limits it | Pays from |
|---|---|---|---|---|
| Weed, a strain of 60 to 80 | 450 to 640 | solo | 6 plants, 60 minute grow, 90 a bag face, after wash 70 percent | minted bills |
| Weed, OG Kush (seed 200) and Amnesia (seed 300) | negative | n/a | seed costs more than 1.5 to 2.2 bags at about 100 | n/a |
| Coke chain | 1,340 | solo | 270 of inputs make 2,640 face, one lab, 65 minutes a brick | minted bills |
| Meth chain | negative (-83 a cook) | solo | 650 of inputs make 900 face before saturation | minted bills |
| Car theft contract C | 2,100 (3 an hour) | 1,000 a contract face | police min 1, 4 bills at 250 | minted bills |
| Car theft contract B | 1,700 each, crew of 3 | split | police min 2, 6 bills at 400 | minted bills |
| Chop shop | 860 (3 a hour) to 1,720 (6) | n/a | 287 of parts a car, scrap buyer cap | treasury via buyer |
| Burglary, low house | 87 a search | n/a | spots unplaced, 120 minute cooldown | fence market |
| Burglary, high house | 224 a search | n/a | spots unplaced, 240 minute cooldown | fence market |
| Store heist | 1,150 each, crew of 2 | 2,300 for the crew a hour at one site | police min 1, 45 minute site cooldown, 1,300 clean plus 600 face | treasury plus minted bills |
| Bank heist | 1,500 to 2,900 each | split of 8,800 a run | police min 3, 90 minute site cooldown | treasury plus minted bills |
| Vault heist | 1,000 to 1,950 each | split of 23,400 a run | police min 5, 240 minute site cooldown | treasury plus minted bills |
| Chain of all three sites | 5,600 to 11,000 each for a crew of 3 to 6 | | about 65 minutes for 33,900 | |
| Racing | zero sum | | pots are the entry stakes, 0 to 25,000 each | players |
| Fence (burglary loot) | capped 3000 an hour | | market price falls with each unit | treasury via market |
| Wash cap | 14,000 a day clean per character | | 20000 face a day | minted |

## 4. What a player pays (sinks)

| Sink | Cost | Source |
|---|---|---|
| Fuel | 4 a litre, 100 litre tank. Driving burns 0.012 plus 0.0016 per m/s of speed each second: 43 litres an hour idling, 112 at city speed (about $450 an hour), 158 at 20 m/s ($630 an hour) | `som-fuel` |
| Jerry can | 120 for 25 litres | `som-fuel` |
| Vehicles | 6,000 to 105,000, median 31,000 (74 models) | `som-garage/shared/catalogue.lua` |
| Properties | 48,000 trailer, 72,000 and 95,000 starter, 185,000 and 210,000 standard, 1,450,000 luxury, 120,000 and 460,000 warehouses | `som-housing` |
| Mortgage | 15 percent deposit, flat 12 percent on the rest, 4 to 26 weekly instalments | `som-housing` |
| Rent | at least 100 a week, at most 2 percent of price a week | `som-housing` |
| Insurance | 1 percent of purchase price a week (min 25), excess 10 percent (min 250), payout is a replacement car at 80 percent | `som-insurance` |
| Fines | presets 250 to 7,500, free text 50 to 25,000, 30 percent to the treasury and 70 percent to the department | `som-police`, `som-economy` |
| Impound release | 2,500 | `som-police` |
| Bail | 50 a second of remaining sentence, minimum 2,500 | `som-jail` |
| Hospital | respawn 350, treatment bill 600, admission fee 250 | `som-medical`, `som-ems` |
| Licences | driver school 400, weapon licence 5,000 | `som-licences` |
| DMV | registration 150 every 14 days, vanity plate 2,500 | `som-dmv` |
| Loans | flat 10 percent fee whatever the term | `som-loans` |
| Shop prices | burger 10 to 15, water 10, cola 10, bandage 5, medikit 26, pistol 1,000, knife 200 | `ox_inventory/data/shops.lua` |
| Tools | pickaxe 150, fishing rod 120, hunting knife 150, hammer 80, screwdriver set 60, lockpick 10 | same |
| Mechanic repairs | engine 250, body 180 plus a kit or steel | `som-mechanic` |
| Taxes | 8 percent of business revenue to the treasury | `som-economy` |
| Car sales between players | 5 percent of price | `som-carsales` |
| Restaurants | supplier 1 to 10 an item, menu 4 to 28, self-serve 10 to 32 | `som-restaurants` |

## 5. Which faucet pays from where, and can that account hold it

| Faucet | Pays from | Opens with | Can it pay on day one |
|---|---|---|---|
| Buyers (fish, scrap, quarry, hunt) and fence | treasury, 6,000 an hour per buyer for all players together, 3,000 for the fence | treasury 0 | No. Nothing is paid until taxes and fines have filled the treasury |
| Heist clean cash | treasury, per tier an hour (4,000, 12,000, 25,000) | 0 | No clean cash; marked bills still mint |
| Welcome payment | treasury, 1,000 each, 2,000 a day, 20,000 a month | 0 | No |
| News stories | treasury, 3,000 an hour | 0 | No |
| Loans | treasury, only while it holds 50,000, 100,000 outstanding | 0 | No |
| Fire and sanitation top-ups | treasury | 0 | No, until funded |
| Wages | business accounts | floats in section 2 | Yes for about 15 to 50 hours, then no |
| Courier and trucking | postop, no inflow | 100,000 | About 14 hours at a crew's pace, then "the company could not pay" |
| Tow | lspd | 750,000 | Yes |
| Marked bill wash | minted at the front | n/a | Yes (this is the designed faucet) |
| Unemployed paycheck | minted | n/a | Yes, always |
| Dealer and realtor commission | pdm and dynasty8 | 250,000 and 200,000 | Yes, but two luxury sales empty dynasty8 |

Treasury inflows are taxes (8 percent of business revenue), 30 percent of fines, shop and restaurant purchase prices,
the supplier, self-serve, licence fees, insurance payouts and the driver school. None of them produces much before the
first day of play. Total opening money minted into accounts: 2,450,000.

## 6. Outliers

Numbers refer to the owner decisions in section 8.

1. **The treasury starts at 0 while the city is promised as the payer.** Fish, scrap, quarry, hunt and fence buyers,
   heist clean cash, the welcome payment, news and loans all pay from it. On day one every one of them answers
   "the city cannot pay right now" while the public floats hold 2.45 million. Decision A.
2. **Public wages.** Police, EMS, fire and court wages (1,200 to 5,200) are 3 to 10 times the civilian service wages
   (250 to 450) and sit at or above the legal median, and they are paid on duty with no activity needed. They are
   whitelisted, which limits exposure, but a cadet on a desk earns 1,200 an hour for nothing. Their floats run out in
   15 to 50 hours. Decision B.
3. **AFK pay.** Unemployed characters are paid 150 an hour whether or not they move (`offDutyPay`), minted, with no cap.
   One account is 3,600 a day; 20 idle accounts are 72,000 a day. Decision C.
4. **Fishing.** About 4,300 an hour net for one person, 3.1 times the median, legal, no interaction and no police risk.
   The only limit is the fish buyer's 6,000 an hour, which one person can use alone. Decision D.
5. **Mining gold.** 2,400 an hour solo and 4,800 with a partner who carries a pickaxe, 1.7 to 3.4 times the median,
   legal, no interaction. Decision D.
6. **Buyer caps are shared by everyone.** Each buyer pays at most 6,000 an hour in total (`som_buyer_payouts` is
   per buyer, not per person). With four people at one buyer each earns under 1,500; with ten under 600, which is
   less than the courier pays. The cap makes gathering not worth doing once the
   server is busy. Decision D.
7. **Post OP cannot fund its work.** Courier and trucking pay from the `postop` account, which funds by sales and
   nothing sells. The 100,000 float is gone in about 14 hours at a crew's pace and then both jobs stop paying.
   Courier pays every crew member the full drop pay (a crew of 4 costs the company 4 times); it had no cap (fixed,
   see section 7). Decision E.
8. **Fuel is the biggest sink and it outweighs the entry wage.** An hour of city driving burns about 112 litres, $450
   at 4 a litre; a full tank is 55 minutes. A taxi driver nets about 110 an hour after fuel. Decision F.
9. **Heist peak.** One crew chaining store, bank and vault takes 33,900 in about 65 minutes, 5,600 to 11,000 each,
   4 to 8 times the median, against the design rule of 1.5 to 2 times. Per site cooldown and police minimums (1, 3
   and 5) are the real limiters, and the clean cash has no wash cut or daily cap. Decision G.
10. **Meth loses money.** 650 of chemicals make 5 meth, face 900 before the price drops and 630 after the wash,
    so a cook loses about 20 to 80. The coke chain next to it makes 2,640 from 270. High tier weed loses money too:
    OG Kush and Amnesia seeds (200 and 300) grow into 1.5 to 2.2 bags worth about 100 each, and cost more than they
    return. Decision H.
11. **Per sale commissions.** A dealer earns 8 percent of price and an agent up to 5 percent; the villa pays 72,500
    from a 200,000 account. Colluding with an alt costs the pair, so this is not a loop, but it empties the float and
    makes one lucky sale worth a day of anything else. Decision I.
12. **Garbage runs out mid month.** `monthlyBudget = 150000` for the whole city is 75 worker hours at the personal
    cap, about 125 at the realistic rate. After that "the city cannot pay this round". Decision J.
13. **Taxi pays the driver the least of any money in the ride.** The passenger pays 20 plus 60 a kilometre; the driver
    keeps 20 percent, the company keeps 80 percent, and nothing in the company spends it. Decision K.
14. **The armoury charges officers more than the shop.** Officers pay 2,500 for a pistol and 45 a cartridge; the store
    sells both for 1,000 and 5 to anyone with a licence. No loop (neither buys back), but an officer will use the store.
    Decision L.
15. **Stale target.** The scale comment in `som-economy` assumed a 10 minute paycheck and an entry wage of 2.4k an hour.
    Real entry wages are 150 to 450 an hour and the real money is per task. The cheapest house (48,000) is also far
    under the 200,000 the comment calls the anchor. Comment corrected; numbers are Decision M.

### Loop and cap checks that came out clean

- Buy low, sell high: no item is sold by a shop for less than any buyer pays, including the market at its ceiling
  (base times 1.4) and turf sales at the owner bonus. `node tools/economy-map.mjs --check` now fails if one appears.
- Mechanic trades pay the shop account, not the seller (the seller gets 12 percent from it), and loans, insurance,
  mortgages, car sales and racing are all zero sum or a net cost to a colluding pair.
- Faucets with a cap: buyers, fence, heist clean cash per tier, wash per citizen and per hour, taxi commission,
  tow (6 paid an hour), garbage, trucking, fire, news, mining strikes, welcome, loans. Faucets with no cap of their own:
  the unemployed wage, EMS transport pay (150 each, zero sum with the patient's 250), and fishing per person.

## 7. Defects fixed in this change

| What | Why it was a defect | Change |
|---|---|---|
| Courier had no hourly cap, unlike trucking and garbage | A crew could draw unlimited pay from `postop` | `Config.hourlyCap = 2000` a character, same in-memory cap as trucking, with tests |
| Burger Shot crew paid 120, 160 and 200 an hour | Less than the unemployed wage of 150, so working was worse than idling | 200, 260 and 320, in line with taxi and delivery |
| Nothing stopped a shop selling an item for less than a buyer pays | The loop is free money and could be added by a config edit | The check in `tools/economy-map.mjs --check`, with a self test |
| Scale comment in `som-economy/shared/config.lua` | Written for a 10 minute paycheck | Marked stale with a pointer here |

## 8. Owner decisions (numbers not changed, recommended value given)

| | Question | Recommendation |
|---|---|---|
| A | The treasury opens at 0 | Seed the treasury once with 250,000 (database insert at launch) and cut the minted floats: lspd 400,000, ems 250,000, doj 150,000, fire 100,000. The seed is minted too, so the total falls from 2,450,000 to about 1,950,000 and the city can pay buyers and the welcome payment on day one |
| B | Public sector pay | Scale every public grade by about 0.5 (police 600 to 2,100, EMS 600 to 2,100, fire 600 to 1,900, courts 700 to 2,600), or pay half the wage as a retainer and half per action. Add `fundFromTreasury` for `ems` like fire has |
| C | Unemployed paycheck 150 an hour | Lower to 100, or pay only a character who has moved in the last 10 minutes (needs code). The welcome payment already covers the first hours |
| D | Gathering vs the legal median | Fish prices to codfish 20, bass 28, loot 45 and 90 (cuts fishing to about 1,500 to 2,000 an hour); gold ingot 60 and silver ingot 45; quarry and fish `hourlyCap` raised to 10,000 or made per character at 2,500 (needs code) so a busy server does not starve |
| E | Post OP funding | Make `postop` treasury funded with a monthly budget like sanitation (150,000 a month), and split courier pay per drop across the crew or accept the 4 times cost |
| F | Fuel | `pricePerLitre = 2` and `drain.perSpeed = 0.0008`. City driving then costs about 110 an hour and a tank lasts about 2 hours. Fuel is the sink that should be felt, not the one that ends a driving job |
| G | Crime vs legal for heists | Vault clean 6,000 to 12,000 and bank 3,000 to 6,000 (store stays), keep the caps. Peak chain income falls to about 20,000 an hour for the crew |
| H | Meth and high tier weed | Meth output 5 to 10 units (or chemicals down by half); OG Kush seed 90 and Amnesia seed 110. Both keep their level gates |
| I | Commissions | Cap a commission at 10,000 a sale (needs code), or lower the realtor finance commission from 5 to 3 percent |
| J | Garbage budget | `monthlyBudget = 400000` |
| K | Taxi share | `commission = 0.40` (cap stays 1,500 an hour) |
| L | Armoury | Align the police armoury with the shop (pistol 1,000, 9 mm 5) or make the store refuse officers on duty |
| M | The targets themselves | Decide the real anchors (entry hourly income, a median car in hours, a house in hours). This sheet shows the median legal hour at about 1,400 and a median car at about 22 hours |

## 9. Not checked, and how to check it

- Everything marked "assumed" in section 1. Measure in a game: seconds per cast, seconds per courier run, how fast a
  taxi finds fares, how many animals appear, how often tow tickets exist.
- Route `base` for trucking and the number of loot spots in burglary shells are not placed, so those jobs are bounds.
- The treasury inflow rate in a real week. The daily digest from `som-economy` (`Config.Watch`) will show it; recheck
  the sink and faucet ratio (`targetSinkFaucetRatio = 0.85`) after the first week.
- Whether a tow driver and a police officer can self-farm tickets with an alt (needs a live pass).
