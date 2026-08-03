-- Custody: cuffing, escorting, moving, searching and seizing.
--
-- CUFFING IS NOT POLICE ONLY.
--
-- It needs handcuffs in the inventory and proximity, and nothing else. If only
-- the police could restrain or move somebody, kidnapping would be impossible
-- and crime would have no counterplay. So the restraint verbs check the item;
-- only the police-specific verbs (seize, fine, impound) check the job.
--
-- `metadata.cuffed` is FRAMEWORK state, not this resource's private flag.
-- som-theft already gates cash robbery on it, and the vehicle-entry block reads
-- the same value, so there is exactly one answer to "is this person restrained".

local core = exports['som-core']

-- Who is escorting whom, server side, because the client that thinks it is
-- dragging someone is not the authority on it.
local escorting = {}   -- escorterSource -> targetSource

-- ---------------------------------------------------------------------------
-- Shared checks
-- ---------------------------------------------------------------------------

---@param source number
---@return boolean
local function hasCuffs(source)
    local found = exports.ox_inventory:Search(source, 'count', Config.Custody.item)
    return (tonumber(found) or 0) > 0
end

---Every custody action starts here: both players real, both close, actor armed
---with the item the action requires.
---@param source number
---@param targetId number
---@param requireItem boolean
---@return table|nil actor, table|nil target, string|nil error
local function pair(source, targetId, requireItem)
    targetId = tonumber(targetId) or 0
    if targetId <= 0 then return nil, nil, 'no target' end
    if targetId == source then return nil, nil, 'not on yourself' end

    local actor = core:getPlayer(source)
    if not actor then return nil, nil, 'not loaded' end

    local target = core:getPlayer(targetId)
    if not target then return nil, nil, 'they are not around' end

    if not Police.InRange(source, targetId, Config.Custody.distance) then
        return nil, nil, 'too far away'
    end

    if requireItem and not hasCuffs(source) then
        return nil, nil, 'you need handcuffs'
    end

    return actor, target
end

---@param source number
---@return boolean
local function isCuffed(source)
    return core:getMetadata(source, 'cuffed') == true
end

Custody = {}
Custody.IsCuffed = isCuffed

-- ---------------------------------------------------------------------------
-- Cuff and uncuff
-- ---------------------------------------------------------------------------

lib.callback.register('som-police:server:cuff', function(source, targetId)
    local actor, target, err = pair(source, targetId, true)
    if not actor then return { success = false, error = err } end

    if isCuffed(target.source) then
        return { success = false, error = 'already cuffed' }
    end

    -- The handcuffs are NOT consumed. Carrying a pair is what makes you able to
    -- cuff, so there is nothing to lose mid-arrest and no item-use flow to
    -- fight with.
    local ok = core:setMetadata(target.source, 'cuffed', true)
    if not ok then return { success = false, error = 'could not restrain them' } end

    MySQL.insert.await([[
        INSERT INTO som_police_custody (citizenid, by_cid, by_job, by_grade)
        VALUES (?, ?, ?, ?)
    ]], { target.citizenid, actor.citizenid, actor.job.name, actor.job.grade })

    TriggerClientEvent('som-police:client:setCuffed', target.source, true)
    TriggerClientEvent('som:client:notify', target.source, 'You have been restrained', 'error')

    return { success = true }
end)

lib.callback.register('som-police:server:uncuff', function(source, targetId)
    -- Uncuffing needs no item. Freeing somebody should never be the harder
    -- half, and requiring the key to be present would strand a cuffed player
    -- when the person who cuffed them logs off.
    local actor, target, err = pair(source, targetId, false)
    if not actor then return { success = false, error = err } end

    if not isCuffed(target.source) then
        return { success = false, error = 'they are not cuffed' }
    end

    core:setMetadata(target.source, 'cuffed', false)

    MySQL.update.await([[
        UPDATE som_police_custody
        SET released_at = CURRENT_TIMESTAMP, released_by = ?
        WHERE citizenid = ? AND released_at IS NULL
    ]], { actor.citizenid, target.citizenid })

    -- Being freed also ends any escort, otherwise the escorter keeps dragging
    -- somebody who is no longer restrained.
    for escorter, escorted in pairs(escorting) do
        if escorted == target.source then
            escorting[escorter] = nil
            TriggerClientEvent('som-police:client:endEscort', escorter)
        end
    end

    TriggerClientEvent('som-police:client:setCuffed', target.source, false)
    TriggerClientEvent('som:client:notify', target.source, 'You have been released', 'success')

    return { success = true }
end)

---Whether a target is currently restrained.
---
---Exists so the cuff KEYBIND can pick the right verb before it starts, and so
---run the same progress bar the eye does. Without it the bind would have to
---fire and react to a refusal, which would make cuffing by key instant while
---cuffing by eye took three seconds. That is a real advantage, not a cosmetic
---difference, so the extra round trip is worth it.
---
---Proximity is still checked, so this cannot be used to poll the restraint
---state of the whole server.
lib.callback.register('som-police:server:custodyState', function(source, targetId)
    local _, target, err = pair(source, targetId, false)
    if not target then return { success = false, error = err } end

    return { success = true, cuffed = isCuffed(target.source) }
end)

-- ---------------------------------------------------------------------------
-- Escort
-- ---------------------------------------------------------------------------

lib.callback.register('som-police:server:escort', function(source, targetId)
    local actor, target, err = pair(source, targetId, false)
    if not actor then return { success = false, error = err } end

    if not isCuffed(target.source) then
        return { success = false, error = 'they are not restrained' }
    end

    -- One at a time, in both directions: a person cannot be dragged by two
    -- people, and one person cannot drag two.
    if escorting[source] then return { success = false, error = 'you are already escorting someone' } end

    for _, escorted in pairs(escorting) do
        if escorted == target.source then
            return { success = false, error = 'somebody else has them' }
        end
    end

    escorting[source] = target.source

    TriggerClientEvent('som-police:client:beginEscort', target.source, source)
    return { success = true }
end)

lib.callback.register('som-police:server:stopEscort', function(source)
    local targetId = escorting[source]
    if not targetId then return { success = false, error = 'you are not escorting anyone' } end

    escorting[source] = nil

    if GetPlayerName(targetId) then
        TriggerClientEvent('som-police:client:endEscort', targetId)
    end

    return { success = true }
end)

-- ---------------------------------------------------------------------------
-- Vehicles
--
-- Deliberately NOT job gated. A cuffed player cannot enter a vehicle unaided,
-- so if only the police could put somebody in one, a kidnapping could never
-- leave the pavement.
-- ---------------------------------------------------------------------------

lib.callback.register('som-police:server:putInVehicle', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'invalid request' } end

    local actor, target, err = pair(source, data.target, false)
    if not actor then return { success = false, error = err } end

    if not isCuffed(target.source) then
        return { success = false, error = 'they are not restrained' }
    end

    local netId = tonumber(data.netId)
    if not netId then return { success = false, error = 'no vehicle' } end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return { success = false, error = 'no such vehicle' }
    end

    -- The vehicle has to be next to the person being put in it, not merely
    -- next to whoever is doing the putting.
    local targetPed = GetPlayerPed(target.source)
    if #(GetEntityCoords(targetPed) - GetEntityCoords(vehicle)) > 5.0 then
        return { success = false, error = 'that vehicle is not here' }
    end

    local seat = tonumber(data.seat)
    -- Rear seats only, so a restrained person cannot be dropped into the
    -- driver's seat.
    if not seat or seat < 1 then seat = 1 end

    if escorting[source] == target.source then
        escorting[source] = nil
        TriggerClientEvent('som-police:client:endEscort', target.source)
    end

    TriggerClientEvent('som-police:client:intoVehicle', target.source, netId, seat)
    return { success = true }
end)

lib.callback.register('som-police:server:pullFromVehicle', function(source, targetId)
    local actor, target, err = pair(source, targetId, false)
    if not actor then return { success = false, error = err } end

    if not isCuffed(target.source) then
        return { success = false, error = 'they are not restrained' }
    end

    TriggerClientEvent('som-police:client:outOfVehicle', target.source)
    return { success = true }
end)

-- ---------------------------------------------------------------------------
-- Search and seize
--
-- Searching is available to anyone who has them restrained, because robbing a
-- captive is a crime that should be possible. SEIZING is police only: it is
-- confiscation into evidence, not theft, and it is ledgered.
-- ---------------------------------------------------------------------------

lib.callback.register('som-police:server:search', function(source, targetId)
    local actor, target, err = pair(source, targetId, false)
    if not actor then return { success = false, error = err } end

    if not isCuffed(target.source) then
        return { success = false, error = 'they are not restrained' }
    end

    -- ox opens the target's inventory for the searcher. The forced open is what
    -- makes this a search rather than a trade request.
    exports.ox_inventory:forceOpenInventory(source, 'player', target.source)

    TriggerClientEvent('som:client:notify', target.source, 'You are being searched', 'inform')
    return { success = true }
end)

lib.callback.register('som-police:server:seizeCash', function(source, targetId)
    local officer, err = Police.Officer(source)
    if not officer then return { success = false, error = err } end

    local _, target, pairError = pair(source, targetId, false)
    if not target then return { success = false, error = pairError } end

    if not isCuffed(target.source) then
        return { success = false, error = 'they are not restrained' }
    end

    local amount = core:getMoney(target.source, 'cash')
    if not amount or amount < 1 then return { success = false, error = 'they have no cash' } end

    -- Straight to the department, never to the officer. Confiscation that pays
    -- the confiscator is just theft with a badge, and it is the same reason
    -- Config.Fines.officerShare is zero.
    local taken = core:removeMoney(target.source, 'cash', amount,
        ('seizure:%s'):format(officer.citizenid))

    if not taken then return { success = false, error = 'could not seize that' } end

    exports['som-core']:businessTransact(Config.Business, amount,
        ('seizure:%s'):format(target.citizenid))

    TriggerClientEvent('som:client:notify', target.source,
        ('$%s was seized'):format(amount), 'error')

    return { success = true, amount = amount }
end)

-- ---------------------------------------------------------------------------
-- Identity
-- ---------------------------------------------------------------------------

lib.callback.register('som-police:server:checkId', function(source, targetId)
    local officer, err = Police.Officer(source)
    if not officer then return { success = false, error = err } end

    local _, target, pairError = pair(source, targetId, false)
    if not target then return { success = false, error = pairError } end

    local info = target.charinfo

    return {
        success = true,
        name = ('%s %s'):format(info.firstname, info.lastname),
        dob = info.dob,
        gender = info.gender,
        citizenid = target.citizenid,
        -- A fingerprint is generated once and then never changes, which is what
        -- makes it useful: a name can be lied about, this cannot.
        fingerprint = core:getMetadata(target.source, 'fingerprint'),
    }
end)

-- ---------------------------------------------------------------------------
-- Cleanup
--
-- A dropped escorter would otherwise hold their target forever, since the
-- release path runs on the escorter's client.
-- ---------------------------------------------------------------------------

AddEventHandler('som:server:playerUnloaded', function(source)
    local held = escorting[source]
    if held and GetPlayerName(held) then
        TriggerClientEvent('som-police:client:endEscort', held)
    end
    escorting[source] = nil

    for escorter, escorted in pairs(escorting) do
        if escorted == source then
            escorting[escorter] = nil
            TriggerClientEvent('som-police:client:endEscort', escorter)
        end
    end
end)
