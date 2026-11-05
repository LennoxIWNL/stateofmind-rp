---
name: som-testing
description: How the mock test harness works and how to extend it (mysql handlers, natives, loader, resets). Load before adding tests.
---

# Testing in this repo

- Run: `lua5.4 tests/run.lua` (server Lua), `node tests/nui/run.mjs` (UI), `tools/check-lua.sh` (syntax). CI runs all three.
- A scene loads the real resource files: `local env = loader.loadResource(REPO .. 'som-x', { 'shared/config.lua', 'server/main.lua' })`. Callbacks are in `RegisteredCallbacks['name']`, commands in `Mocks.commands.name`, phone apps in `Mocks.apps.id`, event handlers in `Handlers[...]`. Open a new scene with `resetDb()` first.
- Players: `Mocks.players[src] = { citizenid, job = {name, onduty}, gang = {name, grade}, charinfo }`. Positions: `FakePeds[src] = vec3(x, y, z)`; vehicles `Vehicles[id]`, animals `Animals[id]`. Inventory: `Mocks.inv[src]` keyed by slot (use a counter, not `#`, for slot keys). Money: `Mocks.bank[src]`, `Mocks.treasury`, `Mocks.gangFunds`, failure switches `Mocks.addMoneyFails`, `Mocks.taxFails`, `Mocks.gangFails`, `Mocks.invFull[src]`.
- Two clocks: `Mocks.clock` is `GetGameTimer()` (milliseconds); `mysql.fakeNow` is SQL `NOW()` seconds. Advance the one the code under test reads. Set `mysql.fakeNow` before seeding a timestamp.
- New SQL: add a handler function in `tests/mocks/mysql.lua` matching the exact query text with `query:find(text, 1, true)`, hook it into the `single`/`scalar`/`update`/`insert`/`query` dispatchers (copy an existing hook line), and reset its table in `run.lua` `resetDb`. An unhandled query errors on purpose.
- New natives go in `tests/mocks/fivem.lua`; new core or phone exports in `tests/mocks/exports.lua`.
- State leaks between scenes: reset `Mocks.admins`, `Mocks.invFull`, `Mocks.addMoneyFails` yourself when a test relies on them.
- Mocks prove logic, not behaviour in a game. Also run new SQL on the dev MariaDB, `fivemAudit` the file, `ensure` it on the headless server and read the console. Say plainly what only a client can verify.
