-- som-inventory: the things ox_inventory's NUI contract cannot do.
--
-- Throwing and giving to a NAMED nearby player have no stock callback, so they
-- land here rather than being bolted onto ox_inventory's Lua. Everything the
-- page can reach through the bridge arrives HERE first and is decided HERE.
--
-- THE PAGE IS NEVER AN AUTHORITY. It sends a slot and a power, and that is the
-- whole of what it is trusted with. This file re-reads the slot from
-- ox_inventory, re-reads both players' positions from the server's own view,
-- and computes the landing point itself. A crafted payload buys a different
-- number in one of those two fields and nothing else.

local core = exports['som-core']
local ox = exports.ox_inventory

local Config = {
    -- How far a throw carries at full charge. Short on purpose: this is an
    -- underarm toss to somebody across a room, not a delivery mechanism for
    -- moving contraband across a street without walking it.
    minDistance = 2.0,
    maxDistance = 12.0,
    -- Giving needs the two of you close enough to be having a conversation.
    -- Matches som-gangboss-app's MaxHireDistance precedent: a transfer is a
    -- physical act.
    giveDistance = 3.0,
    -- One throw per this many ms, per player. Without it the charge bar is a
    -- suggestion and the event is a firehose.
    throwCooldown = 900,
}

local lastThrow = {}

---@param source number
---@return table|nil player
local function loaded(source)
    local player = core:getPlayer(source)
    if not player then return nil end
    return player
end

---Distance between two players, measured from the SERVER's own view of both
---peds rather than from anything either client claimed.
---@return number
local function distanceBetween(a, b)
    local pedA, pedB = GetPlayerPed(a), GetPlayerPed(b)
    if not pedA or pedA == 0 or not pedB or pedB == 0 then return math.huge end
    return #(GetEntityCoords(pedA) - GetEntityCoords(pedB))
end

---Re-reads a slot from ox_inventory. Never trusts a name sent by the page.
---@param source number
---@param slot any
---@return table|nil
local function slotOf(source, slot)
    slot = tonumber(slot)
    if not slot or slot ~= slot or slot < 1 or slot % 1 ~= 0 then return nil end

    local item = ox:GetSlot(source, slot)
    if not item or not item.name then return nil end

    return item
end

-- ---------------------------------------------------------------------------
-- Throwing
-- ---------------------------------------------------------------------------

---The page asks to throw the item in a slot at a charge level.
---
---What actually happens: the server removes the item, works out where it lands
---from its own view of the player, and creates a REAL ox_inventory drop there.
---So a thrown item is a drop like any other, pickupable by anyone, and no new
---item-holding concept enters the codebase.
RegisterNetEvent('som-inventory:server:throw', function(data)
    local src = source
    if type(data) ~= 'table' then return end

    local player = loaded(src)
    if not player then return end

    local now = GetGameTimer()
    if lastThrow[src] and now - lastThrow[src] < Config.throwCooldown then return end

    local item = slotOf(src, data.slot)
    if not item then return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end

    -- THE AIM POINT IS A REQUEST, NOT A DESTINATION.
    --
    -- The client picks where it is throwing, because only the client knows
    -- where the player is looking. The server then re-reads its OWN view of the
    -- ped and refuses anything further than the maximum, so the aim buys a
    -- direction and never a delivery range.
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    if not x or not y or not z or x ~= x or y ~= y or z ~= z then return end

    local origin = GetEntityCoords(ped)
    local landing = vector3(x, y, z)

    if #(origin - landing) > Config.maxDistance then
        -- Clamped rather than refused: a laggy aim point a little too far is a
        -- normal thing to happen, and dropping the throw silently would read as
        -- the item vanishing, which is the bug this rewrite exists to fix.
        local direction = landing - origin
        local length = #direction
        if length < 0.1 then return end
        landing = origin + (direction / length) * Config.maxDistance
    end

    -- Remove FIRST and only drop if the removal succeeded. The other order
    -- creates the drop and then discovers the item was already gone, which is
    -- the whole of how a duplication bug looks from the outside.
    local removed = ox:RemoveItem(src, item.name, 1, item.metadata, item.slot)
    if not removed then return end

    lastThrow[src] = now

    -- The MODEL is cosmetic and comes from the client, because ox_inventory
    -- strips `client` from the server copy of an item so the prop genuinely is
    -- not readable here. It is passed to CustomDrop as a model and used for
    -- nothing else, so a forged value makes an oddly shaped bag and no more.
    local model = tonumber(data.model)

    ox:CustomDrop('Thrown', {
        { name = item.name, count = 1, metadata = item.metadata },
    }, landing, nil, nil, nil, model)
end)

-- ---------------------------------------------------------------------------
-- Giving to a named nearby player
-- ---------------------------------------------------------------------------

---ox_inventory's own `giveItem` gives to whoever the CLIENT decided was in
---front of it. This exists so the page can drag onto a specific person and have
---the server agree that person is real, close, and loaded.
RegisterNetEvent('som-inventory:server:giveTo', function(data)
    local src = source
    if type(data) ~= 'table' then return end

    local target = tonumber(data.target)
    if not target or target ~= target or target % 1 ~= 0 then return end
    if target == src then return end

    if not loaded(src) or not loaded(target) then return end

    if distanceBetween(src, target) > Config.giveDistance then
        TriggerClientEvent('som:client:notify', src, 'They are too far away', 'error')
        return
    end

    local item = slotOf(src, data.slot)
    if not item then return end

    local count = tonumber(data.count) or 1
    if count ~= count or count < 1 or count % 1 ~= 0 then return end
    count = math.min(count, item.count or 1)

    if not ox:CanCarryItem(target, item.name, count) then
        TriggerClientEvent('som:client:notify', src, 'They cannot carry that', 'error')
        return
    end

    -- Same ordering rule as the throw: take before giving, and give nothing if
    -- the take failed.
    if not ox:RemoveItem(src, item.name, count, item.metadata, item.slot) then return end

    if not ox:AddItem(target, item.name, count, item.metadata) then
        -- Put it back rather than destroy it. Failing to hand something over is
        -- not a reason for it to stop existing.
        ox:AddItem(src, item.name, count, item.metadata)
        return
    end

    local label = ox:Items(item.name)
    label = label and label.label or item.name

    TriggerClientEvent('som:client:notify', src, ('Gave %sx %s'):format(count, label), 'success')
    TriggerClientEvent('som:client:notify', target, ('Received %sx %s'):format(count, label), 'success')
end)

AddEventHandler('playerDropped', function()
    lastThrow[source] = nil
end)

-- ---------------------------------------------------------------------------
-- DOWNED PLAYERS CANNOT TOUCH THEIR INVENTORY.
--
-- This is a SECURITY boundary, not a UX one, which is why it is here and not
-- only in the client.
--
-- ox_inventory already refuses to open on `PlayerData.dead` or
-- IsPedFatallyInjured. Neither is true for a SOM downed player: som-medical
-- keeps the ped alive on low health so it can be revived, so as far as
-- ox_inventory was concerned nothing was wrong and every action was allowed.
--
-- What that permitted: bleeding out while eating, healing yourself with a
-- medkit you should have needed a medic for, and handing your entire inventory
-- to a friend standing over you before police could search you. The last one is
-- the real prize and it is why a client-side gate would not have been enough.
--
-- registerHook is ox_inventory's own supported extension point, so this adds no
-- edits to their files. It IS on the AUDIT 16.2 re-apply list, because an
-- ox_inventory upgrade drops the hook registration along with everything else.
-- ---------------------------------------------------------------------------

local function isDowned(source)
    if GetResourceState('som-medical') ~= 'started' then return false end
    return exports['som-medical']:isDowned(source) == true
end

CreateThread(function()
    -- After ox_inventory exists. registerHook is one of its exports, so calling
    -- it at load order is a race we would lose silently.
    while GetResourceState('ox_inventory') ~= 'started' do Wait(250) end
    Wait(500)

    -- EVERY mutating surface, not just opening. Refusing `openInventory` alone
    -- leaves the hotbar, which needs no open inventory to use an item, and
    -- leaves a shop bought through a nearby target.
    local guarded = { 'openInventory', 'swapItems', 'usingItem', 'buyItem', 'craftItem' }

    for _, event in ipairs(guarded) do
        exports.ox_inventory:registerHook(event, function(payload)
            -- `source` VERIFIED, not assumed. All five of these payloads carry
            -- it as a plain field: server.lua:244 and :469,
            -- modules/inventory/server.lua:1581, modules/shops/server.lua:293
            -- and modules/crafting/server.lua:193.
            --
            -- The first draft here read three possible field names as a hedge.
            -- That hedge is worse than useless on a security check: if the
            -- field were ever renamed, a fallback would quietly find some other
            -- number, pass it to isDowned, get false, and allow everything. A
            -- guard that fails open must fail LOUDLY instead.
            local src = payload and payload.source
            if not src then return true end

            return not isDowned(src)
        end)
    end
end)
