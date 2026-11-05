---
name: oxlib
description: ox_lib usage in this repo (callbacks, commands, and the som-ui shims for dialogs and progress). Load before using lib.* functions.
---

# ox_lib

- `lib.callback.register(name, function(source, ...) ... end)` on the server and `lib.callback.await(name, false, ...)` on the client. Return `{ success = bool, error = string|nil, ... }`; resources here use a local `done(ok, err, extra)` helper (see `som-turf/server/main.lua`, `som-outdoors/server/buyer.lua` exports `Buyer.Done`).
- Commands: `lib.addCommand('name', { help, params = { { name, type = 'playerId'|'string'|'longString'|'number', optional = true } } }, function(source, args) end)`. A command is open to everyone unless gated: check `core:hasPermission(source, 'som.admin')` inside the handler (the fivem-kit audit flags that as a false positive).
- UI is NOT stock ox_lib. Load the shims from `som-ui` as the first `client_scripts`: `@som-ui/client/progressbar.lua`, `dialog.lua` (`lib.inputDialog`, `lib.alertDialog`), `context.lua` (`lib.registerContext`, `lib.showContext`), `skillcheck.lua`. Their calls keep ox_lib signatures, e.g. `lib.progressBar({ duration, label, canCancel, disable = { move = true, combat = true } })` returns true or false.
- World interactions go through `exports['som-interact']` (`addSphereZone`, `removeZone`, `addGlobalVehicle`, `addGlobalPed`, `addLocalEntity`). `groups` and `canInteract` are UI filters only; the server must re-check job, gang, grade and distance.
- Docs: overextended.dev (ox_lib).
