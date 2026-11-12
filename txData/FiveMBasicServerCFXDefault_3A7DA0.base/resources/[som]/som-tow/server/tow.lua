--- Tow tickets. An officer asks for a tow instead of an instant impound; an on duty tow driver takes
--- the ticket from the phone, drives the car to the impound lot and delivers it there. The lot's
--- impound itself is som-police's (one authority); this resource only decides who brought the car and pays
--- them from the department. A ticket nobody takes becomes an instant impound, so police are never stuck.
--- Every step is a conditional UPDATE on the ticket state, and time comes from the database. Made by Lennox.

local core = exports['som-core']
local phone = exports['som-phone']

Tow = {}

-- The sweep's "reopened this run is never cancelled this run" rule needs the hold to be shorter than the wait.
if Config.claimMinutes >= Config.ticketMinutes then
    Config.claimMinutes = math.max(1, Config.ticketMinutes - 1)
    print(('[som-tow] claimMinutes must be below ticketMinutes, using %d'):format(Config.claimMinutes))
end

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

local function whole(value, low, high)
    if type(value) ~= 'number' or value ~= value or value % 1 ~= 0 then return nil end
    if value < low or value > high then return nil end
    return value
end

local function normalise(plate)
    return (tostring(plate or ''):upper():gsub('%s+', ''))
end

local function driverOnDuty(player)
    return player and player.job and player.job.name == Config.job and player.job.onduty == true
end

---Called by som-police instead of an instant impound. Returns true when a ticket was raised; false means
---nobody can take it and the caller impounds at once.
---@param plate string
---@param reason number index into som-police Config.Impound.reasons
---@param officerCid string
---@param coords table|nil
function Tow.Request(plate, reason, officerCid, coords)
    if type(plate) ~= 'string' or plate == '' or #plate > 12 then return false end
    if not whole(reason, 1, 255) or type(officerCid) ~= 'string' then return false end
    if #(core:getPlayersByJob(Config.job, true) or {}) == 0 then return false end

    local x, y, z = 0.0, 0.0, 0.0
    if type(coords) == 'table' then x, y, z = coords.x or x, coords.y or y, coords.z or z end

    -- One open ticket per plate, decided in the insert.
    local id = MySQL.insert.await([[
        INSERT INTO som_tow_tickets (plate, reason, requested_by, x, y, z)
        SELECT ?, ?, ?, ?, ?, ? FROM DUAL
        WHERE NOT EXISTS (SELECT 1 FROM som_tow_tickets WHERE plate = ? AND state IN ('open', 'claimed'))
    ]], { plate, reason, officerCid, x, y, z, plate })
    if not id or id < 1 then
        -- Already waiting for a tow is still a tow: the officer must not fall back to an instant impound.
        return MySQL.scalar.await("SELECT 1 FROM som_tow_tickets WHERE plate = ? AND state IN ('open', 'claimed') LIMIT 1", { plate }) ~= nil
    end

    for _, driver in ipairs(core:getPlayersByJob(Config.job, true) or {}) do
        TriggerClientEvent('som:client:notify', driver.source, ('Tow request for %s. Check your phone.'):format(plate), 'inform')
    end
    return true
end
exports('request', Tow.Request)

---An officer impounded the car at once, so its ticket is no longer needed.
exports('cancelPlate', function(plate)
    if type(plate) ~= 'string' then return end
    MySQL.update.await("UPDATE som_tow_tickets SET state = 'cancelled' WHERE plate = ? AND state IN ('open', 'claimed')", { plate })
end)

-- ---------------------------------------------------------------------------
-- Driver actions
-- ---------------------------------------------------------------------------

---False when the impound failed or raised, so every caller can undo its own step.
local function seal(t, car)
    local ok, sealed = pcall(function() return exports['som-police']:impoundPlate(t.plate, t.requested_by, t.reason, car) end)
    if not ok then print(('[som-tow] impound of %s failed: %s'):format(t.plate, tostring(sealed))) end
    return ok and sealed == true
end

local function ticketOf(id) return MySQL.single.await('SELECT * FROM som_tow_tickets WHERE id = ?', { id }) end

---The vehicle in the world with this plate, if any.
local function findCar(key)
    for _, entity in ipairs(GetAllVehicles()) do
        if normalise(GetVehicleNumberPlateText(entity)) == key then return entity end
    end
end

local actions = {}

function actions.view(_, _, player)
    local rows = {}
    local reasons = exports['som-police']:impoundReasons() or {}

    for _, t in ipairs(MySQL.query.await("SELECT id, plate, reason, driver FROM som_tow_tickets WHERE state = 'claimed' AND driver = ? ORDER BY id", { player.citizenid }) or {}) do
        rows[#rows + 1] = { title = ('Deliver %s'):format(t.plate), sub = 'Drive it to the impound lot, then tap', action = 'deliver', payload = { ticket = t.id } }
    end
    for _, t in ipairs(MySQL.query.await("SELECT id, plate, reason, TIMESTAMPDIFF(MINUTE, created_at, NOW()) AS age FROM som_tow_tickets WHERE state = 'open' ORDER BY id LIMIT 20") or {}) do
        rows[#rows + 1] = { title = ('Tow %s'):format(t.plate), sub = ('%s, waiting %d min, $%d'):format(reasons[t.reason] or 'Impound', t.age or 0, Config.fee), action = 'claim', payload = { ticket = t.id } }
    end

    return done(true, nil, { view = { sections = { { title = 'Tow tickets', rows = rows } }, empty = 'No cars waiting' } })
end

function actions.claim(source, payload, player)
    local id = whole(payload.ticket, 1, 2147483647)
    if not id then return done(false, 'bad request') end

    -- shortcut: counted before the claim, so two quick taps can pass the cap by one, upgrade if drivers hoard tickets.
    local held = MySQL.scalar.await("SELECT COUNT(*) FROM som_tow_tickets WHERE state = 'claimed' AND driver = ?", { player.citizenid })
    if (tonumber(held) or 0) >= Config.maxClaimed then return done(false, 'you already have enough tickets') end

    local claimed = MySQL.update.await("UPDATE som_tow_tickets SET state = 'claimed', driver = ?, claimed_at = NOW() WHERE id = ? AND state = 'open'", { player.citizenid, id })
    if (claimed or 0) < 1 then return done(false, 'someone else took it') end

    local t = ticketOf(id)
    if t then TriggerClientEvent('som-tow:client:waypoint', source, t.x, t.y) end
    TriggerClientEvent('som-phone:client:refresh', source)
    return done(true)
end

function actions.deliver(source, payload, player)
    local id = whole(payload.ticket, 1, 2147483647)
    if not id then return done(false, 'bad request') end

    local t = ticketOf(id)
    if not t or t.state ~= 'claimed' or t.driver ~= player.citizenid then return done(false, 'that is not your ticket') end

    local car = findCar(normalise(t.plate))
    if not car then return done(false, 'the car is not here') end

    local ped = GetPlayerPed(source)
    local lot = Config.yard
    if not ped or ped == 0 or #(GetEntityCoords(car) - lot.coords) > lot.radius then return done(false, 'the car is not at the impound lot') end
    if #(GetEntityCoords(ped) - GetEntityCoords(car)) > Config.driverRadius then return done(false, 'you have to be with the car') end

    -- Paid or not is decided before the ticket closes, so this delivery is not counted against itself.
    local recent = MySQL.scalar.await("SELECT COUNT(*) FROM som_tow_tickets WHERE driver = ? AND state = 'done' AND paid > 0 AND done_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)", { player.citizenid })
    -- Only a player's car is paid for: its owner's release fee goes back to the department, so the fee
    -- cannot be farmed by towing street cars nobody will collect.
    local owned = MySQL.scalar.await('SELECT 1 FROM som_vehicles WHERE plate = ?', { t.plate }) ~= nil
    local pay = owned and (tonumber(recent) or 0) < Config.maxPaidPerHour

    local closed = MySQL.update.await("UPDATE som_tow_tickets SET state = 'done', done_at = NOW() WHERE id = ? AND state = 'claimed' AND driver = ?", { id, player.citizenid })
    if (closed or 0) < 1 then return done(false, 'that is not your ticket') end

    if not seal(t, car) then
        MySQL.update.await("UPDATE som_tow_tickets SET state = 'claimed', done_at = NULL WHERE id = ? AND state = 'done' AND driver = ?", { id, player.citizenid })
        return done(false, 'the impound could not be recorded')
    end

    local paid = 0
    if pay then
        local reason = ('tow:%d'):format(id)
        if core:businessTransact(Config.payer, -Config.fee, reason) then
            local ok, credited = pcall(function() return core:addMoney(source, 'bank', Config.fee, reason) end)
            if ok and credited then
                paid = Config.fee
            else
                if not ok then print(('[som-tow] paying %s for %s failed: %s'):format(player.citizenid, reason, tostring(credited))) end
                if not core:businessTransact(Config.payer, Config.fee, reason .. ':refund') then
                    print(('[som-tow] %s could not be refunded to %s, put %d back by hand'):format(reason, Config.payer, Config.fee))
                end
            end
        else
            TriggerClientEvent('som:client:notify', source, 'The department could not pay for this tow right now', 'error')
        end
    elseif owned then
        TriggerClientEvent('som:client:notify', source, 'You reached the paid tow limit for this hour, so this one is unpaid', 'inform')
    end
    MySQL.update.await('UPDATE som_tow_tickets SET paid = ? WHERE id = ?', { paid, id })

    TriggerClientEvent('som-phone:client:refresh', source)
    return done(true, nil, { paid = paid })
end

phone:registerApp({
    id = 'tow', label = 'Tow', icon = 'receipt', colour = '#ff9f0a', order = 71,
    reads = { view = true },
    handler = function(source, action, payload)
        local player = core:getPlayer(source)
        local fn = type(action) == 'string' and actions[action]
        if not fn or not player or not driverOnDuty(player) then return done(false, 'not available') end
        return fn(source, type(payload) == 'table' and payload or {}, player)
    end,
})

-- ---------------------------------------------------------------------------
-- Timeouts
-- ---------------------------------------------------------------------------

function Tow.Sweep()
    -- A reopened ticket keeps claimed_at, so "last touched" is one clock for both steps below: a ticket
    -- reopened here is young by it and cannot be cancelled in the same run, and a held ticket is never stale.
    MySQL.update.await("UPDATE som_tow_tickets SET state = 'open', driver = NULL WHERE state = 'claimed' AND claimed_at < DATE_SUB(NOW(), INTERVAL ? MINUTE)", { Config.claimMinutes })

    local stale = MySQL.query.await("SELECT id, plate, reason, requested_by, x, y, z FROM som_tow_tickets WHERE state = 'open' AND COALESCE(claimed_at, created_at) < DATE_SUB(NOW(), INTERVAL ? MINUTE)", { Config.ticketMinutes }) or {}
    for _, t in ipairs(stale) do
        local taken = MySQL.update.await("UPDATE som_tow_tickets SET state = 'cancelled' WHERE id = ? AND state = 'open'", { t.id })
        if (taken or 0) > 0 then
            -- Only a car still where the officer asked for the tow is impounded; one that moved or left is not ours to remove.
            local car = findCar(normalise(t.plate))
            if car and #(GetEntityCoords(car) - vec3(t.x, t.y, t.z)) <= Config.sweepRadius and not seal(t, car) then
                MySQL.update.await("UPDATE som_tow_tickets SET state = 'open' WHERE id = ? AND state = 'cancelled'", { t.id })
            end
        end
    end
end

CreateThread(function()
    Wait(5000)
    if not pcall(MySQL.scalar.await, 'SELECT 1 FROM som_tow_tickets LIMIT 1') then
        print('[som-tow] som_tow_tickets is missing. Import setup.sql.')
        return
    end
    while true do
        Wait(Config.sweepSeconds * 1000)
        local ok, err = pcall(Tow.Sweep)
        if not ok then print(('[som-tow] sweep failed: %s'):format(tostring(err))) end
    end
end)
