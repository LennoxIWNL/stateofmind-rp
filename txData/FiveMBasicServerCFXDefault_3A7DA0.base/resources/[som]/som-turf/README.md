# som-turf

Turf and the street drug market as one system (AUDIT 17 and 18): owning a zone is what lets a gang sell drugs in it.

## How it works
- **Claim:** a gang member of grade `claimGrade` or higher tags the wall at a zone's tag point (20 s progress, the server checks the time and the distance). An unowned zone becomes theirs.
- **Contest:** a rival gang tagging an owned zone only contests it, and the owner is told. After `holdMinutes` (computed from the database timestamp, so restarts change nothing) the same rival tags again and takes it. The owner can tag any time before then to push the rival back. A third gang cannot jump in while a contest is open. There is no combat requirement, so this is the low intensity mode; a war can still be fought around it.
- **Sell:** only the owning gang sells in a zone. One unit per interaction, a cooldown per character, paid in **marked bills** minted by `som-launder`. No clean cash is created; the bills still have to be washed at a front, which has its own hourly budget. Police can get a "Suspicious Exchange" call at the seller's position (25% chance, set in the dispatch config).
- **Market:** `som_drug_market` counts recently sold units per item. Each unit lowers the price by `dropPerUnit` down to `floor`, and the count decays by `recoverPerHour`, by timestamp. Owners get `ownerBonus` on top.

## Research matrix
| Source | Licence | Took | Left |
|---|---|---|---|
| qb-territories | BSD-3-Clause | zone definition idea and the ownership/contest split | its floating zone UI, client side ownership |
| NoPixel / EchoRP / ProdigyRP notes (AUDIT 17) | n/a | turf gates drug income, a spray tag as the claim, low and high intensity conflict | reputation or heat scores (deliberately not built) |
| qb-drugs / qb-weed / elixir-drugs | mixed | the item set | flat prices, client trusted sales |

## Also in this resource
- **Gang app** (`gang`): roster, invites, ranks, removal, deposits to the gang account.
- **Payroll**: hourly, from the gang account, for gangs holding a zone.
- **Turf app** (`turf`): read only owners, contests, prices.
- **Weed growing**: plants, tending, harvest, bagging (`server/grow.lua`).
- **Labs**: timed recipe cooks (`server/lab.lua`); the coke chain works with existing items, precursors come from a disabled-by-default chemical supplier.

## Scope cuts
- No NPC buyers; selling is an interaction with the zone, not a ped.
- No phone HUD or score of any kind, on purpose.
- `control_points` on `som_turf` is unused.
- Every zone, grow spot, bagging table and lab ships disabled with no coordinates.
