-- Impounds and flagged plates.
--
-- The LIVE state of a vehicle is som_vehicles.state, which already has an
-- 'impounded' value. som_police_impound is the history behind it: who seized
-- it, why, what it cost to get back. Two records, one authoritative, because
-- the history has to survive the vehicle being released.

local core = exports['som-core']

---@param entity number
---@return string|nil
local function plateOf(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end

    local plate = GetVehicleNumberPlateText(entity)
    if not plate then return nil end

    -- The parentheses truncate gsub to its first return. Without them this
    -- yields (plate, count) and oxmysql rejects the query for having one
    -- placeholder and two parameters.
    return (plate:gsub('%s+$', ''))
end

-- ---------------------------------------------------------------------------
-- Impound
-- ---------------------------------------------------------------------------

lib.callback.register('som-police:server:impound', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'invalid request' } end

    local officer, err = Police.Officer(source)
    if not officer then return { success = false, error = err } end

    local entity = NetworkGetEntityFromNetworkId(tonumber(data.netId) or 0)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return { success = false, error = 'no such vehicle' }
    end

    -- Measured here. A client claiming to stand next to a car is not evidence
    -- that it does.
    local ped = GetPlayerPed(source)
    if #(GetEntityCoords(ped) - GetEntityCoords(entity)) > 6.0 then
        return { success = false, error = 'you are not at that vehicle' }
    end

    local plate = plateOf(entity)
    if not plate then return { success = false, error = 'no plate' } end

    -- Reason comes from the config list, not from the client, so the record
    -- cannot be filled with anything a player fancies typing.
    local reason = Config.Impound.reasons[tonumber(data.reason) or 0]
    if not reason then return { success = false, error = 'pick a reason' } end

    local owned = MySQL.single.await(
        'SELECT id, citizenid FROM som_vehicles WHERE plate = ?', { plate })

    -- An unowned vehicle is still towed, it just has nobody to charge and
    -- nothing to mark, so it is simply removed.
    if owned then
        MySQL.update.await(
            'UPDATE som_vehicles SET state = ?, garage = ? WHERE id = ?',
            { 'impounded', 'impound', owned.id })
    end

    MySQL.insert.await([[
        INSERT INTO som_police_impound (plate, citizenid, officer_cid, reason, fee)
        VALUES (?, ?, ?, ?, ?)
    ]], { plate, owned and owned.citizenid or nil, officer.citizenid, reason,
          Config.Impound.fee })

    DeleteEntity(entity)

    if owned and owned.citizenid then
        local owner = core:getPlayerByCitizenId(owned.citizenid)
        if owner then
            TriggerClientEvent('som:client:notify', owner.source,
                ('%s has been impounded: %s'):format(plate, reason), 'error', 10000)
        end
    end

    return { success = true, plate = plate }
end)

lib.callback.register('som-police:server:impoundList', function(source)
    local player = core:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end

    local station = Config.Stations.mrpd
    if not Police.NearCoords(source, station.impound.coords, 8.0) then
        return { success = false, error = 'you are not at the impound' }
    end

    -- Only the owner's own vehicles. An officer wanting somebody else's car out
    -- is a roleplay conversation, not a menu.
    local rows = MySQL.query.await([[
        SELECT v.id, v.plate, v.model, i.reason, i.fee, i.id AS impound_id
        FROM som_vehicles v
        JOIN som_police_impound i ON i.plate = v.plate AND i.released_at IS NULL
        WHERE v.citizenid = ? AND v.state = 'impounded'
        ORDER BY i.impounded_at
    ]], { player.citizenid }) or {}

    return {
        success = true,
        vehicles = rows,
        payment = core:paymentOptions(source),
    }
end)

lib.callback.register('som-police:server:releaseImpound', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'invalid request' } end

    local player = core:getPlayer(source)
    if not player then return { success = false, error = 'not loaded' } end

    local station = Config.Stations.mrpd
    if not Police.NearCoords(source, station.impound.coords, 8.0) then
        return { success = false, error = 'you are not at the impound' }
    end

    -- Re-read from the database and re-matched to this player, so the fee and
    -- the ownership both come from the server rather than the request.
    local row = MySQL.single.await([[
        SELECT v.id, v.plate, v.model, i.id AS impound_id, i.fee
        FROM som_vehicles v
        JOIN som_police_impound i ON i.plate = v.plate AND i.released_at IS NULL
        WHERE v.id = ? AND v.citizenid = ? AND v.state = 'impounded'
    ]], { tonumber(data.id) or 0, player.citizenid })

    if not row then return { success = false, error = 'not yours, or not impounded' } end

    if row.fee > 0 then
        local paid, payError = core:payWith(source, data.account, row.fee,
            ('impound:%s'):format(row.plate))

        if not paid then return { success = false, error = payError or 'you cannot afford that' } end

        -- The fee funds the department that towed it.
        core:businessTransact(Config.Business, row.fee, ('impound:%s'):format(row.plate))
    end

    MySQL.update.await(
        'UPDATE som_vehicles SET state = ?, garage = ? WHERE id = ?',
        { 'garaged', 'impound', row.id })

    MySQL.update.await([[
        UPDATE som_police_impound
        SET released_at = CURRENT_TIMESTAMP, released_to = ?
        WHERE id = ?
    ]], { player.citizenid, row.impound_id })

    return { success = true, plate = row.plate, model = row.model }
end)

-- ---------------------------------------------------------------------------
-- Flagged plates
--
-- Rows are cleared rather than deleted, so "this plate was flagged for a month
-- last year" survives the flag being lifted.
-- ---------------------------------------------------------------------------

lib.callback.register('som-police:server:flagPlate', function(source, data)
    if type(data) ~= 'table' then return { success = false, error = 'invalid request' } end

    local officer, err = Police.Officer(source)
    if not officer then return { success = false, error = err } end

    local entity = NetworkGetEntityFromNetworkId(tonumber(data.netId) or 0)
    local plate = plateOf(entity)
    if not plate then return { success = false, error = 'no such vehicle' } end

    local ped = GetPlayerPed(source)
    if #(GetEntityCoords(ped) - GetEntityCoords(entity)) > 6.0 then
        return { success = false, error = 'you are not at that vehicle' }
    end

    local existing = MySQL.scalar.await(
        'SELECT id FROM som_police_plates WHERE plate = ? AND cleared_at IS NULL',
        { plate })

    if existing then
        -- Clearing somebody else's flag is supervisory. Anyone may flag; not
        -- everyone may un-flag, or a flag would mean nothing.
        if officer.job.grade < Config.SupervisorGrade
            and not core:hasPermission(source, 'som.admin') then
            return { success = false, error = 'only command staff may clear a flag' }
        end

        MySQL.update.await([[
            UPDATE som_police_plates
            SET cleared_at = CURRENT_TIMESTAMP, cleared_by = ?
            WHERE id = ?
        ]], { officer.citizenid, existing })

        return { success = true, flagged = false, plate = plate }
    end

    local reason = type(data.reason) == 'string' and data.reason or ''
    if #reason < 3 or #reason > 160 then return { success = false, error = 'a reason is required' } end

    MySQL.insert.await([[
        INSERT INTO som_police_plates (plate, reason, flagged_by) VALUES (?, ?, ?)
    ]], { plate, reason, officer.citizenid })

    return { success = true, flagged = true, plate = plate }
end)

lib.callback.register('som-police:server:checkPlate', function(source, netId)
    local officer, err = Police.Officer(source)
    if not officer then return { success = false, error = err } end

    local entity = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    local plate = plateOf(entity)
    if not plate then return { success = false, error = 'no such vehicle' } end

    local flag = MySQL.single.await([[
        SELECT reason, flagged_at FROM som_police_plates
        WHERE plate = ? AND cleared_at IS NULL
        ORDER BY id DESC LIMIT 1
    ]], { plate })

    local owner = MySQL.single.await([[
        SELECT c.firstname, c.lastname
        FROM som_vehicles v
        JOIN som_characters c ON c.citizenid = v.citizenid
        WHERE v.plate = ?
    ]], { plate })

    return {
        success = true,
        plate = plate,
        owner = owner and ('%s %s'):format(owner.firstname, owner.lastname) or 'Unregistered',
        flagged = flag and flag.reason or nil,
    }
end)

---Whether a plate is currently flagged. Exposed so a future ANPR or dispatch
---feature does not have to know the table.
exports('isPlateFlagged', function(plate)
    if type(plate) ~= 'string' then return false end

    return MySQL.scalar.await(
        'SELECT id FROM som_police_plates WHERE plate = ? AND cleared_at IS NULL',
        { plate }) ~= nil
end)
