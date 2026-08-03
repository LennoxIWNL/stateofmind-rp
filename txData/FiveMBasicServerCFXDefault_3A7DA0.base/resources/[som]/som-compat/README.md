# som-compat

Answers `exports['qb-core']:GetCoreObject()` with a SOM-backed object, so preserved third-party resources keep running byte-for-byte untouched after QBCore and Qbox are removed.

## Why this exists

The rebuild spec requires two things that conflict on their face: keep `ps-mdt` untouched, and remove all QBCore dependency. `ps-mdt` calls `exports['qb-core']:GetCoreObject()` in four files.

It already works this way today. `qb-core` is disabled, and `qbx_core` declares `provide 'qb-core'` plus a shim at `bridge/qb/server/main.lua:122`. This resource is the same pattern with SOM behind it instead of Qbox.

## Critical: do not run alongside qbx_core

Both declare `provide 'qb-core'`. **Do not add this to `server.cfg` until `qbx_core` is removed in Phase 1.** Two resources claiming the same provide name is undefined behaviour.

## Scope

Deliberately minimal. It implements only what preserved resources actually call, enumerated in `AUDIT.md` section 7.3:

| Member | Backed by |
|---|---|
| `QBCore.Functions.GetPlayer` | `som-core:getPlayer` |
| `QBCore.Functions.GetPlayerByCitizenId` | `som-core:getPlayerByCitizenId` |
| `QBCore.Functions.GetPlayerData` | `som-core:getPlayerData` (client) |
| `QBCore.Functions.GetIdentifier` | native identifier lookup |
| `QBCore.Functions.CreateCallback` | `lib.callback.register` |
| `QBCore.Functions.TriggerCallback` | `lib.callback` |
| `QBCore.Functions.Notify` | `som:client:notify` |
| `QBCore.Functions.GetPlate` | native |
| `QBCore.Functions.SpawnVehicle` | native |
| `QBCore.Functions.SetVehicleProperties` | `lib.setVehicleProperties` |
| `QBCore.Functions.RequestAnimDict` | native |
| `QBCore.Functions.Progressbar` | `lib.progressBar` (client) |
| `QBCore.Functions.GetClosestVehicle` | native (client) |
| `QBCore.Functions.GetPlayers` | native (server) |
| `QBCore.Commands.Add` | `lib.addCommand` |
| `QBCore.Shared.Items` / `Weapons` | projected from `ox_inventory:Items()` |
| `QBCore.Shared.Vehicles` | derived from the vehicle label natives |
| `Player.Functions.*` | `som-core` (see below) |
| `QBCore:Notify` event | `som:client:notify` |

### `Player.Functions`

`wrap()` returned only `PlayerData`, so **every** `Player.Functions.*` call errored. That is why setting a callsign in the MDT did nothing. It now exposes `SetMetaData`, `GetMetaData`, `GetMoney`, `AddMoney`, `RemoveMoney`, `SetJob`, `SetGang`, `SetDuty`, `Notify`, `AddItem`, `RemoveItem` and `GetItemByName`.

Money members reach `som-core`'s transaction bus, which validates the account and ledgers the movement, so the shim still cannot mint currency: it can only ask the bus, and the bus refuses anything invalid. `qb` calls the cash account `money`, which is translated to `cash` on the way through.

### The lazily-built `Shared` members

`Items`, `Weapons` and `Vehicles` are built on first read rather than at boot, because neither `ox_inventory` nor the game's label table is guaranteed to be up when this resource starts. `shared/lazy.lua` holds the registry; `shared/items.lua` and `shared/vehicles.lua` register the builders.

They must not be declared on `QBCore.Shared` as placeholders. `__index` fires only for keys a table does not already have, so an empty placeholder would shadow its own provider forever. `SomCompatLazy.provide` prints a warning if it finds one.

`Shared.Vehicles` is derived from `GetDisplayNameFromVehicleModel` and `GetMakeNameFromVehicleModel` rather than a hand-maintained `vehicles.lua`, so streamed addon vehicles work without being registered anywhere. Enumeration additionally needs `GetAllVehicleModels`, which is feature-detected because nothing else here calls it; without it, keyed lookups still work and only `pairs()` comes back empty.

**New `som-*` code must never call this shim.** It exists only for preserved third-party resources. New code calls `som-core` exports directly.

## Orphaned dependencies

`ps-mdt/client/cl_impound.lua` also calls two things that belong to resources on the Phase 1 delete list. Without them, impound release fails silently:

- `qb-garage:server:GetVehicleProperties` callback, reimplemented here against `som_vehicles`
- `vehiclekeys:client:SetOwner` event, currently a no-op stub until Phase 5 builds vehicle keys

## Known gaps

- `CreateCallback` bridges QBCore's callback-style handlers onto `lib.callback`'s return-by-value shape using a promise, which handles both synchronous and asynchronous handlers. It has not been exercised against the real MDT yet.
- `Shared.Vehicles` is client only. The label natives do not exist on the server and no preserved resource reads it there, so the server registers it as an empty table purely so a stray read gets a table rather than nil.
- ps-mdt's citation path deducts a fine straight out of the bank (`server/main.lua:1827`). The plan calls for fines to arrive as auto-collecting phone bills instead, so that call is expected to be redirected when fines are built.
- Only structurally checked, by matching block and bracket balance. No Lua toolchain is installed, so this has not been parsed or run.
