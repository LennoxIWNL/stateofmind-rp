# State of Mind RP

A FiveM roleplay server running **SOM**, a custom framework written for this
server. Interaction-driven, phone-centric, low-command.

> **Status: rebuild in progress.** The QBox layer has been removed and SOM
> replaces it from the ground up. The framework boots and character selection
> works. There are no jobs, vehicles, housing or economy yet. This is not a
> playable server today.
>
> [AUDIT.md](AUDIT.md) is the build spec and the source of truth for what
> exists, what was removed, and what comes next.

---

## Stack

| Layer | Choice |
|---|---|
| Framework | **SOM** (`som-core`), no QBCore, ESX or Qbox |
| Database | MariaDB via `oxmysql` |
| Library | `ox_lib` |
| Inventory | `ox_inventory`, bridged to SOM |
| Interaction | `qb-target`, wrapped by `som-interact` |
| Voice | `pma-voice`, `pa-radio` |
| MDT | `ps-mdt`, preserved and unmodified |
| Management | txAdmin |

## The SOM resources

All under `resources/[som]/`. Each has its own README.

| Resource | Role |
|---|---|
| **som-core** | Players, characters, money, permissions, entitlements, state bags. Everything else depends on it. |
| **som-interact** | Wraps the target system behind a stable API, plus the single TextUI. |
| **som-ui** | Notifications. The one implementation behind `som:client:notify`. |
| **som-multichar** | Character selection, creation and spawn. |
| **som-theft** | Server-validated cash robbery. |
| **som-compat** | Fake `qb-core` export surface so preserved third-party resources run untouched. |
| **som-assets** | Shared design tokens. Every SOM NUI imports these. |

### How the framework is consumed

```lua
-- Server
local core = exports['som-core']
local player = core:getPlayer(source)
core:addMoney(source, 'bank', 500, 'salvage-payout')   -- always with a reason
core:hasPermission(source, 'som.admin')

-- Client
exports['som-core']:getPlayerData()
exports['som-interact']:addBoxZone({ name = ..., coords = ..., options = { ... } })
exports['som-ui']:notify('Payment received', 'success')
```

Three rules that hold everywhere:

1. **The server decides.** Money, items, jobs and permissions are validated and
   mutated server side only. A client requests; it never asserts.
2. **Money moves through one function.** Every balance change goes through
   `som-core`'s transaction bus and lands in `som_transactions` tagged with the
   calling resource. There is no second writer, and money is deliberately not
   an inventory item.
3. **Interactions are UI, not authority.** A target option being visible grants
   nothing. The server re-checks job, grade and distance on use.

## Repository layout

```
txData/FiveMBasicServerCFXDefault_3A7DA0.base/
  server.cfg.example        template, real server.cfg is gitignored
  resources/
    [som]/                  the framework
    [assets-streams]/       ~5GB of streamed content, gitignored
    [standalone]/           ox_lib, oxmysql, ox_inventory, PolyZone
    [custom]/               ps-mdt, qb-target, Lennox-*, stream holders
    [cfx-default]/          stock managers
    [voice]/  [anticheats]/
tools/
  phase1-teardown.ps1       the teardown script, dry run by default
```

143 loadable resources, down from 286 before the rebuild.

## Setup

1. **Database.** Create the schema, then import:
   ```
   mysql -u root -e "CREATE DATABASE IF NOT EXISTS stateofmindrp CHARACTER SET utf8mb4;"
   mysql -u root stateofmindrp < "resources/[som]/som-core/sql/som_schema.sql"
   ```
   Do **not** import `server_setup.sql` or `origenv2.sql`. They are the legacy
   QBCore and Origen schemas for resources that no longer exist.

2. **Config.** Copy `server.cfg.example` to `server.cfg` and fill in the
   licence key, Steam API key, MySQL string and your admin identifiers.

3. **Start** via txAdmin.

`som-core` prints `[som-core] ready. N jobs, N gangs.` when the schema is found.
If it reports missing tables, step 1 did not take.

## Development

`server.cfg` ships in **dev mode**: the framework only, skipping the ~5GB of
streamed assets and every leftover QBCore-dependent resource. It boots in
seconds. The full boot list sits directly below it, commented, with a note on
what has to happen before it can be enabled.

Also off in dev mode:

- **`connectqueue`**, whose `JoinDelay` holds every connection for two minutes
  after a restart.
- **`chat`**, which is *absent from this server entirely*. Only
  `chat-theme-gtao` is present, which is just a theme. Typed commands are
  therefore unreachable until `chat` is restored from the cfx-server-data repo.

Because chat is missing, dev tooling is on keys: **F10** opens live scene tuning
on the character screen, **F11** prints your coordinates. See
[som-multichar's README](txData/FiveMBasicServerCFXDefault_3A7DA0.base/resources/%5Bsom%5D/som-multichar/README.md).

Restart a single resource from the txAdmin console rather than the whole server;
only `server.cfg` changes need a full restart.

### Two patched third-party resources

Both must be re-applied after upgrading the resource:

- `ox_inventory/modules/bridge/som/` — the SOM framework bridge. ox resolves its
  bridge by folder name from a convar, so it cannot be supplied externally.
- `ox_inventory/web/build/assets/index-*.css` — hides a permanently rendered
  scrollbar track that drew a grey line across the screen.

## Documentation

| File | Contents |
|---|---|
| [AUDIT.md](AUDIT.md) | Build spec. Resource inventory, what was removed and why, design principles, command inventory, phase roadmap. |
| [patreon.md](patreon.md) | Supporter tiers and the non-pay-to-win rule. |
| `resources/[som]/*/README.md` | Per-resource exports, events and known gaps. |
| [CLAUDE.md](CLAUDE.md) | Conventions and security rules for contributors. |

## Roadmap

Phases 0 through 3 are done: audit, teardown, framework core, inventory bridge.

| Next | |
|---|---|
| **4** | Economy: business register, drug market saturation, laundering, sink and faucet instrumentation |
| **4b** | Phone: banking app over the ledger, Twitter, shareable account numbers |
| **4c** | `som-radial`, the F1 menu |
| **4d** | `som-admin`, custom admin tooling |
| **5** | Jobs: police with two-axis rank and clearance, EMS, mechanic, civilian templates |
| **6** | Gangs and turf, entirely greenfield |
| **7** | NUIs, including diegetic world-space UI where a physical anchor exists |
| **8** | Command minimisation |
| **9** | Production readiness |

Full detail, including entry gates and open decisions, in AUDIT.md sections 13
and 14.
