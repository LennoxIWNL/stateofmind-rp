# som-police

LSPD: duty, armoury, custody, fines, impounds and certifications.

## Coordinates are unverified

Every coordinate in `shared/config.lua` is harvested from the qbx_police and
qb-policejob configs, both GPL and both targeting Gabz MRPD. **They have not
been walked in game.** MLO versions drift, and a duty marker inside a wall is
worse than no duty marker.

Two helpers exist for correcting them:

- `/pdcoords` (admin) prints your current position to the console, already
  formatted as `vec3(...)` and `vec4(...)` for pasting into the config.
- `/pdzones` draws a pink marker and a label at every configured point, and
  again to turn it off. Anything buried in a wall or floating over the car park
  is visible rather than merely not working.

## Two axes: rank and certification

**Rank** is seniority. It lives in `som-core/shared/jobs.lua` and decides pay,
who may promote whom, and who reaches the supervisory verbs.

```
0 Cadet   1 Officer   2 Senior Officer   3 Corporal
4 Sergeant   5 Lieutenant*   6 Chief of Police*        (* isboss)
```

**Certification** is competence, and is deliberately independent. A Lieutenant
with no rifle certification still cannot draw a rifle, because promotion is not
a competence test.

| Cert | Gates |
|---|---|
| `cert.rifle` | Carbine and heavier at the armoury |
| `cert.interceptor` | Pursuit rated vehicles |
| `cert.helicopter` | The helipad |
| `cert.audit` | Reserved for the financial audit |
| `cert.k9` | Reserved. Gates nothing yet |

Certifications are rows in `som_licenses` with a `cert.` prefix, so every grant
already carries `issued_by`, `issued_at` and `revoked` without a new table.
Revoking **updates** the row rather than deleting it, so the history of a grant
survives it being taken away.

Granted from the MDT by grade 5+ (`Config.CertGrantGrade`), and readable by any
officer from the duty point.

## Restraint is not police-only

Cuffing needs **handcuffs in the inventory and proximity, and nothing else**.

That is not an oversight. If only the police could restrain or move somebody,
kidnapping would be impossible and crime would have no counterplay. So:

- **Cuff, uncuff, escort, put in vehicle, pull from vehicle and search** are
  available to anyone carrying handcuffs.
- **Seize, fine, impound, plate flagging and the armoury** check the job, duty
  and rank, because those carry authority rather than merely force.

The handcuffs are **not consumed** and never need to be used or equipped.
Carrying a pair is the whole check, so there is no item-use flow to fight with
and nothing to lose mid-arrest.

A cuffed player **can still run**. Restraint is a roleplay state, not a
paralysis: a suspect who can move can still be chased, bundled into a car or
walked into a cell rather than parked on a pavement. What they cannot do is
shoot, punch, or enter a vehicle unaided.

`metadata.cuffed` is framework state, not this resource's private flag.
som-theft already gates cash robbery on it, so there is exactly one answer to
"is this person restrained".

## Keybinds

Arrow keys by default, rebindable in FiveM's own key settings.

| Key | Action |
|---|---|
| Up | Cuff or uncuff the nearest person |
| Down | Put in or pull from the nearest vehicle |
| Left | Escort |
| Right | Stop escorting |

Two rules keep these from being a back door:

1. **A keybind calls the same request the eye calls**, through
   `Custody.Request`. It is a faster way to send an identical message, never a
   shortcut around a check. The cuff bind asks the server which verb it means
   before it starts, specifically so it runs the same progress bar the eye
   does rather than being instant.
2. **Registered once, disabled off duty.** `lib.addKeybind` cannot be
   unregistered, so re-registering per duty change would stack handlers.
   Civilians get no binds at all and keep the eye interactions.

## Money

**The officer receives nothing.** `Config.Fines.officerShare` in som-economy is
zero and nothing here pays the issuer. Fines split 70% department, 30%
treasury. Seized cash goes straight to the department account, because
confiscation that pays the confiscator is theft with a badge.

Fines arrive as a **phone bill that settles itself** after
`Config.Fines.dueDays` (7). A fine is not an offer, so refusing to open your
phone cannot be a way to dodge one. That is what `som_phone_bills.auto_collect`
and `due_at` were added for.

## Department vehicles

Signed out, not owned. They get no `som_vehicles` row, so they can never reach a
personal garage or be sold, and a restart simply loses them, which is correct
for a pool car. Plates are `LSPD####`, eight characters exactly, the GTA
maximum.

## The ps-mdt patch

The certifications panel adds code to a resource that is otherwise preserved
third-party. Both additions are **appended and self-contained**, editing no
existing code path, so a fault in them breaks the panel and nothing else:

- `ps-mdt/ui/dashboard.html` gains one container after the licences block.
- `ps-mdt/ui/app.js` gains an IIFE at the very end. It hooks onto the profile
  view by **watching the citizen id input** rather than by patching the profile
  loader, so it needs no knowledge of how profiles are fetched.
- `ps-mdt/client/main.lua` gains two NUI callbacks, routed through
  `QBCore.Functions.TriggerCallback` rather than `lib.callback`, because ps-mdt
  does not load ox_lib and `lib` is nil there. That shim lives in som-compat,
  where ox_lib is loaded.

Separately, ps-mdt's four record-deletion permissions were moved off grade 4.
That used to be the Chief and is now a Sergeant, so leaving them would have
handed record deletion to a mid rank.

**Re-apply all of this on a ps-mdt upgrade.**

## Known gaps

- Coordinates are unverified. See the top of this file.
- Evidence and forensics are not here. `[custom]/r14-evidence` already
  implements GSR, blood, casings, fingerprints, vehicle forensics and per-type
  decay, far beyond anything that would be written from scratch. It needs the
  som-compat surface, which now exists.
- Jail, dispatch, cameras, ANPR, spike strips and the helicopter spotlight are
  deliberately later.
- ps-mdt's citation path still deducts a fine straight from the bank
  (`server/main.lua:1827`) rather than going through this resource. Redirecting
  it is the remaining piece of the fine flow.
- Not run. There is no Lua toolchain installed, so this has been checked
  structurally (block and bracket balance, callback cross-reference, JS parsed
  with `node --check`) but never executed.
