# som-interact

The single interaction surface for SOM. Wraps the preserved target system and provides the one TextUI.

## Why a wrapper

`qb-target` is escrow protected (`dependency '/assetpacks'`) and carries no version field, so it can never be read, forked, or upgraded. The rebuild spec therefore says reuse it, not replace it. Isolating it behind this resource means every future `som-*` script codes against a stable SOM API, and swapping in `ox_target` later is a change to `client/target.lua` and nothing else.

The wrapper calls qb-target's **ox_target-shaped compat exports** rather than its PascalCase natives, because that surface is smaller and is what a real `ox_target` already understands. It also normalises two rough edges in that shim: zone argument order, and `addGlobalVehicle` being registered twice with the first registration referencing an undefined global.

## Security

**qb-target's `groups` filtering is a client side UI filter.** It decides what a player can see, not what they may do. Any action reached through an interaction must re-check job, gang, grade, and distance on the server. Treat every `onSelect` as an untrusted request.

```lua
-- WRONG: the client decided it was allowed
onSelect = function() TriggerServerEvent('som-evidence:server:collect', evidenceId) end

-- RIGHT: server re-validates job, grade, and distance before acting
onSelect = function() TriggerServerEvent('som-evidence:server:requestCollect', evidenceId) end
```

## Client exports

```lua
local interact = exports['som-interact']

local id = interact:addBoxZone({
    name = 'pd_armoury',
    coords = vec3(452.6, -980.0, 30.7),
    size = vec3(1.5, 1.5, 2.0),
    rotation = 0.0,
    options = {
        {
            label = 'Open Armoury',
            icon = 'fa-solid fa-gun',
            groups = { 'police' },
            distance = 2.0,
            onSelect = function() TriggerServerEvent('som-police:server:requestArmoury') end,
            canInteract = function() return exports['som-core']:hasJob('police', 1, true) end,
        },
    },
})

interact:addSphereZone({ name = 'x', coords = vec3(...), radius = 2.0, options = { ... } })
interact:addPolyZone({ name = 'x', points = { ... }, minZ = 30.0, maxZ = 34.0, options = { ... } })
interact:removeZone(id)

interact:addLocalEntity(ped, options)
interact:removeLocalEntity(ped, { 'Open Armoury' })
interact:addModel({ 'prop_atm_01' }, options)
interact:removeModel({ 'prop_atm_01' }, labels)

interact:addGlobalPlayer(options)     -- the basis for cuff, search, escort
interact:removeGlobalPlayer(labels)
interact:addGlobalVehicle(options)
interact:addGlobalPed(options)
interact:addGlobalObject(options)
```

### Option fields

| Field | Purpose |
|---|---|
| `label` | Text shown in the eye menu |
| `icon` | Font Awesome class, defaults to `fa-solid fa-hand` |
| `distance` | Max interaction distance, defaults to 2.5 |
| `groups` | Job or gang filter. **UI filter only, not a permission check** |
| `item` | Required item in inventory |
| `onSelect` | Called on the client when picked |
| `canInteract` | Predicate, return false to hide |

## TextUI

Replaces the three overlapping implementations catalogued in `AUDIT.md` section 7.4 (`som-textui`, `som-text`, `pa-textui-2`).

```lua
exports['som-interact']:showTextUI('Press to open', { key = 'E' })
exports['som-interact']:hideTextUI()
exports['som-interact']:isTextUIOpen()
```

Styling comes from `som-assets/tokens.css`. There is no per-frame loop: the panel is a DOM element toggled by message. Label text is rendered with `textContent`, never `innerHTML`, so config-sourced strings cannot inject markup.

## Phase 8 role

This resource is how commands get removed. Every entry in `AUDIT.md` section 10.1 (`/cuff`, `/escort`, `/jail`, `/seizecash`, `/takedna`, and the rest) becomes an `addGlobalPlayer` or `addGlobalVehicle` option here, gated by job on the client for visibility and re-validated on the server for authority.

## Known gaps

- No `canInteract` distance caching yet, so a very large number of registered options will cost more per raycast than necessary.
- Not syntax checked against a live server: no Lua toolchain was available when this was written.
