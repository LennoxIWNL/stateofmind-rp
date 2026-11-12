---
name: fivem-basics
description: FiveM resource basics for this repo (manifest, events, server vs client natives, OneSync, state bags). Load before writing any FiveM Lua.
---

# FiveM basics

- Every resource has an `fxmanifest.lua` with `fx_version 'cerulean'`, `game 'gta5'`, `lua54 'yes'`. List `shared_scripts` (`'@ox_lib/init.lua'`, `shared/config.lua`), `client_scripts`, `server_scripts` (`'@oxmysql/lib/MySQL.lua'` first) and `dependencies`. A new resource also needs an `ensure` line in `txData/*/som.cfg` after what it depends on.
- Natives are split by side. Check before use with the `fivem-kit` MCP (`fivemNatives`): `GetEntityHealth`, `GetPedSourceOfDeath`, `GetVehicleEngineHealth`, `SetEntityCoords`, `DeleteEntity`, `GetVehicleNumberPlateText` exist on the server; `SetVehicleEngineHealth`, `SetVehicleBodyHealth` are client only. Never invent a native or export (CLAUDE.md rule 5).
- Server reads of a player: `GetPlayerPed(source)` then `GetEntityCoords(ped)`. Always capture `local src = source` before any `Wait` or `.await`; `source` is gone after a yield.
- Events: `resource:server:action` and `resource:client:action`. Prefer `lib.callback` for request/response. A client sends ids, never prices, amounts or results.
- `Entity(entity).state:set(key, value, true)` replicates a state bag; check-then-set in the same tick is atomic in Lua.
- Do not use `Wait(0)` loops unless rendering needs it. Boot-time work goes in `CreateThread`.
- Restarting a resource stops its dependents; `ensure` them again (the dev FXServer does not restart them).
- Server console and rcon for the dev server: `mcp__fivem-ziyacivan__server_command` (`refresh`, `ensure x`, `restart x`) and `read_console` with `target: "server"`.
