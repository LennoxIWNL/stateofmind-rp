--- Weed growing. A plant is a database row; its stage is computed from the
--- planting and watering timestamps, so restarts change nothing. Position is
--- read from the planter's ped on the server, every action re-checks distance,
--- and harvest is a conditional UPDATE so two people cannot both take one crop.

local core = exports['som-core']
local ox = exports.ox_inventory
local G = Config.grow

local function xp(src, track, n)
    if GetResourceState('som-progress') == 'started' then exports['som-progress']:addXp(src, track, n) end
end

local function level(src, track)
    if GetResourceState('som-progress') == 'started' then return exports['som-progress']:getLevel(src, track) or 1 end
    return 1
end

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

local function inside(point, center, radius)
    return #(point - center) <= radius
end

local function pedPos(source)
    local ped = GetPlayerPed(source)
    if ped == 0 then return nil end
    return GetEntityCoords(ped)
end

---May a plant go here for this player: a grow spot, or a zone their gang holds.
local function allowed(player, pos)
    for _, spot in ipairs(G.spots) do
        if spot.enabled and spot.center and spot.radius and inside(pos, spot.center, spot.radius) then return true end
    end
    if player.gang and player.gang.name ~= 'none' then
        for _, z in ipairs(Config.zones) do
            if Turf.Usable(z) and inside(pos, z.center, z.radius) then
                local r = MySQL.single.await('SELECT name, owner_gang FROM som_turf WHERE name = ?', { z.name })
                if r and r.owner_gang == player.gang.name then return true end
            end
        end
    end
    return false
end

local function wither()
    MySQL.update.await(
        "UPDATE som_plants SET status = 'withered' WHERE status = 'growing' AND last_water < DATE_SUB(NOW(), INTERVAL ? MINUTE)",
        { G.witherMinutes })
end

local function stage(plant)
    if plant.age >= G.growMinutes * 60 then return 'ready' end
    return 'growing'
end

lib.callback.register('som-turf:server:growInfo', function()
    local strains, spots, tables = {}, {}, {}
    for seed, st in pairs(G.strains) do strains[#strains + 1] = { seed = seed, label = st.label } end
    table.sort(strains, function(a, b) return a.seed < b.seed end)
    for _, sp in ipairs(G.spots) do
        if sp.enabled and sp.center and sp.radius then spots[#spots + 1] = { name = sp.name, center = sp.center, radius = sp.radius } end
    end
    for _, t in ipairs(G.bagTables) do
        if t.enabled and t.coords then tables[#tables + 1] = { name = t.name, coords = t.coords } end
    end
    return { strains = strains, spots = spots, tables = tables }
end)

lib.callback.register('som-turf:server:plants', function(source)
    local pos = pedPos(source)
    if not pos then return {} end
    wither()

    local out = {}
    for _, p in ipairs(MySQL.query.await([[
        SELECT id, strain, x, y, z, fed, TIMESTAMPDIFF(SECOND, planted_at, NOW()) AS age
        FROM som_plants WHERE status = 'growing'
    ]]) or {}) do
        if #(pos - vec3(p.x, p.y, p.z)) <= G.showDistance then
            out[#out + 1] = { id = p.id, strain = p.strain, x = p.x, y = p.y, z = p.z, stage = stage(p) }
        end
    end
    return out
end)

lib.callback.register('som-turf:server:plant', function(source, seed)
    local player = core:getPlayer(source)
    if not player then return done(false, 'not available') end
    local strain = type(seed) == 'string' and G.strains[seed]
    if not strain then return done(false, 'that is not a seed') end

    if strain.minLevel and level(source, 'growing') < strain.minLevel then
        return done(false, ('you need growing level %d for %s'):format(strain.minLevel, strain.label))
    end

    local pos = pedPos(source)
    if not pos or not allowed(player, pos) then return done(false, 'nothing will grow here') end

    wither()
    local mine = MySQL.scalar.await("SELECT COUNT(*) FROM som_plants WHERE citizenid = ? AND status = 'growing'", { player.citizenid }) or 0
    if mine >= G.maxPlants then return done(false, 'you are tending enough already') end

    if not ox:RemoveItem(source, seed, 1) then return done(false, 'you have no seed') end

    local id = MySQL.insert.await(
        'INSERT INTO som_plants (citizenid, strain, x, y, z) VALUES (?, ?, ?, ?, ?)',
        { player.citizenid, seed, pos.x, pos.y, pos.z })
    if not id or id < 1 then
        ox:AddItem(source, seed, 1)
        return done(false, 'it did not take')
    end

    exports['som-dispatch']:alert(source, 'drugDeal', { message = 'Someone is planting' })
    return done(true)
end)

local function plantNear(source, id)
    id = tonumber(id)
    if id and id % 1 ~= 0 then id = nil end
    local pos = pedPos(source)
    if not id or not pos then return nil end
    wither()
    local p = MySQL.single.await(
        "SELECT id, strain, x, y, z, fed, TIMESTAMPDIFF(SECOND, planted_at, NOW()) AS age FROM som_plants WHERE id = ? AND status = 'growing'", { id })
    if not p or #(pos - vec3(p.x, p.y, p.z)) > G.tendDistance then return nil end
    return p
end

lib.callback.register('som-turf:server:tend', function(source, id, kind)
    if not core:getPlayer(source) then return done(false, 'not available') end
    if kind ~= 'water' and kind ~= 'feed' then return done(false, 'bad request') end

    local p = plantNear(source, id)
    if not p then return done(false, 'there is nothing to tend here') end

    local item = kind == 'water' and G.waterItem or G.feedItem
    if not ox:RemoveItem(source, item, 1) then return done(false, 'you need ' .. item:gsub('_', ' ')) end

    local n
    if kind == 'water' then
        n = MySQL.update.await("UPDATE som_plants SET last_water = NOW() WHERE id = ? AND status = 'growing'", { p.id })
    else
        n = MySQL.update.await("UPDATE som_plants SET fed = 1 WHERE id = ? AND status = 'growing' AND fed = 0", { p.id })
    end
    if (n or 0) < 1 then
        ox:AddItem(source, item, 1)
        return done(false, kind == 'feed' and 'it is already fed' or 'it did not take')
    end
    return done(true)
end)

lib.callback.register('som-turf:server:harvest', function(source, id)
    if not core:getPlayer(source) then return done(false, 'not available') end

    local p = plantNear(source, id)
    if not p then return done(false, 'there is nothing to harvest here') end
    if p.age < G.growMinutes * 60 then return done(false, 'it is not ready') end

    local n = MySQL.update.await("UPDATE som_plants SET status = 'harvested' WHERE id = ? AND status = 'growing'", { p.id })
    if (n or 0) < 1 then return done(false, 'someone got there first') end

    -- One extra bud for every three growing levels.
    local count = math.random(G.yield.min, G.yield.max) + (p.fed == 1 and G.yield.fedBonus or 0) + math.floor(level(source, 'growing') / 3)
    if not ox:AddItem(source, G.budItem, count, { strain = p.strain }) then
        MySQL.update.await("UPDATE som_plants SET status = 'growing' WHERE id = ? AND status = 'harvested'", { p.id })
        return done(false, 'you cannot carry it')
    end
    xp(source, 'growing', 25)
    return done(true, nil, { count = count })
end)

lib.callback.register('som-turf:server:bag', function(source, seed)
    if not core:getPlayer(source) then return done(false, 'not available') end
    local strain = type(seed) == 'string' and G.strains[seed]
    if not strain then return done(false, 'bad request') end

    local pos = pedPos(source)
    local atTable = false
    for _, t in ipairs(G.bagTables) do
        if t.enabled and t.coords and pos and inside(pos, t.coords, 3.0) then atTable = true end
    end
    if not atTable then return done(false, 'you need a bagging table') end

    local slot
    for _, s in ipairs(ox:Search(source, 'slots', G.budItem) or {}) do
        if s.metadata and s.metadata.strain == seed and (s.count or 1) >= G.budsPerBag then slot = s; break end
    end
    if not slot then return done(false, ('you need %d %s buds'):format(G.budsPerBag, strain.label)) end

    if not ox:RemoveItem(source, G.bagItem, 1) then return done(false, 'you need an empty bag') end
    if not ox:RemoveItem(source, G.budItem, G.budsPerBag, slot.metadata, slot.slot) then
        ox:AddItem(source, G.bagItem, 1)
        return done(false, 'the buds are gone')
    end
    if not ox:AddItem(source, strain.bag, 1) then
        ox:AddItem(source, G.budItem, G.budsPerBag, { strain = seed })
        ox:AddItem(source, G.bagItem, 1)
        return done(false, 'you cannot carry it')
    end
    return done(true)
end)

CreateThread(function()
    while true do
        Wait(3600000)
        MySQL.update.await("DELETE FROM som_plants WHERE status <> 'growing' AND last_water < DATE_SUB(NOW(), INTERVAL 1 DAY)")
    end
end)
