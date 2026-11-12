--- Player-run restaurants: ownership, the boss menu, hiring and taking money out. A restaurant is
--- bought from the city with one conditional UPDATE (the claim), then paid for; every failure
--- undoes the claim. Staff are the restaurant's core job, so clocking in is som-duty and wages are
--- the ordinary paycheck from the restaurant's business account. Made by Lennox.

local core = exports['som-core']

Rest = {}

local byId = {}
for _, r in ipairs(Config.restaurants) do byId[r.id] = r end

function Rest.Done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end
local done = Rest.Done

---A whole number inside a range, or nil. Strings that merely look numeric are rejected.
function Rest.Int(value, low, high)
    if type(value) ~= 'number' or value ~= value or value % 1 ~= 0 then return nil end
    if value < low or value > high then return nil end
    return value
end

---The configured restaurant, only while it is switched on and placed.
function Rest.Find(id)
    local r = type(id) == 'string' and byId[id]
    if r and r.enabled and r.coords then return r end
end

function Rest.ById(id) return byId[id] end

function Rest.Near(source, coords)
    local ped = GetPlayerPed(source)
    return coords ~= nil and ped ~= 0 and #(GetEntityCoords(ped) - coords) <= Config.distance
end

---The station of that restaurant, only while it is placed.
function Rest.Station(r, id)
    for _, s in ipairs(r.stations) do
        if s.id == id and s.coords then return s end
    end
end

---The player and restaurant when this player is on duty in it.
function Rest.Staff(source, id)
    local player = core:getPlayer(source)
    local r = player and Rest.Find(id)
    if r and player.job and player.job.name == r.job and player.job.onduty then return player, r end
end

---The owner, whatever job they hold right now: quitting the job must not lock them out of their own money.
function Rest.Boss(source, id)
    local player = core:getPlayer(source)
    local r = player and Rest.Find(id)
    if r and Rest.Owns(player, r) then return player, r end
end

function Rest.Owns(player, r)
    return MySQL.scalar.await('SELECT 1 FROM som_restaurants WHERE restaurant_id = ? AND owner = ?', { r.id, player.citizenid }) ~= nil
end

function Rest.Balance(r)
    return tonumber(MySQL.scalar.await(
        'SELECT a.balance FROM som_businesses b JOIN som_bank_accounts a ON a.id = b.account_id WHERE b.name = ?',
        { r.business })) or 0
end

---Money customers have paid for orders nobody has served yet. The owner cannot withdraw it.
function Rest.Owed(r)
    return tonumber(MySQL.scalar.await(
        "SELECT COALESCE(SUM(total), 0) FROM som_restaurant_orders WHERE restaurant_id = ? AND state = 'paid'", { r.id })) or 0
end

---True when any staff member of this restaurant is on duty right now.
function Rest.Staffed(r)
    return #core:getPlayersByJob(r.job, true) > 0
end

---A whitelisted job (police, news) is never swapped away by a restaurant.
local function lockedJob(player)
    local def = core:getJobs()[player.job and player.job.name]
    return def == nil or def.whitelisted == true
end

CreateThread(function()
    SomPlacements.Apply(Config)

    for _, r in ipairs(Config.restaurants) do
        local account = 'REST-' .. r.id:upper()
        MySQL.insert.await("INSERT IGNORE INTO som_bank_accounts (account_no, label, type) VALUES (?, ?, 'business')", { account, r.label })
        MySQL.insert.await([[
            INSERT IGNORE INTO som_businesses (name, label, account_id, funding, category, treasury_cut)
            SELECT ?, ?, a.id, 'sales', 'private', 0 FROM som_bank_accounts a WHERE a.account_no = ?
        ]], { r.business, r.label, account })
        MySQL.insert.await('INSERT IGNORE INTO som_restaurants (restaurant_id, business) VALUES (?, ?)', { r.id, r.business })

        if r.fridge and r.fridge.coords then
            exports.ox_inventory:RegisterStash('restaurant_' .. r.id, r.label .. ' fridge', r.fridge.slots, r.fridge.weight, false, { [r.job] = 0 }, r.fridge.coords)
        end
    end
end)

lib.callback.register('som-restaurants:server:list', function()
    local out = {}
    for _, r in ipairs(Config.restaurants) do
        if r.enabled and r.coords then
            local stations = {}
            for _, s in ipairs(r.stations) do
                if s.coords then stations[#stations + 1] = { id = s.id, kind = s.kind, coords = s.coords } end
            end
            out[#out + 1] = {
                id = r.id, label = r.label, job = r.job, coords = r.coords, stations = stations,
                fridge = r.fridge and r.fridge.coords, selfServe = r.selfServe and r.selfServe.coords,
            }
        end
    end
    return { restaurants = out, supplier = Config.supplier.enabled and Config.supplier.coords or nil }
end)

lib.callback.register('som-restaurants:server:open', function(source, id)
    local player = core:getPlayer(source)
    local r = player and Rest.Find(id)
    if not r or not Rest.Near(source, r.coords) then return nil end

    local row = MySQL.single.await('SELECT owner FROM som_restaurants WHERE restaurant_id = ?', { r.id })
    if not row then return nil end

    local staff = player.job and player.job.name == r.job and player.job.onduty
    local out = { id = r.id, label = r.label, price = r.price, forSale = row.owner == nil, staff = staff or false, menu = Config.menu }
    if staff then out.queue = Orders.Queue(r) end
    if not staff and not Rest.Staffed(r) then out.fallback = Config.fallback.goods end

    if Rest.Boss(source, id) then
        out.boss = true
        out.away = player.job.name ~= r.job
        out.balance = Rest.Balance(r)
        out.owed = Rest.Owed(r)
        out.takings = tonumber(MySQL.scalar.await([[
            SELECT COALESCE(SUM(t.amount), 0) FROM som_transactions t JOIN som_businesses b ON b.id = t.business_id
            WHERE b.name = ? AND t.direction = 'credit' AND t.reason LIKE 'restaurant:sale:%' AND t.created_at > DATE_SUB(NOW(), INTERVAL 1 DAY)
        ]], { r.business })) or 0
    end
    return out
end)

lib.callback.register('som-restaurants:server:buy', function(source, id)
    local player = core:getPlayer(source)
    local r = player and Rest.Find(id)
    if not r then return done(false, 'not available') end
    if not Rest.Near(source, r.coords) then return done(false, 'you are too far away') end
    if lockedJob(player) then return done(false, 'leave your current job first') end

    local claimed = MySQL.update.await([[
        UPDATE som_restaurants SET owner = ?, bought_price = ?, bought_at = NOW(), withdraw_at = NULL
        WHERE restaurant_id = ? AND owner IS NULL
          AND (SELECT COUNT(*) FROM (SELECT 1 FROM som_restaurants WHERE owner = ?) x) = 0
    ]], { player.citizenid, r.price, r.id, player.citizenid })
    if (claimed or 0) < 1 then return done(false, 'this restaurant is not for sale, or you already own one') end

    local function release() MySQL.update.await('UPDATE som_restaurants SET owner = NULL, bought_price = 0 WHERE restaurant_id = ? AND owner = ?', { r.id, player.citizenid }) end

    if not core:removeMoney(source, 'bank', r.price, 'restaurant:buy:' .. r.id) then
        release()
        return done(false, 'not enough in your bank')
    end
    if not core:taxToTreasury(r.price, 'restaurant:buy:' .. r.id) then
        core:addMoney(source, 'bank', r.price, 'restaurant:buy_refund:' .. r.id)
        release()
        return done(false, 'the sale fell through')
    end
    if not core:setJob(source, r.job, Config.manageGrade) then
        core:treasuryTransact(-r.price, 'restaurant:buy_refund:' .. r.id)
        core:addMoney(source, 'bank', r.price, 'restaurant:buy_refund:' .. r.id)
        release()
        return done(false, 'the sale fell through')
    end
    return done(true)
end)

lib.callback.register('som-restaurants:server:withdraw', function(source, id, amount)
    local player, r = Rest.Boss(source, id)
    if not r then return done(false, 'not available') end
    if not Rest.Near(source, r.coords) then return done(false, 'you are too far away') end

    amount = Rest.Int(amount, 1, Config.withdrawMax)
    if not amount then return done(false, ('you can take $1 to $%d at a time'):format(Config.withdrawMax)) end
    if Rest.Balance(r) - Rest.Owed(r) < amount then return done(false, 'that money is needed for unserved orders') end

    local claimed = MySQL.update.await([[
        UPDATE som_restaurants SET withdraw_at = NOW()
        WHERE restaurant_id = ? AND owner = ? AND (withdraw_at IS NULL OR withdraw_at < DATE_SUB(NOW(), INTERVAL ? MINUTE))
    ]], { r.id, player.citizenid, Config.withdrawCooldownMinutes })
    if (claimed or 0) < 1 then return done(false, 'you took money out recently, try again later') end

    local reason = 'restaurant:withdraw:' .. r.id
    local function release() MySQL.update.await('UPDATE som_restaurants SET withdraw_at = NULL WHERE restaurant_id = ? AND owner = ?', { r.id, player.citizenid }) end

    if not core:businessTransact(r.business, -amount, reason) then release(); return done(false, 'the restaurant does not have that much') end
    if not core:addMoney(source, 'bank', amount, reason) then
        core:businessTransact(r.business, amount, reason .. '_refund')
        release()
        return done(false, 'the transfer fell through')
    end
    return done(true)
end)

-- ---------------------------------------------------------------------------
-- Hiring. The offer lives in memory for a minute; the job itself is core state.
-- ---------------------------------------------------------------------------

local offers = {}

lib.callback.register('som-restaurants:server:hire', function(source, id, target)
    local boss, r = Rest.Boss(source, id)
    if not r then return done(false, 'not available') end

    local them = Rest.Int(target, 1, 65535)
    local hire = them and them ~= source and core:getPlayer(them)
    if not hire then return done(false, 'there is nobody to hire') end

    local pa, pb = GetPlayerPed(source), GetPlayerPed(them)
    if pa == 0 or pb == 0 or #(GetEntityCoords(pa) - GetEntityCoords(pb)) > Config.hireDistance then return done(false, 'they need to be next to you') end
    if hire.job.name == r.job then return done(false, 'they already work here') end
    if lockedJob(hire) then return done(false, 'they have a job they would have to leave first') end
    if #core:getPlayersByJob(r.job, false) >= Config.maxStaff then return done(false, 'you have all the staff you can have') end

    offers[hire.citizenid] = { restaurant = r.id, boss = boss.citizenid, source = source, expires = os.time() + Config.hireExpireSeconds }
    TriggerClientEvent('som-restaurants:client:hireOffer', hire.source, r.label)
    return done(true)
end)

lib.callback.register('som-restaurants:server:answerHire', function(source, accept)
    local player = core:getPlayer(source)
    if not player or type(accept) ~= 'boolean' then return done(false, 'not available') end

    local offer = offers[player.citizenid]
    offers[player.citizenid] = nil
    if not offer or offer.expires < os.time() then return done(false, 'that offer is gone') end
    if not accept then return done(true) end

    local boss = core:getPlayer(offer.source)
    local r = Rest.Find(offer.restaurant)
    if not r or not boss or boss.citizenid ~= offer.boss or not Rest.Owns(boss, r) then return done(false, 'that offer is gone') end
    if lockedJob(player) then return done(false, 'leave your current job first') end

    if not core:setJob(source, r.job, 0) then return done(false, 'the job is no longer open') end
    TriggerClientEvent('som:client:notify', boss.source, 'They took the job', 'success')
    return done(true)
end)

lib.callback.register('som-restaurants:server:fire', function(source, id, target)
    local _, r = Rest.Boss(source, id)
    if not r then return done(false, 'not available') end

    local them = Rest.Int(target, 1, 65535)
    local worker = them and them ~= source and core:getPlayer(them)
    if not worker or worker.job.name ~= r.job or worker.job.grade >= Config.manageGrade then return done(false, 'they do not work here') end

    if not core:setJob(them, 'unemployed', 0) then return done(false, 'could not let them go') end
    return done(true)
end)

lib.callback.register('som-restaurants:server:resume', function(source, id)
    local player, r = Rest.Boss(source, id)
    if not r then return done(false, 'not available') end
    if player.job.name == r.job then return done(false, 'you already work here') end
    if lockedJob(player) then return done(false, 'leave your current job first') end
    if not core:setJob(source, r.job, Config.manageGrade) then return done(false, 'could not change your job') end
    return done(true)
end)

AddEventHandler('som:server:playerUnloaded', function(_, citizenid)
    if type(citizenid) == 'string' then offers[citizenid] = nil end
end)

-- Static menus for the client (recipes, supplier goods, self-serve goods). Display only: the
-- server re-reads every price and recipe from Config when the request arrives.
lib.callback.register('som-restaurants:server:info', function()
    local recipes = {}
    for id, rec in pairs(Config.recipes) do
        local needs = {}
        for item, n in pairs(rec.ingredients) do needs[#needs + 1] = ('%dx %s'):format(n, (item:gsub('^burgershot_', ''))) end
        table.sort(needs)
        recipes[id] = { station = rec.station, label = rec.label, needs = 'Needs ' .. table.concat(needs, ', ') }
    end
    return { recipes = recipes, goods = Config.supplier.goods, fallback = Config.fallback.goods }
end)
