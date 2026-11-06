--- Registration and vanity plates. The server reads the owner's cars from the
--- database, checks the desk by position, and for a plate change moves every
--- stored copy of the plate or refuses. The fee is a sink: removeMoney, then the
--- city treasury, nothing is ever paid out.

local core = exports['som-core']
local ox = exports.ox_inventory

local lastAction = {}

local function done(ok, err, extra)
    local r = extra or {}
    r.success, r.error = ok == true, (not ok) and err or nil
    return r
end

local function atDesk(source)
    local d = Config.desk
    if not d.enabled or not d.coords then return false end
    local ped = GetPlayerPed(source)
    return ped ~= 0 and #(GetEntityCoords(ped) - d.coords) <= d.distance
end

local function quiet(source)
    local now = GetGameTimer()
    if lastAction[source] and now - lastAction[source] < Config.registration.cooldownMs then return false end
    lastAction[source] = now
    return true
end

local function truthy(v) return v == true or v == 1 end

---Registration for a vehicle id. A car with no row yet gets the grace period,
---created here on the server the first time anything asks.
---@return number|nil expiresAt unix seconds
local function expiryOf(vehicleId)
    MySQL.update.await(
        'INSERT IGNORE INTO som_vehicle_registration (vehicle_id, expires_at) VALUES (?, DATE_ADD(NOW(), INTERVAL ? DAY))',
        { vehicleId, Config.registration.days })
    local at = MySQL.scalar.await('SELECT UNIX_TIMESTAMP(expires_at) FROM som_vehicle_registration WHERE vehicle_id = ?', { vehicleId })
    return at and tonumber(at) or nil
end

local function nowSeconds()
    return tonumber(MySQL.scalar.await('SELECT UNIX_TIMESTAMP(NOW())')) or os.time()
end

---'valid' or 'expired' for a plate of an owned car, nil for any other plate.
exports('registration', function(plate)
    if type(plate) ~= 'string' then return nil end
    local key = plate:upper():gsub('%s+', '')
    if key == '' then return nil end

    local id = MySQL.scalar.await("SELECT id FROM som_vehicles WHERE REPLACE(UPPER(plate), ' ', '') = ?", { key })
    if not id then return nil end

    local at = expiryOf(id)
    return (at and at > nowSeconds()) and 'valid' or 'expired'
end)

lib.callback.register('som-dmv:server:desk', function()
    local d = Config.desk
    if not d.enabled or not d.coords then return nil end
    return { label = d.label, coords = { x = d.coords.x, y = d.coords.y, z = d.coords.z }, distance = d.distance }
end)

lib.callback.register('som-dmv:server:list', function(source)
    local player = core:getPlayer(source)
    if not player then return done(false, 'not loaded') end
    if not atDesk(source) then return done(false, 'you are not at the counter') end

    local rows = MySQL.query.await([[
        SELECT id, plate, model, state FROM som_vehicles
        WHERE citizenid = ? AND state <> 'impounded' AND owner_group IS NULL AND group_restricted = 0
        ORDER BY id LIMIT 30
    ]], { player.citizenid }) or {}

    local now, out = nowSeconds(), {}
    for _, row in ipairs(rows) do
        local at = expiryOf(row.id)
        out[#out + 1] = { id = row.id, plate = row.plate, model = row.model, state = row.state,
            expired = not at or at <= now, daysLeft = at and math.max(0, math.floor((at - now) / 86400)) or 0 }
    end

    return done(true, nil, { vehicles = out, registrationFee = Config.registration.fee, vanityFee = Config.vanity.fee })
end)

---Takes a fee into the city treasury, or reports why it could not.
---@return boolean ok, string|nil err
local function charge(source, fee, reason)
    local ok, taken = pcall(core.removeMoney, core, source, 'bank', fee, reason)
    if not (ok and taken) then return false, ('you need $%d in the bank'):format(fee) end

    local sunk, banked = pcall(core.taxToTreasury, core, fee, reason)
    if sunk and banked then return true end

    pcall(core.addMoney, core, source, 'bank', fee, reason .. ':refund')
    return false, 'the fee could not be taken, nothing was charged'
end

lib.callback.register('som-dmv:server:renew', function(source, vehicleId)
    local player = core:getPlayer(source)
    if not player then return done(false, 'not loaded') end
    if math.type(vehicleId) ~= 'integer' then return done(false, 'bad request') end
    if not atDesk(source) then return done(false, 'you are not at the counter') end
    if not quiet(source) then return done(false, 'one moment') end

    local owned = MySQL.scalar.await(
        "SELECT id FROM som_vehicles WHERE id = ? AND citizenid = ? AND state <> 'impounded' AND owner_group IS NULL AND group_restricted = 0",
        { vehicleId, player.citizenid })
    if not owned then return done(false, 'that is not your vehicle') end

    local before = expiryOf(vehicleId)
    local days = Config.registration.days

    local claimed = MySQL.update.await([[
        UPDATE som_vehicle_registration
        SET expires_at = DATE_ADD(GREATEST(expires_at, NOW()), INTERVAL ? DAY), renewed_by = ?
        WHERE vehicle_id = ? AND expires_at < DATE_ADD(NOW(), INTERVAL ? DAY)
    ]], { days, player.citizenid, vehicleId, days })
    if (claimed or 0) < 1 then return done(false, 'it is already registered for a while yet') end

    local ok, err = charge(source, Config.registration.fee, 'dmv:registration')
    if not ok then
        MySQL.update.await('UPDATE som_vehicle_registration SET expires_at = FROM_UNIXTIME(?) WHERE vehicle_id = ? AND renewed_by = ?',
            { before, vehicleId, player.citizenid })
        return done(false, err)
    end

    return done(true)
end)

---Upper case, no stray spaces, in range and in the allowed alphabet.
---@return string|nil plate, string|nil err
local function cleanPlate(text)
    if type(text) ~= 'string' then return nil, 'bad request' end
    local plate = text:upper():gsub('^%s+', ''):gsub('%s+$', '')
    local V = Config.vanity

    if #plate < V.minLength or #plate > V.maxLength then
        return nil, ('a plate is %d to %d characters'):format(V.minLength, V.maxLength)
    end
    if not plate:match('^[A-Z0-9 ]+$') or plate:find('  ', 1, true) then
        return nil, 'a plate uses letters, numbers and single spaces'
    end
    for _, pattern in ipairs(V.blocked) do
        if plate:gsub(' ', ''):find(pattern) then return nil, 'that plate is not allowed' end
    end
    return plate
end

---Whether the plate carries a police interest the change would hide.
local function held(plate)
    local key = plate:upper():gsub('%s+', '')
    local row = MySQL.single.await([[
        SELECT
          (SELECT COUNT(*) FROM som_police_plates WHERE REPLACE(UPPER(plate), ' ', '') = ? AND cleared_at IS NULL) AS flagged,
          (SELECT COUNT(*) FROM mdt_bolos WHERE REPLACE(UPPER(plate), ' ', '') = ?) AS bolo,
          (SELECT COUNT(*) FROM mdt_vehicleinfo WHERE REPLACE(UPPER(plate), ' ', '') = ? AND (stolen = 1 OR code5 = 1)) AS wanted
    ]], { key, key, key })
    return row and (row.flagged > 0 or row.bolo > 0 or row.wanted > 0)
end

local function storageHasItems(plate)
    for _, id in ipairs({ 'glove' .. plate, 'trunk' .. plate }) do
        local ok, items = pcall(ox.GetInventoryItems, ox, id)
        if ok and type(items) == 'table' and next(items) then return true end
    end
    return false
end

lib.callback.register('som-dmv:server:changePlate', function(source, vehicleId, text)
    local player = core:getPlayer(source)
    if not player then return done(false, 'not loaded') end
    if math.type(vehicleId) ~= 'integer' then return done(false, 'bad request') end
    if not atDesk(source) then return done(false, 'you are not at the counter') end
    if not quiet(source) then return done(false, 'one moment') end

    local plate, bad = cleanPlate(text)
    if not plate then return done(false, bad) end

    local recent = MySQL.scalar.await(
        'SELECT COUNT(*) FROM som_dmv_plate_log WHERE citizenid = ? AND created_at > DATE_SUB(NOW(), INTERVAL ? MINUTE)',
        { player.citizenid, Config.vanity.cooldownMinutes })
    if (recent or 0) > 0 then return done(false, ('you can change a plate once every %d minutes'):format(Config.vanity.cooldownMinutes)) end

    local row = MySQL.single.await([[
        SELECT id, plate, state FROM som_vehicles
        WHERE id = ? AND citizenid = ? AND owner_group IS NULL AND group_restricted = 0 AND assigned_to IS NULL
    ]], { vehicleId, player.citizenid })
    if not row then return done(false, 'that is not your vehicle') end
    if row.state ~= 'garaged' then return done(false, 'put it in a garage first') end
    if row.plate == plate then return done(false, 'it already has that plate') end
    if held(row.plate) then return done(false, 'the police have a hold on that vehicle') end
    if storageHasItems(row.plate) then return done(false, 'empty the glovebox and boot first') end

    -- The unique key on plate makes a taken plate fail here, atomically.
    local ok, claimed = pcall(MySQL.update.await, [[
        UPDATE som_vehicles SET plate = ?
        WHERE id = ? AND citizenid = ? AND plate = ? AND state = 'garaged' AND owner_group IS NULL AND group_restricted = 0 AND assigned_to IS NULL
    ]], { plate, row.id, player.citizenid, row.plate })
    if not ok then return done(false, 'that plate is taken') end
    if (claimed or 0) < 1 then return done(false, 'the vehicle is no longer available') end

    local function undo()
        pcall(MySQL.update.await, 'UPDATE mdt_vehicleinfo SET plate = ? WHERE plate = ?', { row.plate, plate })
        MySQL.update.await('UPDATE som_vehicles SET plate = ? WHERE id = ? AND plate = ?', { row.plate, row.id, plate })
    end

    local moved, err = pcall(MySQL.update.await, 'UPDATE mdt_vehicleinfo SET plate = ? WHERE plate = ?', { plate, row.plate })
    if not moved then
        print(('[som-dmv] could not move the MDT record for %s: %s'):format(row.plate, tostring(err)))
        undo()
        return done(false, 'the plate could not be changed, nothing was charged')
    end

    local paid, payErr = charge(source, Config.vanity.fee, 'dmv:plate')
    if not paid then
        undo()
        return done(false, payErr)
    end

    local logged, why = pcall(MySQL.insert.await,
        'INSERT INTO som_dmv_plate_log (vehicle_id, citizenid, old_plate, new_plate) VALUES (?, ?, ?, ?)',
        { row.id, player.citizenid, row.plate, plate })
    if not logged then print(('[som-dmv] plate log failed for %s: %s'):format(plate, tostring(why))) end

    return done(true, nil, { plate = plate })
end)

AddEventHandler('playerDropped', function() lastAction[source] = nil end)

CreateThread(function() SomPlacements.Apply(Config) end)
