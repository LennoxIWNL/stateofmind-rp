--- Mechanic repairs. The server decides everything that matters: the job and
--- duty, the distance, whether the vehicle is actually damaged (it reads the
--- health itself), the parts and the bill. The client only runs the progress
--- bar and then applies the repaired health the server told it to, because
--- setting vehicle health is a client native.

local core = exports['som-core']
local ox = exports.ox_inventory

local lastRepair = {}

local function xp(src, track, n)
    if GetResourceState('som-progress') == 'started' then exports['som-progress']:addXp(src, track, n) end
end

local function level(src, track)
    if GetResourceState('som-progress') == 'started' then return exports['som-progress']:getLevel(src, track) or 1 end
    return 1
end

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

local function mechanic(source)
    local player = core:getPlayer(source)
    if not player or not player.job or player.job.name ~= Config.job or not player.job.onduty then return nil end
    return player
end

Mechanic = { OnDuty = mechanic }

local function vehicleNear(source, netId)
    netId = tonumber(netId)
    if not netId or netId % 1 ~= 0 then return nil end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return nil end

    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > Config.distance then return nil end
    return vehicle, netId
end

local function health(vehicle, kind)
    return kind == 'engine' and GetVehicleEngineHealth(vehicle) or GetVehicleBodyHealth(vehicle)
end

local function driver(vehicle)
    local ped = GetPedInVehicleSeat(vehicle, -1)
    if not ped or ped == 0 then return nil end
    for _, id in ipairs(GetPlayers()) do
        if GetPlayerPed(tonumber(id)) == ped then return core:getPlayer(tonumber(id)) end
    end
end

lib.callback.register('som-mechanic:server:inspect', function(source, netId)
    if not mechanic(source) then return done(false, 'you are not on duty as a mechanic') end
    local vehicle = vehicleNear(source, netId)
    if not vehicle then return done(false, 'no vehicle here') end

    local out = {}
    for kind, r in pairs(Config.repairs) do
        out[#out + 1] = { kind = kind, label = r.label, seconds = r.seconds, price = r.price, damaged = health(vehicle, kind) < r.below }
    end
    table.sort(out, function(a, b) return a.kind < b.kind end)
    return done(true, nil, { repairs = out })
end)

lib.callback.register('som-mechanic:server:repair', function(source, netId, kind)
    local player = mechanic(source)
    if not player then return done(false, 'you are not on duty as a mechanic') end

    local r = type(kind) == 'string' and Config.repairs[kind]
    if not r then return done(false, 'bad request') end

    if r.minLevel and level(source, 'mechanic') < r.minLevel then
        return done(false, ('you need mechanic level %d for this'):format(r.minLevel))
    end

    local vehicle, id = vehicleNear(source, netId)
    if not vehicle then return done(false, 'no vehicle here') end
    if health(vehicle, kind) >= r.below then return done(false, 'nothing to fix') end

    local now = GetGameTimer()
    if lastRepair[id] and now - lastRepair[id] < Config.cooldownSeconds * 1000 then return done(false, 'give it a moment') end

    if not ox:RemoveItem(source, r.item, r.count) then return done(false, ('you need %d %s'):format(r.count, r.item)) end
    lastRepair[id] = now

    local customer = driver(vehicle)
    if customer and customer.citizenid ~= player.citizenid then
        exports['som-phone']:billCitizen(customer.citizenid, Config.business, r.price, r.label, {
            issuerCitizenid = player.citizenid,
            fromName = ('%s %s'):format(player.charinfo.firstname, player.charinfo.lastname),
        })
    end

    TriggerClientEvent('som-mechanic:client:apply', source, id, kind, r.to)
    xp(source, 'mechanic', 15)
    return done(true)
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then lastRepair = {} end
end)
