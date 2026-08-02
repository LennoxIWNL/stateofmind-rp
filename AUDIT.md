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
| **7. NUIs** | `som-assets/tokens.css` shared by every `som-*` NUI. Inventory, banking, job menus, turf HUD, character creation. Load the design skill in `.claude/skills/` before writing UI code. | Runs alongside Phases 3 through 6, not after. |
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

### 14.10 Command minimisation

Already covered in section 10, and it serves the same goal. Interaction-driven
play is what separates a serious RP server from a menu simulator.

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
