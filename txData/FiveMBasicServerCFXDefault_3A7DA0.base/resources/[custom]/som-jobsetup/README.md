# som-jobsetup

Central, in-game manager for **job interactions, garages and 3rd-eye points**.
Built for State of Mind RP so you can relocate every job interaction from one
menu when you swap from one MLO to another — no editing each job's `config.lua`.

**Deps:** `qb-core`, `ox_lib`, `qb-target` (all already on the server).
It lives in `[custom]`, so it auto-starts via `ensure [custom]` — no `server.cfg`
change needed.

## How it works

Every interaction is a **point** stored in `data/points.json` (the single source
of truth). On every server boot / change, the resource itself **renders** each
point at runtime:

- an optional **map blip**
- an optional **ped** (the relocatable "garage attendant" / shop entity)
- an optional **marker**
- a **qb-target** zone that fires the point's **action**

So moving a garage = open the menu, stand on the new spot, click *Move point to
me*. Nothing in qb-policejob / qb-ambulancejob / qb-garages has to be touched —
the point just triggers their existing event/export.

## Two modes

1. **Job-config injection (PD / EMS)** — writes coordinates **straight into**
   `qb-policejob` / `qb-ambulancejob` `Config.Locations`, so the *real*
   interaction relocates (no duplicate). This is the menu's first option:
   **Set up Job interactions**. It backs up the config every time and can
   restart the resource so the change is live. Supported slots:
   - **Police:** duty, garage (`vehicle`), stash, impound, helicopter, armory,
     trash, **fingerprint**, evidence
   - **Ambulance:** **hospital check-in** (`checking`), duty, armory, roof,
     main, basement, stash, **beds** (patient beds), jailbeds
2. **Managed custom points** — som-jobsetup renders its own blip / ped / marker
   / qb-target zone and fires a configurable event. Use for anything that
   exposes an event/command/export (stashes, shops, 3rd-eye, custom jobs).

## Usage

1. As an admin, run **`/jobsetup`** (ace `command.jobsetup`; `group.admin` already
   has it).
2. **Add interaction point (here)** — stand where you want it, give it a label,
   pick the job + type (garage / duty / armory / stash / shop / 3rd-eye / blip),
   set a radius.
3. **Manage points** → pick a point to:
   - *Teleport* to it
   - *Move point to me* (re-capture coords/heading at your feet — this is the
     MLO-swap workflow)
   - *Set / edit action* — what happens on interact (see below)
   - *Show / hide marker*
   - *Delete*
4. **Show live coords** overlays your exact `x, y, z` + heading on screen.
5. **Export points** prints the full JSON to the F8 console for backup.

## Wiring a point to a job (the "action")

When you edit a point's action you choose a **kind** and a **name**:

| Kind | Fires | Example name |
|------|-------|--------------|
| Client event | `TriggerEvent(name, args)` | `qb-garages:client:OpenMenu` |
| Server event | `TriggerServerEvent(name, args)` | `police:server:toggleDuty` |
| Command | `ExecuteCommand(name)` | `duty` |
| Export | `exports[resource][name](args)` | resource `qb-garages`, name `OpenGarage` |
| None | nothing (blip/ped only) | — |

To find the right event for a PD/Ambulance garage, open that job's `config.lua`
or its garage logic and copy the event it already uses to open the vehicle menu,
then paste it as the action `name`. The point will call it at the new location.

> Tip: the **garage** and **shop** types spawn a ped by default (configurable in
> `config.lua` → `Config.Types`), which becomes the physical "entity" you place
> for the PD / Ambulance garage.

## Notes

- All create/edit/delete actions are server-validated against the `command.jobsetup`
  ace — non-admins can't change points even if they trigger the events.
- `data/points.json` is written with `SaveResourceFile`; back it up by copying the
  file or using **Export points**.
