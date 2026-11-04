# som-courier

A legal group delivery run and the first provider on `som-jobboard`. A crew loads parcels at a
pickup, then hands them over at a few drops. Pay is per drop, per member who is actually there, and
comes out of the `postop` business account: the server debits the business first, credits the
player second, and puts the money back if the credit fails. A run that nobody finishes in
`Config.minutes` simply ends.

The server owns the stage, the distance check (`Config.interactDistance`) and the pay. The client
draws a blip and an interaction zone and asks to complete; it never says what it earned.

## It ships disabled

`Config.routes` is empty, so the provider tells every group "no routes are open yet". A route is
`{ label, pickup = vec3, drops = { vec3, ... } }`. The coordinates have to be chosen on the real map
and are listed in `LAUNCH-TODO.md`. Use `/pdcoords` in game to print one.

## Not verified

No game client: the blip and route, the zone, the carry animation (`anim@heists@box_carry@` is an
unchecked guess), the progress bar, a real crew. The pay is only as large as Post OP's balance, and
that account starts small, so a drop is skipped (with a message) when the company is broke.
