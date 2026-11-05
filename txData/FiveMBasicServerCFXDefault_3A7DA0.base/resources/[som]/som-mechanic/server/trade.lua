--- Player to player sales of mechanic goods, and the roadside fallback. A
--- mechanic on duty offers an item to a nearby customer at a price inside the
--- configured limits. The customer accepts from the phone. Accepting claims the
--- offer with one conditional UPDATE, then moves everything with a rollback at
--- every step: item out of the mechanic, money out of the customer, money to
--- the shop, item to the customer. Made by Lennox.

local core = exports['som-core']
local ox = exports.ox_inventory

local mechanic = Mechanic.OnDuty

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

local function nameOf(player)
    return ('%s %s'):format(player.charinfo.firstname, player.charinfo.lastname)
end

local function onDutyMechanics()
    return #core:getPlayersByJob(Config.job, true)
end

local function near(a, b, distance)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    return pa ~= 0 and pb ~= 0 and #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= distance
end

local function refresh(player)
    if player then TriggerClientEvent('som-phone:client:refresh', player.source) end
end

-- ---------------------------------------------------------------------------
-- Offers
-- ---------------------------------------------------------------------------

lib.callback.register('som-mechanic:server:tradeInfo', function(source)
    if not mechanic(source) then return nil end
    local out = {}
    for item, l in pairs(Config.trade.items) do out[#out + 1] = { item = item, min = l.min, max = l.max } end
    table.sort(out, function(a, b) return a.item < b.item end)
    return out
end)

lib.callback.register('som-mechanic:server:offer', function(source, target, item, price)
    local seller = mechanic(source)
    if not seller then return done(false, 'you are not on duty as a mechanic') end

    local limits = type(item) == 'string' and Config.trade.items[item]
    if not limits then return done(false, 'that is not something you can sell here') end

    price = tonumber(price)
    if not price or price % 1 ~= 0 or price < limits.min or price > limits.max then
        return done(false, ('the price must be between $%d and $%d'):format(limits.min, limits.max))
    end

    target = tonumber(target)
    local buyer = target and target ~= source and core:getPlayer(target)
    if not buyer then return done(false, 'there is nobody to sell to') end
    if not near(source, target, Config.trade.distance) then return done(false, 'they need to be next to you') end
    if (ox:Search(source, 'count', item) or 0) < 1 then return done(false, 'you do not have one') end

    local pending = MySQL.scalar.await(
        "SELECT COUNT(*) FROM som_trade_offers WHERE seller = ? AND status = 'pending' AND created_at > DATE_SUB(NOW(), INTERVAL ? SECOND)",
        { seller.citizenid, Config.trade.expireSeconds }) or 0
    if pending >= 3 then return done(false, 'you have too many open offers') end

    local id = MySQL.insert.await(
        'INSERT INTO som_trade_offers (seller, buyer, item, price) VALUES (?, ?, ?, ?)',
        { seller.citizenid, buyer.citizenid, item, price })
    if not id or id < 1 then return done(false, 'could not make the offer') end

    exports['som-phone']:notifyApp(target, 'trade', ('%s offers you a %s for $%d'):format(nameOf(seller), item:gsub('_', ' '), price))
    refresh(buyer)
    return done(true)
end)

local function view(player)
    local rows = {}
    for _, o in ipairs(MySQL.query.await([[
        SELECT o.id, o.item, o.price, c.firstname, c.lastname
        FROM som_trade_offers o JOIN som_characters c ON c.citizenid = o.seller
        WHERE o.buyer = ? AND o.status = 'pending' AND o.created_at > DATE_SUB(NOW(), INTERVAL ? SECOND)
        ORDER BY o.id DESC LIMIT 5
    ]], { player.citizenid, Config.trade.expireSeconds }) or {}) do
        rows[#rows + 1] = {
            title = ('%s: %s for $%d'):format(('%s %s'):format(o.firstname, o.lastname), o.item:gsub('_', ' '), o.price),
            sub = 'Tap to accept', action = 'accept', payload = { offer = o.id },
        }
    end
    return { sections = { { title = 'Offers', rows = rows } }, empty = 'No offers right now' }
end

local actions = {}

function actions.view(_, _, player) return done(true, nil, { view = view(player) }) end

function actions.accept(source, payload, player)
    local id = math.floor(tonumber(payload.offer) or 0)
    if id < 1 then return done(false, 'bad request') end

    local claimed = MySQL.update.await(
        "UPDATE som_trade_offers SET status = 'done' WHERE id = ? AND buyer = ? AND status = 'pending' AND created_at > DATE_SUB(NOW(), INTERVAL ? SECOND)",
        { id, player.citizenid, Config.trade.expireSeconds })
    if (claimed or 0) < 1 then return done(false, 'that offer is gone') end

    local function cancel(reason)
        MySQL.update.await("UPDATE som_trade_offers SET status = 'cancelled' WHERE id = ?", { id })
        return done(false, reason)
    end

    local o = MySQL.single.await('SELECT seller, item, price FROM som_trade_offers WHERE id = ?', { id })
    local limits = o and Config.trade.items[o.item]
    local seller = o and core:getPlayerByCitizenId(o.seller)
    if not limits or not seller then return cancel('the mechanic is not around any more') end
    if not mechanic(seller.source) then return cancel('the mechanic is not on duty any more') end
    if not near(seller.source, source, Config.trade.distance) then return cancel('you moved apart') end

    if not ox:RemoveItem(seller.source, o.item, 1) then return cancel('they no longer have it') end
    local function itemBack() ox:AddItem(seller.source, o.item, 1) end

    if not core:removeMoney(source, 'bank', o.price, 'trade:' .. o.item) then
        itemBack()
        return cancel('not enough in your bank')
    end
    local function moneyBack() core:addMoney(source, 'bank', o.price, 'trade_refund:' .. o.item) end

    if not core:businessTransact(Config.business, o.price, 'trade:' .. o.item) then
        moneyBack(); itemBack()
        return cancel('the shop could not take the payment')
    end
    if not ox:AddItem(source, o.item, 1) then
        core:businessTransact(Config.business, -o.price, 'trade_refund:' .. o.item)
        moneyBack(); itemBack()
        return cancel('you cannot carry it')
    end

    -- The mechanic keeps the job's commission out of the sale. A failure here
    -- leaves the money in the shop account, which is the safe side.
    local share = (core:getJobs()[Config.job] or {}).commission or 0
    local cut = math.floor(o.price * share)
    if cut >= 1 and core:businessTransact(Config.business, -cut, 'commission:' .. o.item) then
        core:addMoney(seller.source, 'bank', cut, 'commission:' .. o.item)
    end
    TriggerClientEvent('som:client:notify', seller.source, ('Sold a %s for $%d'):format(o.item:gsub('_', ' '), o.price), 'success')
    return done(true)
end

function actions.decline(_, payload, player)
    local id = math.floor(tonumber(payload.offer) or 0)
    MySQL.update.await("UPDATE som_trade_offers SET status = 'cancelled' WHERE id = ? AND buyer = ? AND status = 'pending'", { id, player.citizenid })
    return done(true)
end

exports['som-phone']:registerApp({
    id = 'trade', label = 'Offers', icon = 'receipt', colour = '#ff9f0a', order = 64,
    reads = { view = true },
    handler = function(source, action, payload)
        local fn = type(action) == 'string' and actions[action]
        local player = core:getPlayer(source)
        if not fn or not player then return done(false, 'not available') end
        return fn(source, type(payload) == 'table' and payload or {}, player)
    end,
})

-- ---------------------------------------------------------------------------
-- Roadside fallback
-- ---------------------------------------------------------------------------

local function fallbackOpen()
    local f = Config.fallback
    return f.enabled and f.coords ~= nil
end

lib.callback.register('som-mechanic:server:fallbackInfo', function()
    if not fallbackOpen() then return nil end
    local f = Config.fallback
    return { label = f.label, coords = f.coords, price = f.price, item = f.item }
end)

lib.callback.register('som-mechanic:server:fallbackBuy', function(source)
    local player = core:getPlayer(source)
    if not player then return done(false, 'not available') end
    if not fallbackOpen() then return done(false, 'nobody is selling') end

    local f = Config.fallback
    if onDutyMechanics() > 0 then return done(false, 'a mechanic is on duty, go and see them') end

    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - f.coords) > f.distance then return done(false, 'you are too far away') end

    local bought = MySQL.scalar.await(
        "SELECT COUNT(*) FROM som_trade_offers WHERE buyer = ? AND seller = 'FALLBACK' AND created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)",
        { player.citizenid }) or 0
    if bought >= f.perHour then return done(false, 'you have bought one already, try again later') end

    local id = MySQL.insert.await(
        "INSERT INTO som_trade_offers (seller, buyer, item, price, status) VALUES ('FALLBACK', ?, ?, ?, 'done')",
        { player.citizenid, f.item, f.price })
    if not id or id < 1 then return done(false, 'try again') end

    local function undo() MySQL.update.await("UPDATE som_trade_offers SET status = 'cancelled' WHERE id = ?", { id }) end

    if not core:removeMoney(source, 'bank', f.price, 'fallback:' .. f.item) then undo(); return done(false, 'not enough in your bank') end
    if not ox:AddItem(source, f.item, 1) then
        core:addMoney(source, 'bank', f.price, 'fallback_refund')
        undo()
        return done(false, 'you cannot carry it')
    end
    if not core:taxToTreasury(f.price, 'fallback:' .. f.item) then
        ox:RemoveItem(source, f.item, 1)
        core:addMoney(source, 'bank', f.price, 'fallback_refund')
        undo()
        return done(false, 'the sale fell through')
    end
    return done(true)
end)
