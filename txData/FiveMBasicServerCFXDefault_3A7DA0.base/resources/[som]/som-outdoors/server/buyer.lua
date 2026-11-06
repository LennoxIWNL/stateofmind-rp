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

---Does the sale. `state` records how far it got so a failure part way can be undone.
local function settle(source, name, b, state)
    local total, sold = 0, {}
    for item, price in pairs(b.prices) do
        local have = ox:Search(source, 'count', item) or 0
        if have > 0 then
            total = total + have * price
            sold[#sold + 1] = { item = item, count = have }
        end
    end
    if total < 1 then return done(false, 'you have nothing they want') end

    local spent = tonumber(MySQL.scalar.await(
        'SELECT COALESCE(SUM(amount), 0) FROM som_buyer_payouts WHERE buyer = ? AND created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)',
        { name })) or 0
    local pay = math.min(total, math.max(0, b.hourlyCap - spent))
    if pay < 1 then return done(false, 'they cannot pay any more right now') end

    -- Sell items worth at most `pay`, in list order, so a capped sale takes
    -- only what is paid for.
    local worth = 0
    for _, s in ipairs(sold) do
        local price = b.prices[s.item]
        local n = math.min(s.count, math.floor((pay - worth) / price))
        if n > 0 then
            if not ox:RemoveItem(source, s.item, n) then break end
            state.taken[#state.taken + 1] = { item = s.item, count = n }
            worth = worth + n * price
        end
    end
    state.worth = worth

    if worth < 1 then return done(false, 'they cannot pay any more right now') end

    local reason = 'buyer:' .. name
    if not core:treasuryTransact(-worth, reason) then return done(false, 'the city cannot pay right now') end
    state.debited = true

    if not core:addMoney(source, 'bank', worth, reason) then return done(false, 'the sale fell through') end
    state.paid = true

    MySQL.insert.await('INSERT INTO som_buyer_payouts (buyer, amount) VALUES (?, ?)', { name, worth })
    return done(true, nil, { paid = worth })
end

---Sells everything the player carries that this buyer wants.
lib.callback.register('som-outdoors:server:sell', function(source, name)
    if not core:getPlayer(source) then return done(false, 'not available') end

    local b = type(name) == 'string' and open(name)
    if not b then return done(false, 'nobody is buying') end

    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - b.coords) > b.distance then return done(false, 'you are too far away') end
    if busy then return done(false, 'try again in a moment') end
    busy = true

    local state = { taken = {}, worth = 0, debited = false, paid = false }
    local ok, result = pcall(settle, source, name, b, state)
    busy = false  -- always cleared, even when something above threw

    if not ok then
        print(('[som-outdoors] sale to %s failed: %s'):format(name, tostring(result)))
        result = done(false, 'the sale fell through')
    end

    -- Anything taken or debited without a completed payment goes back.
    if not state.paid then
        if state.debited then core:treasuryTransact(state.worth, 'buyer:' .. name .. ':refund') end
        for _, t in ipairs(state.taken) do ox:AddItem(source, t.item, t.count) end
    end
    return result
end)

CreateThread(function() SomPlacements.Apply(Config) end)
