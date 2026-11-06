--- Player-run shops: ownership, the counter view and taking money out. A shop is bought from the
--- city with one conditional UPDATE (the claim), then paid for; every failure undoes the claim.
--- Takings live in the shop's own business account, never in the job businesses. Made by Lennox.

local core = exports['som-core']

Shops = {}

local byId = {}
for _, s in ipairs(Config.shops) do byId[s.id] = s end

function Shops.Done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end
local done = Shops.Done

---A whole number inside a range, or nil. Strings that merely look numeric are rejected.
function Shops.Int(value, low, high)
    if type(value) ~= 'number' or value ~= value or value % 1 ~= 0 then return nil end
    if value < low or value > high then return nil end
    return value
end

---The configured shop, only while it is switched on and placed.
function Shops.Find(id)
    local shop = type(id) == 'string' and byId[id]
    if shop and shop.enabled and shop.coords then return shop end
end

function Shops.Business(shop) return 'shop_' .. shop.id end

function Shops.Near(source, shop)
    local ped = GetPlayerPed(source)
    return ped ~= 0 and #(GetEntityCoords(ped) - shop.coords) <= Config.distance
end

function Shops.Owns(player, shopId)
    return MySQL.scalar.await('SELECT 1 FROM som_shops WHERE shop_id = ? AND owner = ?', { shopId, player.citizenid }) ~= nil
end

---The player and shop when this player owns that shop, else nil.
function Shops.Owned(source, id)
    local player = core:getPlayer(source)
    local shop = player and Shops.Find(id)
    if shop and Shops.Owns(player, shop.id) then return player, shop end
end

function Shops.Balance(shop)
    return tonumber(MySQL.scalar.await(
        'SELECT a.balance FROM som_businesses b JOIN som_bank_accounts a ON a.id = b.account_id WHERE b.name = ?',
        { Shops.Business(shop) })) or 0
end

---Everything the owner sees: balance, the last day's takings, stock and staff.
function Shops.Overview(shop)
    local takings = tonumber(MySQL.scalar.await([[
        SELECT COALESCE(SUM(t.amount), 0) FROM som_transactions t JOIN som_businesses b ON b.id = t.business_id
        WHERE b.name = ? AND t.direction = 'credit' AND t.reason LIKE 'shop:sale:%' AND t.created_at > DATE_SUB(NOW(), INTERVAL 1 DAY)
    ]], { Shops.Business(shop) })) or 0

    return {
        balance = Shops.Balance(shop),
        takings = takings,
        stock = MySQL.query.await('SELECT item, qty, price FROM som_shop_stock WHERE shop_id = ? ORDER BY item', { shop.id }) or {},
        staff = MySQL.query.await([[
            SELECT s.citizenid, s.hourly_pay, c.firstname, c.lastname FROM som_shop_staff s
            JOIN som_characters c ON c.citizenid = s.citizenid WHERE s.shop_id = ? ORDER BY c.lastname
        ]], { shop.id }) or {},
    }
end

local function refund(shop) return math.floor((MySQL.scalar.await('SELECT bought_price FROM som_shops WHERE shop_id = ?', { shop.id }) or 0) * Config.sellBackRate) end

-- ---------------------------------------------------------------------------
-- Setup: every configured shop gets its row, bank account and business row once.
-- ---------------------------------------------------------------------------

CreateThread(function()
    SomPlacements.Apply(Config)

    for _, shop in ipairs(Config.shops) do
        local account = 'SHOP-' .. shop.id:upper()
        MySQL.insert.await("INSERT IGNORE INTO som_bank_accounts (account_no, label, type) VALUES (?, ?, 'business')", { account, shop.label })
        MySQL.insert.await([[
            INSERT IGNORE INTO som_businesses (name, label, account_id, funding, category, treasury_cut)
            SELECT ?, ?, a.id, 'sales', 'private', ? FROM som_bank_accounts a WHERE a.account_no = ?
        ]], { Shops.Business(shop), shop.label, Config.taxRate, account })
        MySQL.insert.await('INSERT IGNORE INTO som_shops (shop_id, business) VALUES (?, ?)', { shop.id, Shops.Business(shop) })
    end
end)

-- ---------------------------------------------------------------------------
-- Counter
-- ---------------------------------------------------------------------------

lib.callback.register('som-shops:server:list', function()
    local out = {}
    for _, shop in ipairs(Config.shops) do
        if shop.enabled and shop.coords then out[#out + 1] = { id = shop.id, label = shop.label, coords = shop.coords } end
    end
    return out
end)

lib.callback.register('som-shops:server:open', function(source, id)
    local player = core:getPlayer(source)
    local shop = player and Shops.Find(id)
    if not shop or not Shops.Near(source, shop) then return nil end

    local row = MySQL.single.await('SELECT owner FROM som_shops WHERE shop_id = ?', { shop.id })
    if not row then return nil end

    local mine = row.owner == player.citizenid
    local out = { id = shop.id, label = shop.label, price = shop.price, owned = row.owner ~= nil, owner = mine, items = Config.items }

    if mine then
        out.overview = Shops.Overview(shop)
        out.refund = refund(shop)
        out.stock = out.overview.stock
    elseif row.owner then
        out.stock = MySQL.query.await('SELECT item, qty, price FROM som_shop_stock WHERE shop_id = ? AND qty > 0 ORDER BY item', { shop.id }) or {}
    end
    return out
end)

-- ---------------------------------------------------------------------------
-- Buying and selling the shop
-- ---------------------------------------------------------------------------

lib.callback.register('som-shops:server:buyShop', function(source, id)
    local player = core:getPlayer(source)
    local shop = player and Shops.Find(id)
    if not shop then return done(false, 'not available') end
    if not Shops.Near(source, shop) then return done(false, 'you are too far away') end

    -- The claim: only an unowned shop, and only for someone who owns no other.
    local claimed = MySQL.update.await([[
        UPDATE som_shops SET owner = ?, bought_price = ?, bought_at = NOW(), withdraw_at = NULL
        WHERE shop_id = ? AND owner IS NULL
          AND (SELECT COUNT(*) FROM (SELECT 1 FROM som_shops WHERE owner = ?) x) = 0
    ]], { player.citizenid, shop.price, shop.id, player.citizenid })
    if (claimed or 0) < 1 then return done(false, 'this shop is not for sale, or you already own one') end

    local function release() MySQL.update.await('UPDATE som_shops SET owner = NULL, bought_price = 0 WHERE shop_id = ? AND owner = ?', { shop.id, player.citizenid }) end

    if not core:removeMoney(source, 'bank', shop.price, 'shop:buy:' .. shop.id) then
        release()
        return done(false, 'not enough in your bank')
    end
    if not core:taxToTreasury(shop.price, 'shop:buy:' .. shop.id) then
        core:addMoney(source, 'bank', shop.price, 'shop:buy_refund:' .. shop.id)
        release()
        return done(false, 'the sale fell through')
    end
    return done(true)
end)

lib.callback.register('som-shops:server:sellShop', function(source, id)
    local player, shop = Shops.Owned(source, id)
    if not shop then return done(false, 'not available') end
    if not Shops.Near(source, shop) then return done(false, 'you are too far away') end

    local busy = MySQL.scalar.await(
        'SELECT (SELECT COUNT(*) FROM som_shop_stock WHERE shop_id = ? AND qty > 0) + (SELECT COUNT(*) FROM som_shop_staff WHERE shop_id = ?)',
        { shop.id, shop.id }) or 0
    if busy > 0 then return done(false, 'take your stock out and let your staff go first') end
    if Shops.Balance(shop) > 0 then return done(false, 'withdraw the shop money first') end

    local pay = refund(shop)
    local claimed = MySQL.update.await('UPDATE som_shops SET owner = NULL, bought_price = 0 WHERE shop_id = ? AND owner = ?', { shop.id, player.citizenid })
    if (claimed or 0) < 1 then return done(false, 'not available') end

    local function restore() MySQL.update.await('UPDATE som_shops SET owner = ?, bought_price = ? WHERE shop_id = ? AND owner IS NULL', { player.citizenid, shop.price, shop.id }) end

    if pay >= 1 then
        if not core:treasuryTransact(-pay, 'shop:sellback:' .. shop.id) then restore(); return done(false, 'the city cannot buy it back right now') end
        if not core:addMoney(source, 'bank', pay, 'shop:sellback:' .. shop.id) then
            core:treasuryTransact(pay, 'shop:sellback_refund:' .. shop.id)
            restore()
            return done(false, 'the sale fell through')
        end
    end
    MySQL.query.await('DELETE FROM som_shop_stock WHERE shop_id = ?', { shop.id })
    return done(true, nil, { paid = pay })
end)

-- ---------------------------------------------------------------------------
-- Taking money out of the shop account
-- ---------------------------------------------------------------------------

lib.callback.register('som-shops:server:withdraw', function(source, id, amount)
    local player, shop = Shops.Owned(source, id)
    if not shop then return done(false, 'not available') end
    if not Shops.Near(source, shop) then return done(false, 'you are too far away') end

    amount = Shops.Int(amount, 1, Config.withdrawMax)
    if not amount then return done(false, ('you can take $1 to $%d at a time'):format(Config.withdrawMax)) end

    local claimed = MySQL.update.await([[
        UPDATE som_shops SET withdraw_at = NOW()
        WHERE shop_id = ? AND owner = ? AND (withdraw_at IS NULL OR withdraw_at < DATE_SUB(NOW(), INTERVAL ? MINUTE))
    ]], { shop.id, player.citizenid, Config.withdrawCooldownMinutes })
    if (claimed or 0) < 1 then return done(false, 'you took money out recently, try again later') end

    local reason = 'shop:withdraw:' .. shop.id
    local function release() MySQL.update.await('UPDATE som_shops SET withdraw_at = NULL WHERE shop_id = ? AND owner = ?', { shop.id, player.citizenid }) end

    if not core:businessTransact(Shops.Business(shop), -amount, reason) then release(); return done(false, 'the shop does not have that much') end
    if not core:addMoney(source, 'bank', amount, reason) then
        core:businessTransact(Shops.Business(shop), amount, reason .. '_refund')
        release()
        return done(false, 'the transfer fell through')
    end
    return done(true)
end)
