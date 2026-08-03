-- The motor pool.
--
-- Department vehicles are NOT owned: they are signed out and handed back. They
-- get no som_vehicles row, so they can never end up in a personal garage or be
-- sold, and a restart simply loses them, which is the correct outcome for a
-- pool car.
--
-- Access is gated on CERTIFICATION, not rank. A Lieutenant with no interceptor
-- certification drives a normal cruiser, because promotion is not a driving
-- test.

local core = exports['som-core']

local fleet = {}   -- plate -> { citizenid, netId, kind, model }

---@return string|nil an unused plate
local function generatePlate()
    for _ = 1, 30 do
        -- Four digits after a four character prefix is the eight character GTA
        -- maximum exactly.
        local plate = ('%s%04d'):format(Config.PlatePrefix, math.random(0, 9999))

        if not fleet[plate] then
            local taken = MySQL.scalar.await(
                'SELECT 1 FROM som_vehicles WHERE plate = ?', { plate })

            if not taken then return plate end
        end
    end

    return nil
end

---@param kind string 'garage' or 'helipad'
---@return table|nil list, table|nil location
local function fleetFor(kind)
    local station = Config.Stations.mrpd

    if kind == 'helipad' then return Config.Vehicles.helipad, station.helipad end
    if kind == 'garage' then return Config.Vehicles.garage, station.garage end

    return nil, nil
end

lib.callback.register('som-police:server:fleet', function(source, kind)
    local officer, err = Police.Officer(source)
    if not officer then return { success = false, error = err } end

    local list, location = fleetFor(kind)
    if not list then return { success = false, error = 'no such motor pool' } end

    if not Police.NearCoords(source, location.coords, 8.0) then
        return { success = false, error = 'you are not there' }
    end

    local certs = Police.GetCerts(officer.citizenid)
    local out = {}

    for _, vehicle in ipairs(list) do
        if not vehicle.cert or certs[vehicle.cert] then
            out[#out + 1] = { model = vehicle.model, label = vehicle.label }
        end
    end

    return { success = true, vehicles = out }
end)

lib.callback.register('som-police:server:takeVehicle', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'invalid request' } end

    local officer, err = Police.Officer(source)
    if not officer then return { success = false, error = err } end

    local list, location = fleetFor(data.kind)
    if not list then return { success = false, error = 'no such motor pool' } end

    if not Police.NearCoords(source, location.coords, 8.0) then
        return { success = false, error = 'you are not there' }
    end

    -- Re-resolved from config by model name, and the certification re-checked,
    -- so the list the client was shown grants nothing.
    local chosen
    for _, vehicle in ipairs(list) do
        if vehicle.model == data.model then chosen = vehicle break end
    end

    if not chosen then return { success = false, error = 'not in this motor pool' } end

    if chosen.cert and not Police.HasCert(officer.citizenid, chosen.cert) then
        return { success = false, error = ('you are not %s certified')
            :format(Config.Certifications[chosen.cert].label) }
    end

    -- One at a time, or the pool empties into a car park.
    for plate, held in pairs(fleet) do
        if held.citizenid == officer.citizenid then
            return { success = false, error = ('you still have %s signed out'):format(plate) }
        end
    end

    local plate = generatePlate()
    if not plate then return { success = false, error = 'could not issue a plate' } end

    local spawn = location.spawn
    local entity = CreateVehicle(joaat(chosen.model), spawn.x, spawn.y, spawn.z, spawn.w, true, true)

    -- The entity is not addressable the instant it is created, so this waits,
    -- but with a deadline rather than forever.
    local timeout = GetGameTimer() + 5000
    while not DoesEntityExist(entity) and GetGameTimer() < timeout do Wait(0) end

    if not DoesEntityExist(entity) then
        return { success = false, error = 'the vehicle could not be brought round' }
    end

    SetVehicleNumberPlateText(entity, plate)

    local netId = NetworkGetNetworkIdFromEntity(entity)

    Entity(entity).state:set('som:policeVehicle', true, true)
    Entity(entity).state:set('som:policePlate', plate, true)

    fleet[plate] = {
        citizenid = officer.citizenid,
        netId = netId,
        kind = data.kind,
        model = chosen.model,
    }

    return { success = true, netId = netId, plate = plate }
end)

lib.callback.register('som-police:server:storeVehicle', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'invalid request' } end

    local officer, err = Police.Officer(source)
    if not officer then return { success = false, error = err } end

    local _, location = fleetFor(data.kind)
    if not location then return { success = false, error = 'no such motor pool' } end

    local entity = NetworkGetEntityFromNetworkId(tonumber(data.netId) or 0)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return { success = false, error = 'no such vehicle' }
    end

    -- Only department vehicles, so this cannot be used to delete a player's
    -- car by pointing at it and calling it a cruiser.
    if not Entity(entity).state['som:policeVehicle'] then
        return { success = false, error = 'that is not a department vehicle' }
    end

    if #(GetEntityCoords(entity) - location.coords) > location.returnRadius then
        return { success = false, error = 'bring it back to the station first' }
    end

    local plate = Entity(entity).state['som:policePlate']
    if plate then fleet[plate] = nil end

    DeleteEntity(entity)
    return { success = true }
end)

-- A signed-out vehicle whose officer has gone is no longer signed out. The
-- entity itself is left alone: deleting a car somebody may be sitting in
-- because its driver disconnected would be worse than leaking a plate.
AddEventHandler('som:server:playerUnloaded', function(source)
    local player = core:getPlayer(source)
    if not player then return end

    for plate, held in pairs(fleet) do
        if held.citizenid == player.citizenid then fleet[plate] = nil end
    end
end)
