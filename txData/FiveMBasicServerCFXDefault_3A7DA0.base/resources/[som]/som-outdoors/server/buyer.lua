--- Selling to a buyer. The buyer pays from the treasury under an hourly cap
--- recorded in som_buyer_payouts (so a restart cannot reset it). Debit the
--- treasury first, credit the player second, refund if the credit fails. A
--- single lock stops two sales reading the same cap at once.

local core = exports['som-core']
local ox = exports.ox_inventory

Buyer = {}

function Buyer.Xp(src, track, n)
    if GetResourceState('som-progress') == 'started' then exports['som-progress']:addXp(src, track, n) end
end

function Buyer.Level(src, track)
    if GetResourceState('som-progress') == 'started' then return exports['som-progress']:getLevel(src, track) or 1 end
    return 1
end

local busy = false

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end
Buyer.Done = done

local function open(name)
    local b = Config.buyers[name]
    if b and b.enabled and b.coords then return b end
end

lib.callback.register('som-outdoors:server:buyers', function()
    local out = {}
    for name, b in pairs(Config.buyers) do
        if open(name) then
            local items = {}
            for item, price in pairs(b.prices) do items[#items + 1] = { item = item, price = price } end
            table.sort(items, function(x, y) return x.item < y.item end)
            out[#out + 1] = { name = name, label = b.label, coords = b.coords, items = items }
        end
    end
    return out
end)

---Sells everything the player carries that this buyer wants.
lib.callback.register('som-outdoors:server:sell', function(source, name)
    if not core:getPlayer(source) then return done(false, 'not available') end

    local b = type(name) == 'string' and open(name)
    if not b then return done(false, 'nobody is buying') end

    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - b.coords) > b.distance then return done(false, 'you are too far away') end
    if busy then return done(false, 'try again in a moment') end
    busy = true

    local total, sold = 0, {}
    for item, price in pairs(b.prices) do
        local have = ox:Search(source, 'count', item) or 0
        if have > 0 then
            total = total + have * price
            sold[#sold + 1] = { item = item, count = have }
        end
    end

    if total < 1 then
        busy = false
        return done(false, 'you have nothing they want')
    end

    local spent = tonumber(MySQL.scalar.await(
        'SELECT COALESCE(SUM(amount), 0) FROM som_buyer_payouts WHERE buyer = ? AND created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)',
        { name })) or 0
    local pay = math.min(total, math.max(0, b.hourlyCap - spent))
    if pay < 1 then
        busy = false
        return done(false, 'they cannot pay any more right now')
    end

    -- Sell items worth at most `pay`, in list order, so a capped sale takes
    -- only what is paid for.
    local taken, worth = {}, 0
    for _, s in ipairs(sold) do
        local price = b.prices[s.item]
        local n = math.min(s.count, math.floor((pay - worth) / price))
        if n > 0 then
            if not ox:RemoveItem(source, s.item, n) then break end
            taken[#taken + 1] = { item = s.item, count = n }
            worth = worth + n * price
        end
    end

    local function giveBack()
        for _, t in ipairs(taken) do ox:AddItem(source, t.item, t.count) end
    end

    if worth < 1 then
        busy = false
        return done(false, 'they cannot pay any more right now')
    end

    local reason = 'buyer:' .. name
    if not core:treasuryTransact(-worth, reason) then
        giveBack()
        busy = false
        return done(false, 'the city cannot pay right now')
    end
    if not core:addMoney(source, 'bank', worth, reason) then
        core:treasuryTransact(worth, reason .. ':refund')
        giveBack()
        busy = false
        return done(false, 'the sale fell through')
    end

    MySQL.insert.await('INSERT INTO som_buyer_payouts (buyer, amount) VALUES (?, ?)', { name, worth })
    busy = false
    return done(true, nil, { paid = worth })
end)

CreateThread(function() SomPlacements.Apply(Config) end)
