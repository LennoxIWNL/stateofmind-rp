-- SOM PATCH. A NEW FILE, not an edit to any of ox_inventory's own.
--
-- On the AUDIT 16.2 re-apply list: an ox_inventory upgrade drops this and the
-- two fxmanifest lines that reference it, and the extra NUI callbacks below go
-- with them.
--
-- WHY IT HAS TO LIVE IN THIS RESOURCE.
--
-- som-inventory's renderer is served from ox_inventory's origin, because
-- fetchNui posts to whichever resource served the page and a
-- RegisterNUICallback only ever answers for the resource owning the frame.
-- That is what lets the stock eleven callbacks keep working untouched. The
-- same rule means a callback registered in som-inventory is unreachable from
-- the page, so the handful of actions ox_inventory has no stock path for need
-- a registration HERE.
--
-- EVERY ONE OF THESE IS A RELAY AND DECIDES NOTHING. They shape an argument
-- and hand it to a som-inventory server event, which re-reads the slot from
-- ox_inventory, re-reads positions from the server's own view, and refuses
-- whatever it does not like. A player editing this file, or calling these
-- callbacks directly, gains no item they could not already have asked for.

local function num(value)
    value = tonumber(value)
    if not value or value ~= value then return nil end
    return value
end

--- Throw the item in a slot. `power` is a 0..1 charge; the server clamps it and
--- decides the distance, so a forged 99 buys nothing.
RegisterNUICallback('somThrow', function(data, cb)
    cb(1)

    if type(data) ~= 'table' then return end

    local slot = num(data.slot)
    if not slot then return end

    TriggerServerEvent('som-inventory:server:throw', {
        slot = slot,
        power = num(data.power) or 0,
    })
end)

--- Give to a SPECIFIC nearby player, which stock `giveItem` cannot express: it
--- gives to whoever the client decided was in front of it.
RegisterNUICallback('somGiveTo', function(data, cb)
    cb(1)

    if type(data) ~= 'table' then return end

    local slot = num(data.slot)
    local target = num(data.target)
    if not slot or not target then return end

    TriggerServerEvent('som-inventory:server:giveTo', {
        slot = slot,
        target = target,
        count = num(data.count) or 1,
    })
end)

--- Nearby players, for the drag-to-give highlight.
---
--- Client side and READ ONLY on purpose. This answers "who could I drop this
--- on", which is a rendering question. Whether the give is allowed is decided
--- again on the server against its own view of both positions, so a client that
--- lies here only lies to itself about what to draw.
RegisterNUICallback('somNearbyPlayers', function(_, cb)
    local ped = PlayerPedId()
    local origin = GetEntityCoords(ped)
    local nearby = {}

    for _, playerId in ipairs(GetActivePlayers()) do
        local otherPed = GetPlayerPed(playerId)

        if otherPed ~= ped and DoesEntityExist(otherPed) then
            local distance = #(origin - GetEntityCoords(otherPed))

            if distance <= 5.0 then
                nearby[#nearby + 1] = {
                    -- The SERVER id, which is what the give event needs. The
                    -- local player index is meaningless across the network.
                    id = GetPlayerServerId(playerId),
                    name = GetPlayerName(playerId),
                    distance = math.floor(distance * 10) / 10,
                }
            end
        end
    end

    table.sort(nearby, function(a, b) return a.distance < b.distance end)
    cb(nearby)
end)
