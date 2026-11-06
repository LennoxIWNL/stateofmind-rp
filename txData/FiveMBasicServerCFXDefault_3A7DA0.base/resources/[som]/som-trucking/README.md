# som-trucking

A legal long-haul freight contract on `som-jobboard`, one board entry per route in `Config.routes`.
A crew of one or two accepts it; the server spawns a truck and a loaded trailer at the depot. They
drive the trailer to the yard and hand it in.

Pay comes from the `postop` business account (the same account `som-courier` uses; nothing here
funds it): the server debits the business first, credits the player second, and returns the money
if the credit fails. Pay is the route's `base` reduced by trailer damage (read from the server
entity, at most 50%) and by 25% when late, never below 25% of base. Two distinct crew members who
started together and are both at the yard get +20% on the pool. A citizen is paid at most
`hourlyCap` per hour (held in memory).

The server decides everything: it holds the truck and trailer, checks the player and the trailer
by server-read coordinates, refuses a hand in sooner than the straight line depot to yard at
`maxSpeed`, and sets `delivered` before any money moves. Vehicles are deleted on hand in,
abandon, timeout, group disband, last member leaving, and resource stop.

`/abandonhaul` ends the contract with no pay and no fine, and locks the crew out of trucking for
`abandonCooldown` seconds so abandon and re-accept cannot be farmed.

## It ships disabled

`Config.routes` is empty. See `LAUNCH-TODO.md` for what to set and what is unverified.
