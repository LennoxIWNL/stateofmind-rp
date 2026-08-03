# som-rentals

Vehicle rental at LSIA. Built first as the honest test of `som-interact`.

## Why this one first

It exercises the whole interaction chain end to end: a ped you walk up to, an
indicator circle while the eye is up, an option beside it, and a real thing
that happens when you pick it. If the chain does not feel right here it will
not feel right on a police armoury either.

It is also the cheapest way into the world for a new character. Per the economy
scale, the bottom rung is a van at around 2K to **buy**, so renting has to be a
small fraction of that or nobody walks.

## The circle is a zone, not the ped

**ox_target draws its indicator for zones only, not for entity targets.**
Registered against the ped as an entity there would be no circle at all, just an
eye that happens to change when you look at it.

So the counter is a sphere zone at the ped's position. The ped is frozen at
fixed coordinates, so a sphere behaves identically and earns the marker.

```lua
Config.MarkerRadius = 5.0   -- how far away the circle appears
-- per-option `distance`   -- how close you must be to actually pick it
```

Anything static that should show a circle follows the same rule. Players and
vehicles do not: those are aimed at, and a world full of circles defeats the
point.

## Plates are eight characters

GTA caps plates at 8. `rental15474` is eleven, so the game would truncate it and
the papers and the vehicle would then disagree about the plate, which is exactly
what the papers exist to prove. `RENT` plus four digits fits exactly.

Collisions are checked against both live rentals and `som_vehicles`.

## The papers

An `ox_inventory` item carrying the plate, the model, the renter and the time.
`description` is set in metadata because **that is what ox renders in the
tooltip**, so hovering the item shows the agreement. A rental agreement nobody
can read is a prop.

## The deposit is the point

`Config.Deposit` is taken up front and returned when the vehicle comes back to
the forecourt. Without it a rental is a disposable car you abandon at the first
red light.

The hire fee is booked as business revenue. The deposit deliberately is not: it
is held, not earned.

## What the server decides

Everything. The client sends a location and a model name; price, plate, spawn
point and the vehicle itself are all resolved server side, and the vehicle is
created with `CreateVehicle` on the server so the client never spawns anything.

Payment happens **before** the vehicle is created, and a failure to spawn
refunds in full, so a player can never end up with a car they did not pay for or
a charge for a car that never arrived.

Distance is re-checked on the server. Renting from the airport while standing in
Paleto is not renting from the airport.

## Known gaps

- **No keys.** There is no vehicle key system yet, so anyone can drive a rental
  they find. That arrives with the vehicle system.
- **Abandoned rentals are not cleaned up.** `Config.RentalMinutes` exists but
  nothing sweeps on it yet.
- Rentals are held in memory, so a server restart forgets who has what. The
  vehicle survives, the deposit does not come back.
- One rental per character at a time.
- Coordinates are a starting point. Stand where you want the counter, press
  **F11** to print your position, and correct `Config.Locations`.
- Not verified against a live server.
