-- Placeable scene props, client half.
--
-- Deliberately thin. It decides what the eye offers and plays the animation,
-- and that is the whole of it. It does not delete the prop, does not name the
-- item, and does not decide whether the player is close enough: the server
-- re-derives all three from the network id alone. See server/main.lua.
--
-- The reference implementation deleted the entity client side and told the
-- server afterwards, which is the wrong way round. Here the server deletes it,
-- so a client that lies or disconnects mid-pickup changes nothing.

-- Model hashes som-props knows how to pick up. Read on every canInteract, so
-- it is a plain lookup table built once rather than anything computed per call.
local placeableModels = {}

---Fills placeableModels from ox_inventory's client item list.
---
---Iterating that list is fine. Indexing it BY NAME is the AUDIT 21.3 trap,
---since ox_inventory keys weapons uppercase and normalises inside getItem, and
---nothing here looks up by name.
---@return boolean found whether anything was indexed
local function buildIndex()
    local items = exports.ox_inventory:Items()
    if not items then return false end

    local found = false

    for _, data in pairs(items) do
        local def = data.placeable

        if type(def) == 'table' and type(def.models) == 'table' then
            for i = 1, #def.models do
                placeableModels[def.models[i]] = true
                found = true
            end
        end
    end

    return found
end

CreateThread(function()
    -- ox_inventory populates its item list on start, so this retries rather
    -- than reading once at file scope. Caching an empty result would leave the
    -- eye offering nothing for the whole session with no error to show for it.
    for _ = 1, 20 do
        if buildIndex() then break end
        Wait(500)
    end

    exports['som-interact']:addGlobalObject({
        {
            name = 'som-props:pickup',
            label = 'Pick Up',
            icon = 'fa-solid fa-hand',
            distance = 2.0,

            canInteract = function(entity)
                if not entity or entity == 0 then return false end
                return placeableModels[GetEntityModel(entity)] == true
            end,

            onSelect = function(data)
                local entity = data.entity
                if not entity or not DoesEntityExist(entity) then return end

                -- A prop the server placed is networked, so it has an id. One
                -- that does not is not ours and the server would refuse it
                -- anyway, so there is nothing to send.
                if not NetworkGetEntityIsNetworked(entity) then return end

                local netId = NetworkGetNetworkIdFromEntity(entity)
                if not netId or netId == 0 then return end

                if lib.progressBar({
                    duration = 900,
                    label = 'Picking up',
                    useWhileDead = false,
                    canCancel = true,
                    disable = { move = true, car = true, combat = true },
                    anim = { dict = 'anim@mp_snowball', clip = 'pickup_snowball', flag = 48 },
                }) then
                    TriggerServerEvent('som-props:server:pickup', netId)
                end
            end,
        }
    })
end)

-- Only the entity's owner may call SetObjectForceVehiclesToAvoid, so the server
-- flags the prop and whichever client owns it applies the flag.
AddStateBagChangeHandler('somPropAvoid', nil, function(bagName, _, value)
    if not value then return end

    local entity = GetEntityFromStateBagName(bagName)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    if NetworkGetEntityOwner(entity) ~= cache.playerId then return end

    SetObjectForceVehiclesToAvoid(entity, true)
end)
