--- Labs. A cook is a database row with a ready time computed by the database
--- clock. Starting claims the lab with one conditional insert (one cook at a
--- time per lab), inputs are taken all or nothing, and collecting is a
--- conditional UPDATE so a cook can be collected once, by the person who
--- started it, and only when it is done.

local core = exports['som-core']
local ox = exports.ox_inventory

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

local function labByName(name)
    if type(name) ~= 'string' then return nil end
    for _, l in ipairs(Config.labs) do
        if l.name == name and l.enabled and l.coords then return l end
    end
end

local function near(source, lab)
    local ped = GetPlayerPed(source)
    return ped ~= 0 and #(GetEntityCoords(ped) - lab.coords) <= Config.lab.distance
end

local function member(source)
    local player = core:getPlayer(source)
    if not player or not player.gang or player.gang.name == 'none' then return nil end
    return player
end

lib.callback.register('som-turf:server:labInfo', function()
    local labs, recipes = {}, {}
    for _, l in ipairs(Config.labs) do
        if l.enabled and l.coords then labs[#labs + 1] = { name = l.name, label = l.label, coords = l.coords } end
    end
    for id, r in pairs(Config.recipes) do
        if r.enabled then recipes[#recipes + 1] = { id = id, label = r.label } end
    end
    table.sort(recipes, function(a, b) return a.id < b.id end)
    return { labs = labs, recipes = recipes }
end)

local function giveBack(source, taken)
    for _, t in ipairs(taken) do ox:AddItem(source, t.item, t.count) end
end

lib.callback.register('som-turf:server:labStart', function(source, labName, recipeId)
    local player = member(source)
    if not player then return done(false, 'you are not in a gang') end

    local lab = labByName(labName)
    if not lab or not near(source, lab) then return done(false, 'there is no lab here') end

    local recipe = type(recipeId) == 'string' and Config.recipes[recipeId]
    if not recipe or not recipe.enabled then return done(false, 'you do not know that one') end

    local mine = MySQL.scalar.await("SELECT COUNT(*) FROM som_lab_jobs WHERE citizenid = ? AND status = 'cooking'", { player.citizenid }) or 0
    if mine >= Config.lab.maxActive then return done(false, 'you already have something cooking') end

    local taken = {}
    for item, count in pairs(recipe.inputs) do
        if not ox:RemoveItem(source, item, count) then
            giveBack(source, taken)
            return done(false, 'you are missing ingredients')
        end
        taken[#taken + 1] = { item = item, count = count }
    end

    local id = MySQL.insert.await([[
        INSERT INTO som_lab_jobs (citizenid, lab, recipe, ready_at)
        SELECT ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE) FROM DUAL
        WHERE NOT EXISTS (SELECT 1 FROM som_lab_jobs WHERE lab = ? AND status = 'cooking')
    ]], { player.citizenid, lab.name, recipeId, recipe.minutes, lab.name })
    if not id or id < 1 then
        giveBack(source, taken)
        return done(false, 'the lab is busy')
    end

    exports['som-dispatch']:alert(source, 'drugDeal', { message = 'Strange smells reported' })
    return done(true)
end)

lib.callback.register('som-turf:server:labCollect', function(source, labName)
    local player = member(source)
    if not player then return done(false, 'you are not in a gang') end

    local lab = labByName(labName)
    if not lab or not near(source, lab) then return done(false, 'there is no lab here') end

    local job = MySQL.single.await(
        "SELECT id, recipe, ready_at <= NOW() AS ready FROM som_lab_jobs WHERE lab = ? AND citizenid = ? AND status = 'cooking' ORDER BY id LIMIT 1",
        { lab.name, player.citizenid })
    if not job then return done(false, 'you have nothing cooking here') end
    if job.ready ~= 1 then return done(false, 'it is not done yet') end

    local recipe = Config.recipes[job.recipe]
    local n = MySQL.update.await("UPDATE som_lab_jobs SET status = 'collected' WHERE id = ? AND status = 'cooking'", { job.id })
    if (n or 0) < 1 then return done(false, 'someone got there first') end

    local given = {}
    for item, count in pairs(recipe and recipe.outputs or {}) do
        if not ox:AddItem(source, item, count) then
            for _, g in ipairs(given) do ox:RemoveItem(source, g.item, g.count) end
            MySQL.update.await("UPDATE som_lab_jobs SET status = 'cooking' WHERE id = ? AND status = 'collected'", { job.id })
            return done(false, 'you cannot carry it')
        end
        given[#given + 1] = { item = item, count = count }
    end
    return done(true)
end)

-- ---------------------------------------------------------------------------
-- Supplier
-- ---------------------------------------------------------------------------

local function supplierOpen()
    local s = Config.supplier
    return s.enabled and s.coords ~= nil
end

lib.callback.register('som-turf:server:supplierInfo', function()
    if not supplierOpen() then return nil end
    local s = Config.supplier
    local stock = {}
    for item, price in pairs(s.stock) do stock[#stock + 1] = { item = item, price = price } end
    table.sort(stock, function(a, b) return a.item < b.item end)
    return { label = s.label, coords = s.coords, stock = stock, maxQty = s.maxQty }
end)

lib.callback.register('som-turf:server:supplierBuy', function(source, item, qty)
    local player = member(source)
    if not player then return done(false, 'you are not in a gang') end
    if not supplierOpen() then return done(false, 'nobody is selling') end

    local s = Config.supplier
    local ped = GetPlayerPed(source)
    if ped == 0 or #(GetEntityCoords(ped) - s.coords) > s.distance then return done(false, 'you are too far away') end

    local price = type(item) == 'string' and s.stock[item]
    if not price then return done(false, 'they do not sell that') end
    qty = tonumber(qty)
    if not qty or qty % 1 ~= 0 or qty < 1 or qty > s.maxQty then return done(false, ('between 1 and %d'):format(s.maxQty)) end

    local total = price * qty
    if not core:removeMoney(source, 'bank', total, 'supplier:' .. item) then return done(false, 'not enough in your bank') end
    if not ox:AddItem(source, item, qty) then
        core:addMoney(source, 'bank', total, 'supplier_refund:' .. item)
        return done(false, 'you cannot carry it')
    end
    if not core:taxToTreasury(total, 'supplier:' .. item) then
        ox:RemoveItem(source, item, qty)
        core:addMoney(source, 'bank', total, 'supplier_refund:' .. item)
        return done(false, 'the sale fell through')
    end
    return done(true)
end)
