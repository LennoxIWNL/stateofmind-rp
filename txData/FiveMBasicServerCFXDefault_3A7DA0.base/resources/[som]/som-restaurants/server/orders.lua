--- The counter. A cashier builds an order, the customer accepts it, and payment is one conditional
--- claim on the order row followed by customer bank to restaurant account. The price is always
--- computed here from Config.menu. A paid order that nobody serves inside the window is claimed
--- to refunded and the money goes back to the customer, online or not. Made by Lennox.

local core = exports['som-core']
local ox = exports.ox_inventory
local done = Rest.Done

Orders = {}

local function describe(lines)
    local parts = {}
    for _, l in ipairs(lines) do parts[#parts + 1] = ('%dx %s'):format(l.qty, Config.menu[l.item].label) end
    return table.concat(parts, ', ')
end

local function decode(text)
    local lines = type(text) == 'string' and json.decode(text)
    return type(lines) == 'table' and lines or {}
end

---Open orders for the kitchen screen.
function Orders.Queue(r)
    local out = {}
    local rows = MySQL.query.await(
        "SELECT id, items FROM som_restaurant_orders WHERE restaurant_id = ? AND state = 'paid' ORDER BY id LIMIT 20", { r.id }) or {}
    for _, row in ipairs(rows) do out[#out + 1] = { id = row.id, text = describe(decode(row.items)) } end
    return out
end

local function tell(r, event, ...)
    for _, p in ipairs(core:getPlayersByJob(r.job, true)) do TriggerClientEvent(event, p.source, ...) end
end

lib.callback.register('som-restaurants:server:orderCreate', function(source, id, target, lines)
    local cashier, r = Rest.Staff(source, id)
    if not r then return done(false, 'not available') end
    if not Rest.Near(source, r.coords) then return done(false, 'you are too far away') end

    local them = Rest.Int(target, 1, 65535)
    local customer = them and them ~= source and core:getPlayer(them)
    if not customer or not Rest.Near(them, r.coords) then return done(false, 'the customer needs to be at the counter') end

    if type(lines) ~= 'table' or #lines < 1 or #lines > Config.maxLines then return done(false, 'bad order') end
    local clean, total, seen = {}, 0, {}
    for _, l in ipairs(lines) do
        local entry = type(l) == 'table' and type(l.item) == 'string' and Config.menu[l.item]
        local qty = entry and not seen[l.item] and Rest.Int(l.qty, 1, entry.maxQty)
        if not qty then return done(false, 'bad order') end
        seen[l.item] = true
        clean[#clean + 1] = { item = l.item, qty = qty }
        total = total + entry.price * qty
    end

    local orderId = MySQL.insert.await([[
        INSERT INTO som_restaurant_orders (restaurant_id, cashier_cid, customer_cid, items, total, state)
        SELECT ?, ?, ?, ?, ?, 'offered' FROM DUAL
        WHERE NOT EXISTS (SELECT 1 FROM som_restaurant_orders WHERE customer_cid = ? AND state = 'offered' AND created_at > DATE_SUB(NOW(), INTERVAL ? SECOND))
    ]], { r.id, cashier.citizenid, customer.citizenid, json.encode(clean), total, customer.citizenid, Config.offerSeconds })
    if not orderId or orderId < 1 then return done(false, 'they already have an order waiting') end

    TriggerClientEvent('som-restaurants:client:offer', customer.source, orderId, r.label, describe(clean), total)
    return done(true, nil, { orderId = orderId, total = total })
end)

local function cancel(orderId)
    MySQL.update.await("UPDATE som_restaurant_orders SET state = 'cancelled' WHERE id = ? AND state = 'paying'", { orderId })
end

lib.callback.register('som-restaurants:server:orderPay', function(source, orderId)
    local player = core:getPlayer(source)
    orderId = Rest.Int(orderId, 1, 2147483647)
    if not player or not orderId then return done(false, 'not available') end

    local row = MySQL.single.await(
        "SELECT restaurant_id, total FROM som_restaurant_orders WHERE id = ? AND customer_cid = ? AND state = 'offered' AND created_at > DATE_SUB(NOW(), INTERVAL ? SECOND)",
        { orderId, player.citizenid, Config.offerSeconds })
    local r = row and Rest.Find(row.restaurant_id)
    if not r then return done(false, 'that order is gone') end
    if not Rest.Near(source, r.coords) then return done(false, 'you are too far away') end
    if not Rest.Staffed(r) then return done(false, 'nobody is on duty to make that') end

    local claimed = MySQL.update.await(
        "UPDATE som_restaurant_orders SET state = 'paying' WHERE id = ? AND customer_cid = ? AND state = 'offered' AND created_at > DATE_SUB(NOW(), INTERVAL ? SECOND)",
        { orderId, player.citizenid, Config.offerSeconds })
    if (claimed or 0) < 1 then return done(false, 'that order is gone') end

    local total, reason = tonumber(row.total), 'restaurant:sale:' .. r.id
    -- 'paying' is never refunded: a crash between the claim and the money leaves a stuck row for staff, not a refund of money that was never taken.
    if not core:removeMoney(source, 'bank', total, reason) then
        cancel(orderId)
        return done(false, 'not enough in your bank')
    end
    if not core:businessTransact(r.business, total, reason) then
        core:addMoney(source, 'bank', total, 'restaurant:refund:' .. r.id)
        cancel(orderId)
        return done(false, 'the restaurant could not take the payment')
    end
    MySQL.update.await("UPDATE som_restaurant_orders SET state = 'paid', paid_at = NOW() WHERE id = ? AND state = 'paying'", { orderId })

    local order = MySQL.single.await('SELECT items FROM som_restaurant_orders WHERE id = ?', { orderId })
    tell(r, 'som-restaurants:client:ticket', orderId, describe(decode(order and order.items)))
    return done(true)
end)

lib.callback.register('som-restaurants:server:orderDecline', function(source, orderId)
    local player = core:getPlayer(source)
    orderId = Rest.Int(orderId, 1, 2147483647)
    if not player or not orderId then return done(false, 'not available') end
    MySQL.update.await("UPDATE som_restaurant_orders SET state = 'cancelled' WHERE id = ? AND customer_cid = ? AND state = 'offered'", { orderId, player.citizenid })
    return done(true)
end)

lib.callback.register('som-restaurants:server:orderServe', function(source, id, orderId)
    local _, r = Rest.Staff(source, id)
    orderId = Rest.Int(orderId, 1, 2147483647)
    if not r or not orderId then return done(false, 'not available') end
    if not Rest.Near(source, r.coords) then return done(false, 'you are too far away') end

    local row = MySQL.single.await(
        "SELECT customer_cid, items, total FROM som_restaurant_orders WHERE id = ? AND restaurant_id = ? AND state = 'paid'", { orderId, r.id })
    if not row then return done(false, 'that order is gone') end

    local customer = core:getPlayerByCitizenId(row.customer_cid)
    if not customer or not Rest.Near(customer.source, r.coords) then return done(false, 'the customer is not at the counter') end

    local need = {}
    for _, l in ipairs(decode(row.items)) do
        local entry = Config.menu[l.item]
        if entry then need[entry.item] = (need[entry.item] or 0) + l.qty end
    end
    for item, n in pairs(need) do
        if (ox:Search(source, 'count', item) or 0) < n then return done(false, 'you do not have everything for that order') end
        if not ox:CanCarryItem(customer.source, item, n) then return done(false, 'they cannot carry all that') end
    end

    local claimed = MySQL.update.await("UPDATE som_restaurant_orders SET state = 'served', served_at = NOW() WHERE id = ? AND state = 'paid'", { orderId })
    if (claimed or 0) < 1 then return done(false, 'that order is gone') end

    local taken, given = {}, {}
    local function undo()
        for item, n in pairs(given) do ox:RemoveItem(customer.source, item, n) end
        for item, n in pairs(taken) do ox:AddItem(source, item, n) end
        MySQL.update.await("UPDATE som_restaurant_orders SET state = 'paid', served_at = NULL WHERE id = ? AND state = 'served'", { orderId })
    end
    for item, n in pairs(need) do
        if not ox:RemoveItem(source, item, n) then undo(); return done(false, 'you do not have everything for that order') end
        taken[item] = n
    end
    for item, n in pairs(need) do
        if not ox:AddItem(customer.source, item, n) then undo(); return done(false, 'they cannot carry all that') end
        given[item] = n
    end

    -- The city's share comes out of the account now the food is handed over. A failure leaves it in the restaurant.
    local tax = math.floor(tonumber(row.total) * Config.taxRate)
    if tax >= 1 and core:businessTransact(r.business, -tax, 'restaurant:tax:' .. r.id) then
        if not core:taxToTreasury(tax, 'restaurant:tax:' .. r.id) then core:businessTransact(r.business, tax, 'restaurant:tax_refund:' .. r.id) end
    end
    return done(true)
end)

lib.callback.register('som-restaurants:server:selfServe', function(source, id, item, qty)
    local player = core:getPlayer(source)
    local r = player and Rest.Find(id)
    if not r or not r.selfServe or not r.selfServe.coords then return done(false, 'not available') end
    if not Rest.Near(source, r.selfServe.coords) then return done(false, 'you are too far away') end
    if Rest.Staffed(r) then return done(false, 'the kitchen is open, order at the counter') end

    local good = type(item) == 'string' and Config.fallback.goods[item]
    qty = Rest.Int(qty, 1, Config.fallback.maxQty)
    if not good or not qty then return done(false, 'bad request') end
    if not ox:CanCarryItem(source, item, qty) then return done(false, 'you cannot carry that') end

    local total, reason = good.price * qty, 'restaurant:selfserve:' .. r.id
    if not core:removeMoney(source, 'bank', total, reason) then return done(false, 'not enough in your bank') end
    if not core:taxToTreasury(total, reason) then
        core:addMoney(source, 'bank', total, reason .. '_refund')
        return done(false, 'the machine would not take it')
    end
    if not ox:AddItem(source, item, qty) then
        core:treasuryTransact(-total, reason .. '_refund')
        core:addMoney(source, 'bank', total, reason .. '_refund')
        return done(false, 'you cannot carry that')
    end
    return done(true, nil, { paid = total })
end)

-- ---------------------------------------------------------------------------
-- Refunds for orders nobody served
-- ---------------------------------------------------------------------------

---Returns true when the order was refunded. The claim decides who wins against a serve.
function Orders.Refund(order)
    local r = Rest.ById(order.restaurant_id)
    if not r then return false end

    local claimed = MySQL.update.await(
        "UPDATE som_restaurant_orders SET state = 'refunded' WHERE id = ? AND state = 'paid' AND paid_at < DATE_SUB(NOW(), INTERVAL ? MINUTE)",
        { order.id, Config.serveWindowMinutes })
    if (claimed or 0) < 1 then return false end

    local total, reason = tonumber(order.total), 'restaurant:order_refund:' .. r.id
    local function reopen() MySQL.update.await("UPDATE som_restaurant_orders SET state = 'paid' WHERE id = ? AND state = 'refunded'", { order.id }) end

    -- A restaurant that has spent the money cannot refund yet; the order stays paid and is retried.
    if not core:businessTransact(r.business, -total, reason) then reopen(); return false end
    if not core:creditCitizen(order.customer_cid, 'bank', total, reason) then
        core:businessTransact(r.business, total, reason .. '_undo')
        reopen()
        return false
    end

    local customer = core:getPlayerByCitizenId(order.customer_cid)
    if customer then TriggerClientEvent('som:client:notify', customer.source, ('Your $%d order was never served and has been refunded'):format(total), 'inform') end
    return true
end

function Orders.RefundTick()
    local due = MySQL.query.await(
        "SELECT id, restaurant_id, customer_cid, total FROM som_restaurant_orders WHERE state = 'paid' AND paid_at < DATE_SUB(NOW(), INTERVAL ? MINUTE) ORDER BY id LIMIT 20",
        { Config.serveWindowMinutes }) or {}
    for _, order in ipairs(due) do Orders.Refund(order) end
end

CreateThread(function()
    while true do
        Wait(Config.refundTickSeconds * 1000)
        local ok, err = pcall(Orders.RefundTick)
        if not ok then print(('[som-restaurants] refund sweep failed: %s'):format(tostring(err))) end
    end
end)
