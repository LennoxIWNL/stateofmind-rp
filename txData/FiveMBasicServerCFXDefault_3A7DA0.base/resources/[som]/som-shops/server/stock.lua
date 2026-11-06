--- Stock and sales. The owner moves items from their bag into the shop and sets a price inside the
--- configured range; a customer buys at the price stored in the database. Every step that can fail
--- has an undo, and the stock row is claimed before any money moves. Made by Lennox.

local core = exports['som-core']
local ox = exports.ox_inventory
local done = Shops.Done

lib.callback.register('som-shops:server:stock', function(source, id, item, count, price)
    local player, shop = Shops.Owned(source, id)
    if not shop then return done(false, 'not available') end
    if not Shops.Near(source, shop) then return done(false, 'you are too far away') end

    local limits = type(item) == 'string' and Config.items[item]
    if not limits then return done(false, 'the shop cannot sell that') end
    count = Shops.Int(count, 1, Config.maxStockPerItem)
    price = Shops.Int(price, limits.min, limits.max)
    if not count then return done(false, ('you can stock 1 to %d at a time'):format(Config.maxStockPerItem)) end
    if not price then return done(false, ('the price must be between $%d and $%d'):format(limits.min, limits.max)) end

    local kinds = MySQL.scalar.await('SELECT COUNT(*) FROM som_shop_stock WHERE shop_id = ? AND item <> ? AND qty > 0', { shop.id, item }) or 0
    if kinds >= Config.maxItemsPerShop then return done(false, 'the shop cannot hold more kinds of item') end

    if not ox:RemoveItem(source, item, count) then return done(false, 'you do not have that many') end

    MySQL.insert.await('INSERT IGNORE INTO som_shop_stock (shop_id, item, qty, price) VALUES (?, ?, 0, ?)', { shop.id, item, price })
    local added = MySQL.update.await(
        'UPDATE som_shop_stock SET qty = qty + ?, price = ? WHERE shop_id = ? AND item = ? AND qty + ? <= ?',
        { count, price, shop.id, item, count, Config.maxStockPerItem })
    if (added or 0) < 1 then
        ox:AddItem(source, item, count)
        return done(false, ('the shop holds at most %d of one item'):format(Config.maxStockPerItem))
    end
    return done(true)
end)

lib.callback.register('som-shops:server:setPrice', function(source, id, item, price)
    local _, shop = Shops.Owned(source, id)
    if not shop then return done(false, 'not available') end

    local limits = type(item) == 'string' and Config.items[item]
    price = limits and Shops.Int(price, limits.min, limits.max)
    if not price then return done(false, 'that price is not allowed') end

    local changed = MySQL.update.await('UPDATE som_shop_stock SET price = ? WHERE shop_id = ? AND item = ?', { price, shop.id, item })
    if (changed or 0) < 1 then return done(false, 'you do not sell that') end
    return done(true)
end)

lib.callback.register('som-shops:server:retrieve', function(source, id, item, count)
    local _, shop = Shops.Owned(source, id)
    if not shop then return done(false, 'not available') end
    if not Shops.Near(source, shop) then return done(false, 'you are too far away') end

    count = Shops.Int(count, 1, Config.maxStockPerItem)
    if not count or type(item) ~= 'string' or not Config.items[item] then return done(false, 'bad request') end
    if not ox:CanCarryItem(source, item, count) then return done(false, 'you cannot carry that') end

    local taken = MySQL.update.await('UPDATE som_shop_stock SET qty = qty - ? WHERE shop_id = ? AND item = ? AND qty >= ?', { count, shop.id, item, count })
    if (taken or 0) < 1 then return done(false, 'the shop does not have that many') end

    if not ox:AddItem(source, item, count) then
        MySQL.update.await('UPDATE som_shop_stock SET qty = qty + ? WHERE shop_id = ? AND item = ?', { count, shop.id, item })
        return done(false, 'you cannot carry that')
    end
    return done(true)
end)

lib.callback.register('som-shops:server:buy', function(source, id, item, count)
    local player = core:getPlayer(source)
    local shop = player and Shops.Find(id)
    if not shop then return done(false, 'not available') end
    if not Shops.Near(source, shop) then return done(false, 'you are too far away') end

    count = Shops.Int(count, 1, Config.maxBuyPerPurchase)
    if not count or type(item) ~= 'string' or not Config.items[item] then return done(false, 'bad request') end

    local row = MySQL.single.await(
        'SELECT st.price FROM som_shop_stock st JOIN som_shops s ON s.shop_id = st.shop_id WHERE st.shop_id = ? AND st.item = ? AND s.owner IS NOT NULL',
        { shop.id, item })
    if not row then return done(false, 'they do not sell that') end

    local price = tonumber(row.price)
    local total = price * count
    if not ox:CanCarryItem(source, item, count) then return done(false, 'you cannot carry that') end

    -- Claim the stock at the price the customer saw; an owner changing it meanwhile fails the claim.
    local claimed = MySQL.update.await(
        'UPDATE som_shop_stock SET qty = qty - ? WHERE shop_id = ? AND item = ? AND qty >= ? AND price = ?',
        { count, shop.id, item, count, price })
    if (claimed or 0) < 1 then return done(false, 'not enough in stock, or the price changed') end

    local business = Shops.Business(shop)
    local reason = 'shop:sale:' .. item
    local function restock() MySQL.update.await('UPDATE som_shop_stock SET qty = qty + ? WHERE shop_id = ? AND item = ?', { count, shop.id, item }) end
    local function moneyBack() core:addMoney(source, 'bank', total, 'shop:refund:' .. item) end

    if not core:removeMoney(source, 'bank', total, reason) then restock(); return done(false, 'not enough in your bank') end
    if not core:businessTransact(business, total, reason) then moneyBack(); restock(); return done(false, 'the shop could not take the payment') end
    if not ox:AddItem(source, item, count) then
        core:businessTransact(business, -total, 'shop:refund:' .. item)
        moneyBack(); restock()
        return done(false, 'you cannot carry that')
    end

    -- Tax comes out of the shop account into the treasury. A failure leaves the money in the shop.
    local tax = math.floor(total * Config.taxRate)
    if tax >= 1 and core:businessTransact(business, -tax, 'shop:tax') then
        if not core:taxToTreasury(tax, 'shop:tax:' .. shop.id) then core:businessTransact(business, tax, 'shop:tax_refund') end
    end
    return done(true, nil, { paid = total })
end)
