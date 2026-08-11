# SOM Framework Rebuild: Audit and Preserve

**Status:** Phase 0 complete. Nothing has been deleted or modified. The server is unchanged and bootable.
**Branch:** `som-rebuild-audit`
**This file is permanent.** Phase 8 of the rebuild spec requires it to survive to the end of the project. Section 10 (Command Inventory) is a living artifact that gets updated as systems are rebuilt.

Resource root for every path in this document:
`txData/FiveMBasicServerCFXDefault_3A7DA0.base/resources/`

There is no top-level `resources/` directory or symlink.

---

## 1. Purpose and locked decisions

This audit is the build spec anchor for Phases 1 through 9. It records what exists, what is worth keeping, and what SOM should do differently, before anything is destroyed.

Three decisions are locked by the project owner and are binding on later phases:

| Area | Decision | Consequence |
|---|---|---|
| **Inventory** | Keep `ox_inventory`. Point its framework bridge at `som-core` and reskin the NUI to the brand palette. Do not rewrite it. | Confirmed feasible, see section 6.4. Retains the anti-dupe layer in section 6.5. |
| **MDT** | `ps-mdt` stays byte-for-byte untouched. A `som-compat` resource registers a fake `qb-core` export surface backed by `som-core`. | Confirmed feasible, see section 7.3. `qbx_core` already does exactly this today. |
| **Keep-list** | Deferred to the Phase 1 gate. Section 11 presents the tiered manifest for approval. | Phase 1 cannot start until section 11 is signed off. |

A fourth decision is implied by the above and should be made explicit: **the "no third-party framework dependency" constraint is satisfied at the framework layer, not the resource layer.** `ox_inventory`, `ox_lib`, `oxmysql`, and `PolyZone` remain in the tree as libraries. What gets removed is `qbx_core` and everything that binds to it as a *framework*.

---

## 2. Corrections to CLAUDE.md

`CLAUDE.md` is materially stale. It is **not** edited in this phase, but the following must be corrected before or during Phase 2, because the rebuild spec was written against the wrong picture.

| CLAUDE.md says | Reality |
|---|---|
| "QBCore v1.2.6 at `resources/[qb]/qb-core/`" | `qb-core` carries `fxmanifest.lua.disabled` and does not load. The live core is **`qbx_core` v1.23.0**. |
| "qb-inventory v1.0.2" | `qb-inventory` carries `fxmanifest.lua.disabled`. The live inventory is **`ox_inventory` v2.45.0**. |
| "ox_doorlock v1.14.4" | Installed version is **v1.22.1**. |
| "All resources live under `.../resources/`" with a table of 10 groups | Correct, but the table omits **`[assets-streams]` (63 resources)** and `[local]` (empty), and understates counts. |
| "Our code (som-\* / Lennox-\*)" lists 19 resources as ours | **Nine of them carry escrow manifests indicating third-party origin.** See section 3.3. |
| `som-towtruck` listed without a location | It lives at `[jobs]/[public]/som-towtruck`. |
| "qb-target" listed plainly | It is **escrow-protected** (`dependency '/assetpacks'`). Its core cannot be read or forked. |

---

## 3. Resource inventory

**286 loadable resources** (directories containing `fxmanifest.lua` or `__resource.lua`), plus 22 disabled manifests.

### 3.1 Counts by group

| Group | Loadable | Notes |
|---|---:|---|
| `[assets-streams]` | 63 | Pure streaming. 24 are maps, 39 are clothing/vehicles/weapons/graphics/liveries. |
| `[custom]` | 57 | Mixed ours, rebranded, and third-party. |
| `[qb]` | 47 | QBox ecosystem plus job/heist scripts. |
| `[standalone]` | 36 | Libraries and framework-agnostic tools. |
| `[jobs]` | 35 | Sub-bucketed `[public]` 23, `[owned]` 5, `[chopshop]` 5, `[illegal]` 2. |
| `[cfx-default]` | 22 | Stock Cfx resources. |
| `[new]` | 15 | Testing and staging. |
| `[robberies]` | 7 | Heists. |
| `[voice]` | 2 | pma-voice, pa-radio. |
| `[anticheats]` | 1 | Lennox-Anticheat. |
| `[system]` | 1 | baseevents. |
| **Total** | **286** | Reconciles with section 11. |

Three of the 286 are **nested manifests inside a parent resource**, not standalone resources: `[custom]/elixir-petshop/MLO/Petshop`, `[custom]/qb-k9/som-shop`, `[standalone]/menuv/menuv_example`. They are deleted or kept with their parent.

### 3.2 Disabled and dead entries

Disabled (manifest renamed, does not load):
`[qb]/qb-core`, `[qb]/qb-inventory`, `[qb]/qb-phone.disabled`, `[custom]/ds-mdt`, `[standalone]/cityhallv1`, plus 17 stream packs in `[assets-streams]` (`assets_ped_anniversary`, `assets_peds_other_p2`, `assets_peds_p4`, `assets_peds_p5`, `chimp`, `dodobird`, `DougCanada`, `ig_mario`, the five `[rony-sounds]` packs, `rd-vehicleaudio`, `rd-vehicleaudio2`, `rd-xmas-vehicles`, `temp_vh`).

Dead (present but never loads or is unreferenced):
- `[custom]/som-elevator` has a `client/` folder and **no fxmanifest at all**, so it is invisible to the server. Delete without replacement.
- `[qb]/Elixir Inventory.zip` is an unextracted archive sitting loose in a resource group.
- `[custom]/[elixir-hud]/` contains a **second copy of `baseevents`** alongside `[system]/baseevents`.
- `resources/_disabled_maps/` and `resources/[local]/` are empty.

### 3.3 Provenance correction: which `som-*` resources are actually ours

An `escrow_ignore` block in an fxmanifest is written by an asset author packaging for FiveM Keymaster. Its presence is strong evidence a resource was purchased and rebranded rather than authored in-house. Nine `som-*` resources carry one:

| Resource | Escrow markers | Source readable? | Assessment |
|---|---|---|---|
| `som-banking` | `escrow_ignore` | Yes | Rebranded third-party. Also binds to `2na_core` (ESX shim), which no other resource uses. |
| `som-carcontrol` | `escrow_ignore` | Yes | Rebranded third-party. |
| `som-deathscreen` | `escrow_ignore` | Yes | Rebranded third-party. |
| `som-lockpick` | `escrow_ignore` | Yes | Rebranded third-party. Exports `acLockPick`, event prefix `ac:lockpick:`. |
| `som-playerlist` | `escrow_ignore` | Yes | Rebranded third-party. |
| `som-rentacar` | `escrow_ignore` | Yes | Rebranded third-party. |
| `som-scoreboard` | `escrow_ignore` **and** `dependency '/assetpacks'` | Yes | Rebranded third-party, asset-pack gated. |
| `som-text` | `escrow_ignore` | Yes | Rebranded third-party. |
| `som-emotes` | `escrow_ignore` | Yes | Rebranded third-party. |

Additional evidence of rebranding without rewriting: **`som-spray` is `rcore_spray`.** Every one of its net events is still namespaced `rcore_spray:*` (`rcore_spray:addSpray`, `rcore_spray:spray`, `rcore_spray:setSprays`, ...), and it registers a command `rcsprayshowlicense`.

In all nine cases the Lua is plain text and editable, so nothing is blocked. The point is planning accuracy: these are **not** in-house code that can be ported cheaply, and their internals were never designed by us.

Genuinely in-house, by the absence of escrow markers and consistent `som-*:` event namespacing:
`som-gangboss-app`, `som-jobsetup`, `som-lib`, `som-notify`, `som-textui`, `som-zones`, `som-neons`, `som-towtruck` (partly, it is framework-agnostic with an ESX/QB `getCore` shim), and the three `Lennox-*` resources.

---

## 4. Preserve list

Exact paths, because Phase 1 deletes around them.

### 4.1 MDT

`[custom]/ps-mdt` (v2.5.4, Project Sloth "EchoRP MDT Rewrite").
Migration SQL lives **outside** the resource at `txData/FiveMBasicServerCFXDefault_3A7DA0.base/ps-mdt-migrate.sql`. Do not delete it with the base-folder cleanup.
`[custom]/ds-mdt` is a disabled alternative MDT and is **not** covered by the preserve mandate.

### 4.2 Lennox resources

- `[anticheats]/Lennox-Anticheat`
- `[custom]/Lennox-NUIBlocker`
- `[standalone]/Lennox-DoorCreator` (ships `sql/migrate_ox.sql`, `secrets.lua.example`, `web/`, `build/`)

### 4.3 Maps and MLOs

`[assets-streams]/[maps]`, 24 resources, with map-file counts:

| Resource | Map files | Resource | Map files |
|---|---:|---|---:|
| ex-maps | 304 | pablito_taco | 6 |
| gabz_sheriff | 42 | UniqueFamily_fleecabank | 5 |
| ex-prison | 32 | luxury_auto | 5 |
| elixir-pillbox | 24 | cityhallv2 | 5 |
| mrpd | 20 | spike_limeys | 3 |
| tuners | 13 | bobcat_mlo | 3 |
| uniqx_burgershot | 12 | petshop_map | 2 |
| elixir-harmony | 11 | lev_apartment | 2 |
| catcafe | 8 | UniqueFamily_mapdata | 1 |
| dons_hotel_1a | 7 | cfx-gabz-lscustoms | 1 |
| pablito_cafe | 6 | | |

Plus `cfx-gabz-davispd`, `cfx-gabz-pdprops`, `cfx-gabz-mapdata` (capital `Stream/` directories holding props, entitysets, timecycles).

**Map content outside `[maps]`, easily lost in a bulk delete:**
- `[jobs]/[public]/[doj-casino]/DLCiplLoader` (31 map files)
- `[assets-streams]/[extras]/PacificBankExtendedMLOv1` (3)
- `[assets-streams]/[graphics]/karma-graphics-worldprops` (98), `karma-graphics-coastline` (19), `karma-graphics-vegetation` (4), `karma-world-props` (2)
- `[custom]/elixir-petshop/MLO/Petshop/stream` (3), nested inside a script resource
- `[custom]/XNL-FiveM-Trains-U3` (1), `[qb]/qb-smallresources` (21), `[qb]/qb-interior` (2), `[standalone]/dpemotes` (4), `[standalone]/cdn-fuel` (2), `[standalone]/ajnaems` (1), `[jobs]/[public]/som-towtruck` (1), `[jobs]/[public]/jim-recycle` (1), `[new]/punchmachine_prop` (3)
- `[standalone]/cityhallv1` (6, disabled)

Deleting `qb-smallresources` or `dpemotes` for framework reasons silently removes streamed props. Extract the `stream/` folders into a `som-props` resource before removing the parent.

### 4.4 Branding assets (relocate into `som-assets` before Phase 1)

- `[custom]/loadingscreen/nui/dist/assets/som-logo.png` (436,499 bytes, transparent PNG, the pink graffiti wordmark)
- `[custom]/loadingscreen/nui/dist/assets/logo-187456c5.png` (byte-identical duplicate, the Vite-hashed original)
- `txData/FiveMBasicServerCFXDefault_3A7DA0.base/myLogo.png` (599,763 bytes, square txAdmin server icon)
- Decorative SVGs in the same folder: `bgLogo-28542b40.svg` (hex frame motif), `logoProgress-8e2224ea.svg` (hardcodes `#ff1493`), `progressBg-`, `buttonTop-`, `buttonBottom-`, `socialBg-`, `dots-`, `store-`, `twitter-`, `youtube-`

---

## 5. Branding and visual identity

### 5.1 Extracted palette

| Token | Hex | Role | Occurrences |
|---|---|---|---:|
| `--som-pink` | `#ff1493` | Primary brand, borders, active states | 43 in `som-*`, 10 in ox_inventory, 4 in loadscreen |
| `--som-pink-light` | `#ff69b4` | Hover, glow, secondary accent | 12 + 6 |
| `--som-pink-dark` | `#c2185b` | Pressed states | 2 |
| `--som-magenta-deep` | `#b10f7c` | Deep accent | 1 |
| `--som-violet` | `#E566E8` | Violet-pink variant | 3 |
| `--som-bg` | `#0a0a12` | Page background | many |
| `--som-bg-deep` | `#08060a` | Deepest background | several |
| `--som-surface` | `#3d1735` | Plum panel surface | ox_inventory reskin |
| `--som-text` | `#e0e0e0` | Body text | many |
| `--som-danger` | `#e74c3c` | Error | 2 |
| `--som-success` | `#2ecc71` | Success | 2 |

Glow convention already in use: `rgba(255, 20, 147, α)` with α across `.16 / .25 / .30 / .45 / .61 / .8`.

This triad matches the logo art itself (light pink fill around `#f2a8cf`, mid pink shading around `#e8629f`, dark plum outline around `#2d0b3f`).

### 5.2 There is no shared design token file

Confirmed absent. Every resource hardcodes its own hex values. The only two `:root` blocks in the entire `som-*` set are duplicated and **already drifting**:

| Token | `som-gangboss-app/html/index.html:8` | `som-jobsetup/html/index.html:7` |
|---|---|---|
| `--pink` | `#FF1493` | `#FF1493` |
| `--pink-dim` | `rgba(255,20,147,.2)` | `rgba(255,20,147,.25)` |
| `--bg` | `#0a0a12` | `rgba(10,10,18,.96)` |
| `--card` | `rgba(25,25,35,.95)` | `rgba(25,25,35,.9)` |
| `--dim` | `#666` | `#777` |
| `--radius` | `10px` | `8px` |

**Phase 7 contract:** `som-assets` ships one `tokens.css` defining the section 5.1 table as CSS custom properties. Every `som-*` NUI adds it to its `files{}` and imports it. No resource redefines a token locally. The two blocks above are the migration source.

### 5.3 Known rebrand residue (teal under pink)

The previous teal-to-pink rebrand was a hex find and replace, so pink accents now sit on unconverted teal backgrounds. Fix during the Phase 7 reskin, or drop with the resource:

- `[custom]/som-lib/html/main.css:64` teal radial gradient `#1b6f5ef2 / #0f3b32f2 / #145346f2` under a pink icon glow on line 65
- `[custom]/som-lib/html/index.js:87` same `#1b6f5ef2` generated inline
- `[custom]/som-textui/ui/style.css:31-32` pink border over `rgba(3, 60, 56, 0.55)` background and `rgba(10, 116, 103, 0.35)` shadow
- `[custom]/som-banking/UI/styles/style.css:144,154,471` cyan `#2dcfeb` and dark teal `#02222c`

The `ox_inventory` reskin (commit `7c788a62`) is clean and has no residue. Use it as the reference implementation.

### 5.4 Branding strings and rich presence

`server.cfg.example` (mirrored in the live `server.cfg`):
```
sets tags "default, deployer, qbox, ox_inventory"
sv_hostname "State of MindRP By Lennox!"
sets sv_projectName "[Qbox Framework] State of MindRP"
sets sv_projectDesc "An advanced FiveM RP framework including jobs, gangs, housing & more!"
```
Note the inconsistency: config says "State of MindRP", loading screen and manifests say "State of Mind RP". Standardise in Phase 9. The `tags` and `sv_projectName` values advertise Qbox and must change.

**Discord rich presence is on vendor defaults and visible to every player right now.** `[qb]/qbx_core/config/client.lua:54-78` is enabled and ships Qbox boilerplate: app id `1024981890798731345`, icon `duck`, text "Qbox Ducky", buttons linking to `discord.gg/Z6Whda5hHA` and `qbox.re`. The real invite (`https://discord.gg/9QdBP7cgXj`) sits in `[qb]/qb-smallresources/config.lua:51-70`, which is **disabled** (`isEnabled = false`, placeholder app id). SOM must own rich presence in `som-core`.

The loading screen is a rebranded NoPixel 4.0 bundle. `[custom]/loadingscreen/nui/dist/index.html` runs a `setInterval` that rewrites leftover "NoPixel 4.0" text nodes to "State of Mind RP" at runtime, and its favicon points at a dev-time path `/src/assets/favicon.ico` that was never shipped to `dist`. Rebuild rather than reskin.

---

## 6. Inventory deep dive (`ox_inventory` v2.45.0)

### 6.1 Item data structure

Items are a table keyed by name in `data/items.lua`:
```lua
['testburger'] = {
  label, weight, degrade, stack, close, description, consume,
  client = { image, status = { hunger = 200000 }, anim, prop, usetime, export, disable },
  server = { export },
  buttons = { { label, group, action = function(slot) end } },
}
```
`weight` is **integer grams**. `degrade` is minutes. `consume` is fractional (`0.3` for partial use). `client.status` maps into the needs system. `client.export` and `server.export` route use-effects into other resources, which is the extension seam SOM job scripts should use. Weapons are separate, in `data/weapons.lua`.

### 6.2 Slot and weight configuration

There is **no `config.lua`**. Everything is convar driven, declared in `init.lua:17-26` and overridden in `server.cfg`:

| Convar | Default | Live value |
|---|---:|---:|
| `inventory:slots` | 50 | **40** |
| `inventory:weight` | 30000 | **120000** (120 kg) |
| `inventory:framework` | esx | **qbx** |
| `inventory:target` | 0 | **false** |
| `inventory:police` | `["police","sheriff"]` | **`["police"]`** |
| `inventory:evidencegrade` | 2 | 2 |

Other knobs: `dropslots`, `dropweight`, `vehicleloot`, `dumpsterloot`, `randomloot`, `randomprices`, `bulkstashsave`, `loglevel`, `trimplate`, `autoreload`, `dropprops`, `dropmodel`, `weaponmismatch`, `enablestealcommand`.

`inventory:target false` means ox_inventory uses its own drop and marker UI rather than routing through qb-target. Preserve this, or `som-interact` will need to absorb the drop interaction.

### 6.3 Containers and stashes

`data/vehicles.lua` holds a `Storage` table mapping model hashes to `0` (none), `1` (no trunk), `2` (no glovebox), `3` (trunk in hood). `glovebox` and `trunk` tables are keyed by **vehicle class id** with `{slots, maxWeight}`, for example glovebox classes 0-7 give `{11, 88000}` and class 8 (motorcycle) gives `{5, 40000}`. The default heuristic is 8000 weight per slot.

`data/stashes.lua` is an array of `{ coords, target = {loc,length,width,heading,minZ,maxZ,label}, name, label, owner, slots, weight, groups }`. `owner = true` makes it per-player. `groups = shared.police` gates by job. Dynamic registration is available via the server exports `RegisterStash(id, label, slots, maxWeight, owner, groups, coords)` and `CreateTemporaryStash`. Gang stashes, evidence lockers, and drug labs in Phases 5 and 6 should use these rather than inventing a parallel storage system.

### 6.4 The bridge is pluggable (validates the locked decision)

`modules/bridge/` contains one subfolder per framework: `esx/`, `nd/`, `ox/`, `qbx/`, each with `client.lua` and `server.lua`. Both loaders resolve the folder by name from the convar:

- `modules/bridge/server.lua:64` : `pcall(lib.load, ('modules.bridge.%s.server'):format(shared.framework))`
- `modules/bridge/client.lua:78` : `pcall(lib.load, ('modules.bridge.%s.client'):format(shared.framework))`

So a SOM bridge is `modules/bridge/som/{client,server}.lua` plus `setr inventory:framework "som"`. The contract is small. Modelled on `qbx/server.lua` (107 lines total), a bridge must provide:

| Function | Purpose |
|---|---|
| `server.UseItem(source, itemName, data)` | Route item use into the framework |
| `server.setPlayerData(player)` | Populate inventory-side player identity |
| `server.syncInventory(inv)` | Push weight/money changes back to the framework |
| `server.hasLicense(inv, license)` | License lookup |
| `server.buyLicense(inv, license)` | License purchase |
| `server.isPlayerBoss(playerId, group, grade)` | Boss-grade check for society stashes |
| `server.getOwnedVehicleId(entityId)` | Vehicle ownership for trunk/glovebox |
| `server.hasGroup(inv, groups)` | Job/gang gating (used by evidence and stash access) |
| `server.playerDropped` / `server.convertInventory` | Lifecycle and migration |
| `client.setPlayerStatus(values)` | Push hunger/thirst/stress into the needs system (`qbx/client.lua` is 30 lines) |

**Maintenance cost to record:** the bridge folder lives inside `ox_inventory`, so adding `som/` makes this a patched copy. Pin the version, keep the patch as a documented diff in `som-core/docs/`, and re-apply on upgrade. This is the only place SOM code lives outside a `som-*` resource.

### 6.5 Anti-dupe and validation invariants (do not lose these)

This is the strongest security layer in the current stack. Any future rewrite of `som-inventory` must reproduce all nine, and the Phase 2 transaction bus should copy patterns 1, 2, 3 and 6 wholesale.

1. **All mutations are server callbacks, not net events.** `lib.callback.register('ox_inventory:swapItems' | 'openInventory' | 'useItem' | 'getInventory' | 'getItemCount' | 'buyLicense')`. A client cannot fire a raw `AddItem`.
2. **Slot-level mutex.** `swapItems` (`modules/inventory/server.lua` around line 1660) builds `'%s:%s':format(inventoryId, slot)` refs for source and destination, rejects the move if either is already active, and releases both through a `<close>` deferred handler. This is the concurrency dupe guard.
3. **Ownership is re-derived, never trusted.** `swapItems` ignores the client-declared inventory id. The "other" inventory is always resolved as `Inventory(playerInventory.open)`, that is, whatever the server recorded the player as having open. `openInventory` additionally enforces `if invType == 'player' and source ~= data then`.
4. **Distance gating** on stashes, drops, and dumpsters (`stash.distance or 10`, plus a 16.0 entity-distance check at `server.lua:149`).
5. **`Inventory.Lock`**, a global freeze used during saves and restarts, blocks both opening and mutation.
6. **Hook veto system** (`modules/hooks/`): `exports:registerHook(event, cb, options)` and `removeHooks(id)`, firing `TriggerEventHooks('swapItems' | 'usingItem' | 'buyItem' | 'createItem')`. Any hook returning false vetoes the action. **This is the extension point for SOM job and gang rules, and it means custom anti-dupe logic never requires forking the inventory.**
7. **Job and grade gating on evidence.** `swapItems` calls `server.hasGroup(playerInventory, shared.police)` and compares against `server.evidencegrade` before allowing evidence removal.
8. **Provenance logging.** `GetInvokingResource()` is recorded via `lib.logger` on every `addItem` and `removeItem` when `inventory:loglevel > 1`. Feeds the Phase 4 audit ledger directly.
9. **`usingItem` state machine.** `inventory.usingItem` is set and cleared server side and re-validated by a `lib.callback.await('ox_inventory:usingItem', ...)` round trip, so item effects cannot be spammed from the client.

### 6.6 Public API surface

Server exports: `Inventory`, `GetInventory`, `GetInventoryItems`, `GetContainerFromSlot`, `RemoveInventory`, `UpdateVehicle`, `GetItem`, `SwapSlots`, `SetItem`, `GetCurrentWeapon`, `GetSlot`, `SetDurability`, `SetMetadata`, `SetSlotCount`, `SetMaxWeight`, `AddItem`, `Search`, `GetItemSlots`, `RemoveItem`, `CanCarryItem`, `CanCarryAmount`, `CanCarryWeight`, `CanSwapItem`, `CustomDrop`, `CreateDropFromPlayer`, `ConfiscateInventory`, `ReturnInventory`, `ClearInventory`, `GetEmptySlot`, `GetSlotForItem`, `GetSlotWithItem`, `GetSlotIdWithItem`, `GetSlotsWithItem`, `GetSlotIdsWithItem`, `GetItemCount`, `RegisterStash`, `CreateTemporaryStash`, `InspectInventory`, `setPlayerInventory`, `forceOpenInventory`, `Items`, `ItemList`, `ConvertItems`.

Client exports: `openInventory`, `openNearbyInventory`, `closeInventory`, `useItem`, `useSlot`, `giveItemToTarget`, `setStashTarget`, `getCurrentWeapon`, `Search`, `GetPlayerItems`, `GetPlayerWeight`, `GetPlayerMaxWeight`, `GetSlotWithItem`, `GetSlotIdWithItem`, `GetSlotsWithItem`, `GetItemCount`, `Items`, `ItemList`, `displayMetadata`, `Keyboard`, `Progress`, `CancelProgress`, `ProgressActive`.

---

## 7. Interaction system

### 7.1 qb-target is escrow-protected

`[custom]/qb-target/fxmanifest.lua` carries `dependency '/assetpacks'` and an `escrow_ignore` list covering only `client.lua`, `compat/*.lua`, `init.lua`, `data/bones.lua`. **The core is encrypted and cannot be read or forked.** It also has no `version` field, so it is an edited or unversioned copy with no upgrade path. This is precisely why the rebuild spec says wrap rather than replace.

Native exports (PascalCase, qb-target v3 style):
- Zones: `AddCircleZone`, `AddBoxZone`, `AddPolyZone`, `AddComboZone`, `AddEntityZone`, `RemoveZone`
- Entities: `AddTargetEntity`, `RemoveTargetEntity`, `AddTargetModel`, `RemoveTargetModel`, `AddTargetBone`, `RemoveTargetBone`
- Globals: `AddGlobalType`, `AddGlobalPed`, `AddGlobalVehicle`, `AddGlobalObject`, `AddGlobalPlayer` and their `Remove` counterparts
- Introspection: `GetZoneData`, `GetTargetEntityData`, `GetTargetModelData`, `GetTargetBoneData`, `GetGlobalTypeData`, `GetGlobalPedData`, `GetGlobalVehicleData`, `GetGlobalObjectData`, `GetGlobalPlayerData`, `GetPeds`, plus matching `Update*Data` and `SetOptions`
- Peds: `SpawnPed`, `RemoveSpawnedPed`, `DeletePeds`
- State: `RaycastCamera`, `CheckEntity`, `CheckBones`, `IsTargetActive`, `IsTargetSuccess`, `AllowTargeting`, `DisableTarget`, `DisableNUI`, `EnableNUI`, `LeftTarget`, `DrawOutlineEntity`

### 7.2 `som-interact` wraps the lowercase surface

`compat/ox_target.lua` registers ox_target-style exports under other resource names via `__cfx_export_<resource>_<name>` handlers, normalising option hashmaps to arrays and defaulting `distance = 2.5`, `minZ = -100`, `maxZ = 800`.

Available: `addBoxZone`, `addPolyZone`, `addSphereZone`, `removeZone`, `addLocalEntity`, `removeLocalEntity`, `addModel`, `removeModel`, `addGlobalPed`, `removeGlobalPed`, `addGlobalVehicle`, `removeGlobalVehicle`, `addGlobalObject`, `removeGlobalObject`, `addGlobalPlayer`, `removeGlobalPlayer`.

**Decision: `som-interact` wraps this lowercase set, not the PascalCase natives.** It is smaller, it is the shape a future ox_target swap expects, and it is in an `escrow_ignore` file so its behaviour is readable. `som-interact` exposes `som:client:addBoxZone` style exports and every future `som-*` resource calls only those, so the underlying target system is swappable in one file.

### 7.3 `som-compat`: the pattern already exists in-tree

`ps-mdt` calls `exports['qb-core']:GetCoreObject()` in `client/main.lua:1`, `client/cl_mugshot.lua:1`, `server/main.lua:1`, and `server/dbm.lua:1`. `qb-core` is disabled. It works today because **`qbx_core` declares `provide 'qb-core'` (`fxmanifest.lua:72`) and implements a full shim at `bridge/qb/client/main.lua:70` and `bridge/qb/server/main.lua:122` via `createQbExport('GetCoreObject', ...)`.**

`som-compat` copies this pattern exactly. The complete surface `ps-mdt` requires is only 14 members:

| Member | Used for |
|---|---|
| `QBCore.Functions.GetPlayer` | Server-side player lookup |
| `QBCore.Functions.GetPlayerByCitizenId` | Profile and conviction lookups (`server/dbm.lua`) |
| `QBCore.Functions.GetPlayerData` | Client-side player data |
| `QBCore.Functions.GetIdentifier` | License identifier |
| `QBCore.Functions.CreateCallback` | Server callback registration |
| `QBCore.Functions.TriggerCallback` | Client callback invocation |
| `QBCore.Functions.Notify` | Notifications (route to `som-notify`) |
| `QBCore.Functions.GetPlate` | Plate from vehicle entity |
| `QBCore.Functions.SpawnVehicle` | Impound release |
| `QBCore.Functions.SetVehicleProperties` | Impound release |
| `QBCore.Functions.RequestAnimDict` | Mugshot animation |
| `QBCore.Commands.Add` | Registers `mdtleaderboard` |
| `QBCore.Shared.Vehicles` | Vehicle display names |
| `QBCore.Shared.Items` | Item display names |

`ps-mdt` also depends on the callback `qb-garage:server:GetVehicleProperties` (`client/cl_impound.lua:50`) and the event `vehiclekeys:client:SetOwner` (line 57). Both come from resources on the delete list, so `som-compat` must provide them too, or impound release breaks silently.

### 7.4 Duplication to collapse

**Three interaction systems coexist:**
- `[custom]/qb-target` (raycast target, escrowed, primary, `setr UseTarget true`)
- `[qb]/interact` (QBox press-to-interact: `AddInteraction`, `AddLocalEntityInteraction`, `AddEntityInteraction`, `AddModelInteraction`, `AddEntityBoneInteraction`, `AddGlobalVehicleInteraction`, `addGlobalPlayerInteraction`, plus `Remove*`, `RemoveInteractionOption`, `UpdateInteraction`, `Disable`)
- `[custom]/som-zones` (thin PolyZone wrapper, client only: `CreateBoxZone`, `CreatePolyZone`, `CreateCircleZone`, `CreateEntityZone`, `DestroyZone`)

`som-zones` is already the right shape for the abstraction. **Grow `som-zones` into `som-interact` rather than starting fresh.**

**Two PolyZone copies load simultaneously:** `[standalone]/PolyZone` and `[standalone]/elixir-polyzone`.

**TextUI is triplicated:**
- `[custom]/som-textui` (10 exports: `Open`, `Close`, `AddTextUI`, `AddTextUIPed`, `OpenC`, `CloseC`, `drawText`, `drawTextClose`, `drawTextPress`, `changeText`)
- `[custom]/som-text` (2 exports: `openTextUi`, `closeTextUi`)
- `[custom]/pa-textui-2` (escrowed, ensured explicitly at `server.cfg:66`)

Collapse to one, inside `som-interact`, exposing `som:client:showTextUI` / `hideTextUI`.

**`som-lib` has zero exports** despite the name. It is a notification and item-info NUI, not a library. The name is misleading and should not be carried forward.

---

## 8. Per-system notes: what it did well, what SOM should do instead

### 8.1 Police (`[qb]/qb-policejob`, ~4,500 lines)

**Did well.** A genuinely deep evidence suite that already meets much of the Phase 5 "NoPixel depth" bar: blood drops, fingerprints, shell casings, and DNA all flowing into an evidence stash; ANPR and radar guns; plate flagging; security cameras (`Config.SecurityCameras`); helicopter spotlight; GPS trackers on vehicles. Player interaction verbs are complete: cuff, uncuff, escort, kidnap, put in and out of vehicle, search, seize cash, seize licence, rob, jail, bill. Armoury and garage access are gated per grade via `Config.AuthorizedVehicles`. Spike strips capped at `Config.MaxSpikes = 5`, plus placeable cones and barriers.

**What SOM should do instead.** Nearly every verb above is a chat command (`/cuff`, `/escort`, `/jail`, `/seizecash`, `/fine`, `/takedna`, ...). All of them have a physical anchor, a target player within arm's reach, and must become `som-interact` entries on the player entity, gated by job and grade server side. Evidence should carry structured metadata (collector citizen id, timestamp, coordinates, case id) so `ps-mdt` can chain it into an incident, rather than being an opaque item. Grade checks currently live in client code in several paths and must move server side. The `cdn-fuel` export dependency for refuelling police vehicles should become an `som-core` service so the job resource does not bind to a fuel implementation.

### 8.2 EMS and injury (`[qb]/qb-ambulancejob`, `[new]/BC_Wounding`)

**Did well.** The most sophisticated system in the stack. Per-limb damage tracking; bleed levels with tick damage, screen fadeout, and blackout; weapon-class tables mapping to minor, major, or always-bleed outcomes; painkillers; head, arm, and leg injuries with distinct timed side effects. Death flows into a laststand state (`DeathTime = 300`, `ReviveInterval = 360`). Hospital NPC check-in is gated on `MinimalDoctors = 2` being on duty, which is a good pressure valve that pushes players toward real EMS roleplay, with `BillCost = 2000` and an `AIHealTimer` fallback.

**What SOM should do instead.** Keep the entire injury model, it is the reference design for `som-core` metadata (`injuries`, `bleeding`, `pain`). **Reconcile the two competing wounding systems first:** `qb-ambulancejob/client/wounding.lua` and `[new]/BC_Wounding` both run, and `qb-inventory` even ships a `For Damage & BC_Wounding.lua` patch file. Pick one model and delete the other. `WipeInventoryOnRespawn = true` is a harsh faucet-drain that interacts with the Phase 4 economy and should become configurable. Injury state belongs in the `som-core` state bag so the MDT, the HUD, and EMS all read one source without polling.

### 8.3 Jobs (`[qb]/qbx_core/shared/jobs.lua` plus ~35 job resources)

**Did well.** Jobs are already **data, not code**, which is exactly the Phase 5 requirement. The shape is clean and should be the seed for the `som-jobs` schema:
```lua
police = {
  label = 'Law Enforcement',
  type = 'leo',
  defaultDuty = true,
  offDutyPay = false,
  grades = {
    [0] = { name = 'Recruit', payment = 50 },
    [4] = { name = 'Chief', isboss = true, payment = 150 },
  },
}
```
Paychecks are core-driven in `qbx_core/server/loops.lua` with `config.money.paycheckTimeout` and a `paycheckSociety` toggle deciding whether pay is drawn from the society account. Society funds and boss menus come from `[qb]/qb-management` (`AddBossMenuItem`, `RemoveBossMenuItem`, `AddGangMenuItem`, `RemoveGangMenuItem`).

**What SOM should do instead.** Keep the definition shape and extend it with the fields Phase 4 needs: `businessId` linking the job to a business register entry, `taxRate`, `revenueSource`, and per-grade `armoryAccess` and `radioChannel` so police and EMS specifics stop living in job scripts. The `paycheckSociety` toggle is the correct hook for "jobs pay from a business register that tracks revenue": make it mandatory rather than optional, so payroll always debits a real account and never mints money.

Job *content* is spread across 35 resources with wildly inconsistent quality, and consolidating them into one `som-jobs` data format is the single largest chunk of Phase 5. `[custom]/som-jobsetup` (ours) is worth preserving in spirit: it is an in-game NUI that relocates job interaction and garage points, persisting to `data/points.json` and hot-patching resource configs through `server/jobpatch.lua` with timestamped backups. That is a config rewriter working around the absence of a job registry. **In SOM it becomes a first-class feature:** job locations live in the database, and the setup NUI edits rows instead of patching Lua files.

### 8.4 Gangs (`[qb]/qbx_core/shared/gangs.lua`, `[custom]/som-gangboss-app`)

**Did well.** `som-gangboss-app` (genuinely ours) is a solid roster management NUI: `getRoster`, `getNearby`, `hire`, `fire`, `setGrade`, `getCustomRanks`, `setCustomRank`, with `Config.MaxHireDistance = 10.0` forcing hiring to be a physical act, and per-gang custom rank labels. Around 13 gangs are defined (`lostmc`, `ballas`, `vagos`, `cartel`, `families`, ...).

**What SOM should do instead.** **There is no turf system. Grepping `turf` across all 286 resources returns nothing, so Phase 6 is entirely greenfield.** Gang definitions currently have no `payment` field, unlike jobs, so gangs have no economic identity at all. Gang-flavoured content exists but is scattered and territory-blind: `qb-traphouse`, `qb-drugs`, `qb-weed`, `elixir-drugs`, the `[illegal]` jobs, and `som-spray` graffiti. **None of them read gang grade or location to decide anything.** That is the gap Phase 6 fills: those existing activities become the control-point earners for the turf system rather than new mechanics being invented alongside them. `som-gangboss-app` is the natural host for the gang bank cut and shared stash UI, and `Config.MaxHireDistance` is the precedent for making every turf action an interaction.

### 8.5 Economy and banking (`[custom]/som-banking`, `[qb]/qb-management`)

**Did well.** `som-banking` has a real multi-account model rather than a single balance: an `accounts` table (`identifier`, `id`, `name`, `balance`, `transactions`) plus a synthetic "Personal Account" keyed `si:<source>` that maps onto the core bank balance. Deposit, withdraw, and transfer all run through server callbacks. `Config.BankLocations`, `Config.ATMProps`, and `Config.ShowBlips` are cleanly separated from logic.

**What SOM should do instead.** Three structural problems.

First, **`som-banking` is built on `2na_core`, an ESX-style shim** (`exports["2na_core"]:getSharedObject()`, `TwoNa.RegisterServerCallback`, `TwoNa.MySQL.Sync.Fetch`, `xPlayer.getBank()`), and it is the only consumer of that resource in the entire tree. This is a third framework running alongside qbx_core. It must go.

Second, **transactions are a JSON blob in a column**, which cannot be queried, audited, or reconciled. Phase 4 requires a real ledger: one row per transaction with `from_account`, `to_account`, `amount`, `type`, `reason`, `resource`, `timestamp`. Pattern 8 in section 6.5 (`GetInvokingResource()` provenance logging) is the model to copy.

Third, **money creation is scattered**. Faucets currently include `qbx_core` paychecks, `qb-management` society funds, `qb-crypto` and `razed-cryptomining`, `qb-pawnshop`, the casino resources, and every job script that grants payment directly. Sinks include `ac-shop`, `pa-vehicleshop`, `qb-parkingmeter`, `cdn-fuel`, and repair costs. Nothing measures the ratio. The Phase 4 transaction bus must be the only path that mints or destroys money, so faucet and sink totals become a query rather than a guess.

### 8.6 Garages and vehicles

**Did well.** `[qb]/qbx_vehicles` is a clean server-only persistence authority and should be the model for `som-core` vehicle storage: `DoesPlayerVehiclePlateExist`, `GetPlayerVehicles`, `GetPlayerVehicle`, `CreatePlayerVehicle`, `SetPlayerVehicleOwner`, `DeletePlayerVehicles`, `GetVehicleIdByPlate`, `SaveVehicle`. Garages are config-driven with `label`, `takeVehicle` and `spawnPoint` coords, `showBlip`, `type` (`public`, `depot`, or job/gang), and `category`.

**What SOM should do instead.** Build against a `qbx_vehicles`-shaped persistence layer, never garage-local SQL. **Hazard: `[qb]/qb-garages/shared/loltest123.lua` re-declares `Config = {}` alongside `shared/config.lua`**, which is a live config-clobber depending on manifest load order. Verify before touching anything in that resource, and do not reproduce the pattern.

`som-carcontrol` (rebranded third-party) is a flat `c.lua`/`s.lua` door, window, engine, and alarm menu bound to F11 with `AlarmDuration = 30000`. Its functionality is worth keeping, its structure is not. `som-rentacar` hot-links its ~100 vehicle images to a **GitHub raw URL**, which is an external runtime dependency that will break the UI if the repo moves or rate-limits. Internalise those images into `som-assets`.

### 8.7 Housing (`[qb]/qb-houses`, `[qb]/qb-apartments`)

**Did well.** `qb-houses` covers a full property lifecycle: realtor-created listings, purchase, lock and unlock, key sharing (`giveKey`, `giveHouseKey`, `removeHouseKey`), per-house garages, furniture placement and decoration (`Config.Furniture`), tiered house stashes (`Config.StashWeights`), doorbells (`RingDoor`), and police door ramming (`Config.RamsNeeded = 2`). `qb-apartments` handles starter apartments with `coords.enter` and `polyzoneBoxData` per location.

**What SOM should do instead.** **`qb-houses` and `qb-apartments` both manage spawn and logout location**, which is overlapping authority and a known source of spawn bugs. `som-core` must own spawn and logout location exclusively, with housing merely registering candidate locations. House stashes should register through `ox_inventory`'s `RegisterStash` rather than a bespoke storage table. Housing is not in the Phase 2 through 6 scope and is a candidate for a later phase, so the qb-houses schema (`player_houses`, `houselocations`, `house_plants`) is worth preserving in the database even if the resource is removed.

### 8.8 Drugs, illegal, and robberies

**Did well.** Wide coverage already exists: `qb-drugs` (with a dealer system: `newdealer`, `deletedealer`, `dealers`, `dealergoto`), `qb-weed`, `qb-traphouse`, `elixir-drugs`, `elixir-oxyrun`, `elixir-weedrun`, `BakiTelli_weed`, plus `[jobs]/[chopshop]/elixir-chopshop` with its thermite and dialogue dependencies, and seven robbery resources (`qb-bankrobbery`, `qb-storerobbery`, `qb-houserobbery`, `qb-truckrobbery`, `elixir-ammurobbery`, `mk-atmRobbery`, `randol_carheist`).

**What SOM should do instead.** Every one of these pays a **flat, fixed price**. There is no market, no saturation, no heat. Phase 4 requires prices to fall as a drug is dumped and recover over time, which means a single `som_market` table with per-item price, sale volume, and a decay curve, and every sale routed through the Phase 4 transaction bus. The chop shop and ATM robbery resources are the natural first consumers. Risk and heat scaling should read from the same police-presence signal that Phase 6 turf pressure uses, so the illegal economy and the turf system share one tension model instead of two.

---

## 9. Known conflicts and hazards

| Hazard | Location | Risk |
|---|---|---|
| **Duplicate `baseevents`** | `[system]/baseevents` and `[custom]/[elixir-hud]/baseevents` | Both fall under ensured trees. Duplicate event handlers. |
| **Duplicate PolyZone** | `[standalone]/PolyZone` and `[standalone]/elixir-polyzone` | Two copies of the same library loaded. |
| **Config clobber** | `[qb]/qb-garages/shared/loltest123.lua` re-declares `Config = {}` | Silently wipes `shared/config.lua` depending on manifest order. |
| **External runtime dependency** | `[custom]/som-rentacar` images on a GitHub raw URL | UI breaks if the repo moves, is renamed, or rate-limits. |
| **Two wounding systems** | `qb-ambulancejob/client/wounding.lua` and `[new]/BC_Wounding` | Competing damage models, plus a `qb-inventory` patch file referencing both. |
| **Vendor rich presence live** | `qbx_core/config/client.lua:54-78` | Every player sees "Qbox Ducky" and links to `qbox.re`. |
| **Third framework in tree** | `[custom]/2na_core`, used only by `som-banking` | An ESX shim running alongside qbx_core. |
| **Escrowed core interaction** | `[custom]/qb-target` | Encrypted, unversioned, no upgrade path. Wrap, never fork. |
| **SQL outside resources** | `ps-mdt-migrate.sql`, `origenv2.sql`, `server_setup.sql` at base root | Easy to miss in a resource-scoped cleanup. |
| **Loose archive** | `[qb]/Elixir Inventory.zip` | Unextracted archive inside a resource group. |
| **Stream content in script resources** | `qb-smallresources` (21 map files), `dpemotes` (4), `cdn-fuel` (2) | Deleting for framework reasons silently removes streamed props. |
| **Naming inconsistency** | "State of MindRP" in config vs "State of Mind RP" everywhere else | Cosmetic, fix in Phase 9. |

---

## 10. Command inventory (living Phase 8 artifact)

**382 unique command registrations** across the tree: 208 via `RegisterCommand`, 136 via `QBCore.Commands.Add`, 40 via `lib.addCommand` (includes 2 in disabled resources and a handful in README examples).

This is the baseline Phase 8 must reduce. Disposition codes: **KEEP** (no physical anchor, stays a command), **INTERACT** (has a physical anchor, must become a `som-interact` entry), **STAFF** (admin only, stays a command with ACE gating), **DIES** (goes away with its resource, no SOM equivalent needed).

### 10.1 Commands that must become interactions

These all have a physical anchor and are the core of the Phase 8 reduction.

| Commands | Source | Anchor |
|---|---|---|
| `cuff`, `escort`, `jail`, `unjail`, `seizecash`, `takedrivinglicense`, `takedna`, `fine`, `anklet`, `sc`, `depot`, `impound` | qb-policejob | Target player or vehicle within reach |
| `spikestrip`, `pobject`, `clearcasings`, `clearblood`, `flagplate`, `unflagplate`, `plateinfo`, `cam` | qb-policejob | World position or vehicle |
| `selfinvestigate`, `selfgsrtest`, `selfdnaswab`, `selffrisk`, `selfbreathalyze`, `selfdrugtest`, `selfinspectveh`, `selffingerprint` | r14-evidence | Target player or vehicle |
| `heal`, `revive`, `revivep`, `aheal`, `status` | qb-ambulancejob | Downed player |
| `inventory`, `hotbar`, `slot`, `closeinv`, `robme` | qb-inventory (disabled) | Already interaction-driven in ox_inventory |
| `engine`, `togglelocks`, `givekeys`, `addkeys`, `removekeys` | qb-vehiclekeys | Vehicle |
| `hood`, `trunk`, `door`, `seat`, `cleancar`, `flipvehicle`, `checkveh`, `checkdamage`, `checkmods`, `showodo` | jim-mechanic | Vehicle |
| `job`, `setjob`, `changejob`, `addjob`, `removejob`, `gang`, `setgang` | qbx_core | **Phase 5 requires a whitelisted application flow at an NPC. No `/job` command.** |
| `drivinglicense` | qb-cityhall | City hall NPC |
| `mdt` | ps-mdt | Police vehicle laptop or station terminal |
| `spray` | som-spray | Wall surface |
| `doorlock` | ox_doorlock | Door (staff tool, arguably STAFF) |

### 10.2 Commands to keep

| Command | Source | Why it cannot be an interaction |
|---|---|---|
| `me`, `do`, `ooc` | qbx_core, 3dme, 3ddo, elixir-chat | Pure roleplay speech acts, no physical anchor |
| `911`, `911a`, `911e`, `911p`, `311`, `311a` | ps-dispatch, qb-policejob, qb-ambulancejob | Emergency call from anywhere. Fold into a phone if one enters scope. |
| `report` | to be built | Player to staff, no anchor |
| `id` | qbx_core, qb-smallresources | Self-referential lookup |
| `logout`, `deletechar` | qbx_core, qb-multicharacter | Session lifecycle, precedes any world presence |
| `cancelemote`, `e`, `emote`, `walk` | dpemotes, som-emotes | Self-expression, no target |
| `seatbelt`, `togglecruise`, `toggleseatbelt` | qb-smallresources, elixir-hud | Vehicle self-state, keybind is the right form |
| `vol`, `cycleproximity`, `setvoiceintent`, `-radiotalk` | pma-voice | Voice control, keybind driven |
| `callsign` | qb-policejob | Personal metadata, no anchor |

### 10.3 Staff commands (keep, ACE-gated)

`tp`, `tpm`, `togglepvp`, `addpermission`, `removepermission`, `openserver`, `closeserver`, `car`, `dv`, `dvall`, `dvp`, `dvo`, `givemoney`, `setmoney` (qbx_core, 14) plus the 14 `Lennox-Anticheat` commands (`cheater`, `lac_unban`, `lac_score`, `lac_info`, `lac_status`, `lac_exempt`, `lac_unexempt`, `lac_expectwarp`, `lac_screenshot`, `lac_dump`, `lac_banlist`, `lac_baninfo`, `lac_reload`, `lac_hash_resources`), plus `ps-adminmenu` (`heading`, `nc`, `setammo`, `vector2`, `vector3`, `vector4`) and ox_inventory's `removeitem`, `setitem`, `clearevidence`, `takeinv`, `clearinv`, `saveinv`, `viewinv`.

**Every `givemoney` and `setmoney` path must route through the Phase 4 transaction bus and land in the ledger.** Staff money creation is exactly what the audit trail exists to catch.

### 10.4 Commands that die with their resource

The bulk. Includes 16 casino debug commands in `casino-blackjackRT98` (`debugtableserver`, `debugcarddata`, `debugtable`, `debugtable2`, `debugtablepeds`, `testcasinosound`, `testcasinoanim`, `debugblackjack`, `testcleanup`, `debugchips`, ...), 11 in `ps-ui`, 10 in `elixir-hud` (`debug`, `dev`, `god`, `hud`, `fuelxd`, `enginexd`, ...), 7 PolyZone builder commands, 8 `jim-skateboard`, 6 `RollerSkating`, 4 `dream-postal`, 3 `runcode`, plus scattered debug leftovers (`test`, `preview`, `lol`, `fodasse`, `bugs`, `testbar`, `testmenu`, `testwebhook`, `chat_demo`).

**Note for Phase 9:** a meaningful number of these are unguarded debug and cheat commands shipping in production (`god`, `dev`, `setfuel`, `giveboost`, `settier`, `giveitem`, `randomitems`, `setcryptoworth`, `run`, `crun`, `runcode`). Verify none survive the teardown ungated.

### 10.5 Target

Phase 8 target: **fewer than 40 player-facing commands** in the final tree, all justified in sections 10.2 and 10.3, with every entry in 10.1 converted to a `som-interact` entry. Update this section as each system is rebuilt.

---

## 11. Keep and delete manifest (**requires sign-off before Phase 1**)

The four tiers partition all 286 loadable resources. No resource appears twice, none is unlisted.

### Tier A: prompt-mandated preserve (28 resources)
**Recommendation: keep. Risk if deleted: violates the rebuild spec.**

- MDT: `[custom]/ps-mdt` (1). Plus `ps-mdt-migrate.sql` at base root.
- Lennox: `[anticheats]/Lennox-Anticheat`, `[custom]/Lennox-NUIBlocker`, `[standalone]/Lennox-DoorCreator` (3)
- Maps: all 24 in `[assets-streams]/[maps]` (see section 4.3)
- Branding: the asset files in section 4.4, relocated into a new `som-assets` resource before `[custom]/loadingscreen` is removed.

Plus the out-of-`[maps]` map content listed in section 4.3, which must be extracted into `som-props` before its host resources are deleted.

### Tier B: infrastructure libraries (about 40 resources)
**Recommendation: KEEP. Risk if deleted: `som-core` cannot function.**

These are engine-level plumbing, not a competing framework. Removing them does not advance the "no third-party framework" goal, it just deletes the foundation SOM is built on.

- Database and library: `[standalone]/oxmysql`, `[standalone]/ox_lib`
- Inventory: `[standalone]/ox_inventory` (locked decision, see section 6.4)
- Zones: `[standalone]/PolyZone` (drop the duplicate `elixir-polyzone`)
- Voice: `[voice]/pma-voice`, `[voice]/pa-radio`
- Events: `[system]/baseevents` (drop the `[elixir-hud]` duplicate)
- Utility: `[standalone]/screenshot-basic`, `[standalone]/MugShotBase64` (ps-mdt needs it), `[standalone]/connectqueue`, `[standalone]/focusmanager`, `[standalone]/interact-sound`, `[standalone]/xsound`, `[standalone]/progressbar`, `[standalone]/bob74_ipl`, `[standalone]/loaf_lib`
- Cfx stock: `[cfx-default]` managers and system (`mapmanager`, `spawnmanager`, `sessionmanager`, `hardcap`, `rconlog`, `chat`) (22 total in the group, most can go, the managers cannot)

**Open question inside Tier B:** `[standalone]/jim_bridge` exists only to serve `jim-*` resources and dies with them if Tier D is dropped.

### Tier C: streamed assets, non-map (39 resources, several GB)
**Recommendation: KEEP. Risk if deleted: every custom ped, vehicle, and weapon disappears.**

`[assets-streams]` minus `[maps]`. Contains **zero framework logic**, it is pure streamed content:
- `[clothing]` (8 active): `assets_peds`, `assets_peds_other`, `assets_peds_p2`, `assets_peds_p3`, `elixirfwchain`, `rd_clothes`, `rd_clothes_new`, `rd_clothes_props`
- `[vehicles]` (9 active): `assets_vehicles`, `ex-cars`, `New_Truck`, `rd-vehicleconfig`, `rd-vehicletunerfix`, `rd-vehiclewheels`, `tesla`, `vanya`, `veh_lykan`
- `[weapons]` (6): `origen_gunmetas_temp`, `som-custom_weapons`, `som-custom_weapons_melee`, `som-custom_weapons_old`, `som-custom_weapons_thrown`, `som-gunmetas`
- `[graphics]` (8): `karma_visuals`, `karma-graphics-autumn`, `karma-graphics-coastline`, `karma-graphics-trafficlights`, `karma-graphics-vegetation`, `karma-graphics-worldprops`, `karma-minimap`, `karma-world-props`
- `[police]` (3): `c321defender`, `origen_police`, `TIG-PACK`
- `[ems-veh]` (2), `[extras]` (4, includes `PacificBankExtendedMLOv1` which is map content)

Caveat: the weapon packs assume `ox_inventory`'s `data/weapons.lua` entries exist. Keeping the streams means keeping those definitions in sync.

### Tier D: escrowed and paid assets (about 35 resources)
**Recommendation: keep on disk, unensured. Risk if deleted: repurchase or re-download required, and escrowed resources cannot be recovered from git.**

Escrow-locked (`dependency '/assetpacks'`, 12): `[custom]/qb-target`, `[custom]/ac-shop`, `[custom]/pa-textui-2`, `[custom]/pa-vehicleshop`, `[custom]/som-scoreboard`, `[voice]/pa-radio`, `[new]/BC_Wounding`, `[new]/freecity_books`, `[assets-streams]/[graphics]/karma-graphics-trafficlights`, `karma-graphics-worldprops`, `[assets-streams]/[maps]/UniqueFamily_fleecabank`, `UniqueFamily_mapdata`.

Escrow-packaged (`escrow_ignore` without assetpacks, 30, overlapping the above): includes `[custom]/2na_core`, `ac-spawnselector`, `cs_fscanner`, `elixir-petshop`, `karma-reportsystem`, `qb-radialmenu`, the nine `som-*` in section 3.3, `[qb]/qb-garages`, `[standalone]/dpemotes`, the `BakiTelli_*` set, `[new]/[elixir-new]/elixir-chat`.

Plus the paid-but-unmarked families the rebuild spec names as third-party: `elixir-*`, `jim-*`, `randol_*`, `kloud-*`, `ps-*`, `BakiTelli_*`, `cdn-fuel`, the gabz maps.

`[custom]/qb-target` is the critical one: it is Tier D **and** a Phase 2 dependency, since `som-interact` wraps it. It stays ensured.

### Tier E: delete at Phase 1 (the remainder, about 145 resources)

Everything not in A through D. Principally:
- **The framework itself:** `[qb]/qbx_core`, `[qb]/qbx_vehicles`, `[qb]/qb-core` (disabled), `[qb]/qb-inventory` (disabled), `[qb]/qb-multicharacter`, `[qb]/qb-management`, `[qb]/qb-menu`, `[qb]/qb-input`, `[qb]/qb-skillbar`
- **All `qb-*` gameplay:** `qb-policejob`, `qb-ambulancejob`, `qb-garages`, `qb-houses`, `qb-apartments`, `qb-drugs`, `qb-weed`, `qb-crypto`, `qb-cityhall`, `qb-vehiclekeys`, `qb-smallresources`, `qb-weathersync`, `qb-clothing`, `qb-weapons`, `qb-traphouse`, `qb-prison`, `qb-pawnshop`, `qb-jewelery`, `qb-scrapyard`, `qb-diving`, `qb-fitbit`, `qb-lift`, `qb-lockpick`, `qb-keyminigame`, `qb-lapraces`, `qb-streetraces`, `qb-interior`, `qb-npwd`, `qb-phone-compat`, `qb-phone.disabled`, and the `qb-*job` set
- **All `[jobs]`** (35), **all `[robberies]`** (7), **all `[new]`** (15)
- **Rebranded third-party in `[custom]`** that Phase 2 through 7 replaces: `som-banking` (and `2na_core` with it), `som-carcontrol`, `som-deathscreen`, `som-lockpick`, `som-playerlist`, `som-rentacar`, `som-text`, `som-spray`, `som-lib`, `loadingscreen` (after branding extraction), `elixir-base`, `elixir-drugs`, `np-taskbar`, `jim-notepad`, `jim-jobgarage`, `ps-playergroups`, `ps-zones`, `r14-evidence`, `alpr`, `messy-bodycam`, `bbv-cctv`, `npwpdcar`, `qb-k9`, `qb-parkingmeter`, `qb-radargun`, `qb-vehicle-tracker`, `Renewed-Sirensync`, `s4-realisticdisease`, `fl-activeofficers`, `randol_grandma`, `randol_service`, `XNL-FiveM-Trains-U3`, `jim-skateboard`
- **Superseded by SOM:** `som-textui` and `som-zones` fold into `som-interact` (port the code first), `som-notify` folds into `som-core`, `som-jobsetup` and `som-gangboss-app` are rewritten against `som-core` (port the UI and logic first)
- **Dead:** `som-elevator`, `Elixir Inventory.zip`, `[custom]/[elixir-hud]/`, `_disabled_maps/`, `[local]/`, `[custom]/ds-mdt`, `[standalone]/cityhallv1`, the 17 disabled stream packs
- **Duplicates:** `elixir-polyzone`, the second `baseevents`

**Explicitly carry forward before deleting:** `som-zones` export shapes into `som-interact` (section 7.4), `som-textui` behaviour into `som-interact`, `som-gangboss-app` NUI and roster logic into `som-gangs`, `som-jobsetup` NUI into the `som-jobs` location editor, the `qb-ambulancejob` injury model into `som-core` metadata (section 8.2), and the `qbx_core/shared/jobs.lua` schema into `som-jobs` (section 8.3).

**Recovery note.** Repository history was force-pushed clean at some point (see the memory of the 13GB push issue), so **git history is not a reliable recovery path for anything deleted here.** Take a filesystem backup of the full `resources/` tree before Phase 1 begins, independent of git.

---

## 12. Open decisions

### 12.1 Blocking Phase 1

1. **Approve section 11.** Specifically Tiers B, C, and D, where the recommendation is to keep rather than delete.
2. **Confirm the filesystem backup** exists before any deletion, given git history is not a recovery path.

### 12.2 Blocking Phase 4 (economy balance, do not guess)

The rebuild spec explicitly says not to guess silently on these:

| Parameter | Needed for | Note |
|---|---|---|
| Business tax rate into the state budget | Phase 4 legal income | Current stack has no tax at all. |
| Target sink to faucet ratio | Phase 4 inflation control | Spec requires it documented in comments as tunable. |
| Paycheck interval and base amounts | Phase 4, Phase 5 | Currently `config.money.paycheckTimeout` in qbx_core, grades pay 50 to 150. |
| Drug market saturation curve | Phase 4 illegal income | How far prices drop per unit sold, and recovery rate per hour. |
| Laundering cut through a front business | Phase 4 | Percentage taken. |
| Starting cash and bank for a new character | Phase 2 | |

### 12.3 Blocking Phase 6

| Parameter | Note |
|---|---|
| Turf hold window length | Timed hold, or cumulative control points, or both. |
| Control points per action | Drug sale in zone, defending against rival presence, and so on. |
| Turf ownership benefit magnitude | Yield increase, police pressure reduction, passive payout size. |
| Number and boundaries of turf zones | `[custom]/ps-zones` has existing zone definitions worth reusing. |

### 12.4 Scope questions

1. ~~**Is the phone in scope?**~~ **Answered: yes, and it is central.** See
   section 14.5. The phone is the primary interface for anything without a
   physical anchor, and the banking app is its first major consumer. `npwd` and
   `qb-npwd` were removed in the teardown, so a phone must be built or sourced.
   Open sub-question: build `som-phone` from scratch, or adopt an existing
   open-source phone and skin it? Research per 14.2 before deciding.
2. **Housing.** Not named in any phase, but `qb-houses` is substantial and the spec's teardown removes it. Confirm whether SOM ships without housing initially.
3. **Multi-character slot count** for Phase 2.
4. **Does `ps-mdt` stay permanently, or is a `som-mdt` planned later?** This changes how much `som-compat` is worth investing in.

---

## 13. Phase roadmap

| Phase | Scope | Entry gate |
|---|---|---|
| **0. Audit** | This document. | Complete. |
| **1. Teardown** | Delete Tier E. Extract branding into `som-assets` and stray `stream/` folders into `som-props` first. Rewrite `server.cfg` ensure list. Server will not boot until Phase 2 lands. | Section 11 approved, filesystem backup taken. |
| **2. `som-core`** | Player object (identifiers, character, job, gang, money, metadata for hunger/thirst/stress/armor/injuries), character creation and multi-character, server-authoritative transaction bus, ACE permissions, state bag event bridge, `som_*` schema on oxmysql. Plus `som-compat` (section 7.3) and `som-interact` (section 7.2, grown from `som-zones`). **Started ahead of Phase 1, see section 14.** | Phase 1 complete. Multi-character slot count answered. |
| **3. Inventory** | `ox_inventory` bridge at `modules/bridge/som/`, `setr inventory:framework "som"`, NUI reskin against `som-assets/tokens.css`. Documented as a pinned patch. | `som-core` player object stable. |
| **4. Economy** | Business register, transaction ledger, drug market saturation, banking rebuild (replacing `som-banking` and dropping `2na_core`), laundering, sink and faucet instrumentation. | Section 12.2 answered. |
| **4a. `som-appearance`** | Character customisation, and clothing stores afterwards. **Sits between creation and spawn**: create the character, then build their face and outfit, then enter the world. `som_characters.appearance` already exists as JSON for it. Also needed by barbers, clothing shops, and the police and EMS uniform system in Phase 5. Until it exists, every character is the default freemode ped for their gender. | `som-multichar` stable, which it is. |
| **4b. Phone** | `som-phone`, or an adopted open-source phone reskinned. Banking app with transaction history over `som_transactions`, shareable account numbers, share-to-nearby, direct billing, and the police financial audit. See 14.5. **Also needs a Twitter/social app**, since two supporter perks depend on it (14.7). | Phase 4 complete, since the banking app is a view over the economy. |
| **5. Jobs** | `som-jobs` data format seeded from `qbx_core/shared/jobs.lua` (section 8.3). Police and EMS with the section 8.1 and 8.2 depth. Mechanic plus two civilian templates. Whitelisted application flow at an NPC. **Police use the two-axis rank plus clearance model in 14.5**, are built by the merged-review method in **14.9**, and LSPD, BCSO and SASP differ only in blip colour and identity. Fines, armoury split and department accounts already exist from Phase 4. | Phases 2 through 4 complete. Owner available to answer the per-feature questions 14.9 requires. |
| **4c. `som-radial`** | The F1 radial menu, one of the three interaction surfaces (14.6). Declarative registration by other resources, driven by the `som:` state bags. Required, not optional: much of section 10.1 lands here. | `som-core` state bags stable. |
| **4d. `som-admin`** | Custom admin menu (14.8): inventory search, spectate with voice, disconnect logs, vehicle and job management. Replaces the removed `ps-adminmenu`. Defers to txAdmin for restarts, resources and bans. | Phase 4 ledger exists, so money and item actions can be logged through it. |
| **6. Gangs and turf** | `som-gangs` from `som-gangboss-app`. Turf system is fully greenfield (section 8.4). Turf HUD. | Section 12.3 answered. Phase 5 interaction patterns established. |
| **Future: elections** | Players elect a mayor. The mayor sets tax rates per category and allocates budgets to departments (LSPD, BCSO, SASP, EMS). **Tax may never be set to zero**: `Config.Tax.minimum` is a hard floor enforced server side, so an elected official cannot abolish the thing that funds the city. Campaigns, terms and recall are the roleplay layer on top. | Phase 4 economy and Phase 4b phone both live, since voting and budgets need a UI. |
| **7. NUIs** | `som-assets/tokens.css` shared by every `som-*` NUI. Includes the inventory visual rework (14.10) and the custom pause menu (14.11). Inventory, banking, job menus, turf HUD, character creation. Load the design skill in `.claude/skills/` before writing UI code. | Runs alongside Phases 3 through 6, not after. |
| **8. Command minimization** | Execute section 10. Target under 40 player-facing commands. Update section 10 as the living record. | All systems built. |
| **9. Production readiness** | No hardcoded test data, all server events validate input, no unvalidated money or item exports, correct ensure order, top-level `README.md` plus a `README.md` per `som-*` resource. Fix the branding string inconsistency and rich presence (section 5.4). | Phase 8 complete. |

---

## 14. Design principles (owner's direction, binding on all later phases)

Recorded from the project owner. These are not suggestions to weigh later, they
are the quality bar every phase is measured against.

### 14.1 Quality target

**NoPixel and Prodigy tier.** Professional, serious roleplay. If a system feels
like a stock free script with a reskin, it is not done. This is the standard the
rebuild exists to reach, and it outranks shipping speed.

### 14.2 Research before building, then STOP for approval

**This is a hard gate, not a suggestion.** For every new script:

1. **Review real implementations first.** Several of them, not one.
2. **Report back** with: what was reviewed, the feature list, what each does
   well, what each does badly, and a recommendation per feature.
3. **Wait for explicit confirmation.** Do not write any code until the owner
   has approved the feature list.

The reason is that a script's feature set is a design decision that belongs to
the owner, not a detail to be inferred. Building first and asking afterwards
produces work that has to be argued about or thrown away, and it hides the
choices inside code where they are expensive to change.

Expect the approval step to involve many small questions (*do you want map
blips for shots fired?*). That is the point of it, not overhead.

**Exception, narrowly:** something that unblocks testing and would otherwise
leave the server unusable may be built immediately, and then revisited properly.
`som-chat` was built this way, because no typed command was reachable at all
without it. Anything built under this exception must be flagged as owing a
review.

For every significant system, **study the best existing implementations first**,
then write our own against som-core. Explicitly requested for police, and to be
applied to most systems.

The method is the one used in section 8 of this document: read 3 to 4
implementations, write down what each does well and what it gets wrong, then
author one clean resource. Do **not** merge several third-party scripts
together. They are built against different frameworks with different state
models and anti-exploit assumptions, and every seam becomes an inherited bug
nobody understands.

Sourcing rules:
- Public repositories are readable. Most of the FiveM ecosystem is GPL-3, which
  is fine to learn from and adapt for this server; keep attribution.
- **Never** use escrowed or leaked paid scripts. Paid assets the owner has
  actually purchased are fair game to study, since that is inside the licence.
- Resources deleted in Phase 1 remain in git history and are free reference:
  `git show <commit>:<path>`. For drugs alone that is `qb-weed`, `qb-drugs`,
  `elixir-weedrun`, `BakiTelli_weed` and `qb-traphouse`, already reviewed in
  section 8.8.

### 14.3 Diegetic UI, the Prodigy feel

Some interfaces should feel like they exist **inside the 3D world** rather than
floating over the screen. The owner specifically cites Prodigy's casino: screens
that read as physical objects in the scene.

Apply this **only where it makes sense**, where the UI has a real physical
anchor. Good candidates:

| System | Diegetic treatment |
|---|---|
| Weed and drug growing | Plant status rendered at the plant, not a menu |
| Casino | Table and machine displays as world screens |
| Shops and vending | Screen on the actual machine |
| Police MDT in a vehicle | Mounted laptop display |
| ATMs and banking terminals | Screen on the prop |

Keep conventional screen-space UI for things with no physical anchor: the
inventory, the phone, character creation, notifications, the HUD.

Implementation note for Phase 7: this means world-space rendering
(`SetDrawOrigin`, scaleform, or a NUI surface projected onto the prop) rather
than a fullscreen `ui_page`. It changes how those resources are built, so decide
per system **before** writing the UI, not after.

This raises the cost of every diegetic UI noticeably. That is accepted: the
whole point of section 14.1 is that the bar is quality, not speed.

### 14.4 Research notes: character selection

First application of the 14.2 method. Reviewed on GitHub:

| Script | Notable |
|---|---|
| [ak47_multicharacter](https://github.com/MenanAk47/ak47_multicharacter) | React UI, cinematic descent camera, ped lineup with scenario poses, auto mugshots beside stats, time and weather paused during selection, height as a character field |
| [zx_multicharacter](https://github.com/ZeroX-Project/zx_multicharacter) | React + Vite + Tailwind, spawn at last location, player ped hidden during the menu to avoid clipping |
| [wtf_characters](https://github.com/wtf-fivem-mods/wtf_characters) | Separates the selection API from the UI, so the two can be replaced independently |
| [renzu_multicharacter](https://github.com/renzuzu/renzu_multicharacter) | Framework-agnostic adapter layer |

**Adopted:**

- **Freeze time and weather during selection.** The single highest value idea
  found. Without it the screen is lit by whatever hour the server is at, so it
  looks great at 20:00 and terrible at 03:00. Now pinned in `Config.Scene`.
- **Cinematic descent on spawn.** Camera starts high above the spawn point and
  flies down into the player instead of cutting in. `Config.SpawnCinematic`.
- **Varied idle poses**, picked at random, so the screen is not identical every
  session.
- Hidden player ped during the menu, and spawn at last location, were already
  in place before the review.

**Deliberately not adopted:**

- **Ped lineup**, all characters on screen at once. It fights the design goal
  of one character as a clear subject, and it costs a ped and an animation per
  slot.
- **Mugshots beside stats.** Worth revisiting: `MugShotBase64` survived the
  teardown specifically for `ps-mdt`, so the capability exists. Deferred
  because generating them needs each ped rendered and cached, which is a
  meaningful amount of work for a second-order gain.

**Layout conclusion.** Most of these centre the slots on screen, over the
character. SOM puts the UI in a left rail with the camera pushing the character
right of centre, because the character is the subject and the UI is chrome.
That is the Prodigy and NoPixel pattern referenced in 14.1, and it is a
deliberate divergence from the scripts reviewed here.

### 14.5 Phone-centric play (owner's direction)

**The phone is the primary interface for anything without a physical anchor.**
Jobs, money and services are checked on the phone; the world is interacted with
through `som-interact`. Between them they replace commands almost entirely.

This settles the open question in 12.4: **the phone is in scope, and it is
central rather than optional.** It is not a late nice-to-have, and later phases
should assume it exists.

#### Banking app

| Feature | Notes |
|---|---|
| Transaction history | `som_transactions` already records every movement with reason, counterparty and resource. The app is a view over it. This is why the ledger was built as rows rather than a JSON blob. |
| Shareable account numbers | `som_bank_accounts.account_no` already exists for this. |
| Share to nearby players | A button broadcasts the account number to players in range, who receive it as a phone notification. Server validates distance, as always. |
| Direct billing | A player who has your account number can raise a bill against it through the app. |

Depth is the point here, not a minimal transfer screen.

#### Police financial audit

Officers of sufficient rank and clearance can inspect another player's accounts,
for audit roleplay. Server-side permission check, and **the audit itself must be
logged**: someone looking at a player's finances is exactly the kind of action
that needs a trail, both for RP and for catching staff abuse.

#### Two-axis police permissions

Replaces the flat grade ladder with **rank** and **clearance**, which are
independent:

- **Rank 1 to 7**: position in the department. Cadet, officer, and upward.
  Governs seniority, pay and command.
- **Clearance 1 to 5**: certifications held. Interceptor cert, helicopter cert,
  bank audit cert, and so on. Governs what equipment and powers are unlocked.

A senior officer without the helicopter cert cannot fly; a mid-rank officer with
the audit cert can run financial checks. That separation is closer to how real
departments work and gives far finer control than a single grade number.

**Consequences to handle when Phase 5 starts:**

1. `som-core/shared/jobs.lua` currently gives police five grades (0 to 4) with a
   single `isboss` flag. That needs restructuring to 7 ranks plus a separate
   certification set.
2. The schema needs a certifications table (`som_certifications`, keyed by
   citizenid and cert name, with issuer and timestamp), since a cert is granted
   to a person and audited, not derived from rank.
3. `som-jobs` permission checks become two-dimensional. Any helper written
   before this lands should not assume a single grade integer.
4. The phone replaced by the teardown was `npwd` plus `qb-npwd`. Building or
   sourcing a phone is now a required phase, not an optional one, and the
   banking app above is its first real consumer.

### 14.6 The three interaction surfaces (owner's direction)

Everything a player does goes through one of three surfaces. This is the
architecture Phase 8 enforces, and it is what replaces commands.

| Surface | Key | For |
|---|---|---|
| **Radial menu** | `F1` | Self and context actions: emotes, vehicle controls, job duty, quick access |
| **Third eye** | `som-interact` | Anything with a physical target: a player, vehicle, door, prop, zone |
| **Phone** | phone key | Anything with no physical anchor: banking, jobs, services, messaging (14.5) |

**Contextual keys stay.** Pressing `E` to open a door or pick something up is
correct and should not be forced into a menu. The rule is about where
*decisions* live, not about banning every keypress. A radial menu for opening a
door would be worse design, not better.

**Consequence:** `qb-radialmenu` was removed in the teardown, so **`som-radial`
has to be built**. It is not optional: it is one of the three surfaces and a
large share of the commands in section 10.1 are meant to land there rather than
on the third eye.

Design notes for when it is built:

- It must read live player state (job, duty, vehicle, gang) to decide which
  entries exist, so it needs the `som:` state bags from `som-core`.
- Entries are declarative and registered by other resources, in the same spirit
  as `som-interact`, so `som-jobs` and `som-gangs` can contribute without
  `som-radial` knowing about them.
- Same security posture as the third eye: showing an entry is a UI decision, and
  the server re-validates on use. See the note at the top of
  `som-interact/client/target.lua`.

### 14.7 Supporter tiers (owner's direction)

**Hard rule: nothing purchasable may be pay to win.** No money, vehicles, items,
stats or gameplay advantage. Entitlements are limited to convenience (queue
priority, character slots) and cosmetics (names, colours, plates). If a perk
would make a paying player stronger in an interaction with a non-paying one, it
does not ship.

Prices are placeholders: Patreon does not exist yet.

**Full detail, including per-system perk ideas and the rejected list, is in
[patreon.md](patreon.md) at repo root.** Summary:

| Tier | Price | Slots | Queue | Perks |
|---|---:|---:|---:|---|
| Citizen (free) | – | 2 | 0 | – |
| Resident | €5 | 3 | 5 | One extra slot and a slight queue nudge. Nothing else. |
| Insider | €10 | 5 | 15 | + custom phone number |
| Patron | €20 | 6 | 25 | + Twitter handle, 1 colourway, 1 custom plate |
| Benefactor | €30 | 7 | 35 | + 3 colourways, 2 plates, profile title |
| Founder | €40 | 7 | 45 | + 6 colourways, 3 plates, phone theme |

Slots stop at **7**, the purchasable ceiling. Ten exists only for management,
which is what keeps it a staff thing rather than a purchase, so the top tier
sells cosmetics instead of another slot.

Staff are resolved separately and a player receives the **better** of their
staff and supporter entitlement, so buying a tier never removes something staff
already had, and staff rank is never a substitute for supporting.

| Staff | Slots | Queue |
|---|---:|---:|
| Mod | 3 | 25 |
| Admin | 7 | 40 |
| Management | 10 | 50 |

Management alone reaches 10. Everyone else, paying or staff, tops out at 7.

#### How a tier is granted

Tiers resolve through **ACE**, not by reading Patreon directly. The same
mechanism works whether the grant comes from a manual `server.cfg` line, a
Discord bot mapping roles to principals, or a future Patreon webhook, and no
consumer changes when the source does.

```
add_principal identifier.license:<license> group.supporter
add_ace group.supporter som.tier.supporter allow
```

**Neither automated route exists yet.** The txAdmin Discord bot is currently
disabled (section 5.4 notes the rich presence is still on Qbox defaults), and
Patreon is not set up. Grants are manual until one is wired.

#### Built

- `som-core/shared/tiers.lua`, the tier table above.
- `som-core/server/entitlements.lua`, resolving slots, queue priority and perks.
- Character slots are **server enforced** in `Characters.Create`. This is a
  security boundary, not a display value: a client deciding its own cap could
  create characters in slots it had not earned. The client export was removed
  and `som:server:getEntitlements` replaces it.

#### Not built, and what each needs

| Perk | Blocked on |
|---|---|
| Queue priority | `connectqueue` is disabled in dev mode (its 2 minute `JoinDelay`). Its `Config.Priority` table takes identifiers, so wiring `queuePriority` to it is small once re-enabled. |
| Custom Twitter handle and colourways | **There is no Twitter app.** `npwd` was removed in the teardown. Needs the phone (14.5) first. |
| Custom licence plates | Needs vehicle ownership, which is Phase 5 or later. `som_vehicles.plate` exists and is unique, so the validation hook has somewhere to live. Must reject duplicates and reserved formats such as police plates. |
| Custom phone number | Needs the phone. `som_characters.phone` exists and is currently auto-generated. |

**Roadmap consequence:** a Twitter or social app is now a required part of the
phone phase (4b), not optional, because two purchasable perks depend on it.

### 14.8 Admin menu (owner's direction)

A fully custom `som-admin`, replacing `ps-adminmenu` which was removed in the
teardown. The goal is moderating the server entirely from in game, without
needing txAdmin for day-to-day work.

Required capability:

| Area | Needs |
|---|---|
| **Players** | Search and inspect inventories, view and edit jobs, view money and the transaction ledger, teleport, freeze, kick, ban |
| **Spectate** | Watch a player, with voice: staff hear in-game speech while spectating |
| **Logs** | Disconnect log, connection history, and eventually item and money movement drawn from `som_transactions` |
| **Vehicles** | List a player's vehicles, spawn, delete, repair, edit plates |
| **Phone** | Manage numbers, later. Depends on the phone existing |
| **Twitter** | Reassign or reset handles. Note players change their own handle **only if their tier grants it**, so this is moderation and appeals rather than routine |
| **Jobs** | Set job, rank and clearance, matching the two-axis model in 14.5 |

Design constraints, consistent with the rest of the framework:

- **Every action is server validated and ACE gated.** The menu is a request
  form, never an authority. Showing a button grants nothing.
- **Everything is logged**, including who did it and to whom. An admin viewing
  a player's inventory or finances is exactly what an audit trail is for, and
  it is what makes the 14.5 police financial audit defensible too.
- **Money and item actions go through the transaction bus**, so staff grants
  appear in `som_transactions` like any other movement and cannot be laundered
  past the sink/faucet figures.
- It is a `som-radial` entry or its own key, not a chat command, per 14.6.

**Deliberately out of scope:** anything txAdmin already does better, such as
server restarts, resource management, and the ban database itself. `som-admin`
should read from and defer to txAdmin rather than duplicating it.

### 14.9 Police, Phase 5 approach (owner's direction)

#### Build method

Review **7 to 8 police scripts**, take what each does well, and author one
merged custom script. This is the 14.2 method at a larger scale, and the owner
has accepted that it means **being asked about nearly every feature** rather
than having defaults chosen silently.

The questions look like: *do you want map blips for shots fired?* Each is a
design decision with a real effect on how policing feels, and answering them
one at a time is the point, not overhead to be optimised away.

**Sourcing rule still applies (14.2).** Public repositories are fine to read
and learn from. Escrowed or leaked paid scripts are not, whatever channel they
are shared through. If the owner has purchased a script, studying it is inside
the licence and fair game.

Practical sequence:
1. Shortlist candidates, note what each does well and badly.
2. Bring the owner a feature list grouped by area (patrol, evidence, custody,
   equipment, dispatch), with a recommendation per item.
3. Work through it, then build once against `som-core` and `som-interact`.

#### Departments are identical except identity

LSPD, BCSO and SASP must behave **exactly the same**. They differ only in name,
blip colour and livery. Anything that behaves differently between them is a
bug, because it would mean maintaining the police script three times.

Encoded in `som-economy/shared/config.lua` `Config.Departments`, which already
carries `short`, `blip` and `canFine` alongside the funding model. Phase 5 reads
those rather than hardcoding a department anywhere.

Only LSPD is active. BCSO and SASP have `active = false` and no `job` assigned
until their jobs exist.

#### What the police script inherits from Phase 4

Fines are already built and are designed to be driven by a police script rather
than replaced by one:

```lua
exports['som-economy']:issueFine(officerSource, targetSource, amount, reason)
exports['som-economy']:payFine(source, fineId)
exports['som-economy']:voidFine(source, fineId)        -- boss or admin
exports['som-economy']:getUnpaidFines(citizenid)
```

Plus the event `som:server:fineIssued(id, citizenid, officerCitizenid, amount)`
for dispatch, the MDT, or a phone notification to hook.

The department is derived from the officer's job, so a police script never
passes one and cannot fine on behalf of a department the officer does not work
for. `Config.Fines.officerShare` stays at zero: the officer must never earn from
writing tickets.

Equipment is already split between department issue and personal purchase
(`issueEquipment`), so an armoury UI is a front end over an existing rule rather
than new logic.

**Unpaid fines currently do nothing.** Warrants, impound and licence suspension
hang off `Config.Fines.lateAfterHours` and are Phase 5 work.

### 14.10 Inventory visual rework (owner's direction, later stage)

The current inventory is ox_inventory with a light reskin and reads as cheap.
It needs a full visual rebuild so it feels custom, not themed.

**Explicitly not a logic rewrite.** The locked decision in section 1 stands:
ox_inventory keeps the anti-dupe machinery catalogued in 6.5, and only its web
UI is replaced. That UI lives in `ox_inventory/web/`, so this becomes a **third
patched area** in that resource alongside the som bridge and the scrollbar fix,
and must be re-applied on upgrade.

| Change | Notes |
|---|---|
| **Full visual rebuild** | Take inspiration from other inventories rather than reskinning this one. Must feel bespoke. |
| **Drop the Give button** | Replaced by right-click. |
| **Right-click context menu** | Use, Give, Throw at minimum. ox already has a `buttons` concept per item that this can build on. |
| **Backpacks** | Increase carrying capacity. ox supports containers already (6.3), so this is a container item plus UI, not new inventory logic. |

Watch out for: backpacks interacting with `som-theft` and police searches, since
a container is a second place cash-adjacent goods can hide; and weight limits
staying meaningful, or backpacks quietly remove the inventory constraint
entirely.

#### Item icons

The stock ox_inventory icon set is illustrated, and the server already had a
partial set of photoreal ones, so the inventory looked like two different games.

152 icons replaced from two public GPL-3.0 sources, `TenTypeeek/OX_inventory-reimagined`
and `aifazi/items-images`, taking coverage to **205 of 605 declared items**.
Matching is by exact filename, then normalised, then token containment, always
excluding the `vehicles/` folder: a tool called `cutter` matching a car photo
named `Cutter` is exactly the failure those passes produce.

The remaining **250 on stock art and 150 with no image at all** could not be
matched, and the grouping in `tools/inventory-icons-unmatched.txt` shows why:
what is left is script-specific rather than generic. 44 burgershot menu items,
38 weapon tint swatches, 35 attachments, 27 gem tiers, 23 tuning parts, 10 GPU
models. No general-purpose pack carries those names.

The near-misses were reviewed by hand and rejected: `stone` matched a stone
hatchet, `diamond` a diamond-shaped key, and all three `weapontint_*` matched
the same army tint. Those are different objects, not variants, so they stay on
stock art. A wrong icon is worse than an inconsistent one.

**150 items render blank** because no file exists for them at all. Most belong
to resources not currently ensured, so nothing in game is affected yet.

Not sourced from NoPixel, Prodigy or Echo icon packs: those are redistributed
private assets, which the sourcing rule in this document excludes.

### 14.11 Pause menu (owner's direction, Phase 4)

Replace the stock pause menu.

| Element | Requirement |
|---|---|
| **Map first** | Opening pause shows the map, as every server does. Do not bury it behind a menu. |
| **Custom map** | Street names and colours. **No postal codes.** |
| **Settings NUI** | Settings, keybinds and the rest get their own SOM-styled interface rather than the GTA menu. |
| **Overlay** | Light pink tint over the existing blur. |

The map itself is a streamed asset (a minimap replacement), so it belongs in
`[assets-streams]` and is sourced rather than authored. The overlay and settings
UI are SOM code.

Worth noting: the pause menu is one of the few places a **screen-space** UI is
correct, since pausing is inherently out-of-world. It is not a candidate for the
diegetic treatment in 14.3.

**Built as `som-pause`, then cut back to a bar.** The full custom menu was
rejected on sight: too much chrome around things the game already does better,
and it left the minimap expanded and repositioned with no restore, which put a
large translucent map permanently on the HUD.

What ships is a slim branded bar over the blurred, pink-tinted world. Map and
Settings hand back to the native frontend with
`ActivateFrontendMenu(FE_MENU_VERSION_MP_PAUSE, false, -1 | 6)`. **This resource
no longer touches the minimap at all.**

Two things that changes from the notes below: click-to-waypoint is back, because
the native map is back, so `Config.Waypoints` and its destination list are gone.
And the map is no longer drawn through a hole in the NUI.

The original build notes, kept because the reasoning still applies:

- The beige wash is drawn by the native frontend and no native recolours it, so
  the native menu is suppressed outright rather than skinned. The world blur is
  re-applied with `TriggerScreenblurFadeIn` and the tint lives in CSS.
- The map tab shows the **live game map** through a hole in the NUI via
  `SetBigmapActive`, so blips and the player marker stay real. No map image is
  shipped or kept in sync.
- The coloured map was already in the repo: `[assets-streams]/[graphics]/karma-minimap`
  replaces `minimap_main_map.gfx`. It was simply never ensured, which is why the
  vanilla map was showing. Now named explicitly in the dev boot list (19MB).
- Street and area names are HUD components, not part of the map texture, so
  `HideHudComponentThisFrame(9)` and `(7)` handle them independently of which
  map is streamed.
- **Cost accepted: click-to-waypoint is lost.** NUI owns the cursor so the game
  never sees the click, and no native converts a screen point on the expanded
  radar back to world coordinates. `Config.Waypoints` replaces it with a
  searchable destination list calling `SetNewWaypoint`.
- The settings tab is **not** built. There are no settings to put in one yet; it
  arrives with the HUD and keybind work rather than shipping empty.

### 14.14 Decisions taken after the first build pass

Recorded so they are not re-litigated. Each replaced something already built.

| Area | Decision |
|---|---|
| **Pause menu** | Built twice, discarded twice. A full menu and then a slim bar, both replacing the native frontend, and both worse than what they replaced. What ships is a pink `DrawRect` wash and nothing else. NUI cannot be used: it renders above the frontend and captures the cursor, making the menu underneath unclickable. |
| **Interaction engine** | `qb-target` out, `sleepless_interact` in. Escrowed and unversioned versus GPL-3.0 and maintained. Indicator circles appear only while Left Alt is **held**, which is not the resource's default. |
| **Zones are points** | The engine draws a circle at a coordinate, so box, sphere and poly all resolve to a single point with a per-option distance. Genuine regions belong in `som-zones`. |
| **Radial contents** | Things that act on **you**, on the **vehicle you are in**, or on the **person you are looking at**. qb-radialmenu's clothing and housing blocks are rejected: those are UIs wearing a wheel as a costume. Emotes stay on `/e`. |
| **No `event` in registries** | Neither `som-radial` nor `som-interact` passes `event`, `serverEvent` or `command` through from config. A config value naming a server event lets the client choose both the event and its payload. |
| **Ledger slugs are never shown** | `som_transactions.reason` is machine readable and translated to a label **server side**, with the slug replaced rather than supplemented so it cannot leak to the client at all. |
| **Phone owns its own notifications** | Anything phone-shaped is a banner on the phone, working whether or not the phone is open. Only "you do not have a phone" stays a world toast. |
| **ID cards are light** | A document is pale with print on it. Dark chrome reads as interface. Adapted from `alp1x/um-idcard` (GPL-3.0). |
| **Config lives in `som.cfg`** | `server.cfg` is gitignored, so config could not be version controlled and drifted between machines. Everything non-secret moved to a tracked `som.cfg`, loaded with `exec`. |
| **Owner permissions bypass ACE** | ACE never resolved on this server despite the cfg provably executing and the grants being present and correct. Owners are matched by identifier in `som-core/shared/config.lua`. ACE remains the mechanism for everyone else. **Unexplained, and worth revisiting.** |

### 14.12 Command minimisation

Already covered in section 10, and it serves the same goal. Interaction-driven
play is what separates a serious RP server from a menu simulator.

### 14.13 Feature inventory salvaged from the legacy schema

`origenv2.sql` and `server_setup.sql` were the previous server's database dumps.
They are deleted now that `setup.sql` exists, but their table list is the most
complete record of what the old server actually ran, so it is preserved here as
a candidate backlog. **None of this is committed scope.** It is a menu, and each
item still has to pass the 14.2 research gate.

Ordered by how strongly the table structure suggests the feature was real and
in use, rather than installed and abandoned.

| Legacy tables | Feature | Take |
|---|---|---|
| `houselocations`, `player_houses`, `apartments`, `house_plants` | Housing with in-house weed growing | Wanted. Housing is already a Phase 7 anchor, and `house_plants` is the diegetic-UI candidate from 14.3. |
| `player_garages`, `player_vehicles`, `occasion_vehicles` | Garages plus a **player-to-player used car lot** | `occasion_vehicles` is the interesting one: players listing their own cars is a real economy sink and fits the 200K ceiling. |
| `pa_vehicleshop_showroom_vehicles`, `pa_vehicleshop_stocks` | Dealership with finite stock | Stock limits make a dealership an economy actor rather than an infinite faucet. Strong fit with `som_market`. |
| `trucker_available_contracts`, `trucker_drivers`, `trucker_loans`, `trucker_trucks` | Trucking job with **vehicle loans** | Loans are a debt mechanic, which the economy currently has none of. Worth designing properly. |
| `evidence_storage` | Police evidence lockers | Already flagged in the qb-policejob notes. Phase 5. |
| `management_funds` | Boss/business funds | Superseded by `som_bank_accounts` + `som_businesses`. No work needed. |
| `crypto`, `crypto_transactions`, `cryptominers` | Crypto with minable rigs | `som_character_money.crypto` already exists as an account. Miners are a physical anchor, so a diegetic candidate. |
| `fuel_stations` | Player-owned fuel stations | Fits the business register directly. |
| `sprays` | Graffiti tagging | `som-spray` is already on the keep list. Wire it to turf in Phase 6. |
| `races`, `race_tracks`, `lapraces`, `gfx_racing` | Racing with saved tracks | Popular, self-contained, no economy risk if payouts stay small. |
| `player_jobs` | **Multiple jobs per character** | Worth a decision: `som_characters` currently models one job. Changing that later is a migration. |
| `redeem` | Redeem codes | Useful for the Patreon flow in `patreon.md`. |
| `vehicle_trackers` | Vehicle trackers | Small, and a good police/crim tension item. |
| `punchmachine` | Punch machine minigame | Trivial, atmosphere only. The prop is already on the keep list. |
| `player_notes`, `player_mails`, `player_warns` | Notes, mail, warnings | Warnings belong in `som-admin` (14.8). |
| `twitter_*`, `instagram_*`, `tinder_*`, `whatsapp_*`, `darkchat_messages`, `yellowpages_posts` | Six separate social apps | **Do not rebuild six.** Twitter and yellowpages are already planned for phone 4b-2; dark chat is a genuine crime-side tool. The rest were bloat. |
| `phone_invoices` | Phone invoicing | Already built, better: `som_phone_bills` requires acceptance. |
| `elixir_clothing`, `elixir_outfits`, `playerskins`, `player_outfits` | Clothing and saved outfits | Phase 4a appearance work needs an outfit table. Note the shape when it is designed. |
| `debux_petshop`, `kloud_delivery`, `randol_cs` | Third-party job scripts | Their features, not their code. Delivery overlaps Post OP. |

Two things the legacy schema had **no** table for, which confirms they are
greenfield: turf control, and any kind of sink/faucet instrumentation.

---

## 15. Build log

### Phase 2 started ahead of Phase 1 (additive, nothing deleted)

The teardown is gated on section 12.1, so framework work began alongside the
existing stack instead of after it. Everything below is new and additive: no
existing resource was modified, and the server still boots on the legacy stack.

New group folder `resources/[som]/`:

| Resource | Contents |
|---|---|
| `som-core` | `shared/{config,jobs,gangs}.lua`, `server/{permissions,player,money,characters,main}.lua`, `client/main.lua`, `sql/som_schema.sql` |
| `som-interact` | `client/target.lua` (qb-target wrapper), `client/textui.lua` plus its NUI |
| `som-compat` | `server/qbcore.lua`, `client/qbcore.lua` |
| `som-assets` | `tokens.css`, empty `img/` awaiting the Phase 1 logo relocation |

**None of these are in `server.cfg` yet.** `som-compat` in particular declares
`provide 'qb-core'` and must not be started while `qbx_core` is running, since
both claim that name.

Decisions made while building, recorded so Phase 3 onward does not relitigate them:

- **Money never appears without a source.** Payroll debits the job's business
  account through `Money.BusinessTransact` rather than minting. A job with no
  `business` entry is a faucet by definition, and only `unemployed` uses that
  path. This is what makes the section 12.2 sink/faucet ratio measurable.
- **Character deletion is a soft delete** with `slot` set to NULL, so the
  transaction ledger keeps referential integrity while the slot frees for reuse.
- **Metadata is a closed set.** Only keys in `Config.DefaultMetadata` are
  accepted and numeric ones are clamped to `Config.MetadataBounds`, so neither a
  buggy job script nor a compromised resource can invent or overflow state.
- **`som-compat` exposes no money or item members.** A legacy resource must not
  be able to mint currency through the shim.
- **`som-interact` wraps the lowercase compat surface**, per section 7.2, and
  normalises two defects in it: zone argument order, and `addGlobalVehicle`
  being registered twice in `compat/ox_target.lua` (lines 156 and 195) with the
  first registration referencing an undefined `bones` global.

Carried forward into the open decisions list:

- Business opening balances in `som_schema.sql` are **placeholder float, not a
  balance decision**. They exist so payroll functions at all. Phase 4 replaces
  them with real revenue. Tax rates are seeded at `0.0000` pending section 12.2.
- Multi-character slots defaulted to 5 in `Config.Characters.maxSlots`, still
  listed as an open question in section 12.4.

**Not verified:** no Lua toolchain (`luacheck`, `lua`, `luac`) is installed in
this environment, and there is no `.luacheckrc` in the repo, so none of the new
Lua has been syntax checked or run. The schema has not been imported against a
live database. Everything in this section is written but untested.

### Phase 1 teardown, partially executed

Authorised by the project owner. Recoverability was verified first, and it
changes the risk picture recorded in section 11:

- All 11,068 files under `resources/` that are **tracked** are recoverable with
  `git checkout <commit> -- <path>`.
- `[assets-streams]` is **gitignored and untracked**, as is every `**/stream/`
  folder and every loose heavy asset extension. None of that is recoverable
  from history, so none of it may be deleted. This is why Tier C is a keep.
- 29 resources outside `[assets-streams]` hold untracked `stream/` content.
  All are on the keep list. A scan confirmed the delete set contains **zero**
  unrecoverable files before anything was removed.

**Removed (11 resources, commit `dc537fa2`):** `qbx_core`, `qbx_vehicles`,
`qb-core`, `qb-inventory`, `qb-multicharacter`, `qb-management`, `qb-menu`,
`qb-input`, `qb-skillbar`, `interact`, `ps-adminmenu`.

**Not removed (about 145 resources).** The environment's permission layer
blocks bulk deletion, correctly, since that is exactly the operation worth
guarding. `tools/phase1-teardown.ps1` carries the full keep/delete manifest and
the safety gate, defaults to a dry run, and uses `git rm` so every removal stays
recoverable. It refuses to run if any candidate holds untracked assets.

### Resources added since

| Resource | Why |
|---|---|
| `som-ui` | Implements `som:client:notify`, which `som-core` and `som-compat` fire and nothing answered once `som-notify` and `som-lib` were removed. |
| `som-multichar` | Replaces the deleted `qb-multicharacter`. Without it no player can enter the world. |

`server.cfg.example` now targets the SOM boot order, moves permissions from
`qbcore.*` to `som.*` ACEs, drops the Qbox branding strings, and comments out
the emptied folders. The live `server.cfg` is gitignored and must be updated by
hand on the VM.

### Still required before the server boots

1. Run `tools/phase1-teardown.ps1 -Execute` to finish the teardown.
2. Import `som-core/sql/som_schema.sql`.
3. Copy `server.cfg.example` to `server.cfg` and restore the secrets.
4. Boot and fix what surfaces. None of the new Lua has been executed.

Known functional gaps at this point: no appearance or clothing system
(`qb-clothing` removed, Phase 7 owns it), no HUD, no inventory bridge yet
(`inventory:framework` is still `qbx`, see section 6.4), and no job, gang,
vehicle, or housing content.

---

## 16. Session handoff: state and open queue

Written so the next session can continue without re-deriving any of this.
Everything described below is committed and pushed to `main`. Read this section
before touching police, garage, dispatch or the MDT.

### 16.1 What now exists

| Resource | State |
|---|---|
| `som-ui` | Notifications, the progress bar that replaces ox_lib's (see 16.6 item 4 for why the shim lives where it does), and the feedback sound layer (see 18.11) |
| `som-police` | Built. Duty, armoury, custody, fines, impounds, certifications, officer keybinds, vehicle lights and siren |
| `som-dispatch` | Built. Crime detection, call store, answers to the `ps-dispatch` export name |
| `som-garage` | Built. `som_vehicles` authority, ghost preview, garages, PD pool, buy and refund, temporary mod bay |
| `som-compat` | Extended heavily. Full `Functions` surface, `Shared.Items/Weapons/Vehicles`, licence and DOB aliasing |
| `ps-mdt` | Opens, profiles load, certifications panel added |
| `ox_doorlock` | Doors lock and unlock at MRPD |

`som-police` and `som-garage` overlap deliberately. som-garage owns the
`som_vehicles` lifecycle and is the only code path that mints a row;
som-police owns duty, custody and the impound transition. When they disagree
about a vehicle, som-garage is right about ownership and som-police is right
about `state = 'impounded'`.

### 16.2 Patches made to third-party resources

These are the only edits outside `[som]`, and every one is load-bearing. Any
upgrade of these resources drops them, so this table is the re-apply list.

| Resource | Patch | Why |
|---|---|---|
| `ps-mdt` | `server/main.lua:234` and `:1136` guarded with `isDispatchRunning` | Unguarded, they threw before `mdt:client:open` fired. Line 234 sits immediately before the open event, so the MDT never opened at all |
| `ps-mdt` | `client/main.lua` accepts `som-dispatch` as a framework | `provide` does not make `GetResourceState` report the provided name as started |
| `ps-mdt` | Certifications panel appended to `ui/app.js`, `ui/dashboard.html`, `ui/style.css`, `client/main.lua` | Append-only, so a fault breaks the panel and nothing else. The two NUI callbacks use `QBCore.Functions.TriggerCallback`, since ps-mdt does not load ox_lib |
| `ps-mdt` | Record deletion moved from police grade 4 to grades 5 and 6, on four permission tables | Grade 4 was the Chief under the old ladder and is a Sergeant under ours |
| `ps-mdt` | `licenseTypesGlobal` declared in `ui/app.js`, and both readers of `.licences` given a `\|\| {}` guard | The constant is read at `app.js:280` and `:5595` and **declared nowhere upstream**. This is what broke the person search. See 16.3 |
| `ox_inventory` | MRPD locker and `PoliceArmoury` removed from `data/stashes.lua` and `data/shops.lua` | They duplicated som-police's, and ox's armoury stocked no IFAK, armour or radio. This was the real cause of the "empty armoury", not som-police config |
| `ox_inventory` | `ammo-taser` added, `WEAPON_STUNGUN` given `ammoname` | The stock stungun had no ammo type and fired forever |
| `ox_doorlock` | `server/framework/som-compat.lua` added, listed first in `server/utils.lua` | Without it `GetPlayer` is nil and every door refuses silently |
| `ox_doorlock` | `use_experimental_fxv2_oal` commented out | Suspected cause of the manifest and streaming faults; the texture dict still never loaded with it on |
| `ox_doorlock` | Texture dict awaited before the lock sprite draws | Stock requested it once and drew regardless, rendering a white square forever |
| `ox_target` | Reach set through the `ox_target:maxDistance` convar, dots restyled to SOM pink | Stock hardcodes a much longer reach and gives the dot no hover state |
| `ox_target` | `somProgressActive()` added at `client/main.lua:35` and checked alongside `lib.progressActive()` at `:203` | som-ui replaced ox_lib's progress bar, and `lib.progressActive` is not in ox_lib's `imports/`, so ox_target's call resolves to `exports.ox_lib:progressActive()` and reads ox_lib's own state, which is now permanently false. Without this the eye stays openable throughout a search or a cuffing. Guarded on som-ui being started, so ox_target still runs standalone |

### 16.3 Bugs found and their real causes

Recorded because in every one of these the obvious diagnosis was wrong.

- **`lib.addCommand`'s `restricted` option calls `RegisterCommand(name, fn, true)`**,
  which hands enforcement to FiveM's ACE. The command is refused before any Lua
  runs, so nothing prints anywhere and the command looks dead. Staff commands
  now register unrestricted and check `Permissions.Has` inside the handler.
  `Permissions.AddCommand` in `som-core/server/permissions.lua` does this.
- **ACE does resolve on this server.** A stale comment claiming it never had
  sent a whole debugging pass down the wrong path. The boot line
  `permissions: cfg marker som-cfg-exec-ok | group.god=1 | owner identifier=true`
  is the authority. Trust it.
- **Imported ox_doorlock doors broke doors that already worked.** Two records
  for one physical door create two `AddDoorToSystem` entries, and unlocking one
  leaves the other holding it shut. `/pddoors` exposed it: rows #1 and #4 were
  0.8m apart on the same model hash. `sql/mrpd-doors.sql` is now a removal
  script. Build MRPD doors with `/doorlock` in game, not by importing a set
  found online, which will be for a different MLO.
- **The `som:job` statebag replaces the client's job table wholesale.** Anything
  omitted from the bag is stripped from the client moments after
  `som:client:playerLoaded` sent it. This is why ps-mdt concatenated a nil
  `job.grade.name` and sat on "Welcome, loading...". `syncState` now includes
  `label` and `gradeLabel` on both the job and gang bags, and must keep doing so.
- **ps-mdt renders dispatch calls as INTERPOLATED HTML, not textContent.**
  `ui/app.js:4448`, `:4454`, `:4589` and `:4595` build the call list by
  substituting `dispatchMessage`, `dispatchCode` and the rest straight into a
  markup string. A comment in `som-dispatch/server/main.lua` claimed the
  opposite, which is how it went unnoticed. The 911 message is free text typed
  by a player, so a player could put markup in a 911 call and run script in the
  MDT of every officer who opened it. `sanitise()` now strips angle brackets and
  control characters from every string field on the way in. Stripped rather than
  entity encoded, because encoding is right for the interpolated context but
  shows as a literal `&amp;` in any consumer using textContent, which
  som-dispatch's own NUI will.
- **The detection report could raise any alert in the config, including
  `emergencyCall`.** Membership of `Config.Alerts` was the entire check, so a
  client could fire `som-dispatch:server:report` with `emergencyCall` and raise
  a priority 1 call at will, bypassing the 911 path's own validation. Alerts now
  carry `reportable`, and only the five client-detected ones have it.
- **ps-mdt spells it `cid`, som-dispatch compared `citizenid`.** Only one unit
  could ever attach to a dispatch call. ps-mdt builds its unit payload with
  `cid` (`server/main.lua:1441` and `:1512`), so comparing `citizenid` compared
  **nil against nil, which is true**: the first unit in the list matched
  everybody, the second officer to attach was treated as already attached and
  never added, and any officer detaching removed whoever happened to be first
  rather than themselves. `unitKey()` now resolves either spelling and refuses a
  unit with no identity, since one that cannot be identified can never detach.
  Same class of fault as the licences spelling below, hidden the same way.
- **qb spells it `licences`, SOM spells it `licenses`.** Only the online lookup
  broke, because the offline path had a default, which disguised a spelling
  mismatch as a database fault. `som-compat` aliases both directions.
- **oxmysql returns a `DATE` column as epoch milliseconds**, so every date of
  birth printed as `1217721600000`. Normalise through `SomFormatDate` in
  `som-core/server/player.lua`.
- **`SUM()` over a BIGINT returns DECIMAL, which the driver hands back as a
  string**, so `row.faucet == 0` was never true and the economy report printed
  `inf` and `-nan`.
- **A vehicle left `state = 'out'` at shutdown was lost permanently.**
  `reclaimVehicles()` now resets them to `garaged` at boot.
- **`SetEntityAlpha` only honours multiples of 51.** The preview uses 153. The
  third argument is ped-only.
- **ox_target cannot be used from a driver's seat**, which made the mod bay
  unreachable when it was on the eye. It is on the radial now, with the zone
  kept for anyone standing beside a car. Storing a vehicle had the identical
  defect and now has a radial entry too.
- **The MDT person search was a JavaScript ReferenceError, not a query.**
  `/mdtsearch lennox test` proved the SQL: the view held the row, `JSON_VALUE`
  read it, and ps-mdt's own query returned it. The fault was `searchProfilesResults`
  in `ui/app.js` reading `licenseTypesGlobal`, a constant referenced twice and
  **defined nowhere in the resource**, on the branch taken when a character holds
  no licences. som-core's `Config.DefaultMetadata.licenses` is `{}`, so every
  character takes that branch and the throw aborted the render before a single
  row was appended. Rows were always returned; nothing ever drew them. This is
  why it looked like an empty result rather than a crash.

  The lesson worth keeping: the diagnostic that separated "no rows" from "rows
  not rendered" was worth more than any amount of reading the SQL, because the
  SQL was never wrong.

### 16.4 The compatibility view layer

ps-mdt is written against QBCore's schema and is a preserved third-party
resource, so rather than patch twenty SQL statements, `setup.sql` section 8c
presents SOM's tables under the names ps-mdt expects: `players`,
`player_vehicles`, `player_houses`, `houselocations`, `apartments`. Three
details are load-bearing:

- `charinfo` is reassembled with `JSON_OBJECT` into the blob qb expects, and
  `birthdate` is formatted with `DATE_FORMAT` rather than passed through raw.
- `job` must be a JSON object, not a string. ps-mdt calls `json.decode` on it.
- Vehicle `state` maps from SOM's ENUM to the integers ps-mdt renders as
  Out, Garaged and Impounded.

The only two writes ps-mdt makes through a view (`server/dbm.lua:138` and
`:161`, the offline branch of licence revocation) set `metadata` on a
single-table view with no aggregate or union, which MySQL treats as updatable.

`setup.sql` also now carries section 7b (three police tables, no foreign keys),
a `som_add_index` procedure alongside the existing `som_add_column`, and the
`som_vehicles` extension: `owner_group`, `group_restricted`, `assigned_to`,
`taken_at`, `purchase_price`, with `citizenid` made nullable so a pool car can
exist without an owner.

**Re-import `setup.sql` before testing anything in this section.** It is
idempotent.

### 16.5 Diagnostics available in game

| Command | Reports |
|---|---|
| `/somperms` | Your identifiers and staff tier. Unrestricted and self-only, so it still answers when permissions are the thing that is broken |
| `/pdcoords`, `/pdzones` | Position formatted for config, and draws every configured police point |
| `/garagecoords` | Position formatted for som-garage |
| `/pddoors` | Every `ox_doorlock` record within 25m. This is what found the duplicate-door bug |
| `/mdtsearch <name>` | Runs ps-mdt's person search directly and prints what the view returned. Output still needed, see 16.6 |
| `/testphone`, `/testnotify` | Phone peek versus world toast |

### 16.6 The queue

Ordered. Item 1 blocks three separate symptoms and should be first.

1. ~~**MDT person search returns nothing.**~~ **DONE.** It was the UI branch, not
   the view. Cause and fix in 16.3 and 16.2. Officers Involved, Civilians
   Involved and charges should all be reachable now, and all three still need
   testing in game.
2. **Do not build a charges system.** ps-mdt already ships `Config.PenalCode`
   with 181 charges carrying class, penal code number, months, fine, colour and
   description, and `mdt_convictions` already stores charges, fine, sentence and
   `guilty` (the plea). It was unreachable only because of item 1, which is now
   fixed, so this stays a do-not-build.
3. **Report box is a grey rectangle and will not accept typing.** Traced, and a
   fallback is in. It is **not** `disabled`: that attribute appears only on
   `.manage-profile-info` and `.impound-plate`, never on `#reportdetail`. The
   box is a **Trumbowyg** editor, and Trumbowyg, its four plugins and its
   stylesheet all come from remote CDNs (`ui/dashboard.html:18-25`), as do
   jQuery, jQuery UI, Leaflet and Font Awesome. ps-mdt ships no editor CSS of
   its own and paints the bare textarea `#cecece4b`, so a grey rectangle that
   will not take typing is exactly what a failed `$(...).trumbowyg()` leaves
   behind.

   `ui/app.js` now declares a fallback `$.fn.trumbowyg` **only when the real
   plugin is missing**, so all twelve call sites keep working and the box
   degrades to a plain but usable textarea. Reports save either way: the save
   path reads `$("#reportdetail").val()`, the textarea, never the editor.

   Still to confirm in game, and worth doing with the NUI console open: if the
   warning `[ps-mdt] Trumbowyg did not load` appears, the CDN is the cause and
   the permanent fix is to vendor Trumbowyg into `ui/`. If the box is now a
   working plain textarea with no warning, the cause is something else and the
   fallback has masked it, so check there too.
4. **Custom progress bar.** **BUILT, not yet tested in game.** One component in
   `som-ui` in the existing dark and pink language, with `lib.progressBar`
   shimmed to it. ox_lib's UI is a compiled React bundle and cannot be restyled,
   which is why replacing beat theming.

   The architecture is the part worth remembering, because the obvious design
   does not work:

   - `som-ui/client/progress.lua` holds the STATE and does the drawing. It is
     the single claim: one token, one bar, client wide.
   - `som-ui/client/progressbar.lua` holds the blocking loop and **som-ui does
     not load it**. Consumers load it with `'@som-ui/client/progressbar.lua'` as
     the first entry in their `client_scripts`.

   Two reasons the loop has to run in the caller. ox_lib gives every resource
   its **own** `lib` table, so overriding `lib.progressBar` from inside som-ui
   would only ever override som-ui's own copy. And `progressBar` blocks: it
   yields until the action finishes, and **an export cannot yield across a
   resource boundary**, so the waiting has to happen in the caller's context.

   Three traps, all of which this hit on the first attempt and all of which are
   silent:

   - **The shim must be listed in som-ui's `files{}`**, even though it is not in
     `client_scripts`. Without that entry the client never receives the file and
     every consumer fails to start on a missing include. ox_lib lists its own
     `init.lua` for exactly this reason. This alone made the whole feature dead.
   - **The state cannot live in the shim.** A local flag gives every consumer
     its own copy, so som-police and som-compat would each believe they owned
     the one on-screen element, and the shorter action's cleanup would tear down
     the longer one's bar. ox_lib avoided this for free by living in one
     resource. som-ui now holds the token and the shim asks for it.
   - **It must be in `client_scripts`, never `shared_scripts`**, because shared
     also loads on the server, where `cache.ped` and every native it calls do
     not exist.

   Behaviour is ported from ox_lib's `resource/interface/client/progress.lua`
   rather than approximated, because callers depend on things that are easy to
   miss:

   - It interrupts on **ragdoll, cuffs, falling and swimming** as well as death,
     with `allowRagdoll`, `allowCuffed`, `allowFalling`, `allowSwimming` to opt
     out. Checking only death meant a tackled player's search still completed.
   - It sets `LocalPlayer.state.invBusy`, which ox_inventory mirrors to block
     item use, the inventory and the weapon loop. Without it a player could eat
     or draw a weapon mid-search.
   - It **queues** a second request rather than refusing it. Refusing fires
     spurious `onCancel` callbacks in preserved resources, which share one bar
     through som-compat.
   - `StopAnimTask` needs a `Wait(0)` after it or the stop is itself cancelled
     and a looping flag-49 animation outlives the bar. ox_lib carries the same
     comment.
   - Props go through **ox_lib's own networked prop system** by triggering
     `ox_lib:progressProps`. Creating them locally would have made every SOM
     prop invisible to everyone but the person holding it.
   - Cancel is a `RegisterKeyMapping` on X, so it is rebindable, rather than a
     polled control index.
   - A to-be-closed guard hands the token back even if the body throws. Without
     it one error leaves som-ui claimed forever and silently kills every
     progress bar on the client until a restart.

   Wired into som-police, som-theft and som-compat, which are the only callers.
   som-compat matters most: it carries `QBCore.Functions.Progressbar`, so every
   preserved resource gets the SOM bar for free, r14-evidence included.

   Falls back to ox_lib's bar if som-ui is stopped, so a missing progress bar
   cannot take custody and searches down with it.

   **Two claims in the original entry were wrong.** The armoury and the mod bay
   do NOT use a progress bar. `som-garage` contains no progress call of any
   kind, and `som-police/client/armoury.lua` does not call one either. The only
   callers are custody (cuff, uncuff, search), the tow in
   `som-police/client/vehicles.lua`, som-theft, and som-compat.

   Two defects in som-compat's `QBCore.Functions.Progressbar` translation were
   found and fixed at the same time: `canCancel ~= false` inverted qb's default,
   making every caller that omitted the argument cancellable, and `propTwo` and
   qb's `anim.task` scenario were dropped entirely.

   **Known integration gap, still open and undecided:** `ox_target` reads
   `lib.progressActive()` to close its eye while an action runs. ox_target does
   not load this shim, and `lib.progressActive` is not in ox_lib's `imports/`,
   so ox_target's call resolves through to `exports.ox_lib:progressActive()` and
   reads ox_lib's own state, which is now permanently false. The eye is
   therefore openable during a SOM progress. `ox_inventory` had the same problem
   and is already fixed, because it keys off `invBusy` rather than
   `progressActive`. The remaining fix is a one line patch to
   `ox_target/client/main.lua:182` to also check `exports['som-ui']:progressActive()`,
   which would add a fifth row to the ox_target section of 16.2. Not done,
   pending a decision.

   None of this has been run. It is structurally checked only, see 16.9.
5. ~~**Armoury UI redesign.**~~ **DONE, not yet seen in game.** Rebuilt against
   the certifications card in the same page, which is the part of som-police the
   owner liked. Pure UI: `html/index.html`, `style.css` and `app.js` only, no
   Lua touched and no change to the server payload, because everything needed
   was already being sent.

   What changed and why:

   - The head is now the card's head: badge, title, station name, and a count of
     what this officer can actually draw. That count is not the length of the
     config, because the server filters by certification and rank before
     sending, so it answers a real question.
   - Rows are the certification row made interactive. The left rule and a mark
     carry the state (`✓` issued, `+` buyable, `✕` blocked) instead of opacity
     alone, which read as broken rather than unavailable.
   - A blocked row now says **which account is short**, since the fix is usually
     to switch rather than to earn. Previously it just went dim.
   - Payment moved out of the header onto its own row. The header is identity,
     the switcher is a control, and cramming both made the top look busy.
   - Empty sections say so. Personal equipment is legitimately empty when
     nothing is affordable, and a blank panel looked like a failed load.
   - `.panel` and `.card` were 18px/65% against 16px/68% on radius and gradient
     stop. Close enough to look like a mistake, now identical.
   - Dead `.pay__value` rule removed. It was styled and never rendered; the
     decision not to show balances in the switcher is deliberate and stands.
6. **Vehicle inspection menus** (check plate, flag plate, impound) are still
   `lib.registerContext` and look like stock FiveM. They should move to the
   certifications card pattern, as should the mod bay menus in
   `som-garage/client/modshop.lua`.
7. **Garage UI more cinematic.** The ghost preview works; the presentation
   around it should reach the standard of the premium garage scripts.
8. **Character selector loads late.** Several seconds in the shell with no menu.
   Untraced.
9. **Dispatch overhaul.** Not researched yet, and the owner asked for research
   first: notification design, PD radio codes and blip handling cross-referenced
   across several dispatch scripts, with a features-and-examples writeup and
   confirmation before any code. The result must be pre-wired for EMS.
10. **som-dealership.** Nothing creates a civilian-owned vehicle yet, so
    personal garages are empty by construction.
11. **Adopt `r14-evidence`.** Already on disk, and better than anything worth
    writing: GSR, casings, blood, prints, vehicle forensics, per-type decay. It
    needs the som-compat surface, which now exists, and its `Config.Alerts`
    pointed at som-dispatch instead of the dead `police:server:policeAlert`.
12. **Deployables** (spike strips, cones) and **jail**.

Added after the list above was first written, and 13 and 14 are quick:

13. ~~**Empty the PD motor pool.**~~ **DONE.** `retireFleet()` in
    `som-garage/server/fleet.lua` runs at boot between reclaim and seed, and
    deletes any pool row whose model is no longer configured. It sweeps the
    DATABASE rather than looping `Config.Fleets`, so deleting a whole fleet
    block retires its rows too instead of orphaning them where no loop reaches.
    Only `owner_group IS NOT NULL AND citizenid IS NULL` is touched, which is
    exactly what the seeder creates, so a bought vehicle is never retired.
    `Config.Fleets.lspd.vehicles` is now `{}`, with the old list kept in a
    comment. Ordering matters: reclaim marks everything garaged first, so
    nothing deleted can be a car somebody is driving.
14. ~~**Storing a vehicle has no radial entry.**~~ **DONE.** `garage.store` is on
    the radial in the `vehicle` section, so it appears seated or standing beside
    a car and never on an empty street. `nearestGarage()` took a `fromVehicle`
    parameter rather than being reused as-is: it returns nil from a driver's
    seat by design, which is the exact state storing needs, so `hasGarageNear`
    could not have served as the visibility check. New exports `canStoreNear`
    and `storeNearest`. The eye on the zone is kept.
15. **Replace the police fleet.** The audio half is **DONE**, see 16.7. Judge the
    pack again with sound before choosing a replacement. Research and
    recommendation still owed, then the owner installs and Claude wires up
    `Config.Fleets`, `som.cfg` and the meta.
16. **Lore-friendly NPC traffic.** Research task, not started. Note the
    constraint in 16.8.

Deferred, previously agreed: officer map blips with callsigns, an F1 panic
button with sound, the gang and boss laptop app, an end-of-phase coherency pass
across every UI, and anticheat tuning.

### 16.7 Vehicle assets: what works and what does not

| Pack | State |
|---|---|
| `origen_police` | On disk and started. Audio now fixed, see below. Rear lights sit wrong on some models, which is a model defect and not config. Its `carcols.meta` loads correctly, and the `*.xml`, `*.dat` and `*.ytyp` manifest warnings are dead globs matching nothing. No longer in any fleet: `Config.Fleets.lspd.vehicles` is empty |
| `ex-cars` police pack | Judged unfit for broken liveries and misaligned headlights, but now STARTED, because `ensure [assets-streams]` is a group ensure and cannot skip a member. 365MB every client downloads. Nothing references it |
| `TIG-PACK` | Models do not spawn. Also started now, for the same reason. Harmless, still downloaded |
| `rd-vehicleconfig`, `ro-VehicleConfig` | Declare roughly 400 models with no stream folder, so those models still do not exist. But `rd-vehicleconfig/handling.meta` holds **598 entries and now loads**, overriding vanilla handling for real base game cars server wide. If ordinary traffic starts handling oddly, look here first |
| `karma_visuals` | Now started. Replaces `vehicles.meta` for 299 vanilla models and carries its own timecycle, weather, water and popcycle. A global visual change. Also the reference that identified the empty-audio mechanism |

**`ensure [assets-streams]` is now active** at the owner's request, so the whole
group loads: roughly 5GB, a much longer boot, and a large first download per
client. A group ensure is all or nothing. To drop any member, move its folder
out of `[assets-streams]`; it cannot be excluded from the config.

Vanilla police models were removed from the shared garage at the owner's
request. Liveries and mod bay changes now persist per vehicle, and
`Config.ResetPoolProps` is off so pool cars keep what was set on them.

**The police cars were silent because their audio was unset, not because the
models are bad.** Fixed. `karma_visuals/vehicles.meta` is a 299 model vanilla
dump in which every base game car carries `<audioNameHash />` empty, which
proves the mechanism: an empty hash means *fall back to the model name*, so
`polcaracara` asked the engine for a bank called `polcaracara`, which does not
exist, and got silence.

The base model behind each was identified by matching `fMass` and gear count
against `rd-vehicleconfig/handling.meta`, a 598 entry vanilla handling table
already on disk, rather than by guessing from the name:

| Model | Was | Now | How the base was identified |
|---|---|---|---|
| `polcaracara` | empty | `caracara2` | mass 2480 matches CARACARA2 exactly |
| `polvstr` | empty | `vstr` | mass 1878 and 7 gears match VSTR exactly |
| `polcomet` | empty | `comet6` | mass 1550 matches COMET6 exactly. comet3/4/5 are 1200/1150/1500 |
| `polvigero2` | empty | `vigero2` | by name. VIGERO2 is absent from the dump |
| `poldom` | `tamustanggt50p` | `dominator` | mass 1670 and 5 gears against DOMINATOR 1669/5. Was pointed at a Mustang addon bank that is not installed |
| `polbuffalo4` | `schafter4` | `buffalo4` | by name. DLC era, absent from the dump |

**If `polbuffalo4` is the one that goes silent, revert that line to `schafter4`.**
It was the only model with working sound before this change, because `schafter4`
is a real base game bank, just the wrong car. The other five could only improve.
`buffalo4`, `caracara2`, `comet6`, `vigero2` and `vstr` are DLC cars whose
vanilla `vehicles.meta` lives inside `update.rpf`, which is binary and cannot be
read from this repo, so those five rest on the model name fallback convention
rather than on a direct read. Thirty seconds of listening settles each one.

**Handling is not broken, it is tuned hot and uniformly.** Every model has a
`handling.meta` with a matching `<handlingName>`, so nothing is missing. Against
the vanilla values the pack raises the same three fields on all six:

| Field | origen | vanilla |
|---|---|---|
| `fBrakeForce` | 1.00 to 1.50 | 0.40 to 0.60 |
| `fInitialDriveForce` | 0.245 to 0.350 | 0.180 to 0.255 |
| `fInitialDriveMaxFlatVel` | 200 to 250 | 175 to 177 |

`polcaracara` is a 2.5 tonne 4x4 carrying a 250 top speed figure. That is an
arcade pursuit tune applied across the board, not a defect, so whether it is
wrong is the owner's call and not a bug to fix.

**Judge the pack again now that the audio is fixed.** Deciding to replace six
models on the evidence of a blank config field would have been replacing them
for the wrong reason.

### 16.8 Constraint on any vehicle pack work

Claude must not add, move or modify binary assets: `stream/`, `*.yft`, `*.ytd`,
`*.ydr`, `*.ydd`, `*.ybn`, `*.awc` and audio packs are all out of scope per
CLAUDE.md. Installing a vehicle pack is therefore **the owner's step**, and the
most any session can do is research and recommend one, then wire up the config,
`som.cfg` and the `.meta` files once the files are on disk.

`.meta` files are text and may be edited. `[assets-streams]` is **gitignored**
(`.gitignore:75`), so anything inside it is invisible to git by default. The six
`origen_police` `vehicles.meta` files were force added with `git add -f` and are
now tracked individually, so those edits ARE in history and can be recovered.
The binary streams around them stay ignored, which is the point: never
`git add` the directory, only named text files inside it.

### 16.9 Not verified

- Every coordinate other than MRPD duty, armoury, locker, garage and the mod
  bay, all of which were measured in game.
- No Lua toolchain is installed and there is still no `.luacheckrc`, so nothing
  in this phase has been syntax checked by a tool. Checks were structural: block
  and bracket balance, callback name cross-referencing between client and
  server, and `node --check` on the JavaScript.
- Everything in 16.1 has been exercised by hand in game except jail,
  deployables and evidence, which are not built.

---

## 17. Feature gap register

Cross-referenced against **140 distinct sources**: 22 public roleplay servers,
16 server templates, 20 frameworks and 82 free resource bundles. Five feature
domains were surveyed and **104 gaps** recorded. **76 are missing outright and
28 are partial.** By how common they are across the surveyed servers: 51 are
near universal, 45 are common, 8 are differentiators.

**The honest read.** SOM is further along than a typical build at this stage in
exactly one half of the problem and barely started in the other. The framework
layer is genuinely strong: server-authoritative money with a full ledger, a
single mint path for vehicles, a compat layer that lets preserved third-party
resources run untouched, a radial that cannot be told to fire an arbitrary
event, and a dispatch that refuses client-authored calls. Several surveyed
servers, including well known ones, do worse on every one of those.

The content layer is where the work is. There is no death or downed state, so a
shooting has no consequence. There is no route for a civilian to own a vehicle,
so personal garages are empty by construction. There is no housing, no drugs, no
robberies, no freelance job loop, and no way to get a job without a staff member
typing `/setjob`. **32 player-facing capabilities exist today**, and most of them
are police or framework.

So "very little done" is wrong, but "very little a player can DO" is right. That
is a normal consequence of having built the authority layer first, which was the
correct order, and it does mean the visible surface lags a long way behind the
foundation.

**One domain was not surveyed.** Social and world systems (phone apps, clothing,
gyms, casinos, activities, HUD, admin tooling) hit the session limit and never
ran, as did the automated synthesis. This register was assembled by hand from
the five domains that completed. Treat social and world as unknown rather than
empty.

### 17.1 How to read this

- **How common**: near universal means nearly every surveyed server has it;
  common means most do; differentiator means few do and it would stand out.
- **SOM status**: strict. A resource existing but the capability not being
  reachable by a player counts as missing or partial, not present.
- **Effort**: small is under a day, medium one to three days, large about a
  week, epic multiple weeks.
- **Free option** names a genuinely free or open source resource. Paid and
  escrowed scripts were excluded from sourcing entirely.

Only gaps are listed. Anything SOM fully has is absent from these tables, which
is why the police section looks thin relative to how much police work exists.

### 17.2 The critical path

Not everything, just the ordered sequence that unblocks the most.

1. **Death and downed state.** Epic, and it is the single next thing to build.
   Nothing on this server currently has stakes: you cannot be killed, revived or
   hospitalised. It blocks EMS, revive, injuries, the morgue, jail intake, five
   dispatch call types including officer down, r14-evidence's value, and the
   entire consequence side of every crime feature below it. Every other item
   competes for second place; this one has no substitute.
2. **Vehicle keys and hotwiring.** Medium. Turns vehicle theft from taking a car
   into a crime, and is the precondition for boosting and for a chop shop
   meaning anything.
3. **A dealership.** Large. Until a civilian can own a car, personal garages,
   insurance, player-to-player sale and the whole vehicle economy are empty.
4. **Getting a job without staff.** Medium. Everything in the economy domain is
   gated behind a human typing `/setjob` today.
5. **One freelance earning loop.** Medium for the first one. A new player
   currently has no way to earn anything at all.

### 17.3 Cheap wins, disproportionate value

Twenty-seven gaps are small. These are the ones where the ratio is best, several
because the work is already done and only needs wiring:

| Gap | Why it is cheap |
|---|---|
| ~~Fuel stations~~ | **Corrected: not cheap.** See below |
| Lockpick and hack minigame | `ox_lib` skillcheck is already installed |
| Clothing shops and barbers as places | som-appearance is built; it needs som-interact zones |
| Custom loading screen | The `loadingscreen` resource already exists |
| Spawn point selection on login | Small, and it is the first thing a player ever sees |
| Cash withdrawal from the bank | Bank money cannot currently become cash |
| Suppressing vanilla NPC police | Small, and vanilla wanted stars undermine every police feature |
| Police patrol vehicles | The fleet system works; `Config.Fleets.lspd` is deliberately empty pending a pack |
| Photo on ID cards | `screenshot-basic` is already started |
| Money visible without opening the phone | Needs a HUD, which does not exist yet |

**Correction, made while starting on this list.** Fuel was recorded as small
because `cdn-fuel` is on disk. It is not small. Its manifest hard-depends on
`qb-target`, `qb-input` and `qb-menu`, none of which are installed, and it
shared-scripts `@qbx_core/shared/locale.lua`, and **qbx_core is removed from
this server**, so it fails at load rather than degrading. Its ox_lib and
ox_target branches exist but are commented out. Making it work means switching
those branches, dropping the qbx_core include and rewiring its targets to
som-interact: a medium, not a small. `ox_fuel` would be the genuinely cheap
route and is **not** installed. Treat the row above as medium until one of those
two is resolved.

**Done from this list:** vanilla NPC police and the wanted star system are now
suppressed in `som-core/client/main.lua`, configured by `Config.World`. Left on,
GTA answers every shooting with its own infinite police who shoot back and
arrest nobody, which makes the entire player police force decoration.

### 17.4 Emergency services (30 gaps)

| Feature | How common | SOM | Effort | Free option |
|---|---|---|---|---|
| Death and downed state | near universal | missing | epic | qbx_medical (GPL) |
| Revive and medical treatment | near universal | missing | large | build on the above |
| Ambulance job and hospital | near universal | missing | large | qb-ambulancejob |
| Jail and serving a sentence | near universal | missing | large | qb-prison |
| Police patrol vehicles | near universal | missing | small | build, fleet exists |
| Evidence and forensics | near universal | missing | medium | r14-evidence, already on disk |
| Officer blips, callsigns, panic | near universal | missing | medium | build |
| Working service radio | near universal | partial | medium | pma-voice channels exist |
| Dispatch as a real system | near universal | partial | medium | in progress |
| Calling 911 from the phone | near universal | partial | medium | build in som-phone |
| Warrants and wanted status | near universal | partial | medium | ps-mdt ships warrants |
| Citations from the MDT charge list | common | partial | small | build |
| Booking a prisoner (mugshot) | common | missing | medium | MugShotBase64 |
| ANPR and speed radar | common | missing | medium | wk_wars2x (MIT) |
| Police deployables | common | missing | medium | free spike strips |
| Limb injuries and wound effects | common | missing | medium | qb-ambulancejob |
| Air support | common | partial | medium | free helicam |
| K9 unit | common | missing | medium | v-k9 |
| Fire and rescue | common | missing | large | qb-firefighterjob |
| Holding cells, bail, transport | common | missing | medium | qb-prison |
| More than one agency and station | common | missing | medium | build, som-police is configurable |
| CCTV | common | missing | medium | qb-policejob camera code |
| SWAT and tactical kit | common | missing | medium | qb-policejob stormram |
| AI medic fallback | common | missing | small | build |
| Courts and DOJ | differentiator | missing | large | qb-doj |
| Morgue, coroner, permadeath | differentiator | missing | medium | build |
| Bodycam and dashcam | differentiator | missing | medium | ps-mdt v3 |
| Ankle monitor and parole | differentiator | missing | small | qb-policejob |
| Weapon serial registry, ballistics | differentiator | missing | medium | ps-mdt firearm registry |

### 17.5 Vehicles and property (22 gaps)

| Feature | How common | SOM | Effort | Free option |
|---|---|---|---|---|
| Dealership, any route to owning a car | near universal | missing | large | qb-vehicleshop |
| Vehicle keys, lockpicking, hotwiring | near universal | missing | medium | qbx_vehiclekeys |
| Fuel and refuelling | near universal | missing | small | cdn-fuel, on disk |
| Housing and apartments | near universal | missing | epic | ps-housing |
| Mechanic shop and repair | near universal | missing | large | jim-mechanic |
| Vehicle HUD, speedo, fuel gauge | near universal | missing | medium | build som-hud |
| Job and emergency fleets with real cars | near universal | partial | small | build |
| Paid customisation shop | near universal | partial | medium | jim-mechanic catalogue |
| Player to player vehicle sale | common | missing | medium | qb-vehiclesales |
| Impound release fee for civilians | common | partial | small | build |
| Furniture and decoration | common | missing | large | ps-housing |
| Property storage and house garage | common | missing | medium | ps-housing or ox_property |
| Property rental and landlords | common | missing | medium | qbx_properties |
| Racing | common | missing | medium | qb-streetraces |
| DMV and driving test | common | missing | medium | qb-cityhall |
| Vehicle registration and plate ownership | common | partial | small | build on som-police plate flags |
| Vehicle insurance | common | missing | medium | free QBCore insurance |
| Businesses as property, boss menu | common | missing | large | qb-management |
| Garage coverage and types | common | partial | medium | qbx_garages |
| Chop shop | common | missing | medium | elixir-ui chopshop, on disk |
| Tow truck job | common | missing | medium | qb-towjob |
| Rentals surviving a restart | common | partial | small | build, persist to a table |

### 17.6 Crime and illegal (23 gaps)

| Feature | How common | SOM | Effort | Free option |
|---|---|---|---|---|
| An in-world way to sell illegal goods | near universal | partial | small | build on som-economy |
| Drug production chain | near universal | missing | large | md-drugs |
| Store robberies | near universal | missing | medium | qbx_storerobbery |
| Vehicle keys, hotwiring, real theft | near universal | missing | large | qbx_vehiclekeys |
| Jail and prison sentence | near universal | missing | large | qb-prison |
| Suppressing vanilla NPC police | near universal | missing | small | qbx_smallresources |
| Gang org: boss menu, ranks, stash | near universal | partial | medium | qb-management |
| ATM robberies | near universal | missing | small | free ATM robbery scripts |
| Bank and jewellery heists with prep | near universal | missing | epic | qb-bankrobbery, qb-jewelery |
| Chop shop | near universal | missing | medium | free chop shop |
| Money laundering | near universal | missing | medium | ren-laundering |
| Lockpick and hacking minigames | near universal | partial | small | ox_lib skillcheck, installed |
| Black market and weapon dealing | near universal | partial | medium | glow_blackmarket |
| Police alerts for the full crime set | near universal | partial | small | build, som-dispatch exists |
| Robbing another player | near universal | partial | medium | build, som-theft exists |
| Boosting contracts | common | missing | large | qb-car-boost |
| House robbery | common | missing | medium | qb-houserobbery |
| Evidence and forensics | common | missing | medium | r14-evidence, on disk |
| Turf and territory | common | missing | large | qb-gangs |
| Counterfeiting | common | missing | medium | free printer scripts |
| Bounty board | common | missing | medium | free bounty hunting |
| Drug effects on the user | common | missing | small | md-drugs |
| Train robbery | differentiator | missing | large | free train heist |

### 17.7 Core identity and progression (11 gaps)

| Feature | How common | SOM | Effort | Free option |
|---|---|---|---|---|
| Licence issuance and DMV testing | near universal | missing | medium | qb-cityhall |
| Barber, clothing and tattoo shops | near universal | partial | small | build, som-appearance is done |
| Spawn point selection on login | near universal | missing | small | qb-spawn |
| Custom loading screen | near universal | missing | small | resource already present |
| Character select fit for players | near universal | partial | small | build |
| Status metadata that actually drains | near universal | partial | small | build the drain and the effects |
| Weapon licence gating and revocation | near universal | partial | small | qb-cityhall plus existing police verbs |
| Photo on ID cards and licences | common | missing | small | MugShotBase64 |
| New player onboarding | common | missing | medium | free spawn tutorial |
| Job uniforms and clothing rooms | common | missing | medium | build on som-appearance |
| Skills, XP and reputation | common | missing | large | xperience, pn-skills |

### 17.8 Economy and legal jobs (18 gaps)

| Feature | How common | SOM | Effort | Free option |
|---|---|---|---|---|
| Bank money into cash (ATM or teller) | near universal | missing | small | build |
| Getting a job without a staff member | near universal | missing | medium | qb-cityhall |
| Freelance earning loops | near universal | missing | epic | qb-truckerjob, qb-garbagejob and others |
| Buying a personal vehicle | near universal | missing | medium | qb-vehicleshop |
| Fuel stations | near universal | missing | small | ox_fuel or cdn-fuel |
| Boss menu for a job or business | near universal | missing | medium | qb-management |
| Somewhere to sell what you gathered | near universal | missing | medium | qb-pawnshop as a pattern |
| Mechanic job | near universal | missing | medium | qb-mechanicjob |
| Clothing shops and barbers as places | near universal | partial | small | build, only wiring left |
| Money visible without the phone | near universal | missing | small | build a HUD |
| Player-owned businesses | common | missing | large | flex-ownedshops |
| Player to player commerce | common | missing | large | zz-marketplace |
| Crafting | common | partial | medium | ox_inventory crafting is present |
| Taxes | common | partial | medium | build, som-economy has the config |
| Tow job | common | partial | medium | qb-towjob |
| Professional whitelisted roles | common | missing | large | qb-newsjob and others |
| Loans and credit | differentiator | missing | medium | free loans script |
| Crypto trading | differentiator | partial | medium | qb-crypto |

### 17.9 What SOM already does better than the surveyed servers

Truthful, specific, and worth protecting when adding anything above.

- **Money has no client-reachable event at all.** Every movement goes through
  som-core and writes a ledger row tagged with the calling resource. Several
  surveyed servers ship money events a client can trigger.
- **Dispatch refuses client-authored calls.** ps-dispatch, which a large part of
  the ecosystem runs, accepts the entire call payload from the client including
  priority and coordinates, and its attach flow takes the unit's identity from
  the client too. som-dispatch derives all of it server side.
- **One mint path for vehicles.** `Vehicles.Create` is the only code that
  creates a `som_vehicles` row, so plate uniqueness and ownership shape are
  decided once rather than in every caller.
- **The radial cannot fire an arbitrary event.** Entries name a validated
  export, and job and gang filtering happens server side rather than in CSS.
- **The progress bar is stricter than ox_lib's callers expect.** It interrupts
  on ragdoll, cuffs, falling, swimming and death, and sets `invBusy` so a player
  cannot eat or draw a weapon mid-action.
- **A compat layer instead of forked third-party code.** ps-mdt, ox_doorlock and
  ox_inventory run against som-core through som-compat and a SQL view layer, so
  they stay upgradeable instead of becoming forks.
- **Every diagnostic is in game.** `/mdtsearch` is the reason the MDT search bug
  was found in one step rather than a debugging pass down the wrong path.

### 17.10 Not surveyed

- Social and world systems: phone apps beyond banking, social media, clothing
  stores, gyms, casinos, activities and minigames, weather and time sync, world
  events, HUD, scoreboard, admin tooling, anticheat tuning and logging. The
  agent covering this hit the session limit. Assume gaps here too.
- Everything in this register is desk research against public sources plus a
  read of this repo. None of it has been validated by playing the surveyed
  servers.

---

## 18. Roadmap: current stage to launch

Section 16.6 is the near-term queue and stays as it is. This section is the
whole road, so that any queue item can be placed against it and so the size of
what is left is visible rather than felt.

Ordering principle throughout: **build the thing that unblocks the most next,
not the thing that demos best.** A feature with no consequence layer under it
produces a screenshot, not a server.

Effort per phase is engineering time with one person working, and assumes the
free resources named in section 17 are adopted rather than written from scratch
wherever they fit.

### 18.0 Where we are

Framework layer largely done: authority, persistence, money and ledger,
permissions, compat, inventory, phone, radial, eye, notifications, progress,
character creation and selection, police, garages, dispatch skeleton, MDT.

Content layer barely started: 32 player-facing capabilities, most of them police
or framework, and nothing on the server currently has a consequence.

### 18.1 Phase 1: World feel and cheap wins

**Goal.** The server stops feeling like a fresh FiveM install within one working
session. Nothing here is architectural; it is all wiring and settings.

- Suppress vanilla NPC police and the wanted system. **DONE.**
- Spawn point selection on login.
- Custom loading screen (the resource is already on disk).
- Clothing shops, barbers and tattoo as real places, wiring som-interact zones
  to the existing som-appearance.
- Lockpick and hacking minigames on `ox_lib` skillcheck, already installed.
- Photos on ID cards and licences via MugShotBase64 and screenshot-basic, both
  already on disk.
- Cash withdrawal and deposit, so bank money can become cash.
- Character status metadata that actually drains and has effects.
- A HUD, so money, hunger, thirst, armour and vehicle state are visible without
  opening the phone. This is the one item here that is a new build.

**Exit criteria.** A new player can join, choose where to spawn, look how they
want, see their own status, and no vanilla police ever appear.

**Effort.** Roughly a week.

### 18.2 Phase 2: Consequence

**Goal.** Things that happen to a player matter. This is the phase the whole
server is currently missing, and every crime and police feature is worth more
after it than before it.

- **Death and downed state.** Bleeding out, last stand, respawn rules, death
  timer. The single highest-value item on this roadmap.
- Revive and medical treatment, and the item and skill gating around it.
- Ambulance job and a hospital, including AI medic fallback so the loop closes
  when no medic is online.
- Limb injuries and wound effects that persist until treated.
- **Jail and serving a sentence.** Today an arrest ends with nowhere to put
  anybody. Holding cells, bail, prisoner transport.
- Morgue and coroner, and a decision on permadeath.
- Wire som-dispatch's EMS half, which is already pre-wired for it.

**Exit criteria.** A shooting produces a casualty, a medic, a hospital record
and, if police attend, an arrest that ends in a cell.

**Effort.** Three to four weeks. This is the biggest single phase.

### 18.3 Phase 3: Police to a competitive standard

**Goal.** som-police stands next to a serious server's police department. See
18.9 for the specific comparison this phase is written against.

- **Dispatch NUI.** The current notification is a generic toast and reads as
  one. Own call stack, priority tiers, code chips, evidence rows, per-tier
  tones, point and radius blips.
- Full call taxonomy with a real code table, and a server-side caller for each
  from the resource that owns the mechanic.
- Officer map blips, callsigns and an F1 panic button with sound.
- Evidence and forensics: adopt r14-evidence, which is already on disk and
  currently fires at a dead event with its alerts disabled.
- Booking: mugshot, prints, property, charges from the MDT's 181-charge list.
- Deployables: spike strips, cones, barriers, road flares.
- ANPR and speed radar via wk_wars2x, which is MIT.
- Warrants that actually drive behaviour rather than only being records.
- Weapon serial registry tied to evidence and ballistics.
- More than one agency and more than one station.
- K9, SWAT kit, air support with a helicam.
- Bodycam, dashcam and CCTV.
- Courts and DOJ, so charges have a destination.

**Exit criteria.** An officer can run a full shift, from patrol and a traffic
stop through pursuit, arrest, booking, evidence and charges, without leaving the
game to do any of it.

**Effort.** Three to four weeks, and it depends on phase 2 for the arrest to
mean anything.

### 18.4 Phase 4: The vehicle economy

**Goal.** Cars can be owned, stolen, kept and lost. Personal garages stop being
empty by construction.

- **Vehicle keys, lockpicking and hotwiring.** Turns theft from taking a car
  into a crime.
- **A dealership.** New and used, with a test drive and a finance option.
- Fuel, resolving the cdn-fuel or ox_fuel decision recorded in 17.3.
- Mechanic shop, repair and a paid customisation catalogue.
- Vehicle HUD: speedometer, fuel and indicators.
- Player-to-player sale, registration and plate ownership.
- Insurance, and impound release fees for civilians.
- Tow job.
- Racing.

**Exit criteria.** A player can earn money, buy a car, insure it, modify it,
have it stolen, and get it back from an impound lot.

**Effort.** Three weeks.

### 18.5 Phase 5: Earning a living

**Goal.** A new player has something to do that pays, without a staff member
typing a command.

- Getting a job without staff: a city hall or job centre.
- Licence issuance and a DMV driving test.
- Freelance loops: trucker, garbage, bus, taxi, delivery, mining, fishing,
  hunting. The first is medium, each after it is small.
- Somewhere to sell what was gathered.
- Boss menus, hiring and firing, society accounts.
- Player-owned businesses.
- Crafting, using the ox_inventory crafting that is already present.
- Taxes, which som-economy already has config for.
- Professional whitelisted roles: lawyer, judge, news, real estate.

**Exit criteria.** A player who joins with nothing can reach a first car
entirely through legal work.

**Effort.** Three to four weeks.

### 18.6 Phase 6: Crime with a supply chain

**Goal.** Illegal money has a source, a process and a risk, rather than being a
single button.

- Store robberies, ATM robberies, house robbery.
- Drug production chains and drug effects.
- Chop shop and boosting contracts.
- Money laundering and counterfeiting.
- Black market and illegal weapon dealing.
- Bank and jewellery heists with prep chains.
- Gang organisation, stashes, and turf.
- Bounty board.
- An in-world route to sell illegal goods, which som-economy is half way to.

**Exit criteria.** Every illegal income stream has a preparation step, a police
alert, and a way to lose the proceeds.

**Effort.** Four weeks.

### 18.7 Phase 7: Property

**Goal.** Somewhere to live and somewhere to keep things.

- Housing and apartments, purchase and rental.
- Property storage, wardrobes and house garages.
- Furniture and decoration.
- Landlord relations.
- Businesses as property.

**Exit criteria.** A player has an address, storage and a reason to defend both.

**Effort.** Three weeks. Epic if written rather than adopted.

### 18.7b Phase 7b: Identity and continuity

**Goal.** The server stops looking stale and starts looking like itself. Full
detail in 18.12, including the inventory reskin, which is the largest unstyled
surface on the server.

Run **twice**: a first pass now at the end of phase 1 while the surface is small
enough to fix cheaply, and a second before launch when everything exists.
Leaving it all until the end means reconciling forty screens instead of ten.

**Exit criteria.** Five screens side by side read as one product to somebody
who has not seen the server before.

**Effort.** One week for the first pass, two for the second.

### 18.8 Phase 8: Depth, then launch readiness

**Goal.** The things that keep players past week two, then the things that keep
the server up.

Depth: skills, XP and reputation; activities and minigames; casinos; gyms;
social media and the rest of the phone; world events; racing leagues.

Launch readiness, none of which is optional:

- Performance pass under load, with the ~5GB asset group live.
- Anticheat tuning against real player behaviour rather than defaults.
- Logging and staff tooling: an admin menu, reports, and a paper trail on every
  economy and item movement.
- New player onboarding.
- A backup and restore procedure that has actually been tested by restoring.
- A staging server, so changes stop being tested in production.
- Rules, a Discord, and an application or whitelist flow if the server is
  whitelisted.
- Load testing with more players than are expected on opening night.

**Effort.** Four weeks, and the launch readiness half is the part most likely to
be skipped and most likely to hurt.

### 18.9 What a competitive PD needs, measured against ours

Written against the standard the owner named. Ordered by how badly the absence
is felt, not by effort.

| Need | SOM today | Why it matters |
|---|---|---|
| Somewhere to put an arrested person | **Missing** | An arrest currently ends with the officer holding a cuffed player and no next step. This is the single largest hole in the department |
| A casualty state | **Missing** | No officer down, no shooting with a victim, no reason for EMS or for the whole custody chain to exist |
| Dispatch that reads as dispatch | **Partial** | The owner's own assessment is that it looks like a standard notification. Correct, and it is the most visible part of police work |
| Evidence that ties a scene to a suspect | **Missing** | r14-evidence is on disk, better than anything worth writing, wired to a dead event and disabled |
| Knowing where other units are | **Missing** | No officer blips, no callsigns, no panic button. Officers currently coordinate entirely by voice |
| Stopping a vehicle | **Missing** | No spike strips, no ANPR, no radar. Traffic policing is most of a real shift and almost none of it is supported |
| Booking | **Missing** | No mugshot, no prints, no property. ps-mdt supports images and MugShotBase64 is already on disk |
| Charges reaching a destination | **Partial** | 181 charges exist and are reachable now that the MDT search is fixed, but nothing consumes a sentence because there is no jail and no court |
| More than one agency | **Missing** | One department and one station. State police, sheriff and their own stations are standard |
| Cameras | **Missing** | Bodycam, dashcam and CCTV are all differentiators rather than requirements, but the named servers all have them |

**The honest summary.** som-police has a genuinely good foundation: duty,
armoury, custody, fines, impounds, certifications, plate flags and an MDT that
now works. What it does not have is a **beginning and an end**. There is no
casualty to respond to and no cell to finish in, so the middle, which is the
part that is built, has nothing to connect. Jail and the downed state are worth
more to the police experience than every remaining item on the list combined.

### 18.10 Honest total

Roughly **five to six months** of single-person full-time work from here to a
launchable server, assuming free resources are adopted where they fit rather
than written from scratch, and assuming the launch readiness phase is not
skipped.

That is not a discouraging number for a build with this much framework already
correct. The expensive half, the part that is hard to retrofit, is largely done:
server authority, a ledger on every money movement, a single mint path for
vehicles, and a compat layer that keeps third-party resources upgradeable. Most
of what remains is content on top of a foundation that will hold it.

### 18.11 Feedback: the cross-cutting gap

Raised by the owner against the armoury, and correctly diagnosed as general
rather than local: **nothing on this server acknowledges an action.** A purchase,
a vehicle coming out of a garage, a door unlocking, a fine being paid. All of
them changed numbers silently and left the player to infer the outcome from a
list redrawing. That is the difference between a shop and a debug menu, and it
is not a per-screen problem, so it is not being solved per screen.

**The split.** Sound is central, visuals are local.

- `som-ui/client/feedback.lua` exports `playSound(kind)` against a vocabulary in
  `som-ui/shared/config.lua`: `purchase`, `success`, `error`, `select`, `nav`,
  `back`. Every resource asks for a meaning, never an audio string, which is
  what stops the armoury and a future dealership drifting into two different
  purchase sounds. There is also a `som-ui:client:sound` net event for feedback
  the client cannot know it earned, such as a fine landing.
- The VISUAL half belongs to whichever UI is on screen, because only it knows
  what moved.

Sounds are the game's own frontend sets, following the precedent som-phone
already set: guaranteed present on every client, no streaming, no licence
question, and already meaningful to players. **None has been heard on this
server yet.** If one is silent it is a wrong string rather than broken code, and
it is a one line fix in config. That is why they are config.

**The armoury is the first consumer**, and it is worth reading as the template
for every shop that follows:

- A free issue item and a $95,000 rifle no longer sound the same. Drawing from
  department issue plays `success`; spending money plays `purchase`.
- The balance is back on the payment switcher. An earlier pass removed it on the
  grounds that the player already knows what they have, which was right in
  isolation and wrong in context: with it gone, nothing on screen moved when you
  bought something, so a success and a refusal looked identical. **The number
  changing is the feedback.**
- The amount floats up out of the account that paid it, because two balances a
  second apart do not tell you what something cost.
- The row you drew from flashes, so the click is acknowledged by the thing you
  clicked.
- The footer becomes a receipt: what you drew and what it cost. Deliberately the
  footer rather than a toast, because a toast is for things that went wrong and
  vanishes before it is read, while what you just bought is worth leaving on
  screen as you keep shopping.
- `takeItem` now echoes the item, label, count and price back. The client uses
  it for the confirmation line and to choose the sound, never to decide whether
  the purchase was allowed.

**Still to wire**, in rough order of how badly each is missed: garage take and
store, the mod bay, rentals, fines and bills arriving, door lock and unlock,
custody actions, and every shop added from here. None is more than a few lines
now that the layer exists.

### 18.12 Identity and continuity: the missing phase

The roadmap as first written had no phase for how the server LOOKS, and that is
a real omission rather than a detail. The owner's assessment is that the server
currently looks stale and has no distinction of its own, and that the leading
servers have a wow factor this does not. Both are correct.

This is not a polish pass to be tacked onto the end. Continuity is a phase with
its own exit criteria, and it fails if it is left until last, because by then
there are forty screens to reconcile instead of ten.

**Run it twice.** Once now, at the end of phase 1, while the surface is small
enough to fix cheaply. Once again before launch, when everything exists.

#### What continuity actually means here

- **One visual language, enforced.** `som-assets/tokens.css` exists and is the
  single source of truth. Every som-* NUI already imports it. The failure mode
  is not missing tokens, it is screens that import them and then hardcode
  values anyway, which is how `.panel` and `.card` ended up at 18px/65% against
  16px/68% and looked like a mistake. An audit pass over every NUI for local
  values that should be tokens.
- **One motion language.** Durations, easings and entrance directions currently
  differ per screen because each was written on its own day. Pick one set, put
  it in tokens, apply everywhere.
- **One sound language.** Now started, see 18.11. Every screen and every action
  either has a feedback sound or has a reason not to.
- **One empty state, one error state, one loading state.** A blank panel that
  looks like a failed load is a bug that appears once per screen.
- **A brand that is not just a colour.** Pink is a palette, not an identity. A
  logo treatment, a typographic voice, a consistent card silhouette, a login and
  loading sequence that says which server this is.

#### Named work

| Item | What it is | Effort |
|---|---|---|
| **Full inventory reskin** | ox_inventory's stock UI is the single largest unstyled surface on the server and the one players look at most. It must be brought into the SOM language: card shape, tokens, motion, sounds. This is the highest-value visual item on the roadmap | large |
| **Inventory icon set** | Currently a mix of realistic and cartoon, with some items missing icons entirely. See the constraint below | medium |
| Phone visual pass | Slide-up animation, banner design, app chrome. Currently functional and plain | medium |
| Loading screen and login sequence | First thing anyone sees, and currently the stock one | small |
| HUD | Does not exist. Whatever is built sets the tone for everything around it | medium |
| Motion and token audit | Every NUI, checked against tokens | medium |
| Map, blips and waypoint styling | Coloured minimap is in; blip sprites and colours are still per-resource choices | small |
| Character selector presentation | Works, looks plain, and is the second thing anyone sees | medium |
| Death, arrest and jail screens | Do not exist yet. They arrive with phase 2 and must arrive already in-language | medium |

#### Constraint on the icon set

**Icons are binary assets and cannot be added by Claude**, exactly as vehicle
packs cannot. The most any session can do is recommend a set and wire the config
once the files are on disk.

What is needed is a **single complete set covering every item in
`ox_inventory/data/items.lua` plus every som-* item**, in one consistent style.
Mixing two sets is what produces the current half-realistic half-cartoon result,
and adding a few missing icons from a third source makes it worse rather than
better.

Sourcing rules apply as everywhere else: a freely redistributable set, or one
whose licence permits use on a game server. Icon packs are commonly redistributed
without a clear licence, and "found in another inventory script" is not a
licence. This needs checking before adoption, not after.

Once the files are on disk the wiring is small: ox_inventory resolves an item's
image from its name, so a complete set in one folder needs no per-item config.
The audit work is finding the items that have NO icon, which is a script that
lists every item name against the icon folder and prints the misses.

#### Exit criteria

A screenshot of any five screens, shown side by side, reads as one product by
somebody who has not seen the server before. No screen uses a colour, radius,
duration or font that is not in tokens. Every action has feedback. Nothing is
stock.

---

## 19. Session handoff, second pass

Supersedes nothing in 16; that section is still accurate about what it covers.
This is what changed since, what has never been run, and what to do first.

### 19.1 What was built

| Thing | Where | State |
|---|---|---|
| MDT person search | `ps-mdt/ui/app.js` | Fixed. Was a ReferenceError, not SQL |
| MDT report box | `ps-mdt/ui/app.js` | Falls back to a plain textarea when Trumbowyg's CDN is unreachable |
| Fleet retire path | `som-garage/server/fleet.lua` | Pool empties on the next full boot, not a resource restart |
| Store on the radial | `som-garage` | `canStoreNear` / `storeNearest` |
| Police audio | `origen_police/data/*/vehicles.meta` | Six models repointed at their base banks |
| Progress bar | `som-ui/client/progressbar.lua` | Replaces ox_lib's. Read 16.6 item 4 before touching it |
| ox_target progress gap | `ox_target/client/main.lua` | Fifth row on the re-apply list in 16.2 |
| Armoury | `som-police/html` | Rebuilt twice: card language, then a grid of goods with ox_inventory art |
| Feedback layer | `som-ui/client/feedback.lua` | `playSound(kind)`, one vocabulary. See 18.11 |
| Card alerts | `som-phone/server/main.lua` | Aggregated per label, 1200ms window |
| Statement labels | `som-phone/server/bank.lua` | Says what was bought. Whitelist, never the raw slug |
| Notification stacking | `som-ui/html/app.js` | Repeats bump a count instead of flooding |
| NPC police suppression | `som-core/client/main.lua` | `Config.World` |
| Streamed assets | `som.cfg` | Explicit list, not a group ensure |
| **Downed state** | `som-medical` | **Never run. See 19.3** |

### 19.2 Mistakes worth not repeating

- **`SetDispatchServiceActive` does not exist.** The real native is
  `EnableDispatchService`. The nil call threw on the first pass of the
  suppression thread and killed it, so nothing in that block ran, and it was
  reported as working. Check natives exist before shipping, every time.
- **The cheap-win list was wrong about fuel.** `cdn-fuel` is on disk but
  hard-depends on qb-target, qb-input and qb-menu, and shared-scripts
  `@qbx_core/shared/locale.lua` while qbx_core is removed. It fails at load.
  `ox_fuel` is the cheap route and is not installed.
- **ps-mdt renders call text as interpolated HTML**, not textContent. A comment
  in som-dispatch asserted the opposite, which is why a player-typed 911 message
  was an XSS vector into every officer's MDT for as long as it was.
- **Whitelists have to match the shape callers actually emit.** `fine`,
  `paycheck` and `salary` sat in an exact-match table while every caller writes
  `fine:%d`. They never matched a single real transaction.

### 19.3 som-medical has never been run

Structurally checked only. The first test should be, in order:

1. Get shot. Confirm you go down rather than die, and that **you can still
   talk**. If voice is gone, the in-place resurrect is not working.
2. Confirm you cannot move, shoot, or enter a vehicle, and that a second shot
   does not kill you.
3. Wait two minutes. The hold prompt should appear.
4. Hold E. Confirm the fade, the hospital position, and that **$350 leaves cash
   first**, with the phone banner and the statement both reading
   "Hospital treatment".

Known soft spots, in the order I would suspect them:

- **Death detection.** `CEventNetworkEntityDamage` with the fatal flag catches
  being shot. It may not catch drowning, falling or a scripted kill. If some
  deaths still produce a normal death screen, that is why, and the fix is a
  health-based fallback alongside the event.
- **The talk controls.** `DisableAllControlActions` then re-enabling 249 and 46
  assumes pma-voice uses those. If push to talk is dead while down, that is the
  first thing to check.
- **The hospital coordinate is unverified.** `Config.Hospitals.pillbox`.
- Ragdoll is deliberate placeholder presentation, not a bug.

### 19.4 Open decisions

1. **The shop money question was never resolved.** The armoury shows both
   balances. If the complaint was about the ox_inventory shops (General Store,
   Ammunation), those are stock ox UI and show nothing. Which was meant?
2. **Icons.** A single complete set is needed, licence checked, and it must be
   placed by hand. Patching missing icons from a third source is what produced
   the current mix.
3. **`interact-sound` has unvalidated net events.** `PlayOnOne`, `PlayOnAll` and
   `PlayWithinDistance` let any client play any file at any volume for everyone.
   Not fixed, not used by anything of ours, worth patching on its own merits.
4. **Dispatch NUI** is still the generic toast. The security spine landed; the
   surface did not.

### 19.5 Next, in order

1. Test som-medical end to end, above.
2. The rest of phase 1's cheap wins: spawn selection, loading screen, clothing
   and barber zones, lockpick minigame on `ox_lib` skillcheck, ID photos.
3. A HUD. Nothing else in phase 1 sets the tone as much.
4. Dispatch NUI, which is phase 3's most visible item and the one the owner has
   called out twice.
5. Then EMS against `som-medical`'s existing revive contract.

---

## 20. What actually separates the big servers, and what to do about it

Written against the standard the owner named: NoPixel, Prodigy, EchoRP.

### 20.1 The uncomfortable finding

The gap is not CSS quality. SOM's armoury, certification card and phone are
already better looking than plenty of what those servers run. The gap is that
**they have no stock UI anywhere and SOM still has a lot.**

A player forms their impression from the surfaces they touch most, and on SOM
those are, in order: the inventory, the HUD, the target eye, context menus,
input dialogs, the pause menu and chat. Of those, SOM has styled **none**. The
armoury is beautiful and is opened once a shift. ox_inventory is opened four
hundred times and looks like ox_inventory.

That is the whole finding. Polishing more of our own screens has diminishing
returns until the stock ones are gone.

### 20.2 The pattern that already exists and should be extended

The progress bar problem was: ox_lib's UI is a compiled React bundle and cannot
be restyled. The solution was not to fork ox_lib. It was a shim
(`som-ui/client/progressbar.lua`) loaded into each consumer, replacing
`lib.progressBar` with som-ui's own while keeping every caller working
unchanged.

**That same pattern solves the rest of ox_lib's UI surface**, and it is the
highest-leverage NUI work available:

| Surface | ox_lib call | Where it shows today |
|---|---|---|
| Context menus | `lib.registerContext` / `showContext` | Vehicle inspection, plate flags, impound, mod bay |
| Input dialogs | `lib.inputDialog` | Anywhere a value is typed |
| Alert dialogs | `lib.alertDialog` | Confirmations |
| Text UI | `lib.showTextUI` | Already wrapped by som-interact, worth verifying |
| Skill checks | `lib.skillCheck` | Not used yet; will be, for lockpicking |

Doing context menus alone removes stock UI from four existing features. The
shim is written once, the callers never change, and every future feature gets
the SOM look by default rather than by remembering to.

**This is the single most valuable NUI decision left to make.**

### 20.3 Ranked, what to build

1. **Inventory reskin.** Largest surface, most-touched, currently stock. Nothing
   else moves the needle as far. Already named in 18.12.
2. **ox_lib UI shims**, per 20.2. Removes stock UI from everything at once.
3. **A HUD.** Does not exist. It is on screen permanently, so it sets the tone
   for everything around it more than any single panel can.
4. **Dispatch NUI.** The owner has called this out twice. It is the most
   visible part of police work and currently a generic toast.
5. **Death, arrest and jail screens.** They arrive with phase 2 and must arrive
   already in-language, not be retrofitted.
6. **Loading screen and character selector.** First and second things anyone
   ever sees.

### 20.4 What "wow" actually is, concretely

Not gradients. The things those servers do that SOM does not:

- **Diegetic where it can be.** The phone is a phone in a hand, not a panel.
  SOM already does this and should extend it: an ID card held up, a physical radio. Every screen that can be an object should be.
- **Motion with weight.** Things arrive from somewhere and leave somewhere.
  The phone rework this session is the reference; everything else should match
  its easing and duration rather than inventing its own.
- **Sound on every interaction.** Started in 18.11 and currently wired only to
  the armoury. Finish the sweep.
- **Density without clutter.** Their MDTs and inventories show a lot and stay
  readable, through hierarchy and restraint rather than through hiding things
  behind tabs.
- **One accent, used sparingly.** Pink everywhere is the fastest way to look
  cheap. It should mark the one thing that matters on a screen, not decorate.
- **Never a default.** No default cursor, no default scrollbar, no default
  focus ring, no default font fallback visible anywhere.

### 20.5 The systems half

NUI is not the only gap, and the roadmap covers the rest. But two systems
choices affect how premium the server FEELS out of proportion to their size:

- **Feedback on every action**, which is 18.11 and half done.
- **No stock GTA behaviour leaking through.** Vanilla police are suppressed now.
  The same applies to the vanilla death screen (som-medical replaces it), the
  vanilla pause map, vanilla radio, and vanilla weapon wheel. Each one that
  survives tells the player they are in GTA rather than in Los Santos.

---

## 21. Session handoff, third pass

The medical test in 19.3 was run and passed: down instead of death, voice
alive, no movement, no second kill, hold E at two minutes, hospital, fee. So
19.5 item 1 is closed and nothing here was blocked on it.

Then the same code was reviewed adversarially, and two of the four soft spots
19.3 listed were not the ones that were actually broken. That is the thing
worth carrying forward: **it passed a manual test and still had two blockers.**

### 21.1 What was built

| Thing | Where | State |
|---|---|---|
| Down animation | `som-medical` | Replaces ragdoll. `missarmenian2`/`drunk_loop` |
| Anti emote-cancel | `som-medical/client/main.lua` | Re-assert per frame plus a coordinate anchor |
| Free camera while down | `som-medical` | Controls 1 and 2 re-enabled |
| Downed screen | `som-medical/html` | Card, contrast, countdown in both phases |
| Hospital billed to card | `som-medical` + `som-phone` | So the bank app can state it |
| Armoury tiles | `som-police/html` | Art fills the tile, label on a blurred band |
| Cash card alerts | `som-phone` | The armoury notification bug |
| Phone timings | `som-phone/html` | Pop-up 300ms, banner hold 4900ms |
| Text tokens | `som-assets/tokens.css` | dim and mute raised; they failed contrast |
| interact-sound | `[standalone]/interact-sound` | Validated, and its CDN removed |
| **Context menu shim** | `som-ui/client/context.lua` | **The 20.2 pattern, extended** |
| **som-hud** | `som-hud` | **New. Rings, voice, vehicle panel** |
| Feedback sweep | `som-ui/client/notify.lua` | 18.11 closed, at the notification |

### 21.2 The two blockers a passing manual test did not catch

Both were found by review, not by play, and neither is visible from the
outside.

- **Relogging while down was a free revive.** som-core emits
  `som:server:playerLoaded(source, citizenid)` and its README says so.
  som-medical's handler took a player TABLE and read `player.citizenid`.
  Indexing a string in Lua goes through the string metatable and returns nil
  rather than erroring, so the restore returned on its first line every single
  time, silently. The character was also left marked down in the table and in
  the database forever. **A handler that reads the wrong shape does not crash
  in Lua, it just never runs.** Check the emitter, not the memory of it.
- **`som-medical:server:died` validated its argument's type and never checked
  that anyone had died.** Trigger it at full health mid-firefight and the
  client half holds you at 150 HP with `SetEntityInvincible` every frame, so
  the shots about to kill you stop landing. The server now reads its own view
  of the ped, retried once, because entity health replicates and refusing a
  real death is worse than the hole it closes.

### 21.3 Mistakes worth not repeating

- **The fatal-flag argument index is genuinely disputed and nobody should
  settle it by reasoning.** The Cfx `ped-money-drops` sample and PolyZone both
  read `args[4]`. som-medical shipped reading `args[6]` and was confirmed
  working in game. som-dispatch documents `args[6]` as the weapon hash. They
  cannot all be right. The fix in both resources is to stop caring: the
  argument is a hint, `IsPedDeadOrDying` is the truth, and there is a 500ms
  health poll alongside it. That also picks up drowning, falling and scripted
  kills, which is what 19.3 predicted would be missing.
- **A whitelist that is never reached is the same as no whitelist.**
  `itemLabel` called `exports.ox_inventory:Items()` with no argument and
  indexed the raw list. ox_inventory keys weapons uppercase and normalises
  inside `getItem`, so the raw index missed every weapon and matched only ammo.
  "Armoury: Carbine Rifle" has read "Armoury" since the feature was written.
  This is the second time a table in this file has been built in a shape that
  never matched what callers emit; see 19.2 on `fine:%d`.
- **Enabling a notification channel opens it to every reason on that account.**
  Turning on cash alerts routed `robbed`, `robbery-proceeds` and `market-sale`
  through the statement whitelist for the first time. None had a label. On a
  robbery a bare "Transaction" line sitting next to som-theft's own toast is
  worse than silence.
- **Contrast was a token problem, not a screen problem.** `--som-text-dim` and
  `--som-text-mute` at `#777` and `#555` came out around 4.6:1 and 2.6:1 on the
  surfaces actually in use, and mute carries most of the small text on the
  server. Fixed at the token. Two places still needed a local fix afterwards,
  both where an element lifts its own background: check the composite, not the
  base.
- **Server ids are recycled and a stale one is a live weapon.** som-medical's
  `downed` table survives a disconnect on purpose, so a body left by someone
  who logged off fired `forceRespawn` at their old id every five seconds
  forever. Eventually that lands on somebody else and rips them out of a scene
  eight minutes early, charged $350.

### 21.4 The context menu shim, and what it costs to extend

20.2 said this was the highest-leverage NUI work available. It is done for
context menus, and the pattern is now proven twice.

The parts that are not obvious:

- **The shim runs in the consumer, the state runs in som-ui.** Same split as
  the progress bar and for a sharper reason: an `onSelect` is a closure over
  the calling resource's locals and cannot cross a resource boundary. So the
  shim keeps the real menu, sends a flattened description, and resolves the row
  id that comes back.
- **The click comes back as a broadcast plus a token.** som-ui fires
  `som-ui:client:context`, which every consumer with the shim loaded receives.
  Only the one holding the live token acts. This is what avoids a registry of
  which resource owns what.
- **canClose and selectable are re-decided in Lua.** The page is told both so
  it can render correctly, and neither is trusted on the way back.
- **Icons are passed through as names onto a `data-icon` attribute and never
  resolved.** A left accent rule holds the space. When a licensed set lands it
  is one CSS rule and no call site changes. This is the 19.4 item 2 decision
  kept open rather than pre-empted.

`lib.inputDialog`, `lib.alertDialog` and `lib.skillCheck` are the same job
again and each is smaller than this one was. `lib.skillCheck` matters before
the lockpick minigame, since that is what it was going to be built on.

### 21.5 som-hud

New resource. Read only in the strongest sense: no server half, no net event
in, no NUI callback, so there is nothing for a client to lie to.

Bottom right, because karma-minimap owns the bottom left. Five condition rings
and a vehicle panel. Design is subtractive: armour stands down at zero, food
and water above 90%, engine condition until damaged, the whole HUD in the pause
menu and while downed. Pink appears in exactly one place, the voice ring while
transmitting, which is the only element describing something happening now
rather than something merely true.

**Deliberately absent, and not stubbed:**

- **Fuel.** No fuel resource runs here. `cdn-fuel` fails at load (19.2) and
  `ox_fuel` is not installed. `GetVehicleFuelLevel` on a vanilla vehicle does
  not meaningfully deplete, so the gauge would sit at one number forever, which
  teaches the player to ignore the HUD. Install `ox_fuel` and it is a few
  lines.
- **Seatbelt.** There is no seatbelt system on this server. That is an
  ejection-physics feature with an indicator attached, and building only the
  indicator would be the wrong half.

### 21.6 The feedback sweep, closed

18.11's remaining list was garage take and store, the mod bay, rentals, fines,
doors and custody. Every one already ends by notifying success or failure, so
the sound moved into `som-ui`'s notify rather than to thirty call sites.

Thirty `playSound` calls next to thirty `notify` calls is a sweep the
thirty-first feature forgets, which is how the gap opened. An action is now
audible because it reported itself.

Info stays silent. Warning borrows the error sound rather than inventing a
second audio string. A `silent` flag exists for callers that already said it
better; the armoury is the model, distinguishing a $95,000 rifle from a free
bandage.

**Doors were deliberately not changed.** ox_doorlock already plays positional
lock and unlock audio from its own sound set, which is more correct than a
frontend UI sound: a door should sound like a door in the world.

### 21.7 Open decisions

1. **The shop money question is still open**, and the owner does not recall
   which screen it was. The armoury half is done and has been for two sessions.
   If it was the ox_inventory shops, those are stock ox UI showing no balance
   at all, and that is a reskin of ox_inventory's shop rather than a config
   change. It is bundled with the inventory reskin in 20.3 item 1.
2. **Icons.** Unchanged from 19.4 item 2, and now with a hook waiting for them:
   `data-icon` on every context menu row.
3. **`interact-sound` is patched** but is still not ensured in `som.cfg`. It
   was patched on its own merits. `PlayOnAll` has no caller anywhere in the
   tree and should be deleted outright if it is still unused when the resource
   is finally started.
4. **`ox_lib` on disk is 3.38.0**, not the 3.14.0 recorded in CLAUDE.md.
5. **Dispatch NUI** is still the generic toast. Unchanged from 19.4 item 4.

### 21.8 Next, in order

1. **The rest of the ox_lib shims**, per 21.4. `skillCheck` first, because the
   lockpick minigame is waiting on it, then `inputDialog` and `alertDialog`.
2. **Inventory reskin**, still 20.3 item 1 and still the largest surface.
3. **Dispatch NUI**, called out twice by the owner.
4. The rest of phase 1's cheap wins: spawn selection, loading screen, clothing
   and barber zones, ID photos.
5. EMS against som-medical's existing revive contract, which is unchanged and
   still exported.

### 21.9 Things to test in game

Nothing in this session has been run on a live server.

**Confidence is not even across this session.** som-medical, the phone, the
armoury and the token change were reviewed adversarially and that review found
the two blockers in 21.2. The context menu shim and som-hud were NOT: that
review was launched and died on a session limit before returning anything, so
they have had structural checks only (DOM ids matched against their pages, the
`files{}` and `client_scripts` split, no `lib.*` or `cache.*` in a resource
that does not load ox_lib, one message listener per page, both halves of every
NUI callback name agreeing). Treat the two of them as the least proven things
here and give them the review before trusting them.

- **The context menus, hardest.** Mod bay, plate lookup, impound reason, fleet,
  ID check, fine presets. Specifically: submenus and back, opening the fine
  input dialog from inside a menu selection, and pressing Escape. If the cursor
  ever survives a menu closing, stop and read `som-ui/client/contextui.lua`.
- **The down state again**, end to end, including relogging while down. That
  path has never worked and now should.
- **The HUD**, in and out of a vehicle, and that it stands down in the pause
  menu and while downed.
- **A cash purchase**, for the phone banner that was missing.
- **Whether any feedback sound is silent.** Every string in
  `som-ui/shared/config.lua` is believed correct and none has been heard on
  this server. A silent one is a wrong string, not broken code, and it is a one
  line fix there.
