# som-props

Placeable scene props. Cones, barriers and worklights that an officer puts down
to close a road or light a scene, and picks back up afterwards.

Every model is vanilla GTA, so this streams nothing.

## Items

Defined in `ox_inventory/data/items.lua`, not here, so they sit with every other
item rather than in a second parallel catalogue:

`prop_cone_small`, `prop_cone_large`, `prop_police_barrier`,
`prop_barrier_small`, `prop_barrier_medium`, `prop_barrier_large`,
`prop_worklight_small`, `prop_worklight_large`

Each carries a `placeable` table that only this resource reads:

```lua
placeable = { models = { `prop_mp_cone_02`, ... }, avoid = true }
```

`models` is a variety list. A place picks one at random, and a pickup accepts
any of them. `avoid` makes traffic steer around the placed object.

To add a prop: define the item with a `placeable` block and
`server = { export = 'som-props.use' }`, and drop an icon into
`ox_inventory/web/images`. No change to this resource is needed.

## Provenance

Item definitions and icons are adapted from
[Andyyy7666/itemcollection](https://github.com/Andyyy7666/itemcollection).
**That repository ships no licence file.** Vendoring it anyway was the owner's
explicit decision, recorded here so the position is not lost.

**Its Lua was not used.** The pickup path is a reimplementation, for cause.

## Why the reference implementation was not ported

Its pickup event took a **model name from the client** and handed over the
matching item:

```lua
RegisterNetEvent("itemcollection:pickup", function(netid, entityModel)
    local model = entityModel or GetEntityModel(entity)
    if not config[model] then return end
    exports.ox_inventory:AddItem(src, config[model], 1)
end)
```

Passing `entityModel` skipped the entity lookup entirely, so there was no
entity, no distance check and no proof anything was ever placed. Sending that
event in a loop minted unlimited items. It also read a global
`vehiclesWillAvoid` that its server file never assigned, so the traffic
avoidance it advertised never ran.

## The three rules that replace it

The client sends **one** argument, a network id. Everything else is re-derived
server side.

1. **Only props this resource placed can be picked up.** A server-side table
   keyed by entity handle, which a client cannot reach. An entity state bag
   would have survived restarts, but clients can write state bags on entities
   they own, so a player could paint "police barrier" onto any object and farm
   it.
2. **The model must still match what was recorded**, so a replaced entity on a
   reused handle cannot yield a different item.
3. **Distance is measured server side**, against the server's own view of both
   positions.

Then `CanCarryItem`, then the claim, then the delete, then the grant. Claiming
before deleting is what stops two racing pickups both paying out, the same
shape as ox_inventory's slot mutex (AUDIT 6.5 item 2).

## Known cost of rule 1

Props placed before a `som-props` restart are no longer pickupable and remain
as scenery. That is deliberate. Losing a cone is better than minting one.
