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

-- ---------------------------------------------------------------------------
-- No screen blur.
--
-- ox_inventory calls TriggerScreenblurFadeIn when the inventory opens
-- (modules/utils/client.lua:231). There is no convar for it, so the function
-- is replaced rather than the native fought: blurring the world behind a panel
-- that already has its own background just makes the game look out of focus.
--
-- Replacing the module member rather than editing their file keeps this on the
-- re-apply list with everything else instead of buried in their source.
-- ---------------------------------------------------------------------------

CreateThread(function()
    local ok, Utils = pcall(require, 'modules.utils.client')
    if not ok or type(Utils) ~= 'table' then return end

    Utils.blurIn = function() end
    Utils.blurOut = function()
        -- Still clears any fade left running by something else, so turning the
        -- blur off here cannot strand one that another resource started.
        if IsScreenblurFadeRunning() then DisableScreenblurFade() end
    end
end)

local function num(value)
    value = tonumber(value)
    if not value or value ~= value then return nil end
    return value
end

-- ---------------------------------------------------------------------------
-- Throwing
--
-- Rewritten: the first version removed the item and made a drop appear a fixed
-- distance in front of the player, which reads as the item vanishing.
--
-- How a throw actually works, which is what this now does:
--   1. The page closes and the player AIMS. A ghost prop sits in their hand and
--      an arc is drawn to where it will land, so the throw is a decision.
--   2. Left click throws. The ped plays the underarm/overarm animation.
--   3. The item lands as a REAL ox_inventory drop carrying THAT ITEM'S prop
--      model, so a thrown bandage is a bandage lying on the floor.
--
-- The client picks the aim point and the server still decides everything that
-- matters: it re-reads the slot, clamps the distance, and refuses a landing
-- point further than the maximum from the player's own server-side position.
-- ---------------------------------------------------------------------------

local aiming = false

---The prop a thrown item should become on the ground.
---
---Read CLIENT side because ox_inventory strips `client` from the server copy of
---an item, so the server genuinely cannot see it. Cosmetic only: the server
---uses it as a model and nothing else, so the worst a forged value achieves is
---an oddly shaped bag.
local function propFor(name)
    local item = exports.ox_inventory:Items(name)
    local prop = item and item.client and item.client.prop

    if type(prop) == 'table' then
        -- The binder shape is { model = hash, pos, rot }; a list is several
        -- variants, in which case the first is representative.
        return prop.model or prop[1] and prop[1].model
    end

    return nil
end

RegisterNUICallback('somThrow', function(data, cb)
    cb(1)

    if type(data) ~= 'table' or aiming then return end

    local slot = num(data.slot)
    if not slot then return end

    -- GetPlayerItems, NOT GetSlot.
    --
    -- GetSlot is a SERVER export and does not exist on the client, so this
    -- returned nil every single time and the throw returned one line later
    -- without a word. That is why throwing looked like it did nothing: the
    -- callback fired, found no item, and gave up silently.
    --
    -- Same class as FreezeEntityPosition being client-only: an export existing
    -- is not the same as it existing on the side you are calling it from.
    local items = exports.ox_inventory:GetPlayerItems()
    local item = items and items[slot]
    if not item or not item.name then return end

    local model = propFor(item.name) or `prop_cs_bandage`

    CreateThread(function()
        aiming = true

        -- Close the inventory first. Aiming with the grid still on screen is
        -- the version that made the old one feel like the item vanished.
        exports.ox_inventory:closeInventory()
        Wait(150)

        local ped = PlayerPedId()

        lib.requestModel(model, 2000)
        local ghost = CreateObject(model, GetEntityCoords(ped), false, false, false)
        SetEntityCollision(ghost, false, false)
        SetEntityAlpha(ghost, 153, false)
        AttachEntityToEntity(ghost, ped, GetPedBoneIndex(ped, 28422),
            0.1, 0.02, 0.02, -80.0, 0.0, 0.0, true, true, false, true, 1, true)

        lib.requestAnimDict('anim@mp_snowball', 2000)
        TaskPlayAnim(ped, 'anim@mp_snowball', 'pickup_snowball', 3.0, 3.0, -1, 50, 0, false, false, false)

        local thrown, cancelled = false, false

        while not thrown and not cancelled do
            Wait(0)

            -- The arc, drawn from the hand to where it lands. Sampled rather
            -- than solved: twelve points of a simple ballistic curve is enough
            -- to read as a trajectory and costs nothing.
            local from = GetPedBoneCoords(ped, 28422, 0.0, 0.0, 0.0)
            local forward = GetEntityForwardVector(ped)
            local distance = 9.0

            local prev = from
            for i = 1, 12 do
                local t = i / 12
                local point = vector3(
                    from.x + forward.x * distance * t,
                    from.y + forward.y * distance * t,
                    from.z + (2.2 * t) - (9.0 * t * t)
                )
                DrawLine(prev.x, prev.y, prev.z, point.x, point.y, point.z, 255, 20, 147, 180)
                prev = point
            end

            DrawMarker(28, prev.x, prev.y, prev.z, 0, 0, 0, 0, 0, 0,
                0.18, 0.18, 0.18, 255, 20, 147, 120, false, false, 2, nil, nil, false)

            -- Attack throws, right click or Escape backs out. Disabled while
            -- aiming so an unarmed swing does not go out with it.
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true)

            if IsDisabledControlJustPressed(0, 24) then
                thrown = true
            elseif IsDisabledControlJustPressed(0, 25) or IsControlJustPressed(0, 202) then
                cancelled = true
            end
        end

        ClearPedTasks(ped)
        if DoesEntityExist(ghost) then DeleteEntity(ghost) end
        SetModelAsNoLongerNeeded(model)

        if thrown then
            lib.requestAnimDict('anim@arena@celeb@flat@paired@no_props@', 1000)
            TaskPlayAnim(ped, 'anim@arena@celeb@flat@paired@no_props@',
                'flip_a_player_a', 3.0, 3.0, 900, 48, 0, false, false, false)

            TriggerServerEvent('som-inventory:server:throw', {
                slot = slot,
                -- The AIM POINT, not a charge. The server re-reads the player's
                -- position and refuses anything beyond its own maximum, so this
                -- is a request rather than a destination.
                x = prev.x, y = prev.y, z = prev.z,
                model = model,
            })
        end

        aiming = false
    end)
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

-- ESC MUST CLOSE THE INVENTORY, NOT OPEN THE PAUSE MENU.
--
-- NUI focus does not take the pause key from the game: CEF sees the keypress
-- AND so does GTA, so the page closed itself and the pause menu opened behind
-- it in the same frame.
--
-- Control 200 is INPUT_FRONTEND_PAUSE and 199 is its alternate. Disabled only
-- while the inventory is actually open, and per frame because that is the only
-- rate a disabled control holds for.
CreateThread(function()
    while true do
        if somOpen then
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)
            Wait(0)
        else
            Wait(200)
        end
    end
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

--- Drops that ALREADY EXISTED when this client connected.
---
--- They never fire createDrop. The server hands the whole set over once, in the
--- first argument of setPlayerInventory (server.lua:64), and ox_inventory's own
--- client.lua registers them by calling its local createDrop directly rather
--- than re-emitting the event. Listening only for createDrop therefore finds
--- nothing a player did not watch happen, which means every drop on the ground
--- is invisible after a relog or an ox_inventory restart.
RegisterNetEvent('ox_inventory:setPlayerInventory', function(currentDrops)
    if type(currentDrops) ~= 'table' then return end

    -- Replaced rather than merged: this message IS the full current set, so
    -- anything held from a previous session is stale by definition.
    drops = {}

    for dropId, data in pairs(currentDrops) do
        if type(data) == 'table' and data.coords then drops[dropId] = data.coords end
    end
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

--- Opens a specific drop by id, through ox_inventory's own openInventory.
---
--- NOT `openNearbyInventory`, which reads like the right export and is not:
--- it is `client.openInventory('player')` (client.lua:709), the function behind
--- the /steal command, which opens the nearest PLAYER'S POCKETS. Wiring the
--- drop button to it would have turned picking up a bag into pickpocketing
--- whoever was standing closest.
---
--- The id comes from the page, which is why nothing here trusts it: the server
--- distance-gates every drop open of its own accord, so a forged id opens
--- nothing that walking up to it would not have.
RegisterNUICallback('somOpenNearbyDrop', function(data, cb)
    cb(1)

    if type(data) ~= 'table' or type(data.id) ~= 'string' then return end

    exports.ox_inventory:openInventory('drop', data.id)
end)
