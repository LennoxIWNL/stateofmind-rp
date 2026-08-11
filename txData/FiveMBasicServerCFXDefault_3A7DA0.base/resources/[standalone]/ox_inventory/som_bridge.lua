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

-- ---------------------------------------------------------------------------
-- The bottom status strip
--
-- ox_inventory's NUI contract carries no player condition at all, so the strip
-- in the reference cannot be built from the seven inbound messages. It CAN be
-- built here: this file is a client script, so it can read the ped and push its
-- own message into the same frame.
--
-- The two things worth copying from som-hud rather than rediscovering:
--
--   * GTA player health runs 100 to 200, not 0 to 100. Sending the raw value
--     shows a corpse at 50% and a healthy player at 100%.
--   * Send only on CHANGE. A payload every tick makes the NUI feel heavy in a
--     way profiling will not show, because the cost is in the bridge and the
--     render, not in the Lua.
-- ---------------------------------------------------------------------------

local somOpen = false
local lastStatus = {}

local function healthPercent(ped)
    local max = GetEntityMaxHealth(ped)
    local floor = 100
    if max <= floor then return 0 end

    local value = (GetEntityHealth(ped) - floor) / (max - floor) * 100
    if value < 0 then return 0 end
    if value > 100 then return 100 end
    return math.floor(value + 0.5)
end

---Hunger and thirst live on som-core metadata. Guarded on the resource being
---started so ox_inventory still runs standalone without it.
local function need(key)
    if GetResourceState('som-core') ~= 'started' then return 100 end

    local value = tonumber(exports['som-core']:getMetadata(key))
    if not value then return 100 end
    if value < 0 then return 0 end
    if value > 100 then return 100 end
    return math.floor(value + 0.5)
end

local function statusChanged(a, b)
    for key, value in pairs(b) do
        if a[key] ~= value then return true end
    end
    return false
end

--- The page tells us when it is on screen, so the poll below only runs while
--- something is actually looking at it.
RegisterNUICallback('somInventoryOpen', function(data, cb)
    cb(1)
    somOpen = type(data) == 'table' and data.open == true
    if not somOpen then lastStatus = {} end
end)

CreateThread(function()
    while true do
        Wait(somOpen and 500 or 1500)

        if somOpen then
            local ped = PlayerPedId()

            local payload = {
                health = healthPercent(ped),
                armour = math.floor(GetPedArmour(ped) + 0.5),
                hunger = need('hunger'),
                thirst = need('thirst'),
            }

            if statusChanged(lastStatus, payload) then
                lastStatus = payload
                SendNUIMessage({ action = 'somStatus', data = payload })
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Basket persistence
--
-- The page is destroyed when the inventory closes, so a basket that should
-- survive a close and reopen cannot live there. It lives here, keyed by shop
-- id, and is handed back when the same shop is opened again.
--
-- It is a CONVENIENCE AND NEVER AN AUTHORITY. Checkout replays each line
-- through ox_inventory's own buyItem, which re-prices and re-validates every
-- one, so a basket restored from here buys exactly what a freshly built one
-- would.
-- ---------------------------------------------------------------------------

local baskets = {}

RegisterNUICallback('somBasketSave', function(data, cb)
    cb(1)
    if type(data) ~= 'table' or type(data.shop) ~= 'string' then return end
    baskets[data.shop] = type(data.lines) == 'table' and data.lines or nil
end)

RegisterNUICallback('somBasketLoad', function(data, cb)
    if type(data) ~= 'table' or type(data.shop) ~= 'string' then return cb({}) end
    cb(baskets[data.shop] or {})
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then baskets = {} end
end)

-- ---------------------------------------------------------------------------
-- Wardrobe
--
-- Relays only. som-appearance owns the mutation, because appearance is its data
-- and keeping the write there means there is still exactly one writer of
-- som_characters.appearance. It re-reads the stored record, checks the
-- component against its own allow list and refuses anything else, so a crafted
-- id here strips nothing.
-- ---------------------------------------------------------------------------

RegisterNUICallback('somWardrobeState', function(_, cb)
    if GetResourceState('som-appearance') ~= 'started' then
        return cb({ success = false, error = 'som-appearance is not running' })
    end

    -- Own thread, because lib.callback.await yields and a NUI callback handler
    -- is not a context to assume that is legal in. cb may be answered later,
    -- which is exactly what a thread gives us.
    CreateThread(function()
        cb(lib.callback.await('som-appearance:server:wardrobeState', false) or { success = false })
    end)
end)

RegisterNUICallback('somWardrobe', function(data, cb)
    cb(1)

    if type(data) ~= 'table' then return end
    if GetResourceState('som-appearance') ~= 'started' then return end

    TriggerServerEvent('som-appearance:server:wardrobe', {
        action = data.action,
        kind = data.kind,
        id = num(data.id),
    })
end)

-- ---------------------------------------------------------------------------
-- Items dropped nearby
--
-- ox_inventory keeps its drop table private to its own client.lua, so this
-- tracks the same two events it does rather than reaching into it. That is the
-- difference between reading a contract and reading an implementation: these
-- two event names are the surface, and if they change this stops finding drops
-- instead of erroring on a nil table.
--
-- COORDS ONLY. The CONTENTS of a drop are not read here and are not sent to the
-- page: knowing what is inside a container you have not opened is not something
-- the stock inventory grants, and adding it here would be a new capability
-- rather than a new surface. The page shows that a drop is there and how far
-- away; opening it is still ox_inventory's own path.
-- ---------------------------------------------------------------------------

local drops = {}

RegisterNetEvent('ox_inventory:createDrop', function(dropId, data)
    if type(data) ~= 'table' or not data.coords then return end
    drops[dropId] = data.coords
end)

RegisterNetEvent('ox_inventory:removeDrop', function(dropId)
    drops[dropId] = nil
end)

RegisterNUICallback('somNearbyDrops', function(_, cb)
    local coords = GetEntityCoords(PlayerPedId())
    local near = {}

    for dropId, position in pairs(drops) do
        local distance = #(coords - position)

        -- Roughly the reach ox_inventory itself allows for opening a drop.
        -- Listing one further away than it can be opened would be an offer the
        -- player cannot take.
        if distance <= 3.0 then
            near[#near + 1] = { id = dropId, distance = math.floor(distance * 10) / 10 }
        end
    end

    table.sort(near, function(a, b) return a.distance < b.distance end)
    cb(near)
end)

--- Opens the nearest drop, through ox_inventory's OWN export, so the distance
--- and access rules that apply to walking up to one apply here too.
RegisterNUICallback('somOpenNearbyDrop', function(_, cb)
    cb(1)
    exports.ox_inventory:openNearbyInventory()
end)
