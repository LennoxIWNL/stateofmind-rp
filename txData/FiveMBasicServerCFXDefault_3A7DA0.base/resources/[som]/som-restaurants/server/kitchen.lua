--- Supplier and stations. The supplier is paid from the restaurant's account. A cook step is a
--- start and a finish: the finish checks the server clock, then takes the ingredients and gives
--- the dish in one guarded sequence, so a failure puts everything back and nothing is lost.
--- Made by Lennox.

local core = exports['som-core']
local ox = exports.ox_inventory
local done = Rest.Done

lib.callback.register('som-restaurants:server:supplier', function(source, id, item, qty)
    local player, r = Rest.Staff(source, id)
    local supplier = Config.supplier
    if not r or not supplier.enabled or not supplier.coords then return done(false, 'not available') end
    if not Rest.Near(source, supplier.coords) then return done(false, 'you are too far away') end

    local price = type(item) == 'string' and supplier.goods[item]
    qty = Rest.Int(qty, 1, Config.maxBuyPerPurchase)
    if not price or not qty then return done(false, 'bad request') end
    if not ox:CanCarryItem(source, item, qty) then return done(false, 'you cannot carry that') end

    local total, reason = price * qty, 'restaurant:supplier:' .. r.id
    if not core:businessTransact(r.business, -total, reason) then return done(false, 'the restaurant account cannot pay for that') end
    if not core:taxToTreasury(total, reason) then
        core:businessTransact(r.business, total, reason .. '_refund')
        return done(false, 'the supplier could not take the payment')
    end
    if not ox:AddItem(source, item, qty) then
        core:treasuryTransact(-total, reason .. '_refund')
        core:businessTransact(r.business, total, reason .. '_refund')
        return done(false, 'you cannot carry that')
    end
    return done(true, nil, { paid = total })
end)

local cooking = {}

---Everything the recipe needs is in the bag right now.
local function hasAll(source, recipe)
    for item, n in pairs(recipe.ingredients) do
        if (ox:Search(source, 'count', item) or 0) < n then return false end
    end
    return true
end

lib.callback.register('som-restaurants:server:cookStart', function(source, id, stationId, recipeId)
    local _, r = Rest.Staff(source, id)
    if not r then return done(false, 'not available') end

    local station = type(stationId) == 'string' and Rest.Station(r, stationId)
    local recipe = type(recipeId) == 'string' and Config.recipes[recipeId]
    if not station or not recipe or recipe.station ~= station.kind then return done(false, 'bad request') end
    if not Rest.Near(source, station.coords) then return done(false, 'you are too far away') end
    local busy = cooking[source]
    -- A run whose finish never came (client crash) expires, so nobody stays stuck.
    if busy and GetGameTimer() - busy.at < Config.recipes[busy.recipe].duration + 30000 then return done(false, 'you are already cooking') end
    if not hasAll(source, recipe) then return done(false, 'you are missing ingredients') end
    if not ox:CanCarryItem(source, recipe.output, recipe.count) then return done(false, 'you cannot carry that') end

    cooking[source] = { restaurant = r.id, station = station.id, recipe = recipeId, at = GetGameTimer() }
    return done(true, nil, { duration = recipe.duration })
end)

lib.callback.register('som-restaurants:server:cookFinish', function(source)
    local run = cooking[source]
    cooking[source] = nil
    if not run then return done(false, 'you were not cooking') end

    local _, r = Rest.Staff(source, run.restaurant)
    local station = r and Rest.Station(r, run.station)
    if not station or not Rest.Near(source, station.coords) then return done(false, 'you left the station') end

    local recipe = Config.recipes[run.recipe]
    if GetGameTimer() - run.at < recipe.duration * Config.cookMinFraction then return done(false, 'that was not finished yet') end

    local taken = {}
    local function putBack() for item, n in pairs(taken) do ox:AddItem(source, item, n) end end
    for item, n in pairs(recipe.ingredients) do
        if not ox:RemoveItem(source, item, n) then putBack(); return done(false, 'you are missing ingredients') end
        taken[item] = n
    end
    if not ox:AddItem(source, recipe.output, recipe.count) then putBack(); return done(false, 'you cannot carry that') end
    return done(true)
end)

AddEventHandler('playerDropped', function() cooking[source] = nil end)
