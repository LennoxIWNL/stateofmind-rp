# State of Mind RP — FiveM QBCore server

## Framework
- **QBCore v1.2.6** at `resources/[qb]/qb-core/` (uses `oxmysql` + `lua54`)
- **ox_lib v3.14.0** at `resources/[standalone]/ox_lib/`
- **oxmysql v2.7.5** at `resources/[standalone]/oxmysql/` (provides `mysql-async`)
- **ox_doorlock v1.14.4**, **qb-target**, **qb-inventory v1.0.2**, **pma-voice**
- DB convar: `set mysql_connection_string` in `server.cfg` (file is gitignored; see `server.cfg.example`)

## Resource layout
All resources live under `txData/FiveMBasicServerCFXDefault_3A7DA0.base/resources/`.

| Folder | Purpose |
|---|---|
| `[qb]` | QBCore ecosystem (47 resources) |
| `[custom]` | Mixed custom + third-party (53 resources) |
| `[standalone]` | Framework-agnostic libs & tools (33) |
| `[jobs]/[public\|owned\|illegal\|chopshop]` | Job resources (27 total) |
| `[new]` | Recently added / testing (15) |
| `[robberies]` | Heist & robbery scripts (7) |
| `[anticheats]` | Lennox-Anticheat (main branch only) |
| `[voice]` | pma-voice, pa-radio |
| `[system]` | baseevents |
| `[cfx-default]` | Stock cfx resources |

**Our code** (som-* / Lennox-*): `som-banking`, `som-carcontrol`, `som-deathscreen`, `som-jobsetup`, `som-lib`, `som-lockpick`, `som-notify`, `som-playerlist`, `som-rentacar`, `som-scoreboard`, `som-spray`, `som-text`, `som-textui`, `som-zones`, `som-towtruck`, `som-neons`, `som-emotes`, `Lennox-Anticheat`, `Lennox-NUIBlocker`.

**Third-party** (do not rewrite; config edits only): everything in `[qb]` except `som-*`, all Overextended resources, elixir-*, jim-*, randol_*, ps-*, BakiTelli_*, kloud-*, cdn-fuel, dpemotes, PolyZone, etc.

## Skills
Load the matching FiveAI skill from `.claude/skills/` **before** writing any FiveM code:
- `fivem-basics` — resource structure, fxmanifest, client/server/shared, events
- `lua-basics` — Lua patterns for FiveM
- `qbcore-framework` — QBCore APIs: PlayerData, jobs, gangs, economy, inventory
- `oxlib` — ox_lib notify/alert/input/menu/progress, callbacks, zones
- `oxmysql` — query/insert/update/single/scalar/prepare/transaction
- `fivem-nui` — NUI HTML/CSS/JS and callbacks
- `fivem-security` — server authority, event validation, anti-exploit (**always load**)

Source: `github.com/germanfndez/fiveai-skills`

## Hard security rules (non-negotiable)
1. Server is the authority — money, bank, inventory, items, jobs, gangs, permissions are validated and mutated **server-side only**; never trust the client.
2. Every `RegisterNetEvent` handler validates `source` and all arguments (type, range, existence).
3. Events use namespaced names: `resourcename:server:action` / `resourcename:client:action` (match existing `som-*:` prefix).
4. Admin actions check ACE (`qbcore.god`, `group.admin`) or framework permission groups — never a client-sent flag.
5. Never invent natives or exports; confirm they exist in the installed resource versions before using them.
6. Client events stay thin — no reward calculation, no inventory mutation, no permission decisions.

## Workspace rules
- Edit code only; never touch binary assets: `stream/`, `*.ytd`, `*.yft`, `*.ydr`, `*.ydd`, `*.ybn`, `*.gfx`, `*.dds`, audio packs, `cache/`, or txData artifacts outside `resources/`.
- Always work on a branch; prefer small reviewable patches over generating whole resources.
- `server.cfg` is gitignored — edit `server.cfg.example` for config changes.

## Conventions
- `local` by default; early-return on failure; config separate from logic.
- No per-frame `Citizen.CreateThread` + `Wait(0)` loops unless rendering or input demands it; use events or longer intervals.
- Access QBCore via `exports['qb-core']:GetCoreObject()`, not by event.
- ox_lib callbacks (`lib.callback`) preferred over raw event pairs for request/response flows.

## Done criteria
- `luacheck` passes if a `.luacheckrc` exists.
- Manual dev-server test for anything touching economy, inventory, persistence, or admin.
