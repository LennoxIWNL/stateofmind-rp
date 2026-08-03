-- Rental server.
--
-- The client asks to rent. It does not say what it costs, what it gets, or
-- where it appears: all three are resolved here from config, and the vehicle
-- is created server side so the client never spawns anything of its own.

local active = {}   -- plate -> { citizenid, model, label, netId, rentedAt }

---@param locationId string
---@param modelName string
---@return table|nil location, table|nil vehicle
local function resolve(locationId, modelName)
    local location = Config.Locations[locationId]
    if not location then return nil end

    for _, vehicle in ipairs(location.vehicles) do
        if vehicle.model == modelName then return location, vehicle end
    end

    return location, nil
end

---@return string an unused 8 character plate
local function generatePlate()
    for _ = 1, 30 do
        local plate = ('%s%04d'):format(Config.PlatePrefix, math.random(0, 9999))

        if not active[plate] then
            local taken = MySQL.scalar.await(
                'SELECT 1 FROM som_vehicles WHERE plate = ?', { plate })

            if not taken then return plate end
        end
    end

    -- Astronomically unlikely, but returning a duplicate would hand somebody
    -- else's car over, so fail instead.
    return nil
end

lib.callback.register('som-rentals:server:catalogue', function(source, locationId)
    local location = Config.Locations[locationId]
    if not location then return nil end

    local player = exports['som-core']:getPlayer(source)
    if not player then return nil end

    return {
        label = location.label,
        deposit = Config.Deposit,
        account = Config.Account,
        balance = player.money[Config.Account] or 0,
        vehicles = location.vehicles,
    }
end)

lib.callback.register('som-rentals:server:rent', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'invalid request' } end

    local player = exports['som-core']:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end

    local location, vehicle = resolve(data.location, data.model)
    if not location or not vehicle then
        return { success = false, error = 'that is not on the forecourt' }
    end

    -- Distance is checked here. A client asking to rent from the airport while
    -- standing in Paleto is not renting from the airport.
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return { success = false, error = 'no ped' } end

    if #(GetEntityCoords(ped) - vector3(location.ped.coords.x, location.ped.coords.y, location.ped.coords.z)) > 10.0 then
        return { success = false, error = 'you are not at the counter' }
    end

    -- One at a time. Otherwise the deposit becomes a rounding error on a fleet.
    for plate, rental in pairs(active) do
        if rental.citizenid == player.citizenid then
            return { success = false, error = ('you still have %s out'):format(plate) }
        end
    end

    local total = vehicle.price + Config.Deposit
    local plate = generatePlate()
    if not plate then return { success = false, error = 'could not issue a plate' } end

    -- Paid before anything is created, so a failure to spawn cannot leave the
    -- player with a vehicle they did not pay for.
    local paid = exports['som-core']:removeMoney(source, Config.Account, total,
        'vehicle-rental')

    if not paid then
        return { success = false, error = ('you need $%d'):format(total) }
    end

    local entity = CreateVehicle(joaat(vehicle.model),
        location.spawn.x, location.spawn.y, location.spawn.z, location.spawn.w, true, true)

    -- Bounded wait: the entity is not addressable the instant it is created.
    local deadline = GetGameTimer() + 5000
    while not DoesEntityExist(entity) and GetGameTimer() < deadline do Wait(0) end

    if not DoesEntityExist(entity) then
        -- Refund in full. The player did nothing wrong.
        exports['som-core']:addMoney(source, Config.Account, total, 'vehicle-rental-refund')
        return { success = false, error = 'the vehicle could not be brought round' }
    end

    SetVehicleNumberPlateText(entity, plate)

    local netId = NetworkGetNetworkIdFromEntity(entity)
    Entity(entity).state:set('som:rentalPlate', plate, true)

    active[plate] = {
        citizenid = player.citizenid,
        model = vehicle.model,
        label = vehicle.label,
        netId = netId,
        rentedAt = os.time(),
    }

    -- The fee is revenue for the business; the deposit is held, not earned, so
    -- it is deliberately not booked as revenue.
    if Config.Business and GetResourceState('som-economy') == 'started' then
        pcall(function()
            exports['som-economy']:recordBusinessRevenue(Config.Business, vehicle.price)
        end)
    end

    local renter = ('%s %s'):format(player.charinfo.firstname, player.charinfo.lastname)
    local rentedAt = os.date('%d/%m/%Y %H:%M')

    -- Metadata is what makes the papers a document rather than a token. ox
    -- renders `description` in the tooltip, so the agreement is readable by
    -- hovering it, which is the whole point of handing it over.
    exports.ox_inventory:AddItem(source, Config.PapersItem, 1, {
        plate = plate,
        model = vehicle.label,
        renter = renter,
        rentedAt = rentedAt,
        location = location.label,
        description = ('**%s**  \nPlate: **%s**  \nRenter: %s  \nRented: %s  \nFrom: %s')
            :format(vehicle.label, plate, renter, rentedAt, location.label),
    })

    return { success = true, plate = plate, netId = netId, label = vehicle.label }
end)

lib.callback.register('som-rentals:server:return', function(source, locationId)
    local location = Config.Locations[locationId]
    if not location then return { success = false, error = 'unknown location' } end

    local player = exports['som-core']:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end

    local plate, rental
    for p, r in pairs(active) do
        if r.citizenid == player.citizenid then plate, rental = p, r break end
    end

    if not plate then return { success = false, error = 'you have nothing out' } end

    -- The vehicle has to actually be here. Returning one from across the map
    -- would make the deposit meaningless.
    local entity = NetworkGetEntityFromNetworkId(rental.netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return { success = false, error = 'that vehicle is not here' }
    end

    if #(GetEntityCoords(entity) - vector3(location.spawn.x, location.spawn.y, location.spawn.z)) > 25.0 then
        return { success = false, error = 'bring it back to the forecourt first' }
    end

    DeleteEntity(entity)
    active[plate] = nil

    -- Papers are taken back with the vehicle, matched on the plate so somebody
    -- else's agreement cannot be handed in.
    local items = exports.ox_inventory:Search(source, 'slots', Config.PapersItem)
    for _, slot in pairs(items or {}) do
        if slot.metadata and slot.metadata.plate == plate then
            exports.ox_inventory:RemoveItem(source, Config.PapersItem, 1, nil, slot.slot)
            break
        end
    end

    local refund = math.floor(Config.Deposit * Config.DepositRefund)
    if refund > 0 then
        exports['som-core']:addMoney(source, Config.Account, refund, 'vehicle-rental-deposit')
    end

    return { success = true, refund = refund }
end)

-- A rental whose renter has left is no longer anybody's problem to return, so
-- the slot is freed. The vehicle itself is left alone deliberately: deleting a
-- car out from under whoever is driving it is worse than an orphan.
AddEventHandler('som:server:playerUnloaded', function(_, citizenid)
    for plate, rental in pairs(active) do
        if rental.citizenid == citizenid then active[plate] = nil end
    end
end)
