# som-interact

The single interaction surface for SOM. Wraps the preserved target system and provides the one TextUI.

## Why a wrapper

The engine has been swapped twice, and this file is why each swap cost an
afternoon rather than a rewrite.

It was `qb-target`, which is escrow protected (`dependency '/assetpacks'`) and
carries no version field, so it could never be read, forked or upgraded.

It briefly ran on `sleepless_interact`, which was the wrong pick: that resource
has no raycast, no aim and no eye at all, only proximity indicators. "Hold Alt,
look at the ped, pick an option beside it" cannot be expressed in that model, so
it was never a skin difference.

It is now **`ox_target`**: MIT, maintained, and an aiming eye. Hold the key, look
at something, the eye changes to show it is interactable, options appear beside
it, and a left click picks one.

## Configured by convar, not by patching

```cfg
setr ox_target:defaultHotkey "LMENU"   # Left Alt
setr ox_target:toggleHotkey 0          # hold, not toggle
setr ox_target:leftClick 1             # left click selects
```

Convars rather than a patched config file, so upgrading ox_target cannot quietly
undo any of it. The one thing that IS patched is `web/`, the reskin, and that is
listed in som-core's README with the rest.

## The circle is drawn for ZONES

**ox_target draws its indicator for zones only, not for entity targets.**

Anything static that should show a circle, a shop counter, a stash, a door, is
registered as a zone even when there is an entity standing there. `som-rentals`
does exactly this: the counter ped is a sphere zone, because registered against
the ped there would be no circle at all, just an eye that happens to change.

Players and vehicles stay entity targets. Those are aimed at, and a world full
of circles defeats the point.

## Real zones

Box, sphere and poly are genuine volumes again. `sleepless_interact` collapsed
all three to a single point, which this wrapper had to paper over; ox_target
does not, so that compromise is gone.

## No event fields

`ox_target` options support `event`, `serverEvent` and `command`. The
wrapper **does not pass any of them through**. A config value naming a server
event lets the client choose both the event and its payload, which is the same
hole `som-radial` refuses to open. Use `onSelect` and go through a validated
export, or a request the server re-checks.

## Security

**`groups` is a client side UI filter.** It decides what a player can see, not
what they may do. ox_target has a `groups` field and it is passed straight
through, but it is still only a filter on what is drawn. Any action reached through an interaction must re-check job, gang, grade, and distance on the server. Treat every `onSelect` as an untrusted request.

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
