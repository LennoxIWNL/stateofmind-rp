--- Plate reader hits. wk_wars2x fires wk:onPlateScanned from the officer's own
--- client, so nothing in it is trusted: the officer, the cruiser, the seat and
--- the scanned vehicle are all checked from the server's view, and the plate is
--- looked up only if a real vehicle near the cruiser carries it. The result goes
--- to that officer and, once per plate, to dispatch. No owner is ever sent.

local core = exports['som-core']

local models = {}
for _, name in ipairs(Config.vehicles) do models[joaat(name)] = true end

local told, called, window, last = {}, {}, {}, {}

---One spelling of a plate for lookups and throttle keys: upper case, no spaces.
local function normalise(plate)
    if type(plate) ~= 'string' then return nil end
    local key = plate:upper():gsub('%s+', '')
    if key == '' or #key > 12 then return nil end
    return key
end

local function prune(map, ttl, now)
    for key, at in pairs(map) do
        if now - at > ttl then map[key] = nil end
    end
end

local function cruiserOf(source)
    local ped = GetPlayerPed(source)
    if ped == 0 then return nil end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or not models[GetEntityModel(vehicle)] then return nil end
    if GetPedInVehicleSeat(vehicle, -1) ~= ped and GetPedInVehicleSeat(vehicle, 0) ~= ped then return nil end
    return vehicle
end

local function scanned(cruiser, key)
    local from = GetEntityCoords(cruiser)
    for _, vehicle in ipairs(GetAllVehicles()) do
        if vehicle ~= cruiser and #(GetEntityCoords(vehicle) - from) <= Config.range
            and normalise(GetVehicleNumberPlateText(vehicle)) == key then
            return vehicle
        end
    end
end

local function reasonsFor(key)
    local row = MySQL.single.await([[
        SELECT
          (SELECT COUNT(*) FROM mdt_bolos WHERE UPPER(REPLACE(plate, ' ', '')) = ? AND jobtype = 'police') AS bolo,
          (SELECT COUNT(*) FROM mdt_vehicleinfo WHERE UPPER(REPLACE(plate, ' ', '')) = ? AND stolen = 1) AS stolen,
          (SELECT COUNT(*) FROM som_police_plates WHERE UPPER(REPLACE(plate, ' ', '')) = ? AND cleared_at IS NULL) AS flagged
    ]], { key, key, key })

    local out = {}
    if row then
        if row.stolen > 0 then out[#out + 1] = 'stolen' end
        if row.bolo > 0 then out[#out + 1] = 'BOLO' end
        if row.flagged > 0 then out[#out + 1] = 'police flag' end
    end
    return out
end

RegisterNetEvent('wk:onPlateScanned', function(cam, plate)
    local source = source
    local now = GetGameTimer()
    if last[source] and now - last[source] < Config.minInterval then return end
    last[source] = now

    local key = normalise(plate)
    if type(cam) ~= 'string' or not Config.cams[cam] or not key then return end

    local player = core:getPlayer(source)
    if not player or not player.job or player.job.name ~= Config.job or not player.job.onduty then return end

    local cruiser = cruiserOf(source)
    if not cruiser then return end

    local target = scanned(cruiser, key)
    if not target then return end

    -- Claimed before the query so a burst of scans of one plate runs it once.
    local mine = source .. ':' .. key
    if told[mine] and now - told[mine] < Config.officerCooldown * 1000 then return end
    told[mine] = now
    prune(told, Config.officerCooldown * 1000, now)

    local reasons = reasonsFor(key)

    -- An expired registration is for the officer only; it never raises a dispatch call.
    local hard = #reasons
    local ok, registration = pcall(function() return exports['som-dmv']:registration(key) end)
    if ok and registration == 'expired' then reasons[#reasons + 1] = 'registration expired' end
    if #reasons == 0 then return end

    TriggerClientEvent('som-anpr:client:hit', source, cam, key, reasons)
    if hard == 0 then return end

    if called[key] and now - called[key] < Config.plateCooldown * 1000 then return end
    prune(window, 60000, now)
    local n = 0
    for _ in pairs(window) do n = n + 1 end
    if n >= Config.callsPerMinute then return end

    called[key] = now
    prune(called, Config.plateCooldown * 1000, now)
    window[key] = now
    exports['som-dispatch']:alert(source, 'flaggedVehicle', {
        coords = GetEntityCoords(target),
        message = ('Flagged vehicle %s: %s'):format(key, table.concat(reasons, ', ')),
        plate = key,
    })
end)

AddEventHandler('playerDropped', function()
    last[source] = nil
    local prefix = source .. ':'
    for key in pairs(told) do
        if key:sub(1, #prefix) == prefix then told[key] = nil end
    end
end)
