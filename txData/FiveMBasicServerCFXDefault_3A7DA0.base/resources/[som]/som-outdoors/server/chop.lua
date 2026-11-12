--- Chop shop. Starting records what is being chopped and when; finishing needs
--- the scrub time to have passed, the vehicle still at the drop-off, and one
--- conditional insert to claim the drop-off cooldown. A plate that belongs to a
--- player is refused. The vehicle is deleted by the server and the parts are
--- items, which sell to the capped scrap buyer.

local core = exports['som-core']
local ox = exports.ox_inventory
local C = Config.chop

local jobs = {}

local function done(ok, err, extra) return Buyer.Done(ok, err, extra) end

local function dropoffByName(name)
    if type(name) ~= 'string' then return nil end
    for _, d in ipairs(C.dropoffs) do
        if d.name == name and d.enabled and d.coords then return d end
    end
end

local function vehicleAt(netId, drop)
    netId = tonumber(netId)
    if not netId or netId % 1 ~= 0 then return nil end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return nil end
    if #(GetEntityCoords(vehicle) - drop.coords) > C.distance then return nil end
    return vehicle
end

local function plateOf(vehicle)
    return (GetVehicleNumberPlateText(vehicle) or ''):gsub('%s+$', ''):upper()
end

lib.callback.register('som-outdoors:server:chopSpots', function()
    local out = {}
    for _, d in ipairs(C.dropoffs) do
        if d.enabled and d.coords then out[#out + 1] = { name = d.name, label = d.label, coords = d.coords, distance = C.distance } end
    end
    return out
end)

lib.callback.register('som-outdoors:server:chopBegin', function(source, dropName, netId)
    local player = core:getPlayer(source)
    if not player then return done(false, 'not available') end

    local drop = dropoffByName(dropName)
    if not drop then return done(false, 'nobody is buying cars here') end

    local vehicle = vehicleAt(netId, drop)
    if not vehicle then return done(false, 'bring the vehicle here') end

    local plate = plateOf(vehicle)
    if plate == '' then return done(false, 'this one has no plate') end
    if MySQL.scalar.await('SELECT 1 FROM som_vehicles WHERE plate = ?', { plate }) then
        return done(false, 'this belongs to someone, they will not touch it')
    end

    jobs[player.citizenid] = { drop = drop.name, netId = tonumber(netId), plate = plate, at = GetGameTimer() }
    exports['som-dispatch']:alert(source, 'chopShop', { coords = drop.coords, message = 'Suspicious vehicle activity' })
    return done(true, nil, { seconds = C.scrubSeconds })
end)

lib.callback.register('som-outdoors:server:chopFinish', function(source)
    local player = core:getPlayer(source)
    if not player then return done(false, 'not available') end

    local job = jobs[player.citizenid]
    jobs[player.citizenid] = nil
    if not job then return done(false, 'you have not started') end
    if GetGameTimer() - job.at < (C.scrubSeconds - 1) * 1000 then return done(false, 'you were too quick') end

    local drop = dropoffByName(job.drop)
    local vehicle = drop and vehicleAt(job.netId, drop)
    if not vehicle or plateOf(vehicle) ~= job.plate then return done(false, 'the vehicle is gone') end

    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - drop.coords) > C.distance then return done(false, 'you are too far away') end

    local id = MySQL.insert.await([[
        INSERT INTO som_chop_log (citizenid, dropoff, plate)
        SELECT ?, ?, ? FROM DUAL
        WHERE NOT EXISTS (SELECT 1 FROM som_chop_log WHERE dropoff = ? AND created_at > DATE_SUB(NOW(), INTERVAL ? MINUTE))
          AND NOT EXISTS (SELECT 1 FROM som_chop_log WHERE plate = ? AND created_at > DATE_SUB(NOW(), INTERVAL ? MINUTE))
    ]], { player.citizenid, drop.name, job.plate, drop.name, C.dropoffCooldown, job.plate, C.plateCooldown })
    if not id or id < 1 then return done(false, 'this place is too hot, or you have done this one') end

    DeleteEntity(vehicle)

    -- One extra of each part for every three scrapping levels.
    local extra = math.floor(Buyer.Level(source, 'scrapping') / 3)
    local got = {}
    for _, part in ipairs(C.parts) do
        local n = math.random(part[2], part[3]) + extra
        if ox:AddItem(source, part[1], n) then got[#got + 1] = { item = part[1], count = n } end
    end
    Buyer.Xp(source, 'scrapping', 30)
    return done(true, nil, { parts = got })
end)

AddEventHandler('som:server:playerUnloaded', function(_, citizenid)
    if type(citizenid) == 'string' then jobs[citizenid] = nil end
end)
