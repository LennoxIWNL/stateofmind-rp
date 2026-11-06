--- The meter. Distance and waiting time are measured here from the vehicle's
--- position; the client sends only which button was pressed. The passenger
--- agrees to the fare before anything is taken.

local core = exports['som-core']

local models = {}
for _, name in ipairs(Config.vehicles) do models[joaat(name)] = true end

local commissionRate = math.min(Config.commission, 0.5)
local transfer = { counterparty = Config.business, flow = 'transfer' }

local sessions = {} -- driver source -> { entity, citizenid, last, trip }
local offers = {}   -- passenger citizenid -> { driver, driverCid, fare, commission, meters, expires }

local function done(ok, err, extra)
    local r = extra or {}
    r.success, r.error = ok == true, (not ok) and err or nil
    return r
end

local function driverOf(source)
    local player = core:getPlayer(source)
    if not player or player.job.name ~= Config.job or not player.job.onduty then return nil end
    return player
end

local function cabOf(source)
    local ped = GetPlayerPed(source)
    if ped == 0 then return nil end
    local entity = GetVehiclePedIsIn(ped, false)
    if entity == 0 or not models[GetEntityModel(entity)] or GetPedInVehicleSeat(entity, -1) ~= ped then return nil end
    return entity
end

---@return number|nil source, table|nil player a rider in a rear seat
local function riderIn(entity, driver)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local ped = GetPlayerPed(src)
        if src ~= driver and ped ~= 0 and GetVehiclePedIsIn(ped, false) == entity then
            local player = core:getPlayer(src)
            if player then return src, player end
        end
    end
end

local function fareOf(trip)
    local fare = Config.baseFare + Config.perKm * trip.meters / 1000 + Config.perWaitMinute * trip.wait / 60
    return math.min(math.floor(fare), Config.maxFare)
end

local function endSession(source)
    local s = sessions[source]
    if not s then return end
    sessions[source] = nil
    TriggerClientEvent('som-taxi:client:meter', source, nil)
    if s.trip then TriggerClientEvent('som-taxi:client:meter', s.trip.source, nil) end
end

local function tick(source, s)
    if not driverOf(source) or cabOf(source) ~= s.entity then return endSession(source) end

    local at = GetEntityCoords(s.entity)
    local trip = s.trip
    local rider = riderIn(s.entity, source)

    if rider and (not trip or trip.source ~= rider) then
        -- A new rider replaces an earlier one who was never charged.
        local player = core:getPlayer(rider)
        s.trip = { source = rider, citizenid = player.citizenid, meters = 0, wait = 0 }
        trip = s.trip
    end

    if trip and rider == trip.source then
        local step = #(at - s.last)
        if step > 0.5 and step <= Config.maxStepMeters then trip.meters = trip.meters + step end
        if GetEntitySpeed(s.entity) < 1.0 then trip.wait = trip.wait + 1 end
        trip.shown = (trip.shown or 0) + 1
        if trip.shown % 3 == 0 then
            local line = ('Fare $%d'):format(fareOf(trip))
            TriggerClientEvent('som-taxi:client:meter', source, line)
            TriggerClientEvent('som-taxi:client:meter', trip.source, line)
        end
    end

    s.last = at
end

CreateThread(function()
    while true do
        Wait(1000)
        local ids = {}
        for source in pairs(sessions) do ids[#ids + 1] = source end
        for _, source in ipairs(ids) do
            local s = sessions[source]
            if s then
                local ok, err = pcall(tick, source, s)
                if not ok then print(('[som-taxi] meter failed for %s: %s'):format(source, err)) end
            end
        end
    end
end)

lib.callback.register('som-taxi:server:act', function(source, action)
    local driver = driverOf(source)
    if not driver then return done(false, 'you are not on duty as a cab driver') end
    if action ~= 'start' and action ~= 'charge' and action ~= 'stop' then return done(false, 'bad request') end

    local s = sessions[source]

    if action == 'start' then
        local entity = cabOf(source)
        if not entity then return done(false, 'sit in the driver seat of a cab') end
        if s then return done(false, 'the meter is already running') end
        sessions[source] = { entity = entity, last = GetEntityCoords(entity) }
        return done(true)
    end

    if not s then return done(false, 'the meter is not running') end

    if action == 'stop' then
        endSession(source)
        return done(true)
    end

    local trip = s.trip
    if not trip then return done(false, 'nobody has ridden yet') end
    local pending = offers[trip.citizenid]
    if pending and pending.expires > GetGameTimer() then return done(false, 'they are already deciding') end

    local rider = core:getPlayer(trip.source)
    if not rider or rider.citizenid ~= trip.citizenid then
        s.trip = nil
        return done(false, 'the passenger is gone')
    end
    if rider.citizenid == driver.citizenid then s.trip = nil return done(false, 'you cannot charge yourself') end
    if trip.meters < Config.minMeters then
        s.trip = nil
        return done(false, 'too short to charge, the ride is free')
    end

    local a, b = GetPlayerPed(source), GetPlayerPed(trip.source)
    if b == 0 or #(GetEntityCoords(a) - GetEntityCoords(b)) > Config.passengerDistance then
        s.trip = nil
        return done(false, 'the passenger is gone')
    end

    local fare = fareOf(trip)
    offers[rider.citizenid] = {
        driver = source, driverCid = driver.citizenid, trip = trip, fare = fare,
        meters = math.floor(trip.meters), expires = GetGameTimer() + Config.offerSeconds * 1000,
    }
    s.trip = nil
    TriggerClientEvent('som-taxi:client:fare', trip.source, fare, math.floor(trip.meters))
    return done(true)
end)

---Debit first, credit second, and a failed credit hands the money back.
local function spend(fn, ...)
    local ok, res = pcall(fn, ...)
    return ok and res == true
end

local function commissionFor(driverCid, wanted)
    local earned = MySQL.scalar.await([[
        SELECT COALESCE(SUM(amount), 0) FROM som_transactions
        WHERE citizenid = ? AND reason = 'taxi:commission' AND direction = 'credit'
          AND created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)
    ]], { driverCid }) or 0
    return math.max(0, math.min(wanted, Config.hourlyCommissionCap - earned))
end

lib.callback.register('som-taxi:server:answer', function(source, accepted)
    local rider = core:getPlayer(source)
    local offer = rider and offers[rider.citizenid]
    if not offer then return done(false, 'no fare to pay') end
    offers[rider.citizenid] = nil

    if accepted ~= true then
        if core:getPlayer(offer.driver) then TriggerClientEvent('som:client:notify', offer.driver, 'They refused to pay the fare', 'error') end
        return done(false, 'declined')
    end
    if offer.expires < GetGameTimer() then return done(false, 'the fare request ran out') end

    local driver = driverOf(offer.driver)
    if not driver or driver.citizenid ~= offer.driverCid or driver.citizenid == rider.citizenid then
        return done(false, 'the driver is no longer on duty')
    end

    if not spend(core.removeMoney, core, source, 'bank', offer.fare, 'taxi:fare', transfer) then
        return done(false, ('you need $%d in the bank'):format(offer.fare))
    end
    if not spend(core.businessTransact, core, Config.business, offer.fare, 'taxi:fare') then
        pcall(core.addMoney, core, source, 'bank', offer.fare, 'taxi:fare:refund', transfer)
        return done(false, 'the fare could not be paid, nothing was charged')
    end

    local pay = math.min(commissionFor(driver.citizenid, math.floor(offer.fare * commissionRate)), offer.fare - 1)
    local paid = 0
    if pay >= 1 and spend(core.businessTransact, core, Config.business, -pay, 'taxi:commission') then
        local ok, credited = pcall(core.addMoney, core, offer.driver, 'bank', pay, 'taxi:commission', transfer)
        if ok and credited then paid = pay else pcall(core.businessTransact, core, Config.business, pay, 'taxi:commission:undo') end
    end

    TriggerClientEvent('som:client:notify', offer.driver, ('Fare paid: $%d, your share $%d'):format(offer.fare, paid), 'success')
    return done(true, nil, { fare = offer.fare, paid = paid })
end)

AddEventHandler('som:server:playerUnloaded', function(source, citizenid)
    endSession(source)
    offers[citizenid] = nil
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for source in pairs(sessions) do endSession(source) end
end)

local function registerRadial()
    if GetResourceState('som-radial') ~= 'started' then return end
    exports['som-radial']:register({
        id = 'taxi.meter', section = 'job', label = 'Cab meter', icon = 'car', order = 20,
        export = 'som-taxi.meter', job = Config.job, duty = true,
    })
end

AddEventHandler('onResourceStart', function(name)
    if name == 'som-radial' or name == GetCurrentResourceName() then registerRadial() end
end)
