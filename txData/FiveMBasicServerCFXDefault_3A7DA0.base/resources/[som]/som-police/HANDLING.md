# Police handling balance

`lspd-Police-Cars.handling.meta` in this folder is a **committed copy** of the
live file at
`[assets-streams]/[police]/lspd-Police-Cars/handling.meta`.

It lives here because `[assets-streams]` is gitignored, so the live file is
hand-copied to the server and every edit to it would otherwise be lost on the
next machine. Same reason `som-traffic` keeps a copy of som-lorefriendly's
manifest.

**Copy this file over the live one after any fresh install of the pack.**

## What was changed and why

The pack shipped police cars in a different performance category to civilian
traffic rather than merely faster than it. Measured against the lore-friendly
civilian cars, which sit at `fInitialDriveMaxFlatVel` 145 to 150:

| Model | Was | Now |
|---|---|---|
| `police2` | **495.0** | 178.0 |
| `pranger` | 350.0 | 170.0 |
| `police3` | 325.0 | 182.0 |
| `fbi2` | 270.0 | 170.0 |
| `fbi` | 250.0 | 176.0 |
| `policeold1` | 250.0 | 162.0 |
| `police4` | 100.0 | 176.0 |

`police2` at 495 against a civilian 145 is 3.4x, which is not a pursuit, it is a
different species of vehicle.

Drive force was brought to 0.315 to 0.355 across the fleet, against a civilian
0.23 to 0.30. The intent is a police car that is clearly quicker off the line
and a little faster flat out, so a pursuit is winnable by either side.

`police4` also shipped `fInitialDriveForce` **3.6** and `fMass` **5600**, which
are not tuning values at any scale: 3.6 is roughly ten times a normal drive
force. Both were corrected, mass to 2100.

`police3` has two `CHandlingData` entries in the file and both were patched.

## Tuning

These are the two fields worth touching:

- `fInitialDriveMaxFlatVel` scales top speed. Raise it for faster pursuits.
- `fInitialDriveForce` is acceleration. This is what makes a car *feel* fast.

Mass was deliberately left alone except on `police4`, because it drives ramming
and collision behaviour rather than speed, and speed was the complaint.
