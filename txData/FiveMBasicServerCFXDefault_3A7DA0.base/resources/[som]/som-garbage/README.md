# som-garbage

A legal municipal garbage and recycling round on `som-jobboard`. A crew of one to three gets a
server-spawned garbage truck, works the labelled bins at each stop on foot, then tips the general
waste at the landfill and the recycling at the recycling centre.

The server owns the truck, the bin list, the count and the sort. A client names a bin id and the
compartment it chose; the server checks the bin is on the current stop, not yet emptied, the
player and truck are close, and a minimum time has passed since the last pickup. A recycling bin
put in the recycling compartment counts as recycling; any other combination counts as general waste.

Pay is per bag (recycling pays a bonus) from the `sanitation` business, a treasury funded
department: debit the business first, credit the player second, undo if the credit fails. When the
account is short, the exact shortfall is drawn from the city treasury through `fundFromTreasury`,
only within `monthlyBudget` per 30 days, with the cap read and the draw done under one lock. The
pool is fixed by the route, so a bigger crew is faster, not richer. A citizen earns at most
`hourlyCap` per hour (in memory).

The board refuses the job up front when the account plus the allowed top-up cannot cover a round.
Abandon (`/abandonround`), timeout, disband, the last member leaving and a resource stop all remove
the truck; abandon, timeout and disband lock the crew out for `abandonCooldown`.

## It ships disabled

`Config.routes` is empty and the `sanitation` row must be imported. See `LAUNCH-TODO.md`.
