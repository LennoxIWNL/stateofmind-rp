-- Placeable scene props, server half.
--
-- The server owns every decision here. The client may ask to pick something up
-- and nothing more: it does not say what the thing is, what item it yields, or
-- whether it is close enough.
--
-- This is a reimplementation, not a port. The reference (Andyyy7666/
-- itemcollection) had its pickup event take a MODEL NAME from the client and
-- hand out the matching item for it, with no distance check and no proof the
-- entity existed. Sending that event in a loop minted unlimited items. The
-- three rules below are what close it, and none of them can be relaxed without
-- reopening it.

local PICKUP_DISTANCE = 3.0

-- Rule 1: only props THIS resource placed can be picked up.
--
-- Keyed by server entity handle, which a client cannot forge or reach. An
-- entity state bag would survive a restart and was the obvious alternative, but
-- clients can write state bags on entities they own, so a player could paint
-- 'this is a police barrier' onto any object and farm it. A plain server-side
-- table cannot be written from outside.
--
-- Cost of that choice, stated plainly: props placed before a som-props restart
-- are no longer pickupable and stay as scenery until someone with admin tools
-- clears them. Losing a cone is better than minting one.
local placed = {}

local placeableByModel, placeableByItem = {}, {}
local indexed = false

---Builds model hash -> item name from ox_inventory's own item list.
---
---`Items()` with no argument is correct HERE because this iterates the list
---rather than indexing it by name. Indexing the raw list is the trap recorded
---in AUDIT 21.3: ox_inventory keys weapons uppercase and normalises inside
---getItem, so a raw lookup by name misses them. Nothing is looked up by name.
---
---Only marks itself done once it has actually found something. ox_inventory
---may not have populated its list on the first call, and latching an empty
---index would silently disable placing and picking up for the whole uptime.
local function buildIndex()
    if indexed then return end

    local items = exports.ox_inventory:Items()
    if not items then return end

    for name, data in pairs(items) do
        local def = data.placeable

        if type(def) == 'table' and type(def.models) == 'table' then
            placeableByItem[name] = def
            indexed = true

            for i = 1, #def.models do
                placeableByModel[def.models[i]] = name
            end
        end
    end
end

---Position in front of a ped, on the ground.
---@param ped number
---@return vector3 coords, number heading
local function inFrontOf(ped)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local rad = math.rad(heading)

    return vector3(
        coords.x - math.sin(rad) * 0.9,
        coords.y + math.cos(rad) * 0.9,
        coords.z - 0.9
    ), heading
end

---@param src number
---@param item table ox_inventory item definition
local function placeProp(src, item)
    buildIndex()

    local def = placeableByItem[item.name]
    if not def then return end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end

    local coords, heading = inFrontOf(ped)

    -- Several models per item is a variety list, not a fallback chain. The
    -- reference always took models[1], so the other four cones it shipped were
    -- never once placed.
    local model = def.models[math.random(#def.models)]

    -- CreateObjectNoOffset, not CreateObject. The offsetting variant shifts the
    -- object relative to the coordinate given, which makes ground placement
    -- guesswork. ox_lib's own server-side prop constructor
    -- (ox_lib/imports/prop/server.lua:22) uses NoOffset for the same reason.
    --
    -- The last argument is `dynamic`, and false is what makes the prop static.
    -- That is deliberately doing the job FreezeEntityPosition would: that native
    -- is client-only, ox_lib never calls it from its server path, and an
    -- unverified native that silently does nothing is exactly the mistake
    -- recorded in AUDIT 19.2. A cone that drifts is better than a nil call that
    -- kills the rest of this function.
    local entity = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, true, true, false)
    if not entity or entity == 0 then return end

    local timeout = GetGameTimer() + 5000
    while not DoesEntityExist(entity) and GetGameTimer() < timeout do Wait(0) end

    if not DoesEntityExist(entity) then return end

    -- Server-safe: ox_lib calls this from its server path via
    -- gameEntity:setHeading (imports/gameEntity/shared.lua:141).
    SetEntityHeading(entity, heading)

    if def.avoid then
        -- Read by the client, which is the only side that can call
        -- SetObjectForceVehiclesToAvoid, and only on the entity it owns.
        --
        -- The reference read a bare global `vehiclesWillAvoid` that was never
        -- assigned in its server file, so this was nil on every path and the
        -- feature it advertised never ran once.
        Entity(entity).state:set('somPropAvoid', true, true)
    end

    placed[entity] = item.name
end

---Pick up a placed prop.
---
---The client sends ONE argument, a network id, and every fact is re-derived
---from it server side: which entity, which item, and how far away the player
---is.
RegisterNetEvent('som-props:server:pickup', function(netId)
    local src = source

    if type(netId) ~= 'number' or netId ~= netId or netId <= 0 then return end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    -- Rule 1. Not one we placed, not pickupable. This is what stops a player
    -- spawning their own object, or walking up to a map prop, and cashing it in.
    local itemName = placed[entity]
    if not itemName then return end

    -- CLAIM IMMEDIATELY, before any call below that might yield.
    --
    -- This is the anti-dupe line and its position is the whole point. Claiming
    -- lower down, next to the delete, reads more naturally and is wrong: an
    -- export or a query that yields anywhere between the read above and the
    -- claim lets two racing pickups both pass every check and both be granted
    -- an item. Held rather than assumed, because whether ox_inventory's
    -- CanCarryItem yields is its business and could change under us.
    --
    -- Every rejection below therefore has to put the claim back.
    placed[entity] = nil

    ---@param reason? string
    local function refuse(reason)
        placed[entity] = itemName
        if reason then TriggerClientEvent('som:client:notify', src, reason, 'error') end
    end

    -- Rule 2. The model still has to agree with what we recorded, so a swapped
    -- or replaced entity on a reused handle cannot yield the wrong item.
    buildIndex()
    if placeableByModel[GetEntityModel(entity)] ~= itemName then return refuse() end

    -- Rule 3. Distance, measured server side against the server's own view of
    -- both positions.
    local ped = GetPlayerPed(src)
    if ped == 0 then return refuse() end

    if #(GetEntityCoords(ped) - GetEntityCoords(entity)) > PICKUP_DISTANCE then return refuse() end

    if not exports.ox_inventory:CanCarryItem(src, itemName, 1) then
        return refuse('You cannot carry that')
    end

    DeleteEntity(entity)
    exports.ox_inventory:AddItem(src, itemName, 1)
end)

---ox_inventory server.export hook. Signature is (event, item, inventory, slot,
---data), documented at ox_inventory/modules/items/server.lua:352.
exports('use', function(event, item, inventory)
    local src = inventory.id

    if event == 'usingItem' then
        local ped = GetPlayerPed(src)
        if ped == 0 then return false end

        if GetVehiclePedIsIn(ped) ~= 0 then
            TriggerClientEvent('som:client:notify', src, 'Not from inside a vehicle', 'error')
            -- Returning false cancels the use, so the item is not consumed.
            return false
        end

        return
    end

    if event == 'usedItem' then
        -- Own thread, because placeProp waits for the entity to exist and this
        -- export is called from ox_inventory's context, where a yield is not
        -- guaranteed to be legal. Nothing reads a return value from usedItem.
        CreateThread(function() placeProp(src, item) end)
    end
end)

-- Handles are reused once an entity is gone, so a stale key could eventually
-- collide with an unrelated new entity. Rule 2 already refuses a mismatched
-- model, but sweeping keeps the table from growing without bound on a long
-- uptime as props are deleted by other means.
CreateThread(function()
    while true do
        Wait(60000)

        for entity in pairs(placed) do
            if not DoesEntityExist(entity) then placed[entity] = nil end
        end
    end
end)
