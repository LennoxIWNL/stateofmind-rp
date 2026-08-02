-- Market with saturation and recovery.
--
-- Selling pushes a price down, time pulls it back toward base. Flooding one
-- market therefore stops being worth it, and leaving it alone restores it. The
-- point is to make WHERE and WHEN you sell a decision, instead of every sale
-- being identical forever.
--
-- Prices live in the database rather than memory so they survive a restart.
-- An economy that resets whenever the server reboots teaches players to wait
-- for a restart rather than to read the market.

Market = {}

local cache = {}

---Loads the catalogue, inserting anything new from config.
function Market.Load()
    for _, entry in ipairs(Config.MarketItems) do
        local item, label, category, base, saturation, recovery = table.unpack(entry)

        MySQL.insert.await([[
            INSERT IGNORE INTO som_market
                (item, label, category, base_price, current_price, min_price, max_price, saturation, recovery)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            item, label, category, base, base,
            math.floor(base * Config.Market.floorRatio),
            math.floor(base * Config.Market.ceilingRatio),
            saturation, recovery,
        })
    end

    cache = {}
    local rows = MySQL.query.await('SELECT * FROM som_market') or {}
    for _, row in ipairs(rows) do
        cache[row.item] = row
    end

    print(('[som-economy] market loaded, %d items'):format(#rows))
end

---@param item string
---@return table|nil
function Market.Get(item)
    return cache[item]
end

---@param item string
---@return number price per unit, 0 if the item is not traded
function Market.GetPrice(item)
    local row = cache[item]
    return row and row.current_price or 0
end

---@return table[] the whole catalogue, for a UI
function Market.GetAll()
    local list = {}
    for _, row in pairs(cache) do
        list[#list + 1] = {
            item = row.item,
            label = row.label,
            category = row.category,
            price = row.current_price,
            base = row.base_price,
            -- Ratio is what a player actually cares about: is this market
            -- worked out or fresh.
            health = row.base_price > 0 and (row.current_price / row.base_price) or 1.0,
        }
    end
    return list
end

---Quotes a sale WITHOUT executing it, applying saturation across the batch so
---the hundredth unit is worth less than the first.
---
---Quoting separately from selling matters: a UI can show an honest total, and
---the server can re-quote at the moment of sale rather than trusting a price
---the client was shown earlier.
---@param item string
---@param quantity number
---@return number gross, number unitAverage
function Market.Quote(item, quantity)
    local row = cache[item]
    if not row or quantity < 1 then return 0, 0 end

    local price = row.current_price
    local floor = row.min_price
    local gross = 0

    for _ = 1, quantity do
        gross = gross + price
        price = math.floor(price * (1.0 - row.saturation))
        if price < floor then price = floor end
    end

    return gross, math.floor(gross / quantity)
end

---Executes a sale: pays the seller, moves the price, logs it.
---
---The caller must already have removed the goods from the seller's inventory.
---This function deliberately does not touch items: mixing item removal and
---payment in one place is how double-pay bugs happen.
---@param source number
---@param item string
---@param quantity number
---@param opts table|nil { business = string, reason = string }
---@return boolean success, number|string paid, or an error
function Market.Sell(source, item, quantity, opts)
    opts = opts or {}

    local player = exports['som-core']:getPlayer(source)
    if not player then return false, 'player not found' end

    local row = cache[item]
    if not row then return false, 'item is not traded here' end

    quantity = tonumber(quantity)
    if not quantity or quantity % 1 ~= 0 or quantity < 1 or quantity > 10000 then
        return false, 'invalid quantity'
    end

    local gross, unit = Market.Quote(item, quantity)
    if gross < 1 then return false, 'worthless' end

    local paid = exports['som-core']:addMoney(
        source, 'cash', gross,
        opts.reason or ('market-sale:%s'):format(item)
    )
    if not paid then return false, 'payment failed' end

    -- Apply the saturation permanently now the sale is real.
    local newPrice = row.current_price
    for _ = 1, quantity do
        newPrice = math.floor(newPrice * (1.0 - row.saturation))
        if newPrice < row.min_price then newPrice = row.min_price break end
    end

    row.current_price = newPrice
    row.volume_sold = row.volume_sold + quantity

    MySQL.update.await(
        'UPDATE som_market SET current_price = ?, volume_sold = volume_sold + ? WHERE item = ?',
        { newPrice, quantity, item }
    )

    MySQL.insert.await([[
        INSERT INTO som_market_sales (item, citizenid, quantity, unit_price, gross, business)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { item, player.citizenid, quantity, unit, gross, opts.business })

    -- A sale through a registered business is revenue for that business, and
    -- is taxed. Selling to a back-alley buyer is not, which is part of what
    -- makes laundering worth doing later.
    if opts.business then
        Business.RecordRevenue(opts.business, gross)
        -- And the employee who made the sale takes their cut. For low-base
        -- jobs this is the actual wage.
        Business.PayCommission(source, opts.business, gross)
    end

    TriggerEvent('som:server:marketSale', item, quantity, gross, newPrice)

    return true, gross
end

---Pulls every price back toward base. Called on a timer.
function Market.Recover()
    for item, row in pairs(cache) do
        if row.current_price < row.base_price then
            local gap = row.base_price - row.current_price
            -- Recovery is per hour; scale it to how often this actually runs.
            local step = gap * row.recovery * (Config.Market.tickMinutes / 60.0)
            local newPrice = math.floor(row.current_price + math.max(step, 1))

            if newPrice > row.max_price then newPrice = row.max_price end
            if newPrice > row.base_price then newPrice = row.base_price end

            row.current_price = newPrice
            MySQL.update.await('UPDATE som_market SET current_price = ? WHERE item = ?',
                { newPrice, item })
        end
    end
end

exports('getMarketPrice', Market.GetPrice)
exports('getMarket', Market.GetAll)
exports('quoteMarketSale', Market.Quote)
exports('sellToMarket', Market.Sell)

lib.callback.register('som-economy:server:getMarket', function()
    return Market.GetAll()
end)

lib.callback.register('som-economy:server:quote', function(_, item, quantity)
    local gross, unit = Market.Quote(item, tonumber(quantity) or 0)
    return { gross = gross, unit = unit }
end)
