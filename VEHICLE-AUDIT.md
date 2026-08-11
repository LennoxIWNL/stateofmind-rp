# Vehicle add-on audit

Run 2026-08-11. **Nothing has been deleted, and nothing will be.**

## Owner's decision, 2026-08-11: KEEP EVERYTHING

Groups 1 and 2 are kept rather than removed, and `ex-cars` is kept. **This
whole removal list is closed.** Do not re-propose it.

That is a reasonable call on the evidence: the audit's own finding is that none
of it is ensured, so none of it costs a byte of streaming memory. It is disk,
and disk is cheap. Deleting would have bought tidiness and risked a resource
turning out to be wanted later.

**The one thing still open on `ex-cars`:** it is 87 complete civilian vehicles
sitting on disk and NOT ensured. Keeping it is not the same as switching it on.
Turning it on is one line in `som.cfg`, but it puts 365 MB into streaming and
there is still no dealership for the cars to be sold from, so that is a
separate decision and has not been taken.

The rest of this file is the original audit, kept because the reasoning about
what is and is not streaming is still the useful part.

## The finding that reframes the task

**Only 6 of 22 vehicle resources are ensured.** Everything else is on disk and
never loads.

`som.cfg` names streamed assets explicitly and the only two group ensures in
the whole config are `[anticheats]` and `[voice]`, so a resource that is not
named does not start. That was verified rather than assumed.

| | Resources | Disk |
|---|---:|---:|
| Ensured, actually streaming | 6 | ~349 MB |
| On disk, never loads | 16 | **~4.7 GB** |

So the memory question the plan worried about is not the question. **Nothing
listed for removal is currently costing a single byte of streaming memory.**
Removing it frees disk and reduces confusion, nothing more. The real streaming
budget is the ~349 MB below, and there is far more headroom than assumed.

## What is actually streaming (keep, all of it load-bearing)

| Resource | Models | Disk |
|---|---:|---:|
| `[police]/lspd-Police-Cars` | 14 yft | 246 MB |
| `[police]/origen_police` | 219 yft | 44 MB |
| `[police]/lspd-Police-SWAT` | 2 yft | 33 MB |
| `[police]/lspd-Police-Bike` | 2 yft | 15 MB |
| `[vehicles]/rd-vehicleconfig` | config only | 9 MB |
| `[ems-veh]/ro-VehicleConfig` | config only | 2 MB |

**Every model our configs reference resolves to one of these.** Checked one by
one:

- `som-police` garage and helipad: `police2`, `police3`, `police4`, `fbi`,
  `fbi2`, `pranger` from lspd-Police-Cars; `policeb` from lspd-Police-Bike;
  `pitbullbb` from lspd-Police-SWAT; `polbuffalo4`, `polcaracara`, `poldom`,
  `polcomet`, `polvstr` from origen_police; `polmav` is vanilla.
- `som-rentals`: `blista`, `panto`, `asea`, `rumpo`, `faggio`, all vanilla, no
  add-on needed.
- `som-garage` is DB-driven with no static list.

**No dangling reference anywhere.** The PD fleet is correctly wired.

## Removal list, awaiting sign-off

### Group 1: broken, cannot load at all (4 resources, 297 MB)

No `fxmanifest.lua` and no `__resource.lua`, so FiveM cannot see them however
the config is written.

| Resource | Disk | Note |
|---|---:|---|
| `[vehicles]/rd-vehicleaudio` | 232 MB | |
| `[vehicles]/rd-vehicleaudio2` | 33 MB | |
| `[vehicles]/temp_vh` | 20 MB | 6 yft. Name says staging |
| `[vehicles]/rd-xmas-vehicles` | 12 MB | 2 yft. Seasonal |

Safest group to remove. **One check first:** `rd-vehicleconfig` IS ensured, so
confirm it does not expect the audio or wheels resources beside it before the
`rd-*` family is broken up.

### Group 2: unreferenced add-ons, the handoff's original candidates (6 resources, 179 MB)

Not ensured, and nothing in any config references them.

| Resource | Models | Disk |
|---|---:|---:|
| `[police]/TIG-PACK` | 48 yft | 78 MB |
| `[police]/c321defender` | 2 yft | 32 MB |
| `[vehicles]/vanya` | 1 yft | 20 MB |
| `[custom]/npwpdcar` | 2 yft | 19 MB |
| `[vehicles]/veh_lykan` | 9 yft | 14 MB |
| `[vehicles]/tesla` | 2 yft | 14 MB |
| `[vehicles]/New_Truck` | 2 yft | 4 MB |

`npwpdcar` is worth noting: the handoff listed it as a `[police]` candidate but
it actually lives in `[custom]`, which is why an earlier sweep would have
missed it.

### Group 3: do NOT remove yet, decide first (3 resources, 4.2 GB)

These are the ones that matter, and they are not simple deletes.

| Resource | Contents | Disk |
|---|---|---:|
| `[vehicles]/assets_vehicles` | **Tuning parts, not vehicles.** 5,012 yft of aero kits, bonnets and similar, zero `vehicles.meta`. Also ships **`popgroups.ymt` and `popcycle.dat`** | 3,760 MB |
| `[vehicles]/ex-cars` | **87 complete civilian vehicles** | 365 MB |
| `[ems-veh]/mainasset` | 12 yft of EMS vehicles | 85 MB |

Three reasons to hold:

1. **`ex-cars` is 87 civilian cars already on disk and simply switched off.**
   The plan's next step is downloading a 158-car lore-friendly pack. Turning
   this on first may deliver most of the civilian roster for free, and it is
   already vetted and in the tree. **Look at this before downloading anything.**
2. **`assets_vehicles` carries `popgroups.ymt` and `popcycle.dat`**, which are
   exactly the files the NPC traffic sub-task needs to weight sedate models
   into traffic. Deleting it throws away the mechanism for a task still on the
   list. The 3.7 GB of parts and the traffic files can be separated.
3. **`mainasset` is the EMS fleet.** EMS is on the roadmap, so this is content
   waiting for a consumer rather than dead weight.

## The LCPDFR pack: blocked, and not on tooling

871 MB landed at `Vehicles/`, now gitignored. It is **the LSPDFR/singleplayer
build, not a FiveM release**, and it cannot be used as-is:

- All 38 vehicles (19 police, 19 EMS) are sealed inside two `dlc.rpf` archives,
  480 MB and 295 MB. There is not one loose `.yft` in the download.
- Its install instructions are `mods\update\x64\dlcpacks` plus a `dlclist.xml`
  edit, which is the singleplayer path. FiveM streams loose files.
- The lighting configs are **ELS VCF XMLs**, and no ELS resource runs here.
  som-police already owns lights and sirens itself.

**The blocker is licensing, not tooling.** The pack's own terms state:

> Do not rip, modify, or alter the contents of this archive.

Extracting the `.rpf` into loose files is exactly that, and it is the only way
to make it stream in FiveM. So this is not something to solve with OpenIV or a
packer. **The right move is to ask the author (BlueGhost on LCPDFR) whether a
FiveM release exists, or find one that ships loose files.** I have not
extracted anything.

Spawn names are readable from the ELS filenames if the config work is wanted
in advance: police `aleutianp bansheep buffalop buffalop2 carap cavalcadep
deityp grangerp gresleyp kurumap rhinehartp sentinelp sentinelp2 sugoip tenfp
terminusp vigerop vivanitep vivanitep2`, EMS the same list with an `e` suffix
plus `ballere`, `calicoe` and `monstroe`.

## Recommended order

1. Sign off group 1 and group 2. 476 MB, zero risk, nothing references them.
2. Look at `ex-cars` before downloading the 158-car pack.
3. Split the traffic files out of `assets_vehicles` before deciding its fate.
4. Resolve the LCPDFR licensing question before any more work on task 9d.
