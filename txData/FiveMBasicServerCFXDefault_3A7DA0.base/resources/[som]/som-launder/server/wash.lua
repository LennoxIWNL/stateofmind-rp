--- The front: a desk where marked bills are handed over and, some time later,
--- clean cash is collected. Bills are claimed in the ledger before anything is
--- taken from the inventory or paid, and the payout comes from the ledger's
--- worth, never from the item's metadata.

local core = exports['som-core']
local ox = exports.ox_inventory

local function fail(err) return { success = false, error = err } end

---@param source number
---@param key any
---@return table|nil front, string|nil error
local function frontAt(source, key)
    local front = type(key) == 'string' and Config.Fronts[key]
    if not front or not front.enabled or not front.set then return nil, 'that front is closed' end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or #(GetEntityCoords(ped) - front.coords) > front.range then
        return nil, 'too far away'
    end

    return front
end

lib.callback.register('som-launder:server:bills', function(source, key)
    if not core:getPlayer(source) then return fail('not loaded') end

    local _, err = frontAt(source, key)
    if err then return fail(err) end

    local bills, seen = {}, {}
    for _, slot in ipairs(ox:Search(source, 'slots', Config.Item) or {}) do
        local uid = slot.metadata and slot.metadata.uid
        local row = uid and not seen[uid] and Ledger.Get(uid)

        if row and row.status == 'issued' then
            seen[uid] = true
            bills[#bills + 1] = { uid = uid, worth = row.worth }
        end
    end

    return { success = true, bills = bills }
end)

lib.callback.register('som-launder:server:deposit', function(source, key, uids)
    local player = core:getPlayer(source)
    if not player then return fail('not loaded') end

    local _, err = frontAt(source, key)
    if err then return fail(err) end

    if type(uids) ~= 'table' or #uids < 1 or #uids > Config.Wash.maxBills then return fail('choose some bills') end

    local bills, face, seen = {}, 0, {}
    for _, uid in ipairs(uids) do
        if seen[uid] then return fail('each bill can only be handed over once') end
        seen[uid] = true

        local row = Ledger.Get(uid)
        if not row or row.status ~= 'issued' then return fail('one of those bills is no good') end

        local slot = Ledger.SlotOf(source, uid)
        if not slot then return fail('you are not carrying one of those bills') end

        bills[#bills + 1] = { uid = uid, worth = row.worth }
        face = face + row.worth
    end

    local day = tonumber(MySQL.scalar.await(
        "SELECT COALESCE(SUM(face), 0) FROM som_launder_orders WHERE citizenid = ? AND status <> 'cancelled' AND created_at > DATE_SUB(NOW(), INTERVAL 1 DAY)",
        { player.citizenid })) or 0
    if day + face > Config.Wash.dailyCap then return fail('you have washed enough for one day') end

    local hour = tonumber(MySQL.scalar.await(
        "SELECT COALESCE(SUM(face), 0) FROM som_launder_orders WHERE status <> 'cancelled' AND created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)")) or 0
    if hour >= Config.Wash.hourlyBudget then return fail('the front is not taking any more this hour') end

    local factor = 1 - (1 - Config.Wash.priceFloor) * math.min(1, hour / Config.Wash.hourlyBudget)
    local payout = math.floor(face * (1 - Config.Wash.cut) * factor)
    if payout < 1 then return fail('that is not worth washing') end

    -- The reads above only give the friendly message and the price. The caps are
    -- enforced by this one insert, so deposits in flight together cannot all pass.
    local orderId = MySQL.insert.await([[
        INSERT INTO som_launder_orders (citizenid, front, face, payout, ready_at)
        SELECT ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE) FROM DUAL
        WHERE (SELECT COALESCE(SUM(face), 0) FROM som_launder_orders
               WHERE citizenid = ? AND status <> 'cancelled' AND created_at > DATE_SUB(NOW(), INTERVAL 1 DAY)) + ? <= ?
          AND (SELECT COALESCE(SUM(face), 0) FROM som_launder_orders
               WHERE status <> 'cancelled' AND created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)) < ?
    ]], { player.citizenid, key, face, payout, Config.Wash.delayMinutes,
        player.citizenid, face, Config.Wash.dailyCap, Config.Wash.hourlyBudget })
    if not orderId or orderId < 1 then return fail('you have washed enough for now') end

    local claimed, taken = {}, {}

    local function undo(reason)
        for _, bill in ipairs(taken) do ox:AddItem(source, Config.Item, 1, { uid = bill.uid, worth = bill.worth }) end
        for _, bill in ipairs(claimed) do
            MySQL.update.await(
                "UPDATE som_marked_bills SET status = 'issued', order_id = NULL WHERE uid = ? AND status = 'washing'",
                { bill.uid })
        end
        MySQL.update.await("UPDATE som_launder_orders SET status = 'cancelled' WHERE id = ? AND status = 'washing'", { orderId })
        return fail(reason)
    end

    for _, bill in ipairs(bills) do
        if MySQL.update.await(
            "UPDATE som_marked_bills SET status = 'washing', order_id = ? WHERE uid = ? AND status = 'issued'",
            { orderId, bill.uid }) ~= 1 then
            return undo('one of those bills was just used')
        end
        claimed[#claimed + 1] = bill
    end

    for _, bill in ipairs(bills) do
        local slot = Ledger.SlotOf(source, bill.uid)
        if not slot or not ox:RemoveItem(source, Config.Item, 1, nil, slot) then
            return undo('you are not carrying one of those bills')
        end
        taken[#taken + 1] = bill
    end

    Ledger.Log(('%s handed over %d bills (%d face) for order %d'):format(player.citizenid, #bills, face, orderId))
    return { success = true, orderId = orderId, face = face, payout = payout, minutes = Config.Wash.delayMinutes }
end)

lib.callback.register('som-launder:server:orders', function(source, key)
    local player = core:getPlayer(source)
    if not player then return fail('not loaded') end

    local _, err = frontAt(source, key)
    if err then return fail(err) end

    return { success = true, orders = MySQL.query.await(
        "SELECT id, face, payout, ready_at <= NOW() AS ready FROM som_launder_orders WHERE citizenid = ? AND front = ? AND status = 'washing' ORDER BY id",
        { player.citizenid, key }) or {} }
end)

lib.callback.register('som-launder:server:collect', function(source, key, orderId)
    local player = core:getPlayer(source)
    if not player then return fail('not loaded') end

    local _, err = frontAt(source, key)
    if err then return fail(err) end

    orderId = math.floor(tonumber(orderId) or 0)
    if orderId < 1 then return fail('no such order') end

    local won = MySQL.update.await([[
        UPDATE som_launder_orders SET status = 'collected'
        WHERE id = ? AND citizenid = ? AND status = 'washing' AND ready_at <= NOW()
    ]], { orderId, player.citizenid })
    if won ~= 1 then return fail('that order is not ready') end

    local order = MySQL.single.await('SELECT * FROM som_launder_orders WHERE id = ?', { orderId })

    if not core:addMoney(source, 'cash', order.payout, ('launder:%d'):format(orderId)) then
        MySQL.update.await("UPDATE som_launder_orders SET status = 'washing' WHERE id = ? AND status = 'collected'", { orderId })
        return fail('could not pay you')
    end

    MySQL.update.await("UPDATE som_marked_bills SET status = 'washed' WHERE order_id = ? AND status = 'washing'", { orderId })
    Ledger.Log(('%s collected %d clean from order %d'):format(player.citizenid, order.payout, orderId))
    return { success = true, amount = order.payout }
end)

CreateThread(function()
    Wait(9000)
    math.randomseed(os.time() + GetGameTimer())

    for key, front in pairs(Config.Fronts) do
        if not (front.enabled and front.set) then
            print(('[som-launder] front "%s" is disabled: set its coordinates and enable it (LAUNCH-TODO.md)'):format(key))
        end
    end
end)

CreateThread(function() SomPlacements.Apply(Config) end)
