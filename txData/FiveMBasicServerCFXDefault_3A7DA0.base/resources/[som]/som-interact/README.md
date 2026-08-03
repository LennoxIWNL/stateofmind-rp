# som-interact

The single interaction surface for SOM. Wraps the preserved target system and provides the one TextUI.

## Why a wrapper

The engine has already been swapped once, and this file is why that cost an
afternoon rather than a rewrite.

It was `qb-target`, which is escrow protected (`dependency '/assetpacks'`) and
carries no version field, so it could never be read, forked or upgraded. It is
now **`sleepless_interact`**, which is GPL-3.0, actively maintained, and draws a
small circle at every interactable point.

Its **native** API is wrapped rather than its ox_target compat shim: the native
one exposes `holdTime`, `cooldown` and the active callbacks, and one less
translation layer is one less place for a signature to drift quietly.

## Circles only while Left Alt is held

`sleepless_interact/client/modules/config.lua` is a SOM patch. **Re-apply it
after upgrading that resource.**

```lua
config.useShowKeyBind      = true       -- was false, circles were permanent
config.defaultShowKeyBind  = 'LMENU'    -- Left Alt, same as qb-target
config.showKeyBindBehavior = 'hold'     -- was 'toggle'
config.themeColor          = { 255, 20, 147, 200 }
config.maxInteractDistance = 5.0
```

The indicator uses the base game `shared / emptydot_32` texture, so nothing has
to be streamed for it to work.

## Zones are points

The engine draws a circle at a coordinate, and there is nowhere to put a circle
for a 20 metre polygon. `addBoxZone`, `addSphereZone` and `addPolyZone` all
resolve to a **single point** with a per-option `distance`; a poly resolves to
its centroid.

For a door, a till or a stash that is what you wanted anyway. For a genuine
region ("am I inside this area"), use several points or a PolyZone in
`som-zones` instead.

## No event fields

`sleepless_interact` options support `event`, `serverEvent` and `command`. The
wrapper **does not pass any of them through**. A config value naming a server
event lets the client choose both the event and its payload, which is the same
hole `som-radial` refuses to open. Use `onSelect` and go through a validated
export, or a request the server re-checks.

## Security

**`groups` is a client side UI filter.** It decides what a player can see, not
what they may do. sleepless has no `groups` field of its own, so the wrapper
folds it into `canInteract`: same visibility behaviour, same non-guarantee. Any action reached through an interaction must re-check job, gang, grade, and distance on the server. Treat every `onSelect` as an untrusted request.

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
