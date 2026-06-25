# State of Mind RP — Server Rundown

> Auto-generated codebase audit. All coordinates and mechanics are extracted directly from config/client files.

---

## Table of Contents

1. [Interactive NPCs & Peds](#1-interactive-npcs--peds)
2. [Legal Jobs](#2-legal-jobs)
3. [Criminal Jobs & Robberies](#3-criminal-jobs--robberies)
4. [Drug Operations](#4-drug-operations)
5. [Gang Scripts & Turf Wars](#5-gang-scripts--turf-wars)
6. [Hidden Locations & Special Areas](#6-hidden-locations--special-areas)

---

## 1. Interactive NPCs & Peds

### City Services

| NPC | Model | Coordinates | Interaction | Source |
|-----|-------|-------------|-------------|--------|
| City Hall Clerk | `a_m_m_hasjew_01` | `(-262.79, -964.18, 30.22)` | Apply for jobs, ID card ($50), driver license ($50), weapon license ($50) | `[qb]/qb-cityhall/config.lua` |
| Driving School Instructor | `a_m_m_eastsa_02` | `(240.91, -1379.2, 32.74)` | Take driving lessons | `[qb]/qb-cityhall/config.lua` |
| Car Rental Agent | `a_m_m_business_01` | `(302.33, -328.75, 44.92)` | Car rental menu | `[custom]/som-rentacar/config.lua` |

### Vehicle & Transport

| NPC | Model | Coordinates | Interaction | Source |
|-----|-------|-------------|-------------|--------|
| Car Dealer | `a_m_y_hasjew_01` | `(-57.13, -1099.05, 26.42)` | Browse dealership, management (job: cardealer) | `[custom]/pa-vehicleshop/shared/config.lua` |

### Healing NPCs

| NPC | Model | Coordinates | Interaction | Source |
|-----|-------|-------------|-------------|--------|
| Grandma | `ig_mrs_thornhill` | `(2432.59, 4966.1, 46.81)` | Revive downed player — $500 bank | `[custom]/randol_grandma/` |
| Grandpa | `cs_nigel` | `(1974.38, 3820.33, 33.43)` | Revive downed player — $500 bank | `[custom]/randol_grandma/` |

### Pet Shop

| NPC | Model | Coordinates | Interaction | Source |
|-----|-------|-------------|-------------|--------|
| Pet Shop Owner | `cs_zimbor` | `(-662.29, -933.57, 21.83)` | Buy pets: Cat ($15k), Chop ($10k), Husky ($15k), Poodle ($10k), Pug ($7k), Retriever ($10k), Rottweiler ($4k), Shepherd ($10k), Westy ($20k) | `[custom]/elixir-petshop/shared/config.lua` |

### Prison

| NPC | Model | Coordinates | Interaction | Source |
|-----|-------|-------------|-------------|--------|
| Freedom Ped | `s_m_m_armoured_01` | `(1740.88, 2476.57, 44.85)` | Check time / leave prison | `[qb]/qb-prison/client/main.lua` |
| Canteen Ped | `s_m_m_armoured_01` | `(1777.59, 2560.52, 44.62)` | Buy food (sandwich, water) | `[qb]/qb-prison/client/main.lua` |

### Shops — 7/24 Markets (9 locations)

All use model `mp_m_shopkeep_01`. Source: `[custom]/ac-shop/shared/config.lua`

| # | Coordinates | Area |
|---|-------------|------|
| 1 | `(24.47, -1346.62, 29.5)` | Strawberry |
| 2 | `(-3039.54, 584.38, 7.91)` | Inseno Road |
| 3 | `(-3242.97, 1000.01, 12.83)` | Banham Canyon |
| 4 | `(1728.07, 6415.63, 35.04)` | Paleto Bay |
| 5 | `(1959.82, 3740.48, 32.34)` | Sandy Shores |
| 6 | `(549.13, 2670.85, 42.16)` | Harmony |
| 7 | `(2677.47, 3279.76, 55.24)` | Tataviam Mountains |
| 8 | `(2556.66, 380.84, 108.62)` | Murrieta Heights |
| 9 | `(372.66, 326.98, 103.57)` | Vinewood Hills |

### Shops — LTD Gasoline (5 locations)

| # | Coordinates | Area |
|---|-------------|------|
| 1 | `(-47.02, -1758.23, 29.42)` | Davis |
| 2 | `(-706.06, -913.97, 19.22)` | Little Seoul |
| 3 | `(-1820.02, 794.03, 138.09)` | Pacific Bluffs |
| 4 | `(1164.71, -322.94, 69.21)` | Mirror Park |
| 5 | `(1697.87, 4922.96, 42.06)` | Grapeseed |

### Shops — Rob's Liquor (5 locations)

| # | Coordinates | Area |
|---|-------------|------|
| 1 | `(-1221.58, -908.15, 12.33)` | Vespucci |
| 2 | `(-1486.59, -377.68, 40.16)` | Del Perro |
| 3 | `(-2966.39, 391.42, 15.04)` | Chumash |
| 4 | `(1165.17, 2710.88, 38.16)` | Route 68 |
| 5 | `(1134.2, -982.91, 46.42)` | Murrieta Heights |

### Shops — Hardware Stores (3 locations)

Sells: lockpick, wrench, hammer, repairkit, screwdriverset, phone, radio, fitbit, cleaningkit, advancedrepairkit

| # | Coordinates | Area |
|---|-------------|------|
| 1 | `(45.68, -1749.04, 29.61)` | Davis |
| 2 | `(2747.71, 3472.85, 55.67)` | Sandy Shores |
| 3 | `(-421.83, 6136.13, 31.88)` | Paleto |

### Shops — Ammunation (11 locations)

Sells: knife, bat, hatchet, pistol_ammo, pistol (license required), snspistol, vintagepistol

| # | Coordinates |
|---|-------------|
| 1 | `(-3173.31, 1088.85, 20.84)` |
| 2 | `(-1304.19, -395.12, 36.7)` |
| 3 | `(841.92, -1035.32, 28.19)` |
| 4 | `(-1118.59, 2700.05, 18.55)` |
| 5 | `(2567.48, 292.59, 108.73)` |
| 6 | `(23.0, -1105.67, 29.8)` |
| 7 | `(253.63, -51.02, 69.94)` |
| 8 | `(-331.23, 6085.37, 31.45)` |
| 9 | `(1692.67, 3761.38, 34.71)` |
| 10 | `(809.68, -2159.13, 29.62)` |
| 11 | `(-661.96, -933.53, 21.83)` |

### LSPD Ammunation (Police Only)

- **Location:** `(482.58, -995.36, 30.69)` — Inside MRPD
- **Model:** `ig_andreas`
- **Sells:** PD ammo, handcuffs, evidence bags, stormram, armor, radio, bodycam, medical supplies, tasers, firearms
- **Source:** `[custom]/ac-shop/shared/config.lua`

### Weapon Repair

- **Location:** `(964.02, -1267.41, 34.97)`
- **Costs:** Pistol $1,000 | SMG $3,000 | MG $4,000 | Rifle $5,000 | Shotgun $6,000 | Sniper $7,000
- **Source:** `[qb]/qb-weapons/config.lua`

### Pawnshop

- **Location:** `(412.34, 314.81, 103.13)`
- **Accepts:** goldchain, diamond_ring, rolex, 10kgoldchain, tablet, iphone, samsungphone, laptop ($50–100 each)
- **Melting Recipes:**
  - goldchain → 2x goldbar
  - diamond_ring → 1x diamond + 1x goldbar
  - rolex → 1x diamond + 1x goldbar + 1x electronickit
  - 10kgoldchain → 5x diamond + 1x goldbar
- **Source:** `[qb]/qb-pawnshop/config.lua`

### Electronics Dealer (Criminal)

- **Location:** `(-1369.58, -332.6, 38.97)`
- **Model:** `a_m_y_bevhills_01`
- **Sells:** rfid_disruptor ($2,500)
- **Source:** `[robberies]/mk-atmRobbery/config.lua`

### Gas Station Attendants (30 stations)

All use model `a_m_m_indian_01`. Player-owned station management (currently disabled). Source: `[standalone]/cdn-fuel/shared/config.lua`

Key stations: Davis Avenue Ron, Grove Street LTD, Dutch London Xero, Little Seoul LTD, Strawberry Ave Xero, Mirror Park LTD, Great Ocean Xero, Paleto Blvd Xero, Sandy Shores Xero, Route 68 Globe Oil, and 20 more.

### Fishing NPCs (6 peds)

Source: `[jobs]/[public]/doj-fishing/config.lua`

| NPC | Model | Coordinates | Purpose |
|-----|-------|-------------|---------|
| La Puerta Fisher | `s_m_y_ammucity_01` | `(-806.17, -1496.57, 0.6)` | Boat/Gear Menu |
| Paleto Cove Fisher | `u_m_m_filmdirector` | `(-1604.24, 5256.48, 1.07)` | Boat/Gear Menu |
| El Gordo Fisher | `s_m_o_busker_01` | `(3373.22, 5183.52, 0.46)` | Boat/Gear Menu |
| Act Dam Fisher | `ig_cletus` | `(1694.81, 39.93, 160.77)` | Boat/Gear Menu |
| Alamo Sea Fisher | `a_m_m_hillbilly_01` | `(1299.67, 4231.89, 32.91)` | Boat/Gear Menu |
| Fish Seller | `s_m_y_busboy_01` | `(-1816.41, -1193.33, 13.31)` | Sell caught fish |

### Job-Specific NPCs

| NPC | Model | Coordinates | Interaction | Source |
|-----|-------|-------------|-------------|--------|
| Tow Truck NPC | `s_m_m_autoshop_02` | `(392.74, -1632.67, 29.29)` | Start/stop tow job | `[jobs]/[public]/som-towtruck/` |
| Taxi Boss | — | `(895.53, -179.30, 74.70)` | Taxi management | `[jobs]/[public]/pickle_taxijob/` |
| Postal Manager | `s_m_y_construct_01` | `(132.96, 96.13, 82.51)` | Accept postal delivery | `[jobs]/[public]/dream-postal/` |
| Garbage Manager | `s_m_y_garbage` | `(-322.24, -1546.02, 30.02)` | Start garbage route | `[qb]/qb-garbagejob/` |
| Security Manager | `s_m_m_armoured_01` | `(0.94, -659.21, 32.48)` | Security contracts | `[jobs]/[public]/qb-securityjob/` |
| Jimmy (Gruppe 6) | `mp_s_m_armoured_01` | `(-4.22, -659.18, 32.48)` | Armored deliveries | `[jobs]/[public]/pengu_gruppe6delivery/` |
| Pizza Boss | `u_m_y_party_01` | `(538.35, 101.8, 95.54)` | Start pizza delivery | `[jobs]/[public]/randol_pizzajob/` |
| City Work Foreman | `s_m_y_construct_02` | `(884.47, -2337.14, 29.34)` | City work tasks | `[jobs]/[public]/randol_cityworker/` |
| UwU Cafe Vendor | `a_m_m_farmer_01` | `(462.2, -693.88, 26.44)` | Cafe vendor | `[jobs]/[owned]/mt-UwUCafe/` |
| Coral Buyer | `a_m_m_salton_01` | `(-1684.13, -1068.91, 13.15)` | Sell coral from diving | `[qb]/qb-diving/config.lua` |
| Chop Shop Buyer | `a_m_m_ktown_01` | `(1219.56, 1905.86, 77.86)` | Sell chopped parts | `[jobs]/[chopshop]/elixir-chopshop/` |
| Weed Run Boss | `a_m_y_eastsa_01` | `(87.94, -1434.8, 29.31)` | Start weed delivery run | `[jobs]/[illegal]/elixir-weedrun/` |
| Oxy Run Boss | `cs_manuel` | `(-966.69, -266.99, 39.35)` | Start oxy delivery run | `[jobs]/[illegal]/elixir-oxyrun/` |
| Car Heist Mechanic | `U_M_Y_SmugMech_01` | `(4.95, -723.95, 31.17)` | Start car theft mission | `[robberies]/randol_carheist/` |
| Truck Robbery Dealer | — | `(960.78, -216.25, 76.25)` | Start truck robbery | `[robberies]/qb-truckrobbery/` |
| Weed Field NPC | `a_f_m_fatbla_01` | `(3715.81, 4522.65, 20.87)` | Dry weed buds | `[new]/BakiTelli_weed/` |

### Bank Branches (7 locations)

Source: `[custom]/som-banking/Config.lua`

| # | Location | Coordinates |
|---|----------|-------------|
| 1 | Legion Square | `(149.02, -1041.17, 29.37)` |
| 2 | Del Perro | `(-1212.92, -331.6, 37.79)` |
| 3 | Hawick | `(-351.78, -50.36, 49.04)` |
| 4 | Hawick 2 | `(313.37, -279.53, 54.17)` |
| 5 | Great Ocean | `(-2961.91, 482.27, 15.7)` |
| 6 | Route 68 | `(1175.7, 2707.51, 38.09)` |
| 7 | Paleto Bay | `(-111.54, 6469.59, 31.62)` |

---

## 2. Legal Jobs

### Tow Truck

- **Source:** `[jobs]/[public]/som-towtruck/shared/config.lua`
- **NPC:** `s_m_m_autoshop_02` at `(392.74, -1632.67, 29.29)`
- **Vehicle:** flatbed3, spawns at `(395.15, -1625.97, 29.29)` or `(397.04, -1623.66, 29.29)`
- **Drop-off:** `(379.54, -1627.38, 29.29)`

**How it works:**
1. Talk to NPC → Start job
2. Use `/towtruck` command to open the tablet and accept a tow task
3. Drive to the broken vehicle location (15 locations across LS and Blaine County)
4. Hook the vehicle to the flatbed and tow it back to the drop-off
5. Deliver the vehicle → Get paid

**Payouts:** $200–600 base per task + distance bonus ($50/mile) + level bonus ($120/level). Vehicle class multipliers range 1.0x–2.5x (Super cars pay the most). 7 reputation ranks, max 500 XP.

---

### Taxi Service

- **Source:** `[jobs]/[public]/pickle_taxijob/config.lua`
- **Boss:** `(895.53, -179.30, 74.70)` | **Duty:** `(900.58, -171.51, 74.08)`
- **Vehicle:** Taxi/Stretch Limo, spawn at `(916.07, -163.43, 74.68)`

**How it works:**
1. Go on duty at the taxi depot
2. Accept NPC passenger pickups from 11 zones across LS
3. Drive passengers to their destinations
4. Get paid per trip

**Payout:** $170–300 base + $2.0 per mile driven.

---

### Bus Driver

- **Source:** `[qb]/qb-busjob/config.lua`
- **Location:** `(462.22, -641.15, 28.45)`
- **Vehicle:** Bus

**How it works:**
1. Pick up bus at depot
2. Follow route through 5 bus stops:
   - `(304.36, -764.56, 29.31)`
   - `(-110.31, -1686.29, 29.31)`
   - `(-712.83, -824.56, 23.54)`
   - `(-692.63, -670.44, 30.86)`
   - `(-250.14, -886.78, 30.63)`
3. Stop at each point, let passengers on/off
4. Complete the route for pay

---

### Postal Delivery

- **Source:** `[jobs]/[public]/dream-postal/config.lua`
- **HQ:** `(132.96, 96.13, 82.51)` | NPC: `s_m_y_construct_01`
- **Vehicle:** boxville2 at `(130.50, 88.77, 82.12)`

**How it works:**
1. Talk to postal manager → Accept job
2. Put on postal uniform
3. Collect packages from 21+ blue postal boxes around the map
4. Deliver to 15 residential locations
5. 1.5x pay multiplier per delivery

---

### Garbage Collection

- **Source:** `[qb]/qb-garbagejob/client/main.lua`
- **NPC:** `s_m_y_garbage` at `(-322.24, -1546.02, 30.02)`
- **Vehicle:** trash2 at `(-333.84, -1527.28, 27.28)`
- **Deposit:** $250

**How it works:**
1. Talk to garbage manager → Get garbage truck
2. Drive to 21 pickup locations
3. Collect 2–5 bags per stop
4. Minimum 5 stops required

**Payout:** $50–100 per bag. 75% chance for cryptostick per stop.

---

### Trucker

- **Source:** `[qb]/qb-truckerjob/`
- **Location:** `(153.68, -3211.88, 5.91)` | Vehicle spawn: `(141.12, -3204.31, 5.85)`
- **Vehicles:** Rumpo, Benson, Mule, Pounder, Boxville StepVan
- **Deposit:** $125

**How it works:**
1. Pick up truck at depot
2. Drive to delivery locations (up to 20 drops)
3. $500 per delivery. 20% bonus after 5+ deliveries. 15% tax deducted.

---

### Fishing

- **Source:** `[jobs]/[public]/doj-fishing/config.lua`
- **5 Boat Rental Locations:** La Puerta, Paleto Cove, El Gordo, Alamo Dam, Alamo Sea (see NPC table above)
- **Fish Sell Location:** `(-1816.41, -1193.33, 13.31)`

**Gear (buy from any fishing NPC):**
- Fishing Rod: $50
- Bait: $5 each
- Boat Anchor: $500
- Fishing Ice Box: $1,000
- Boat Rental: $100 (refundable)

**How it works:**
1. Buy gear from a fishing NPC
2. Rent a boat (dinghy) → Sail to open water
3. Cast rod → Wait 21–45 seconds → Skillbar minigame
4. Catch fish and store in ice box
5. Sell at the Fish Seller NPC

**Fish Prices:**

| Fish | Price | Rarity |
|------|-------|--------|
| Mackerel | $5 | Common |
| Cod | $15 | Common |
| Bass | $35 | Common |
| Flounder | $40 | Common |
| Stingray | $50 | Common |
| Dolphin | $100 | Exotic |
| Tiger Shark | $200 | Exotic |
| Hammerhead Shark | $200 | Exotic |
| Killer Whale | $500 | Exotic |

**Bonus:** Loot boxes can be found — Metal Box gives $100 + diamond_ring. Treasure Chest gives random items.

---

### Mining

- **Source:** `[jobs]/[public]/jim-mining/config.lua`
- **Activities:** Cracking, Washing, Panning, Pickaxe mining, Drill mining, Laser mining

**Store Items:**
- Water: $0 | Gold Pan: $0 | Pickaxe: $100 | Mining Drill: $10,000 | Mining Laser: $60,000

**How it works:**
1. Go to the mine (location defined in Loc table, loaded per-server)
2. Mine rocks with pickaxe/drill/laser
3. Crack stones → carbon, copperore, ironore, metalscrap
4. Wash stones → goldore, uncut gems (ruby, emerald, diamond, sapphire)
5. Pan in water → goldore, silverore, junk items
6. Smelt ores into ingots, cut gems at crafting stations
7. Sell to ore buyer NPC — all ores/gems at $100 each

**Crafting:** Multi-craft support (1, 5, 10, 50, 100 at once). Smelt ores into goldingot/silveringot, cut gems into polished versions.

---

### Electrical Work

- **Source:** `[jobs]/[public]/mz-electrical/shared/config.lua`
- **Location:** `(687.54, 132.27, 80.75)`

**How it works:**
1. Go to electrical work location
2. Accept a tier-appropriate job
3. Complete skillcheck minigames (4 circle parses for opening, 3 for fixing wires)
4. 10% chance of electrocution on failed skillcheck (-10 health)

**Tier System:**

| Tier | Tasks | Payout | XP Required |
|------|-------|--------|-------------|
| Prep | 3 | $500–1,500 | 0 |
| Tier 1 | 4 | $1,500–2,500 | 400 |
| Tier 2 | 5 | $2,500–3,500 | 2,400 |
| Tier 3 | 6 | $3,500–4,500 | 6,400 |

**Item Drops:** rubber, plastic, metalscrap, glass, aluminum, electronicscrap

---

### Pizza Delivery

- **Source:** `[jobs]/[public]/randol_pizzajob/`
- **Boss:** `u_m_y_party_01` at `(538.35, 101.8, 95.54)`
- **Vehicle:** Surge at `(535.3, 95.58, 96.32)`

**How it works:**
1. Talk to pizza boss → Get delivery vehicle
2. Pick up pizzas from the vehicle
3. Carry to customer houses and deliver

---

### City Worker

- **Source:** `[jobs]/[public]/randol_cityworker/config.lua`
- **Boss:** `s_m_y_construct_02` at `(884.47, -2337.14, 29.34)`
- **Vehicle:** Bison at `(892.6, -2339.76, 30.39)`

**How it works:**
1. Talk to foreman → Get work vehicle
2. Drive to 20 random city locations (construction sites, road work, etc.)
3. Complete task at each location (10s progress bar, 15s timeout)

**Payout:** $150–275 per task completed.

---

### Security / Armored Transport

- **Source:** `[jobs]/[public]/qb-securityjob/`
- **NPC:** `s_m_m_armoured_01` at `(0.94, -659.21, 32.48)`
- **Vehicle:** Stockade at `(-5.55, -670.1, 32.34)`

**How it works:**
1. Get stockade from NPC
2. Drive to 17 drop-off locations
3. Deliver 2–4 cash bags per stop, minimum 5 stops

**Payout:** $75–550 per bag delivered.

---

### Gruppe 6 Delivery

- **Source:** `[jobs]/[public]/pengu_gruppe6delivery/`
- **NPC:** "Jimmy" at `(-4.22, -659.18, 32.48)`
- **Vehicle:** Stockade (7 spawn points)

**How it works:**
1. Organize cash bags at the depot
2. Drive stockade to delivery locations (1–4 bags per drop)

**Payout:** $100–300 per bag + $300–400 for organizing.

---

### Farming

- **Source:** `[jobs]/[public]/kloud-farmjob/`
- **Requires:** trowel (from shop)

**Crop Fields (25 harvests each):**

| Crop | Field Location |
|------|---------------|
| Potato | `(2852.95, 4627.06, 50.69)` |
| Cabbage | `(2541.34, 4812.27, 33.73)` |
| Tomato | `(2238.95, 5074.01, 47.25)` |
| Coffee | `(2308.01, 5131.05, 50.5)` |
| Oranges | `(2341.86, 5003.98, 42.53)` |

**How it works:**
1. Buy a trowel from the farm shop ($50)
2. Go to a crop field → Harvest crops
3. Wash crops at wash stations (3s per item)
4. Sell to farm NPC for $50 per crop

---

### Coral Diving

- **Source:** `[qb]/qb-diving/config.lua`
- **Sell NPC:** `a_m_m_salton_01` at `(-1684.13, -1068.91, 13.15)`

**How it works:**
1. Go to one of 7 dive sites around the coast
2. Dive underwater and collect coral (3–4 pickups per site)
3. Sell at the coral buyer NPC

**Prices:** Dendrogyra $70–100, Antipatharia $50–70. Bonus tiers: 5–10 coral = 5–10% bonus, 11–15 = 10–15%, 16+ = 15–20%.
**Risk:** 50% police call chance per coral pickup.

---

### Hot Dog Vendor

- **Source:** `[qb]/qb-hotdogjob/`
- **Location:** `(39.31, -1005.54, 29.48)` | Spawn: `(38.15, -1001.65, 29.44)`
- **Deposit:** $250

**How it works:**
1. Get hot dog cart
2. Sell hot dogs to NPCs around the city
3. Payout scales with reputation (4 tiers): Exotic $8–15, Rare $6–12, Common $4–9 per hot dog
4. Max reputation: 200

---

### Vineyard / Wine Production

- **Source:** `[qb]/qb-vineyard/`
- **Grape Picking:** `(-1928.81, 2059.53, 140.84)` — Harvest 8–12 grapes
- **Wine Production:** `(-1879.54, 2062.55, 135.92)` — Produce 6–10 wine bottles (180s fermentation)
- **Grape Juice:** `(828.76, 2191.16, 52.37)` — Make 6–10 grape juice

---

### Recycling

- **Source:** `[qb]/qb-recyclejob/`
- **Outside:** `(55.55, 6472.18, 31.43)` | **Inside:** `(1073.0, -3102.49, -39.0)`
- **Duty:** `(1048.7, -3100.62, -38.2)`

**How it works:**
1. Go on duty at recycling center
2. Pick up recyclable items (metalscrap, plastic, copper, iron, aluminum, steel, glass)
3. 2–6 qty per pickup, max 5 items. Chance for cryptostick.

---

### Scrapyard

- **Source:** `[qb]/qb-scrapyard/config.lua`
- **Location:** `(2397.42, 3089.44, 49.92)` | Delivery: `(2351.5, 3132.96, 48.2)`
- **Items:** metalscrap, plastic, copper, iron, aluminum, steel, glass from 80 vehicle models

---

### News Reporter

- **Source:** `[qb]/qb-newsjob/`
- **HQ:** `(-597.89, -929.95, 24.0)` (Weazel News)
- **Vehicles:** Rumpo vans at `(-552.24, -925.61, 23.86)` | Frogger helicopter at `(-583.08, -930.55, 36.83)`
- **Equipment:** News camera, microphone, boom mic

---

### Phone Delivery

- **Source:** `[jobs]/[public]/rz-delivery/`
- **NPC:** `(-1671.75, 136.5, 63.27)`
- **Payout:** $600 per delivery to 10 customer locations

---

### Owned Business Jobs

| Business | Job Name | Duty Location | Source |
|----------|----------|---------------|--------|
| Burger Shot | `burgershot` | `(-1200.36, -902.45, 13.89)` | `[jobs]/[owned]/ex-burgershot/` |
| Mechanic | `mechanic` | (dynamic per location) | `[jobs]/[owned]/jim-mechanic/` |
| UwU Cafe | `uwucafe` | `(462.2, -693.88, 26.44)` | `[jobs]/[owned]/mt-UwUCafe/` |
| Limey's Candy | `limeys` | (config-defined) | `[jobs]/[owned]/qb-limeysjob/` |
| Little Teapot | `littleteapot` | `(-510.55, -30.93, 45.72)` | `[jobs]/[owned]/randol_littleteapot/` |

**Burger Shot Details:**
- Delivery vehicle: NSpeedo at `(-1164.57, -891.6, 14.1)`
- Work stations: Burger, Fries, Drinks, Meat, Package, Clean, Sell
- Delivery payout: Small bag $2,500, Big bag $5,000 (20 delivery zones)
- 8 ice cream flavors available

**Little Teapot Details:**
- Ingredients box: $1,500 (30x each ingredient)
- Sweet treats: $75 (cookies, donuts, croissants)
- Menu: Bacon Egg, Pancakes, BLT Sandwich, Teas, Coffee, Smoothies

---

## 3. Criminal Jobs & Robberies

### Bank Robberies

Source: `[robberies]/qb-bankrobbery/`

#### Fleeca Banks (6 locations)

**Required Items:** `lockpick` + `drill`
**Police Required:** 0 | **Evidence Chance:** 65% fingerprints, 85% other

| # | Coordinates |
|---|-------------|
| 1 | `(311.15, -284.49, 54.16)` |
| 2 | `(146.92, -1046.11, 29.36)` |
| 3 | `(-353.82, -55.37, 49.03)` |
| 4 | `(-1210.77, -336.57, 37.78)` |
| 5 | `(-2956.55, 481.74, 15.69)` |
| 6 | `(1175.96, 2712.87, 38.09)` |

**How it works:**
1. Lockpick the safe door
2. Drill 8 vault lockers (18,000–30,000ms each, drilling animation)
3. Rewards per locker: 5–15 goldchain OR 5–15 rolex OR 1–2 goldbar + 2–3 markedbills
4. Stress: +4–8 per drill action

#### Paleto Bank

- **Location:** `(-105.61, 6472.03, 31.62)`
- **Required Items:** `security_card_01` + `thermite` + `drill`

**How it works:**
1. Use security card at entrance (5–10s)
2. Thermite the reinforced door at `(-106.11, 6475.36, 31.62)`
3. Drill 8 vault lockers
4. Rewards per locker: 10–20 goldchain OR 10–20 rolex OR 2–4 goldbar + 1–4 markedbills

#### Pacific Standard Bank

- **Location:** `(261.95, 223.11, 106.28)` / `(253.25, 228.44, 101.68)`
- **Required Items:** `security_card_02` OR (`trojan_usb` + `electronickit`) + 2x `thermite` + `drill`

**How it works:**
1. Use security card OR hack (hacking minigame: 5 blocks, 30s timer)
2. Thermite door 1 at `(252.55, 221.15, 101.68)`
3. Thermite door 2 at `(261.15, 215.21, 101.68)`
4. Drill 10 vault lockers
5. Rewards per locker: 4–8 goldbar + 1–4 markedbills

#### Power Stations (disable bank cameras — 13 locations)

`(2835.24, 1505.68, 24.72)`, `(2811.76, 1500.6, 24.72)`, `(2137.73, 1949.62, 93.78)`, `(708.92, 117.49, 80.95)`, `(670.23, 128.14, 80.95)`, `(692.17, 160.28, 80.94)`, `(2459.16, 1460.94, 36.2)`, `(2280.45, 2964.83, 46.75)`, `(2059.68, 3683.8, 34.58)`, `(2589.5, 5057.38, 44.91)`, `(1343.61, 6388.13, 33.4)`, `(236.61, 6406.1, 31.83)`, `(-293.1, 6023.54, 31.54)`

---

### Store Robbery

- **Source:** `[robberies]/qb-storerobbery/config.lua`
- **Registers:** 32 locations across all convenience stores
- **Safes:** 19 locations (keypad or padlock type)
- **Required Items:** None for registers; lockpick/hacking device for safes
- **Cooldown:** 30 minutes per register/safe
- **Police Required:** 0

**Payout:** $100–450 per register (markedbills) + 10% chance for sticky note with safe code.

**Sample Register Locations:** `(-47.24, -1757.65, 29.53)`, `(-1486.26, -378.0, 40.16)`, `(-1222.03, -908.32, 12.32)`, `(-706.08, -915.42, 19.21)`, `(24.47, -1344.99, 29.49)`, `(1134.15, -982.53, 46.41)`, `(1165.05, -324.49, 69.2)`, `(373.14, 328.62, 103.56)`

---

### ATM Robbery

- **Source:** `[robberies]/mk-atmRobbery/config.lua`
- **Required Item:** `rfid_disruptor` (buy from Electronics Dealer at `(-1369.58, -332.6, 38.97)` for $2,500)
- **Target:** Any ATM (prop_atm_01, prop_atm_02, prop_atm_03, prop_fleeca_atm)
- **Cooldown:** 1 minute | **Police Required:** 0

**How it works:**
1. Buy RFID Disruptor from electronics dealer
2. Find any ATM in the city
3. Use disruptor on ATM → Complete alphanumeric hack (25s timer)
4. Receive payout

**Payout:** $2,000–6,000 cash + 33% chance for `cryptostick`.

---

### House Robbery

- **Source:** `[robberies]/qb-houserobbery/config.lua`
- **Time Restriction:** 6 AM – 10 PM in-game only
- **Required Items:** `lockpick` (30% break chance) or `advancedlockpick` (15% break); `screwdriverset` if using basic lockpick
- **Cooldown:** 25 minutes per house | **Police Alert:** 20% chance per search | **Police Required:** 0

**House Locations (Vinewood Hills):**
- **Perfect Drive:** 6 houses starting at `(-784.72, 459.77, 100.39)`
- **Milton Road:** 4 houses starting at `(-536.67, 477.36, 103.19)`
- **Didion Drive:** 4 houses starting at `(-418.09, 568.99, 125.06)`
- **Hillcrest:** 3 houses starting at `(-908.66, 693.67, 151.44)`
- **North Sheldon:** 5+ houses starting at `(-1130.87, 784.44, 163.89)`

**How it works:**
1. Go to a house during allowed hours
2. Lockpick the front door
3. Search 10 furniture items inside (cabin, kitchen, chest, living room)
4. Each search has a 20% chance to alert police

**Loot by Room:**

| Room | Possible Loot |
|------|--------------|
| Cabin | plastic, diamond_ring, goldchain, weed_skunk, thermite, cryptostick, weapon_golfclub |
| Kitchen | tosti, sandwich, goldchain |
| Chest | plastic, rolex, diamond_ring, goldchain, weed_skunk, thermite, cryptostick, weapon_combatpistol |
| Living Room | plastic, rolex, diamond_ring, goldchain, thermite, cryptostick, tablet, pistol_ammo |

---

### Jewelry Store Robbery

- **Source:** `[qb]/qb-jewelery/`
- **Location:** `(-630.5, -237.13, 38.08)`
- **Required:** Any whitelisted weapon (pistol, rifle, shotgun, SMG — 12 types)
- **Cooldown:** 60 minutes | **Police Required:** 0

**How it works:**
1. Enter the jewelry store with a weapon
2. Shoot display windows (10s timeout between windows)
3. Loot each of 20 vitrines

**Payout per vitrine:** 1–4 rolex + 1–4 diamond_ring + 1–4 goldchain.

---

### Ammu-Nation Robbery

- **Source:** `[robberies]/elixir-ammurobbery/config/config.lua`
- **Location:** Central ammo shop area around `(20.55, -1105.46, 29.8)`
- **Required Item:** `advancedlockpick`
- **Cooldown:** 1 hour per vitrine | **Police Required:** 0

**Targets:**
- 6 weapon vitrines near `(16–24, -1103 to -1112, 29.8)`
- 3 ammo shelves
- 1 armor shelf at `(16.36, -1109.5, 29.8)`

**How it works:**
1. Get an advancedlockpick (hardware store or crafting)
2. Approach vitrine/shelf → Use lockpick → Search (5s)
3. Receive random weapon/ammo loot

**Vitrine Rewards:** weapon_knife (30–50%), weapon_pistol (10–40%), weapon_pistol50 (10–50%)
**Shelf Rewards:** pistol_ammo (1–2), smg_ammo (1–2), armor (1)

---

### Armored Truck Robbery

- **Source:** `[robberies]/qb-truckrobbery/config.lua`
- **Dealer NPC:** `(960.78, -216.25, 76.25)` | **Activation Cost:** $500 from bank
- **Cooldown:** 10 minutes | **Police Required:** 0

**Vehicle Spawn Locations:**
- `(-1327.48, -86.05, 49.31)`
- `(-2075.89, -233.74, 21.10)`
- `(-972.18, -1530.90, 4.89)`
- `(798.18, -1799.82, 29.33)`
- `(1247.07, -344.66, 69.08)`

**Delivery Locations:**
- `(806.18, 2181.29, 52.25)`
- `(-86.47, 1880.51, 197.31)`
- `(2135.38, 4780.8, 40.97)`

**How it works:**
1. Pay $500 to the dealer NPC
2. Drive to random vehicle spawn location
3. Place bomb on cargo doors (30s detonation timer)
4. Deliver goods to drop location

**Payout:** $6,500–8,700 (markedbills) + 5% chance for `security_card_01`.

---

### Luxury Car Heist

- **Source:** `[robberies]/randol_carheist/sv_config.lua`
- **Mechanic NPC:** `U_M_Y_SmugMech_01` at `(4.95, -723.95, 31.17)`
- **Time Limit:** 30 minutes | **Police Required:** 0

**Vehicle Pool:** furia, vacca, adder, zentorno, cheetah, entityxf, reaper, autarch, taipan, sm722, italirsx, comet5, tenf, growler, coquette3, coquette4, jester3

**7 Vehicle Spawn Locations:** `(895.6, -887.01)`, `(929.51, -2307.92)`, `(1084.72, -2289.35)`, `(995.39, -1854.3)`, `(18.44, -209.74)`, `(-786.76, -798.91)`, `(-1173.53, -1173.81)`

**Delivery Locations:** `(806.18, 2181.29, 52.25)`, `(-86.47, 1880.51, 197.31)`, `(2135.38, 4780.8, 40.97)`

**How it works:**
1. Talk to mechanic → Accept delivery mission
2. Go to random spawn location → Steal the luxury car
3. Deliver to drop point within 30 minutes

**Payout:** $6,500–8,700 (markedbills).

---

### Chopshop

- **Source:** `[jobs]/[chopshop]/elixir-chopshop/config.lua`
- **Start NPC:** `a_m_m_ktown_01` at `(1219.56, 1905.86, 77.86)`
- **Required Item:** `lockpick`
- **Cooldown:** 15 minutes

**How it works:**
1. Talk to NPC → Get a vehicle target
2. Find and steal the target vehicle
3. Deliver to one of 4 scrapyard locations
4. Vehicle is stripped into parts

**Parts & Sale Prices:**
- car_wheel: $500
- car_door: $500
- radiator: $2,500
- trunk: $500

**Trunk Loot:** lockpick, joint, weapon_bat (random)

---

### Gruppe 6 Truck Robbery (Rob Other Players/NPCs)

- **Source:** `[jobs]/[public]/pengu_gruppe6delivery/`
- **Required Items:** `thermite` + `lighter`

**How it works:**
1. Target any Stockade vehicle (NPC or player-driven)
2. "Break Open Trunk" → Thermite animation
3. Complete skill check to defuse ink bomb
4. Success: `cash_bag` (uninked) | Failure: `inked_cash_bag`
5. NPC trucks contain 2–5 random bags

---

### Street Racing

- **Source:** `[qb]/qb-streetraces/`
- **Commands:** `/createrace [amount]`, `/startrace`, `/stoprace`, `/quitrace`
- **No fixed locations** — fully dynamic based on player waypoints

**How it works:**
1. Creator sets waypoint as finish line (must be 500+ units from start)
2. Other players join (press H near start marker within 15m)
3. Entry fee set by creator
4. 5-second countdown → Race!
5. Winner takes entire pot

---

### Crypto Mining

- **Source:** `[new]/razed-cryptomining/`
- **Purchase Price:** $85,000 (cash or bank)
- **Interact with:** `prop_laptop_01a` or `v_corp_servercln` models (player places in house)

**GPU Tiers:**

| GPU | Mining Rate | Time |
|-----|-----------|------|
| GTX 480 | 0.1–0.3 crypto | 15–50s |
| GTX 1050 | (faster) | (faster) |
| RTX 4090 | 2.5–5.0 crypto | 2.5–18.5s |

**Withdrawal:** 10% fee. Sell via `/sellcrypto [amount]` at current qbit market price.

---

### Traphouse

- **Source:** `[qb]/qb-traphouse/config.lua`
- **Entrance:** `(-1202.21, -1308.48, 4.92)` | **Interior:** `(-1207.63, -1311.75, -32.65)`
- **Takeover Cost:** $5,000 | **Default PIN:** 1234

**How it works:**
1. Pay $5,000 to take over the traphouse
2. Set a custom PIN code
3. Use as a gang stash for items and drugs
4. Convert items to cash:
   - metalscrap: $3 | lockpick: $150 | screwdriverset: $300
   - electronickit: $300 | radioscanner: $850 | gatecrack: $600
   - trojan_usb: $1,000 | weed_brick: $250 | phone: $750
   - 10kgoldchain: $3,000

---

## 4. Drug Operations

### Weed Growing (Elixir System — 6 Strains)

- **Source:** `[custom]/elixir-drugs/config.lua`

**Strains:** Skunk, OG Kush, White Widow, Purple Haze, AK47, Amnesia
**Seed Items:** `weed_skunk_seed`, `weed_og-kush_seed`, `weed_white-widow_seed`, `weed_purple-haze_seed`, `weed_ak47_seed`, `weed_amnesia_seed`

**Required Items:**
- Seeds (strain-specific)
- `empty_weed_bag` (for bagging)
- `weed_nutrition` (fertilizer)
- `water_bottle`
- `leaf_blower` (for harvesting)

**How it works:**
1. Plant a seed in the ground
2. Water and feed the plant to maintain health/thirst (depletes 1%/5s health, 1%/15s quality)
3. Wait for growth stages (300–600s initial, 60–200s per stage)
4. Harvest with leaf blower when mature
5. Bag the weed into portions

**Yield:** Max 5 baggies per plant. Low quality: 1, Mid: 1–3, High: 2–5 baggies depending on strain.

---

### Weed Field Growing (Outdoor)

- **Source:** `[new]/BakiTelli_weed/shared/config.lua`
- **Planting Field:** `(3718.13, 4537.12, 21.50)` — 70-unit radius (Grapeseed)
- **Drying NPC:** `a_f_m_fatbla_01` at `(3715.81, 4522.65, 20.87)`
- **Max:** 3 plants simultaneously | 5 growth levels
- **Blip visible on map** (sprite 496, color 25)

**Required Items:** `weed_seed`, `water_bottle` (+10%), `weed_nutrition` (+10%), `dust` (+15% health, +10% growth), `trowel`, `empty_weed_bag`, `cutter`

**How it works:**
1. Go to weed field in Grapeseed
2. Plant seeds with trowel
3. Water and fertilize to speed growth
4. Harvest → 1x `weedbud`
5. Take to drying NPC → Produces 2x `weed_whitewidow`

---

### Cocaine Processing

- **Source:** `[custom]/elixir-drugs/config.lua`

**Coca Plant Locations (9 sites — Northern Grapeseed/Paleto forest):**
- `(-2164.42, 5177.58, 14.93)`, `(-2178.75, 5177.67, 15.7)`, `(-2190.01, 5177.04, 15.3)`
- `(-2188.29, 5191.62, 18.12)`, `(-2158.44, 5171.27, 13.76)`, `(-2161.61, 5161.26, 12.93)`
- `(-2193.84, 5148.27, 11.03)`, `(-2199.09, 5141.53, 12.05)`, `(-2205.03, 5140.11, 12.12)`

**Processing Location:** `(1090.4, -3194.82, -38.99)` (underground lab)
**Packing Location:** `(1100.86, -3198.78, -38.99)` (underground lab)

**How it works:**
1. **Harvest coca leaves:** Pick 2–4 `coca_leaf` per plant at the 9 locations above
2. **Get gasoline:** Use 4x `empty_jerry_can` → 1–4 `gasoline` (70% success, 30min cooldown)
3. **Get cement:** Process bags → 2–5 `cement` per bag (70% success)
4. **Get benzocaine:** Search airport boxes for `benzocaine`, `copper`, `aluminum`, `iron`
5. **Process at lab:** 3x coca_leaf + 1x gasoline + 3x cement + 2x benzocaine = **50x `cokebaggy`**
6. **Pack:** 100g → `coke_small_brick`, 500g → `coke_brick`

---

### Methamphetamine Cooking

- **Source:** `[custom]/elixir-drugs/config.lua`

**Lithium Rock Locations (13 sites — Beach/coastal area):**
- `(2831.16, -629.3, 1.96)`, `(2832.03, -636.05, 1.87)`, `(2825.8, -641.07, 1.92)`
- `(2820.53, -639.92, 2.19)`, `(2818.22, -632.33, 2.5)`, `(2816.49, -624.55, 2.67)`
- `(2815.17, -615.55, 2.73)`, `(2821.74, -610.34, 1.93)`, `(2808.3, -619.48, 3.33)`
- `(2802.08, -634.58, 3.64)`, `(2813.22, -646.08, 2.44)`, `(2821.25, -648.15, 1.93)`
- `(2831.18, -649.39, 1.72)`

**Lab Locations (underground, z = -38.99):**
- Processing: `(1004.6, -3194.93, -38.99)`
- Cooking: `(1003.84, -3202.54, -38.99)`
- Cracking: `(1012.02, -3194.96, -38.99)`

**How it works:**
1. **Mine lithium:** Use `trowel` at rock locations → 1–3 `lithium` per rock
2. **Get hydrochloric acid:** 4x `empty_jerry_can` → 1–4 `hydrochloric_acid` (70%, 30min cooldown)
3. **Get methylamine:** 4x `empty_jerry_can` → 1–4 `methylamine` (70%, 30min cooldown)
4. **Get acetone:** Search boxes → random `acetone` (30min cooldown)
5. **Process at lab:** 3x hydrochloric_acid + 2x methylamine + 4x acetone + 6x lithium = **3–8x `meth_processed`**
6. **Cook:** 1x `methtray` → 5–25x `meth` (30s cook time)

---

### Corner Selling

- **Source:** `[qb]/qb-drugs/config.lua`

**Sellable Drugs:**

| Drug | Price Range |
|------|-----------|
| weed_whitewidow | $15–24 |
| weed_skunk | $15–31 |
| weed_purplehaze | $18–37 |
| weed_ogkush | $15–28 |
| weed_amnesia | $18–34 |
| weed_ak47 | $18–40 |
| crack_baggy | $18–34 |
| cokebaggy | $18–37 |
| meth | $18–40 |

**Mechanics:**
- Walk up to NPCs on the street and offer drugs
- **Success:** 50% | **Scam (reduced pay):** 25% | **Robbery (NPC robs you):** 25%
- Police call chance: 99%
- Random 1–15 bags per transaction

---

### Drug Deliveries (5 drop-off locations)

- **Source:** `[qb]/qb-drugs/`

| Location | Coordinates |
|----------|-------------|
| Stripclub | `(106.24, -1280.32, 29.24)` |
| Vinewood | `(223.98, 121.53, 102.76)` |
| Taxi Depot | `(882.67, -160.26, 77.11)` |
| Resort | `(-1245.63, 376.21, 75.34)` |
| Bahama Mamas | `(-1383.1, -639.99, 28.67)` |

**Items:** `weed_brick` ($1,000 payout), `coke_brick` ($1,000 payout)
**Rep system:** +1 per delivery, -1 per fail

---

### Weed Delivery Run

- **Source:** `[jobs]/[illegal]/elixir-weedrun/config.lua`
- **Boss:** `a_m_y_eastsa_01` at `(87.94, -1434.8, 29.31)`
- **Required Items:** 2x `weedbud` per handoff
- **Cost:** $500 per run | **Cooldown:** 600s (10 min) | **Police Required:** 0

**How it works:**
1. Talk to boss → Start delivery run
2. Drive to 37+ handoff/selling locations across the map
3. Hand off weed to NPCs at each stop

**Rewards:** Marked bills 100% chance ($750–2,000), money rolls 20% chance ($250–750), 5% chance for `security_card_01`.

---

### Oxy Delivery Run

- **Source:** `[jobs]/[illegal]/elixir-oxyrun/config.lua`
- **Boss:** `cs_manuel` at `(-966.69, -266.99, 39.35)` — "Mysterious Person"
- **Cost:** $500 per run | **Cooldown:** 600s (10 min) | **Police Required:** 0
- **Deliveries per run:** 4–6

**How it works:**
1. Talk to boss → Pay $500 → Start oxy run
2. Drive to pickup locations (8 across the city)
3. Follow 4 delivery routes with spawn/delivery/despawn coordinates
4. Complete all deliveries for rewards

**Rewards:** 1–3x `oxy` + marked bills 25% chance ($750–2,000), money rolls 20% chance ($250–750), 5% chance for `security_card_01`. Police call chance: 50%.

---

## 5. Gang Scripts & Turf Wars

### Defined Gangs

Source: `[qb]/qb-core/shared/gangs.lua`

| Gang | Label | Grade 0 | Grade 1 | Grade 2 | Grade 3 (Boss) |
|------|-------|---------|---------|---------|----------------|
| lostmc | The Lost MC | Recruit | Enforcer | Shot Caller | Boss |
| ballas | Ballas | Recruit | Enforcer | Shot Caller | Boss |
| vagos | Vagos | Recruit | Enforcer | Shot Caller | Boss |
| cartel | Cartel | Recruit | Enforcer | Shot Caller | Boss |
| families | Families | Recruit | Enforcer | Shot Caller | Boss |
| triads | Triads | Recruit | Enforcer | Shot Caller | Boss |

### Territory System

**No dedicated turf war/territory capture system exists.** Gang management menu locations are all set to `vector3(0, 0, 0)` (unconfigured) in `[qb]/qb-management/client/cl_config.lua`.

The `som-spray` resource provides cosmetic graffiti spraying but has no gang territory mechanics.

### Gang Traphouse (Closest to Territory)

- **Source:** `[qb]/qb-traphouse/config.lua`
- **Entry:** `(-1202.21, -1308.48, 4.92)` (South LS near La Mesa)
- **Interior:** `(-1207.63, -1311.75, -32.65)` (underground)
- **Takeover:** $5,000 — Any gang can take over
- **PIN:** Default 1234, customizable
- **Stash items:** metalscrap, copper, iron, aluminum, steel, glass, lockpick, screwdriverset, electronickit, radioscanner, gatecrack, trojan_usb, weed_brick, phone, radio, handcuffs, 10kgoldchain

---

## 6. Hidden Locations & Special Areas

### Underground Drug Labs (z = -38.99)

Source: `[custom]/elixir-drugs/config.lua`

These are underground interiors accessed via specific entry points:

| Lab | Purpose | Coordinates |
|-----|---------|-------------|
| Coke Processing | Process coca leaves into cocaine | `(1090.4, -3194.82, -38.99)` |
| Coke Packing | Pack cocaine into bricks | `(1100.86, -3198.78, -38.99)` |
| Meth Processing | Process raw chemicals | `(1004.6, -3194.93, -38.99)` |
| Meth Cooking | Cook methamphetamine | `(1003.84, -3202.54, -38.99)` |
| Meth Cracking | Crack meth into crystals | `(1012.02, -3194.96, -38.99)` |

### Underground Crafting Area (z = -98.26)

Source: `[qb]/qb-lift/config.lua`

Elevator system "Under Ground":
- **Outside entrance:** `(485.47, -3383.67, 6.07)` (restricted floor)
- **Inside underground:** `(894.55, -3246.24, -98.26)` (unrestricted from inside)

### State of Mind RP Apartment (Custom Interior)

Source: `[qb]/qb-lift/config.lua`

Elevator "Apartment" (police/ambulance restricted):
- **Outside exit:** `(-1002.81, -477.7, 50.03)`
- **Interior spawn:** `(-1007.1, -486.59, 39.97)` — "State of Mind RP - Here your New Journey Starts"

### Restricted Rooftops

Source: `[qb]/qb-lift/config.lua`

**Pillbox Hospital (police/ambulance only):**
- Garage: `(341.48, -580.91, 28.8)`
- Main floor: `(331.98, -595.54, 43.28)`
- Roof: `(338.76, -583.81, 74.17)`

**Police Station:**
- Main: `(360.58, -1410.34, 32.43)`
- Roof: `(335.15, -1432.53, 46.51)`

### Weed Field (Grapeseed)

- **Location:** `(3718.13, 4537.12, 21.50)` — 70m radius
- **NPC:** `a_f_m_fatbla_01` at `(3715.81, 4522.65, 20.87)`
- **Blip visible on map** (sprite 496, color 25)
- Source: `[new]/BakiTelli_weed/shared/config.lua`

### Coca Plant Cluster (Paleto Forest)

9 plants clustered at X: -2164 to -2205, Y: 5140 to 5191 — Northern forest area near Paleto. Source: `[custom]/elixir-drugs/config.lua`

### Lithium Rock Beach

13 rocks along the coast at X: 2800–2832, Y: -610 to -649 — Beach/coastal area. Source: `[custom]/elixir-drugs/config.lua`

### Underwater Coral Sites

7 diving zones with multiple coral pickup points — exact locations vary per zone. Source: `[qb]/qb-diving/config.lua`

### Prison

Source: `[qb]/qb-prison/config.lua`

- **Freedom exit:** `(1740.88, 2476.57, 44.85)`
- **Outside entrance:** `(1848.13, 2586.05, 44.67)`
- 11 spawn points inside
- 7 electrician job locations (prison work)
- Canteen sells: sandwich, water

### Apartments

Source: `[qb]/qb-apartments/config.lua`

- **Entrance:** `(-269.41, -961.19, 31.23)` (Alta Street)
- Each unit has its own stash (dynamic, per-player)

---

## Where to Get Required Items

### Item Source Reference

| Item | Where to Get | Coordinates |
|------|-------------|-------------|
| `lockpick` | Hardware Store | `(45.68, -1749.04)`, `(2747.71, 3472.85)`, `(-421.83, 6136.13)` |
| `advancedlockpick` | Crafting / loot | — |
| `rfid_disruptor` | Electronics Dealer | `(-1369.58, -332.6, 38.97)` — $2,500 |
| `drill` | — | Needed for bank robberies |
| `thermite` | House robbery loot / events | Drops from cabin, chest, living room |
| `security_card_01` | 5% drop | Oxy Run, Weed Run, Truck Robbery |
| `security_card_02` | Admin/event item | Not available from regular gameplay |
| `trojan_usb` | Traphouse / loot | Traphouse converts for $1,000 |
| `electronickit` | Pawnshop melting | Melt rolex → electronickit + diamond + goldbar |
| `screwdriverset` | Hardware Store | Same as lockpick locations — $300 |
| `trowel` | Farm Shop / Hardware | Used for lithium mining and farming |
| `empty_jerry_can` | — | Used for gasoline/acid/methylamine extraction |
| `weed_seed` | Drug shops / loot | Gated by reputation |
| `water_bottle` | Shops | Any 7/24 or LTD store |
| `weed_nutrition` | Drug shops | Fertilizer for plants |
| `leaf_blower` | — | Required for harvesting weed |

---

*Generated from codebase analysis. All coordinates extracted directly from server config files.*
