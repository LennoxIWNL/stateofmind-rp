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
| `QBCore.Commands.Add` | `lib.addCommand` |
| `QBCore.Shared.Vehicles` / `Items` | empty tables, populate if the MDT needs labels |

**No money or item members are exposed.** That is intentional: a legacy resource must not be able to mint currency or spawn items through the shim. Anything needing money goes through `som-core`'s transaction bus explicitly.

**New `som-*` code must never call this shim.** It exists only for preserved third-party resources. New code calls `som-core` exports directly.

## Orphaned dependencies

`ps-mdt/client/cl_impound.lua` also calls two things that belong to resources on the Phase 1 delete list. Without them, impound release fails silently:

- `qb-garage:server:GetVehicleProperties` callback, reimplemented here against `som_vehicles`
- `vehiclekeys:client:SetOwner` event, currently a no-op stub until Phase 5 builds vehicle keys

## Known gaps

- `QBCore.Shared.Vehicles` and `Shared.Items` are empty. The MDT uses them for display names on vehicle and weapon lookups, so those columns will render blank until populated.
- `CreateCallback` bridges QBCore's callback-style handlers onto `lib.callback`'s return-by-value shape using a promise, which handles both synchronous and asynchronous handlers. It has not been exercised against the real MDT yet.
- Not syntax checked against a live server: no Lua toolchain was available when this was written.
