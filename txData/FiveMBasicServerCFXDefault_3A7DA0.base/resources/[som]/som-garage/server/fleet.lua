-- Department fleets: seeding the pool, buying a personal one, and selling it
-- back when somebody leaves the job.
--
-- A pool is REAL ROWS. Five cruisers means five rows with five plates, so
-- taking the fifth leaves none until one comes back. A config-list spawner
-- cannot express that, which is the whole reason the pool is not one.

local core = exports['som-core']

Fleet = {}

-- ---------------------------------------------------------------------------
-- Seeding
--
-- Runs once at boot and tops the pool up to the configured count. Raising
-- `count` in config is therefore the only thing needed to grow a fleet, and
-- lowering it leaves the extra cars alone rather than deleting vehicles that
-- may be out on the road.
-- ---------------------------------------------------------------------------

local function seedFleet(fleetId, fleet)
    for _, entry in ipairs(fleet.vehicles) do
        local existing = MySQL.scalar.await([[
            SELECT COUNT(*) FROM som_vehicles
            WHERE owner_group = ? AND model = ? AND citizenid IS NULL
        ]], { fleetId, entry.model }) or 0

        local missing = (entry.count or 0) - existing

        for _ = 1, missing do
            local created, err = Vehicles.Create({
                ownerGroup = fleetId,
                groupRestricted = true,
                model = entry.model,
                garage = fleetId,
                platePrefix = fleet.platePrefix,
            })

            if not created then
                print(('[som-garage] could not seed %s for %s: %s')
                    :format(entry.model, fleetId, err or 'unknown'))
                break
            end
        end

        if missing > 0 then
            print(('[som-garage] %s fleet: added %d x %s'):format(fleetId, missing, entry.model))
        end
    end
end

---Pool rows whose model is no longer configured are deleted.
---
---seedFleet only ever counts up, so taking a model out of Config.Fleets left its
---rows behind: still holding plates, still listed at the garage, and no longer
---spawnable once the pack that supplied the model goes. Emptying the config list
---without this does not empty the motor pool.
---
---Driven by what is in the DATABASE rather than by looping Config.Fleets, so
---deleting an entire fleet block retires its rows too instead of orphaning them
---where no loop would ever reach.
---
---Only pool rows are touched. `owner_group IS NOT NULL AND citizenid IS NULL` is
---exactly the set seedFleet creates: Vehicles.Create is the only path in the
---codebase that mints a row, and its only other caller sets citizenid. A vehicle
---an officer bought is never retired here, whatever happens to the config.
local function retireFleet()
    local rows = MySQL.query.await([[
        SELECT id, model, owner_group FROM som_vehicles
        WHERE owner_group IS NOT NULL AND citizenid IS NULL
    ]]) or {}

    if #rows == 0 then return end

    local configured = {}

    for fleetId, fleet in pairs(Config.Fleets) do
        configured[fleetId] = {}
        for _, entry in ipairs(fleet.vehicles or {}) do
            configured[fleetId][entry.model] = true
        end
    end

    local doomed, counts = {}, {}

    for _, row in ipairs(rows) do
        local fleet = configured[row.owner_group]

        if not fleet or not fleet[row.model] then
            doomed[#doomed + 1] = row.id
            counts[row.model] = (counts[row.model] or 0) + 1
        end
    end

    if #doomed == 0 then return end

    -- One statement, so an emptied fleet cannot end up half retired if the
    -- server dies mid-boot.
    local placeholders = ('?,'):rep(#doomed - 1) .. '?'

    MySQL.update.await(
        ('DELETE FROM som_vehicles WHERE id IN (%s)'):format(placeholders), doomed)

    for model, count in pairs(counts) do
        print(('[som-garage] retired %d x %s: no longer in any fleet.')
            :format(count, model))
    end
end

---Every vehicle marked `out` is put back.
---
---A restart destroys every spawned entity, so a row still marked `out`
---describes a car that no longer exists anywhere. Left alone it is
---unretrievable FOREVER: the garage refuses it as already out, and nothing ever
---clears the flag. That is a permanent loss of somebody's vehicle, and it
---applies to bought and personal cars just as much as to the pool.
---
---Pool cars go home to their own garage. Personal cars keep whichever garage
---they were last stored at, so nobody's car teleports across the map because
---the server rebooted.
local function reclaimVehicles()
    local reclaimed = MySQL.update.await([[
        UPDATE som_vehicles
        SET state = 'garaged', assigned_to = NULL, taken_at = NULL,
            garage = CASE WHEN owner_group IS NOT NULL AND citizenid IS NULL
                          THEN owner_group ELSE garage END
        WHERE state = 'out'
    ]]) or 0

    if reclaimed > 0 then
        print(('[som-garage] reclaimed %d vehicle(s) left out by the last shutdown.')
            :format(reclaimed))
    end
end

CreateThread(function()
    -- After som-core has confirmed the schema is present.
    Wait(3000)

    local ok = pcall(function()
        MySQL.scalar.await('SELECT 1 FROM som_vehicles LIMIT 1')
    end)

    if not ok then
        print('[som-garage] som_vehicles is missing. Import setup.sql.')
        return
    end

    -- Before seeding, so a fleet that looks short only because its cars are
    -- flagged out does not get topped up with duplicates.
    reclaimVehicles()

    -- Then retire, so a car deleted here cannot be one somebody is driving:
    -- reclaim has just marked every row garaged, and no entity exists yet at
    -- this point in the boot.
    retireFleet()

    for fleetId, fleet in pairs(Config.Fleets) do
        seedFleet(fleetId, fleet)
    end
end)

exports('reclaimVehicles', reclaimVehicles)
exports('retireFleet', retireFleet)

-- ---------------------------------------------------------------------------
-- Buying
-- ---------------------------------------------------------------------------

lib.callback.register('som-garage:server:buyFleetVehicle', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'invalid request' } end

    local player = core:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end

    local garage = Config.Garages[data.garage]
    if not garage or not garage.fleet then return { success = false, error = 'unknown garage' } end

    if not Garage.CanAccess(player, garage) then
        return { success = false, error = 'you do not have access here' }
    end

    local ped = GetPlayerPed(source)
    if #(GetEntityCoords(ped) - garage.coords) > 12.0 then
        return { success = false, error = 'you are not at that garage' }
    end

    -- Re-resolved from config by model name. The client sends a name and
    -- nothing else: not a price, not whether it is for sale.
    local entry = Garage.FleetEntry(garage, data.model)
    if not entry then return { success = false, error = 'not in this fleet' } end
    if not entry.price then return { success = false, error = 'that is not for sale' } end

    if entry.cert then
        if GetResourceState('som-police') ~= 'started'
            or not exports['som-police']:hasCert(player.citizenid, entry.cert) then
            return { success = false, error = 'you are not certified for that' }
        end
    end

    -- One personal department vehicle per model, or an officer buys a garage
    -- full of cruisers and the pool becomes irrelevant.
    local owned = MySQL.scalar.await([[
        SELECT COUNT(*) FROM som_vehicles
        WHERE citizenid = ? AND owner_group = ? AND model = ?
    ]], { player.citizenid, garage.business, data.model }) or 0

    if owned > 0 then
        return { success = false, error = 'you already own one of those' }
    end

    local paid, payError = core:payWith(source, data.account, entry.price,
        ('vehicle:%s'):format(data.model))

    if not paid then return { success = false, error = payError or 'you cannot afford that' } end

    local created, createError = Vehicles.Create({
        citizenid = player.citizenid,
        ownerGroup = garage.business,
        groupRestricted = Config.Purchase.groupRestricted,
        model = data.model,
        garage = data.garage,
        price = entry.price,
        platePrefix = Config.Fleets[garage.fleet].platePrefix,
    })

    if not created then
        -- Refunded in full. Failing to write a row is not the buyer's fault.
        core:addMoney(source, data.account, entry.price, 'vehicle-refund')
        return { success = false, error = createError or 'could not register it' }
    end

    -- The department is paid for the vehicle it just handed over, so buying one
    -- funds the fleet rather than deleting money.
    if garage.business then
        core:businessTransact(garage.business, entry.price,
            ('vehicle-sale:%s'):format(created.plate))
    end

    return { success = true, plate = created.plate }
end)

-- ---------------------------------------------------------------------------
-- Leaving the job
--
-- A job-restricted vehicle is sold back automatically. It cannot be driven
-- anywhere but the department garage, so leaving the department would otherwise
-- turn a $50,000 purchase into a row nobody can ever reach.
-- ---------------------------------------------------------------------------

---@param citizenid string
---@param newJob string
local function refundRestricted(citizenid, newJob)
    -- The buyback only happens while the owner is ONLINE, because som-core has
    -- no exported path to credit an offline character outright: TransferToCitizen
    -- needs a payer to debit, and there is no department "player" to be one.
    --
    -- Skipping is safe and recoverable. The vehicle stays in the database, still
    -- restricted and still unreachable until they rejoin the department, which
    -- is a far better failure than deleting a $50,000 car and not paying for it.
    local player = core:getPlayerByCitizenId(citizenid)
    if not player then return end

    local rows = MySQL.query.await([[
        SELECT v.id, v.plate, v.model, v.owner_group, v.purchase_price
        FROM som_vehicles v
        WHERE v.citizenid = ? AND v.group_restricted = 1 AND v.owner_group IS NOT NULL
    ]], { citizenid }) or {}

    if #rows == 0 then return end

    local jobs = core:getJobs() or {}
    local stillEntitled = jobs[newJob] and jobs[newJob].business or nil

    for _, row in ipairs(rows) do
        -- Moving between two jobs that share a department is not leaving it.
        if row.owner_group ~= stillEntitled then
            local refund = math.floor((tonumber(row.purchase_price) or 0) * Config.RefundRate)

            MySQL.update.await('DELETE FROM som_vehicles WHERE id = ?', { row.id })

            if refund > 0 then
                -- The department buys it back, so the money leaves the account
                -- that was credited when it was sold. If the department cannot
                -- cover it the officer is still paid: the vehicle has already
                -- gone, and stranding somebody's money because a business is
                -- broke would be the worse outcome.
                pcall(function()
                    exports['som-economy']:businessSpend(row.owner_group, refund,
                        ('vehicle-buyback:%s'):format(row.plate))
                end)

                core:addMoney(player.source, 'bank', refund,
                    ('vehicle-buyback:%s'):format(row.plate))
            end

            TriggerClientEvent('som:client:notify', player.source,
                ('Your %s was sold back for $%s'):format(row.model, refund),
                'inform', 10000)
        end
    end
end

AddEventHandler('som:server:jobChanged', function(source, citizenid, job)
    if not citizenid or not job then return end

    -- Deferred a tick: the job change is what triggered this, and reading the
    -- player mid-transition has caught stale state before.
    SetTimeout(500, function()
        refundRestricted(citizenid, job.name)
    end)
end)

exports('refundRestricted', refundRestricted)
