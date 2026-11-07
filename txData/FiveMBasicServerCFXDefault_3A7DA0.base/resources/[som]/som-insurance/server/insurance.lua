--- Vehicle insurance. A policy belongs to one vehicle id and the person who holds the car, is paid
--- weekly from their bank into the insurer's business account, and covers a car that has been taken
--- out of the garage and is gone from the world: destroyed, or stolen and not found. A claim puts the
--- car back in the garage for an excess fee. The insurer pays the replacement cost to the treasury and
--- can never pay more than it holds. Cover, lapse, waiting time and claim limits are all read from
--- database timestamps; every step that moves money or the vehicle is a conditional UPDATE with an undo.
--- There is no risk score. Made by Lennox.

local core = exports['som-core']
local phone = exports['som-phone']

Insurance = {}

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

local function normalise(plate)
    return (tostring(plate or ''):upper():gsub('%s+', ''))
end

local function whole(value, low, high)
    if type(value) ~= 'number' or value ~= value or value % 1 ~= 0 then return nil end
    if value < low or value > high then return nil end
    return value
end

---What a vehicle costs to insure and to claim on, from its recorded price.
function Insurance.Prices(price)
    price = tonumber(price) or 0
    return {
        premium = math.max(Config.minPremium, math.floor(price * Config.premiumRate)),
        excess = math.max(Config.minExcess, math.floor(price * Config.excessRate)),
        cost = math.floor(price * Config.replacementShare),
    }
end

-- ---------------------------------------------------------------------------
-- Setup: the insurer's account and business row, once.
-- ---------------------------------------------------------------------------

CreateThread(function()
    MySQL.insert.await("INSERT IGNORE INTO som_bank_accounts (account_no, label, type) VALUES ('BUS-INSURER', ?, 'business')", { Config.label })
    MySQL.insert.await([[
        INSERT IGNORE INTO som_businesses (name, label, account_id, funding, category, treasury_cut)
        SELECT ?, ?, a.id, 'sales', 'private', 0 FROM som_bank_accounts a WHERE a.account_no = 'BUS-INSURER'
    ]], { Config.business, Config.label })
end)

-- ---------------------------------------------------------------------------
-- Buying and renewing cover
-- ---------------------------------------------------------------------------

---The premium: owner's bank to the insurer. Returns false if either step fails (the owner is refunded).
local function charge(player, amount, reason)
    if not core:removeMoney(player.source, 'bank', amount, reason) then return false end
    if not core:businessTransact(Config.business, amount, reason) then
        core:addMoney(player.source, 'bank', amount, reason .. ':refund')
        return false
    end
    return true
end

local function insure(player, vehicleId)
    local row = MySQL.single.await(
        'SELECT id, purchase_price FROM som_vehicles WHERE id = ? AND citizenid = ? AND owner_group IS NULL AND group_restricted = 0',
        { vehicleId, player.citizenid })
    if not row then return done(false, 'that is not your vehicle') end
    if (tonumber(row.purchase_price) or 0) < Config.minValue then return done(false, 'this vehicle cannot be insured') end

    local premium = Insurance.Prices(row.purchase_price).premium

    -- The claim: a new policy, or one that was cancelled, lapsed or belonged to a previous holder.
    -- Affected rows, not an insert id: the key is the vehicle id, so an insert id is 0 even when the row is new.
    local claimed = MySQL.update.await(
        "INSERT IGNORE INTO som_vehicle_insurance (vehicle_id, citizenid, paid_until, covered_from, status) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ? DAY), NOW(), 'active')",
        { vehicleId, player.citizenid, Config.periodDays })
    if (claimed or 0) < 1 then
        local reopened = MySQL.update.await([[
            UPDATE som_vehicle_insurance SET citizenid = ?, status = 'active', paid_until = DATE_ADD(NOW(), INTERVAL ? DAY), covered_from = NOW()
            WHERE vehicle_id = ? AND (status = 'cancelled' OR paid_until <= NOW() OR citizenid <> ?)
        ]], { player.citizenid, Config.periodDays, vehicleId, player.citizenid })
        if (reopened or 0) < 1 then return done(false, 'this vehicle is already insured') end
    end

    if not charge(player, premium, 'insurance:premium:' .. vehicleId) then
        MySQL.update.await("UPDATE som_vehicle_insurance SET status = 'cancelled', paid_until = NOW() WHERE vehicle_id = ? AND citizenid = ?", { vehicleId, player.citizenid })
        return done(false, 'not enough in your bank')
    end
    return done(true)
end

---One renewal. Claims paid_until first (continuing cover) or restarts cover after a lapse, then charges;
---a failed charge puts both dates back.
function Insurance.Renew(policy, owner)
    local premium = Insurance.Prices(policy.price).premium

    local claimed
    if policy.lapsed == 1 or policy.lapsed == true then
        claimed = MySQL.update.await([[
            UPDATE som_vehicle_insurance SET paid_until = DATE_ADD(NOW(), INTERVAL ? DAY), covered_from = NOW()
            WHERE vehicle_id = ? AND status = 'active' AND UNIX_TIMESTAMP(paid_until) = ? AND paid_until <= NOW()
        ]], { Config.periodDays, policy.vehicle_id, policy.due })
    else
        claimed = MySQL.update.await([[
            UPDATE som_vehicle_insurance SET paid_until = DATE_ADD(paid_until, INTERVAL ? DAY)
            WHERE vehicle_id = ? AND status = 'active' AND UNIX_TIMESTAMP(paid_until) = ? AND paid_until > NOW()
        ]], { Config.periodDays, policy.vehicle_id, policy.due })
    end
    if (claimed or 0) < 1 then return end

    if not charge(owner, premium, 'insurance:premium:' .. policy.vehicle_id) then
        MySQL.update.await(
            "UPDATE som_vehicle_insurance SET paid_until = FROM_UNIXTIME(?), covered_from = FROM_UNIXTIME(?) WHERE vehicle_id = ? AND status = 'active'",
            { policy.due, policy.from_at, policy.vehicle_id })
    end
end

function Insurance.Sweep(citizenid)
    local due = MySQL.query.await([[
        SELECT i.vehicle_id, i.citizenid, UNIX_TIMESTAMP(i.paid_until) AS due, UNIX_TIMESTAMP(i.covered_from) AS from_at,
               (i.paid_until <= NOW()) AS lapsed, v.citizenid AS holder, v.purchase_price AS price
        FROM som_vehicle_insurance i LEFT JOIN som_vehicles v ON v.id = i.vehicle_id
        WHERE i.status = 'active' AND i.paid_until <= DATE_ADD(NOW(), INTERVAL ? HOUR) AND i.citizenid LIKE ?
    ]], { Config.renewAheadHours, citizenid or '%' }) or {}

    for _, policy in ipairs(due) do
        -- Sold, or gone: the policy ends and nothing more is charged.
        if policy.holder ~= policy.citizenid or (tonumber(policy.price) or 0) < Config.minValue then
            MySQL.update.await("UPDATE som_vehicle_insurance SET status = 'cancelled' WHERE vehicle_id = ? AND status = 'active'", { policy.vehicle_id })
        else
            local owner = core:getPlayerByCitizenId(policy.citizenid)
            if owner then
                local ok, err = pcall(Insurance.Renew, policy, owner)
                if not ok then print(('[som-insurance] renewal %s failed: %s'):format(tostring(policy.vehicle_id), tostring(err))) end
            end
        end
    end
end

CreateThread(function()
    Wait(5000)

    if not pcall(MySQL.scalar.await, 'SELECT 1 FROM som_vehicle_insurance LIMIT 1') then
        print('[som-insurance] som_vehicle_insurance is missing. Import setup.sql.')
        return
    end

    while true do
        Wait(Config.sweepMinutes * 60000)
        local ok, err = pcall(Insurance.Sweep)
        if not ok then print(('[som-insurance] sweep failed: %s'):format(tostring(err))) end
    end
end)

AddEventHandler('som:server:playerLoaded', function(_, citizenid)
    if type(citizenid) ~= 'string' then return end
    SetTimeout(10000, function() pcall(Insurance.Sweep, citizenid) end)
end)

-- ---------------------------------------------------------------------------
-- Claims
-- ---------------------------------------------------------------------------

---Whether anything in the world carries this plate. A wreck counts unless Config says otherwise.
local function worldHas(key)
    for _, vehicle in ipairs(GetAllVehicles()) do
        if normalise(GetVehicleNumberPlateText(vehicle)) == key then
            if Config.wreckBlocksClaim or (tonumber(GetVehicleEngineHealth(vehicle)) or 0) > 0 then return true end
        end
    end
    return false
end

---Whether the plate carries a police interest (same sources as som-dmv's plate change check).
local function held(key)
    local row = MySQL.single.await([[
        SELECT
          (SELECT COUNT(*) FROM som_police_plates WHERE REPLACE(UPPER(plate), ' ', '') = ? AND cleared_at IS NULL) AS flagged,
          (SELECT COUNT(*) FROM mdt_bolos WHERE REPLACE(UPPER(plate), ' ', '') = ?) AS bolo,
          (SELECT COUNT(*) FROM mdt_vehicleinfo WHERE REPLACE(UPPER(plate), ' ', '') = ? AND (stolen = 1 OR code5 = 1)) AS wanted
    ]], { key, key, key })
    return row and (row.flagged > 0 or row.bolo > 0 or row.wanted > 0)
end

local function claim(player, vehicleId)
    -- Everything time based is decided in this one read, from the database clock.
    local v = MySQL.single.await([[
        SELECT v.id, v.plate, v.state, v.purchase_price, UNIX_TIMESTAMP(v.taken_at) AS taken,
               (v.taken_at IS NOT NULL AND v.taken_at <= DATE_SUB(NOW(), INTERVAL ? MINUTE)) AS out_long,
               (i.status = 'active' AND i.paid_until > NOW() AND i.covered_from <= DATE_SUB(NOW(), INTERVAL ? DAY)
                AND i.citizenid = v.citizenid AND v.taken_at >= i.covered_from) AS covered
        FROM som_vehicles v JOIN som_vehicle_insurance i ON i.vehicle_id = v.id
        WHERE v.id = ? AND v.citizenid = ? AND v.owner_group IS NULL AND v.group_restricted = 0
    ]], { Config.minOutMinutes, Config.waitingDays, vehicleId, player.citizenid })

    if not v then return done(false, 'that vehicle is not insured') end
    if v.state ~= 'out' then return done(false, 'only a vehicle that is out can be claimed') end
    if v.covered ~= 1 and v.covered ~= true then return done(false, 'this vehicle is not covered for this') end
    if v.out_long ~= 1 and v.out_long ~= true then return done(false, 'it has not been gone long enough') end

    local key = normalise(v.plate)
    if held(key) then return done(false, 'this vehicle cannot be claimed right now') end
    if worldHas(key) then return done(false, 'this vehicle is still out there') end

    local prices = Insurance.Prices(v.purchase_price)

    -- The claim: the limits per vehicle and per owner, counted from the database in the INSERT itself.
    local id = MySQL.insert.await([[
        INSERT INTO som_insurance_claims (vehicle_id, citizenid, cost, excess)
        SELECT ?, ?, ?, ? FROM DUAL
        WHERE (SELECT COUNT(*) FROM som_insurance_claims WHERE vehicle_id = ? AND status <> 'cancelled' AND created_at > DATE_SUB(NOW(), INTERVAL ? DAY)) < ?
          AND (SELECT COUNT(*) FROM som_insurance_claims WHERE citizenid = ? AND status <> 'cancelled' AND created_at > DATE_SUB(NOW(), INTERVAL ? DAY)) < ?
    ]], { vehicleId, player.citizenid, prices.cost, prices.excess,
          vehicleId, Config.claimWindowDays, Config.claimsPerVehicle,
          player.citizenid, Config.claimWindowDays, Config.claimsPerOwner })
    if not id or id < 1 then return done(false, 'you have claimed too often recently') end

    local reason = 'insurance:claim:' .. id
    local undo = {}
    local function fail(text)
        for i = #undo, 1, -1 do undo[i]() end
        MySQL.update.await("UPDATE som_insurance_claims SET status = 'cancelled' WHERE id = ?", { id })
        return done(false, text)
    end

    -- Excess in.
    if not core:removeMoney(player.source, 'bank', prices.excess, reason .. ':excess') then return fail('not enough in your bank for the excess') end
    undo[#undo + 1] = function() core:addMoney(player.source, 'bank', prices.excess, reason .. ':excess_refund') end

    if not core:businessTransact(Config.business, prices.excess, reason .. ':excess') then return fail('the insurer could not take the excess') end
    undo[#undo + 1] = function() core:businessTransact(Config.business, -prices.excess, reason .. ':excess_refund') end

    -- Insurer to treasury: refused if the insurer does not hold it.
    if not core:businessTransact(Config.business, -prices.cost, reason .. ':payout') then return fail('the insurer cannot pay out right now') end
    undo[#undo + 1] = function() core:businessTransact(Config.business, prices.cost, reason .. ':payout_refund') end

    if not core:taxToTreasury(prices.cost, reason .. ':replacement') then return fail('the payout fell through') end
    undo[#undo + 1] = function()
        if not core:treasuryTransact(-prices.cost, reason .. ':payout_refund') then print(('[som-insurance] claim %s: could not take the replacement cost back from the treasury'):format(id)) end
    end

    -- The car is back, only if it is still this person's and still out since the time that was checked.
    local restored = MySQL.update.await([[
        UPDATE som_vehicles SET state = 'garaged', assigned_to = NULL, taken_at = NULL, body = 1000, engine = 1000, fuel = 100
        WHERE id = ? AND citizenid = ? AND state = 'out' AND UNIX_TIMESTAMP(taken_at) = ?
    ]], { vehicleId, player.citizenid, v.taken })
    if (restored or 0) < 1 then return fail('the vehicle changed hands or was found, nothing was paid') end

    MySQL.update.await("UPDATE som_insurance_claims SET status = 'paid' WHERE id = ?", { id })
    return done(true, nil, { plate = v.plate })
end

-- ---------------------------------------------------------------------------
-- Phone
-- ---------------------------------------------------------------------------

local actions = {}

function actions.view(_, _, player)
    local rows = {}

    for _, v in ipairs(MySQL.query.await([[
        SELECT v.id, v.plate, v.model, v.state, v.purchase_price,
               GREATEST(0, UNIX_TIMESTAMP(i.paid_until) - UNIX_TIMESTAMP(NOW())) AS secs,
               (i.status = 'active' AND i.paid_until > NOW() AND i.citizenid = v.citizenid) AS covered
        FROM som_vehicles v LEFT JOIN som_vehicle_insurance i ON i.vehicle_id = v.id
        WHERE v.citizenid = ? AND v.owner_group IS NULL AND v.group_restricted = 0 ORDER BY v.model, v.plate LIMIT 30
    ]], { player.citizenid }) or {}) do
        local title = ('%s %s'):format(v.model, v.plate)
        local p = Insurance.Prices(v.purchase_price)

        if v.covered == 1 or v.covered == true then
            rows[#rows + 1] = { title = title, sub = ('Covered for %d more days, tap to cancel'):format(math.ceil(v.secs / 86400)), action = 'cancel', payload = { vehicle = v.id } }
            if v.state == 'out' then
                rows[#rows + 1] = { title = ('Claim for %s'):format(v.plate), sub = ('If it is gone. Excess $%d'):format(p.excess), action = 'claim', payload = { vehicle = v.id } }
            end
        elseif (tonumber(v.purchase_price) or 0) >= Config.minValue then
            rows[#rows + 1] = { title = title, sub = ('Not insured, $%d every %d days, tap to insure'):format(p.premium, Config.periodDays), action = 'insure', payload = { vehicle = v.id } }
        end
    end

    return done(true, nil, { view = { sections = { { title = 'Your vehicles', rows = rows } }, empty = 'You have no vehicles to insure' } })
end

local function vehicleArg(payload) return whole(payload.vehicle, 1, 2147483647) end

function actions.insure(source, payload, player)
    local id = vehicleArg(payload)
    if not id then return done(false, 'bad request') end
    local result = insure(player, id)
    TriggerClientEvent('som-phone:client:refresh', source)
    return result
end

function actions.cancel(source, payload, player)
    local id = vehicleArg(payload)
    if not id then return done(false, 'bad request') end

    local changed = MySQL.update.await("UPDATE som_vehicle_insurance SET status = 'cancelled' WHERE vehicle_id = ? AND citizenid = ? AND status = 'active'", { id, player.citizenid })
    TriggerClientEvent('som-phone:client:refresh', source)
    if (changed or 0) < 1 then return done(false, 'that vehicle is not insured') end
    return done(true)
end

function actions.claim(source, payload, player)
    local id = vehicleArg(payload)
    if not id then return done(false, 'bad request') end

    local ok, result = pcall(claim, player, id)
    if not ok then
        print(('[som-insurance] claim failed: %s'):format(tostring(result)))
        return done(false, 'the claim fell through')
    end
    TriggerClientEvent('som-phone:client:refresh', source)
    return result
end

phone:registerApp({
    id = 'insurance', label = 'Insurance', icon = 'receipt', colour = '#32ade6', order = 69,
    reads = { view = true },
    handler = function(source, action, payload)
        local fn = type(action) == 'string' and actions[action]
        local player = core:getPlayer(source)
        if not fn or not player then return done(false, 'not available') end
        return fn(source, type(payload) == 'table' and payload or {}, player)
    end,
})

-- ---------------------------------------------------------------------------
-- Information for police tools, and staff funding
-- ---------------------------------------------------------------------------

---Read only, like som-dmv's registration: whether a plate has valid cover, and until when (unix seconds).
exports('insured', function(plate)
    local key = normalise(plate)
    if key == '' then return nil end

    local row = MySQL.single.await([[
        SELECT UNIX_TIMESTAMP(i.paid_until) AS expires,
               (i.status = 'active' AND i.paid_until > NOW() AND i.citizenid = v.citizenid) AS covered
        FROM som_vehicles v JOIN som_vehicle_insurance i ON i.vehicle_id = v.id
        WHERE REPLACE(UPPER(v.plate), ' ', '') = ?
    ]], { key })
    if not row then return { insured = false } end
    return { insured = row.covered == 1 or row.covered == true, expires = tonumber(row.expires) }
end)

---Moves money from the treasury to the insurer on purpose. Both sides are ledgered by the money bus.
lib.addCommand('insurerfund', {
    help = 'Move money from the treasury to the insurer (staff)',
    params = { { name = 'amount', type = 'number', help = 'Dollars' } },
}, function(source, args)
    local function say(text) if source == 0 then print('[som-insurance] ' .. text) else TriggerClientEvent('som:client:notify', source, text, 'inform') end end

    if source ~= 0 and not core:hasPermission(source, 'som.admin') then return say('no permission') end

    local amount = whole(args.amount, 1, Config.fundMax)
    if not amount then return say(('give an amount from 1 to %d'):format(Config.fundMax)) end

    if not core:treasuryTransact(-amount, 'insurance:fund') then return say('the treasury does not have that much') end
    if not core:businessTransact(Config.business, amount, 'insurance:fund') then
        core:treasuryTransact(amount, 'insurance:fund_refund')
        return say('the insurer account could not take it, nothing moved')
    end
    say(('moved $%d to the insurer'):format(amount))
end)
