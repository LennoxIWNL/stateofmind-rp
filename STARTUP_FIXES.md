# Startup Errors — Fixes & Asset Report (State of Mind RP)

## ✅ Fixed automatically

| Error | Fix applied |
|---|---|
| **Duplicate resources** (×22) | Removed the accidental top-level copies under `[system]`, `[gameplay]`, `[test]`, `[managers]`, `[gamemodes]` — kept the canonical `[cfx-default]` set. Each deletion was verified to have a `[cfx-default]` twin first. |
| **`baseevents` "duplicate"** | **Kept** — it exists *only* in `[system]/baseevents` (no `[cfx-default]` twin, not in the artifact). Deleting it would have broken core events. |
| **Missing resource: `chat`** | Copied the artifact's `chat` resource into `resources/[cfx-default]/[gameplay]/chat` (the artifact's `system_resources/chat` was not being mounted, hence "could not be found"). |
| **Missing logo (96×96)** | Your real `myLogo.png` is **1170×1133** (brand asset — left intact). Generated a valid **96×96 `server-icon.png`** and repointed `server.cfg` → `load_server_icon server-icon.png`. Swap in a 96×96 crop of your logo whenever you like. |
| **New_Truck fxmanifest** | `data/` contains only `.meta` files, but the manifest globbed `data/**/*.xml`, `*.dat`, `*.ytyp` (matched nothing → "missing file" warnings). Removed those three dead globs; kept `data/**/*.meta`. All `data_file` lines still resolve. |

> Note: the duplicate resources were git-tracked, so the deletions are fully recoverable via git if anything is needed back.

---

## ⚠️ Server timeout — `assets_peds` (HeartBeat failure)

**Root cause is size, not the manifest.** The `fxmanifest.lua` is correct (8 lines). The problem:

- **`assets_peds/stream` = 3,712 MB (3.7 GB) across 17,287 files.**

A single resource that large cannot finish streaming within the startup HeartBeat window, so the watchdog kills it (>1 min load). The manifest cannot fix this — the resource itself is oversized.

**✅ Applied fix 1 — raised txAdmin's boot tolerance:**
`txData/default/config.json` → added `"restarter": { "bootGracePeriod": 300 }`.
txAdmin's default boot grace is **60 s**; `assets_peds` loads in >60 s, so the health
monitor was killing the server mid-boot. 300 s gives it room to finish mounting.

**✅ Applied fix 2 — load heavy streams LAST:**
`server.cfg` — moved `ensure [assets-streams]` from *before* qb-core to the **end** of
the ensure list. The framework now boots first (server responsive / heartbeat OK)
*before* the ~5 GB of ped/vehicle streams mount. This is why the console appeared
"stuck on starting assets_peds_other" — it was loading early and blocking.

> **`assets_peds_other`** (1.35 GB, 4,993 files) was diagnosed: all 61 declared peds
> have matching models — nothing missing/broken. The ~47 warnings are benign component/
> texture notices, not load failures. It is slow, not stuck.

**✅ Applied fix 3 — split the oversized packs:**
- `assets_peds` (3.7 GB) → **5 resources** `assets_peds` + `assets_peds_p2..p5` (~734 MB each).
- `assets_peds_other` (1.35 GB) → **2 resources** + `assets_peds_other_p2` (~675 MB each).
- `peds.meta` kept in the originals; stream files distributed across parts. Asset names
  stream into a global pool, so peds still resolve their models from any part. All parts
  live under `[assets-streams]/[clothing]/` and auto-start via `ensure [assets-streams]`.

**Still recommended (optional):**
- **Trim** unused ped models — 17k stream files is far more than most servers use.
- Run from **SSD/NVMe** — HDD streaming will always be slower.

---

## ⚠️ Oversized streaming assets (memory / streaming warnings)

Measured on disk (your old log figures differed — these are current actuals):

| Resource | Size | Path | Recommendation |
|---|---|---|---|
| **assets_peds** | **3,712 MB** | `[assets-streams]/[clothing]/assets_peds` | **Split or trim** (see above) — by far the biggest offender. |
| **assets_dogs** | **98 MB** | `[assets-streams]/[extras]/assets_dogs` | Acceptable alone, but combined with peds it pressures the streamer. Keep only dog models in use. |
| **TIG-PACK** | **78 MB** | `[assets-streams]/[police]/TIG-PACK` | Police pack — fine if used. Verify it's actually ensured; remove if not. |
| **PacificBankExtendedMLOv1** | **29 MB** | `[assets-streams]/[extras]/PacificBankExtendedMLOv1` | Normal for an MLO. No action unless unused. |
| **New_Truck** | **4 MB** | `[assets-streams]/[vehicles]/New_Truck` | Small — the old "72 MB" figure no longer applies. Manifest fixed. |

**General streaming guidance:**
- Total stream footprint drives client download size and server RAM. `assets_peds` alone dwarfs everything else — fixing it resolves the bulk of the streaming pressure.
- Run on SSD/NVMe. Large `stream/` folders on HDD cause exactly these HeartBeat timeouts.
- Confirm every heavy asset pack is actually `ensure`d in `server.cfg`; remove ones you don't use rather than streaming them for nothing.
