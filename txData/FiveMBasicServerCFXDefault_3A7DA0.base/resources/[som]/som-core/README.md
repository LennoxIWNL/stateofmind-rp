# som-core

The SOM framework core. Owns player identity, characters, money, permissions, and state replication. No QBCore, ESX, or Qbox dependency: only `ox_lib` and `oxmysql`.

**Status: Phase 2, not yet wired into `server.cfg`.** It runs alongside the legacy stack without touching it. See `AUDIT.md` at repo root for the rebuild plan.

## Setup

1. Import `setup.sql` from the repo root into the `stateofmindrp` database.
   It is the single import for the whole server; there is no per-resource SQL.
2. Grant staff ACEs in `server.cfg`:
   ```
   add_ace group.admin som.admin allow
   add_ace group.admin som.mod allow
   add_ace group.god   som.god allow
   ```
3. Ensure after `ox_lib` and `oxmysql`.

## Concepts

**The player object** is server side and lives only in memory while a character is loaded. Get it with `getPlayer(source)`. It carries `citizenid`, `charinfo`, `job`, `gang`, `money`, and `metadata`.

**The money bus** (`server/money.lua`) is the only code that changes a balance. Every movement writes a row to `som_transactions` tagged with the calling resource, which is what makes Phase 4 sink/faucet analysis a query rather than a guess. There is no net event for money, so a client cannot reach it.

**State replication** uses player state bags under the `som:` namespace. Job and gang are replicated to all clients; money and metadata are sent only to the owning client, so nobody can read another player's balance from a state bag.

## Server exports

```lua
local core = exports['som-core']

core:getPlayer(source)                   -- player object or nil
core:getPlayerByCitizenId(citizenid)
core:getPlayerByLicense(license)
core:getPlayers()                        -- array of loaded players
core:getPlayersByJob('police', true)     -- second arg: on duty only
core:getPlayersByGang('ballas')

core:setJob(source, 'police', 2)         -- returns ok, err
core:setGang(source, 'ballas', 1)
core:setDuty(source, true)
core:setMetadata(source, 'stress', 40)   -- validated and clamped
core:getMetadata(source, 'stress')

core:getJobs()                           -- shared/jobs.lua
core:getGangs()                          -- shared/gangs.lua

core:hasPermission(source, 'som.admin')
core:getPermissionTier(source)
```

### Money

```lua
core:addMoney(source, 'bank', 500, 'salvage-payout')      -- ok, err
core:removeMoney(source, 'cash', 200, 'repair-bill')
core:getMoney(source, 'cash')                             -- number
core:hasMoney(source, 'cash', 200)                        -- boolean
core:transferMoney(fromSource, toSource, 'bank', 100, 'sale')
core:businessTransact('lscustoms', -250, 'payroll:mechanic')
core:taxToTreasury(1000, 'sales-tax')
core:getTreasury()
```

`reason` is required and lands in the ledger. Amounts must be positive whole numbers; negatives, fractions, NaN, and infinities are rejected. The `dirty` account is protected and only Phase 4 laundering may touch it.

### Money is not an inventory item

**som-core owns every account outright**: `cash`, `bank`, `crypto`, `dirty`. None of them is an ox_inventory item, and `inventory:accounts` is set to `[]` so ox never registers one.

The alternative, cash as a `money` item, is what ESX and QBox do, and it hands the authoritative cash count to ox_inventory. Ownership of the economy then straddles two systems, the two records drift, and drift is indistinguishable from a dupe. Every balance change goes through this bus and lands in `som_transactions`, with no second writer.

Cash is still robbable. `som-theft` performs a validated server-side transfer, so a thief cannot simply drag a stack out of a victim's bag:

```lua
core:stealCash(victimSource, thiefSource, amount)  -- returns ok, stolen
```

That function guarantees the money maths and the audit trail only. The caller must have already checked proximity and victim state; `som-theft` does both server side.

## The ox_inventory bridge

`ox_inventory/modules/bridge/som/{client,server}.lua` is **a patch to a third-party resource**, and the only SOM code outside a `som-*` folder. ox resolves its bridge by folder name from the `inventory:framework` convar, so there is no way to supply it externally.

Set `setr inventory:framework "som"` in `server.cfg`. **Re-apply the patch on every ox_inventory upgrade.**

The bridge maps SOM job and gang into ox's `groups` table (`{ police = 2, ballas = 0 }`), which drives stash access rules and the police evidence-grade check.

### Everything patched inside ox_inventory

Six places. All of them are overwritten by an upgrade, so check this list first
when something inventory-shaped breaks after one.

| File | Change |
|---|---|
| `modules/bridge/som/{client,server}.lua` | The bridge itself. Also replaces `lib.notify` so ox's error toasts render in som-ui. `lib` is per-resource, so this affects ox_inventory only. |
| `modules/mysql/server.lua` | A second hardcoded framework switch. Needs a `som` branch pointing at `som_characters` / `citizenid`, or every player load fails. |
| `data/items.lua` | `client.export` on `id_card`, `driver_license` and `weaponlicense` for som-id. |
| `data/vehicles.lua` | Motorcycles removed from the `glovebox` table. |
| `client.lua` | `openGlovebox` falls back to the player's own inventory when a vehicle has no glovebox, instead of doing nothing. |
| `web/build/assets/index-*.css` | Hides the item notification scrollbar. |

Notifications are otherwise handled by convar, not by patching: `inventory:itemnotify 0`
and `inventory:weaponnotify 0` remove the item and weapon cards outright.

## Client exports

```lua
local core = exports['som-core']

core:getPlayerData()                     -- read-only mirror
core:isPlayerLoaded()
core:getJob() / core:getGang()
core:getMetadata('stress')
core:hasJob('police', 2, true)           -- name, minGrade, requireDuty
```

Client data is a cache of a server decision. Never gate a server action on it.

## Events

Server side:

| Event | Args |
|---|---|
| `som:server:playerLoaded` | source, citizenid |
| `som:server:playerUnloaded` | source, citizenid |
| `som:server:jobChanged` | source, citizenid, job |
| `som:server:gangChanged` | source, citizenid, gang |
| `som:server:dutyChanged` | source, citizenid, jobName, onduty |
| `som:server:moneyChanged` | source, citizenid, account, delta, balance, reason |
| `som:server:metadataChanged` | source, citizenid, key, value |

Client side: `som:client:onPlayerLoaded`, `onJobChanged`, `onGangChanged`, `onMoneyChanged`, `onMetadataChanged`.

Client callbacks: `som:server:getCharacters`, `createCharacter`, `selectCharacter`, `deleteCharacter`.

## Adding a job

Edit `shared/jobs.lua`. No new resource is needed.

```lua
myjob = {
    label = 'My Job',
    business = 'mybusiness',   -- must exist in som_businesses or nobody is paid
    whitelisted = false,
    defaultDuty = true,
    grades = {
        [0] = { name = 'Trainee', payment = 40 },
        [1] = { name = 'Owner', payment = 90, isboss = true },
    },
}
```

Payroll debits the business account. A job with no `business` mints money and should only be used for `unemployed`.

## Commands

Only three, all ACE gated: `/setjob`, `/setgang`, `/givemoney`. Everything else in SOM is an interaction, per Phase 8 of the rebuild plan. `/givemoney` writes to the ledger like any other movement, so staff money creation is auditable.

## Known gaps

- Character creation has no UI yet, only the callbacks. Phase 7 builds it.
- Business opening balances in the schema are placeholder float, not a balance decision. See `AUDIT.md` section 12.2.
- Not syntax checked against a live server: no Lua toolchain was available when this was written.
