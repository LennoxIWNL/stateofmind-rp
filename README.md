# State of Mind RP

A QBCore-based FiveM roleplay server featuring a full economy, jobs, housing, custom vehicles, and more.

## Tech Stack

- **Framework:** QBCore
- **Database:** MySQL (via oxmysql)
- **Voice:** pma-voice with pa-radio
- **UI Libraries:** ox_lib, menuv, qb-menu, ps-ui
- **Target System:** qb-target with ox_lib support
- **Server Management:** txAdmin

## Resource Categories

| Folder | Description | Count |
|---|---|---|
| `[qb]` | Core QBCore framework resources (inventory, jobs, garages, phone, etc.) | ~40 |
| `[standalone]` | Independent libraries and utilities (ox_lib, PolyZone, emotes, fuel, etc.) | ~30 |
| `[custom]` | Custom/community scripts (MDT, HUD, shops, banking, spawn selector, etc.) | ~50 |
| `[new]` | Recently added resources (laptop, wounding, football, crypto, etc.) | ~15 |
| `[jobs]` | Job-specific resources (mechanic, farm, food delivery, chopshop, etc.) | ~10 |
| `[robberies]` | Robbery scripts (bank, store, house, ATM, truck, car heist) | 7 |
| `[voice]` | Voice chat (pma-voice + pa-radio) | 2 |
| `[system]` | Base events | 1 |

## Key Features

- **Multi-character** system with spawn selection
- **Custom HUD** (elixir-hud)
- **Police MDT** (ps-mdt) with dispatch (ps-dispatch)
- **Custom banking** (som-banking)
- **Vehicle system** with tracker, customs, and job garages
- **Drug system** (elixir-drugs, BakiTelli_weed)
- **Housing** (qb-houses + qb-apartments)
- **Robberies** (bank, store, house, ATM, truck, car heist, ammu)
- **K9 unit** and evidence system
- **Custom emotes** (som-emotes)
- **Skateboard & Roller Skating** activities
- **CCTV system** (bbv-cctv)
- **Train system** (XNL-FiveM-Trains)
- **Bodycam** (messy-bodycam)

## Setup

1. Copy `server.cfg.example` to `server.cfg`
2. Fill in your license key, Steam API key, and MySQL connection string
3. Place streaming assets (peds, vehicles, MLOs) in `[assets-streams]` if needed
4. Configure admin identifiers in `server.cfg`
5. Start the server via txAdmin

## Project Structure

```
txData/FiveMBasicServerCFXDefault_3A7DA0.base/
  server.cfg.example    # Template config (real cfg is gitignored)
  resources/
    [cfx-default]/      # Default CFX resources
    [qb]/               # QBCore framework
    [standalone]/        # Independent libraries
    [custom]/            # Community/custom scripts
    [new]/               # Recently added
    [jobs]/              # Job resources
    [robberies]/         # Robbery scripts
    [voice]/             # Voice chat
    [system]/            # Base events
```

## Notes

- `server.cfg`, streaming assets (`stream/` folders), and binary files (`.ytd`, `.yft`, `.ydd`, etc.) are gitignored to keep the repo lightweight
- The `[assets-streams]` folder (peds, vehicles, MLOs ~5GB+) must be set up separately on the server
- Boot grace period is set to 300s in txAdmin to accommodate large streaming assets

---

## Potential Future Tasks

- **Phone replacement** — Current `qb-phone` is dated; migrating to a modern phone (e.g. lb-phone, qs-smartphone, or npwd) would improve UX significantly but requires dependency mapping (camera, contacts, banking, dispatch integration)
- **Inventory upgrade** — Consider migrating from `qb-inventory` to `ox_inventory` for better performance, weight-based system, and active maintenance
- **Anti-cheat** — No anti-cheat resource detected; adding one (e.g. txAdmin's built-in, or a standalone AC) would protect against exploits
- **Webhook centralization** — Multiple scripts have hardcoded webhook URLs scattered across configs; a central webhook manager resource would make maintenance easier
- **ox_target migration** — Currently using `qb-target`; migrating to `ox_target` would improve performance (uses ox_lib zones instead of raycasting)
- **Job consolidation** — Several overlapping job resources (qb-cityhall + cityhallv1); audit and remove duplicates
- **Resource audit** — Some resources in `[new]` may be unused/experimental; disabling them would reduce boot time
- **Locale/translation** — Server is set to `en-US` but some scripts have untranslated strings; a locale pass would improve consistency
- **Custom loading screen** — The `loadingscreen` resource exists but could be refreshed with server branding
- **Database optimization** — Add indexes to frequently queried tables (players, vehicles, housing) for faster lookups at scale
