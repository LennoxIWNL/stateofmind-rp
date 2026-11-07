--- Mining. The server keeps every vein's rest time, times the swing, rolls the
--- yield and counts helpers by their own positions. The smelter takes its
--- inputs all or nothing. Metal is sold through the capped quarry buyer.

local core = exports['som-core']
local ox = exports.ox_inventory
local M = Config.mining

local veins = {}
local swings = {}
local smelts = {}
local strikeLog = {}

local function done(ok, err, extra) return Buyer.Done(ok, err, extra) end

local function now() return GetGameTimer() end

local function nodeByKey(key)
    if type(key) ~= 'string' then return nil end
    local name, index = key:match('^([%w_%-]+):(%d+)$')
    if not name then return nil end

    for _, site in ipairs(M.sites) do
        if site.name == name then
            local coords = site.nodes[tonumber(index)]
            if coords then return site, coords end
        end
    end
end

local function near(source, at, distance)
    local ped = GetPlayerPed(source)
    return ped ~= 0 and #(GetEntityCoords(ped) - at) <= distance
end

local function hasTool(source)
    return (ox:Search(source, 'count', M.tool) or 0) >= 1
end

-- shortcut: the strike count lives in memory, so a restart resets it; upgrade to a table if abuse shows.
local function strikesLeft(citizenid)
    local cutoff, keep = os.time() - 3600, {}
    for _, t in ipairs(strikeLog[citizenid] or {}) do
        if t > cutoff then keep[#keep + 1] = t end
    end
    strikeLog[citizenid] = keep
    return M.hourlyStrikes - #keep
end

lib.callback.register('som-outdoors:server:mineNodes', function()
    local out = {}
    for _, site in ipairs(M.sites) do
        for i, coords in ipairs(site.nodes) do
            out[#out + 1] = { key = ('%s:%d'):format(site.name, i), label = site.label, coords = coords }
        end
    end
    return out
end)

lib.callback.register('som-outdoors:server:mineBegin', function(source, key)
    local player = core:getPlayer(source)
    if not player then return done(false, 'not available') end

    local site, coords = nodeByKey(key)
    if not site then return done(false, 'there is nothing to mine here') end
    -- Aliases such as 'a:01' must not get their own vein state.
    if key ~= ('%s:%d'):format(site.name, tonumber(key:match(':(%d+)$'))) then return done(false, 'there is nothing to mine here') end
    if not hasTool(source) then return done(false, 'you need a pickaxe') end
    if not near(source, coords, M.distance) then return done(false, 'you are too far from the vein') end
    if strikesLeft(player.citizenid) < 1 then return done(false, 'you have mined enough for this hour') end

    local vein = veins[key] or { readyAt = 0 }
    local t = now()
    if vein.readyAt > t then return done(false, 'this vein is spent for now') end
    if vein.by and vein.by ~= player.citizenid and t - vein.at < M.staleSeconds * 1000 then
        return done(false, 'someone else is working that vein')
    end

    local previous = swings[player.citizenid]
    if previous and previous.key ~= key and veins[previous.key] and veins[previous.key].by == player.citizenid then
        veins[previous.key].by = nil
    end

    vein.by, vein.at = player.citizenid, t
    veins[key] = vein
    swings[player.citizenid] = { key = key, at = t }
    return done(true, nil, { seconds = M.seconds })
end)

---Distinct characters near the vein, also carrying a pickaxe, up to the cap.
local function helpers(source, citizenid, coords)
    local n = 0
    for _, id in ipairs(GetPlayers()) do
        local other = tonumber(id)
        local friend = other and other ~= source and core:getPlayer(other)
        if friend and friend.citizenid ~= citizenid and near(other, coords, M.assistRadius) and hasTool(other) then
            n = n + 1
        end
    end
    return math.min(n, M.assistMax)
end

lib.callback.register('som-outdoors:server:mineFinish', function(source)
    local player = core:getPlayer(source)
    if not player then return done(false, 'not available') end

    local swing = swings[player.citizenid]
    swings[player.citizenid] = nil
    if not swing then return done(false, 'you have not started') end

    local vein = veins[swing.key]
    local age = now() - swing.at
    if age < M.seconds * 900 or age > M.staleSeconds * 1000 then
        if vein and vein.by == player.citizenid then vein.by = nil end
        return done(false, 'you were too quick')
    end

    local site, coords = nodeByKey(swing.key)
    if not site or not vein or vein.by ~= player.citizenid then return done(false, 'the vein is gone') end
    if not near(source, coords, M.distance) then
        vein.by = nil
        return done(false, 'you are too far from the vein')
    end
    if not hasTool(source) then
        vein.by = nil
        return done(false, 'you need a pickaxe')
    end
    if strikesLeft(player.citizenid) < 1 then
        vein.by = nil
        return done(false, 'you have mined enough for this hour')
    end

    -- Claim the vein before the item is added, and give it back if the add fails.
    vein.by, vein.readyAt = nil, now() + M.cooldown * 1000

    local count = math.random(site.min, site.max) + helpers(source, player.citizenid, coords)
    if not ox:AddItem(source, site.ore, count) then
        vein.readyAt = 0
        return done(false, 'you cannot carry it')
    end

    local log = strikeLog[player.citizenid]
    log[#log + 1] = os.time()
    return done(true, nil, { item = site.ore, count = count })
end)

local function smelterReady()
    local s = M.smelter
    return s.enabled and s.coords and s
end

lib.callback.register('som-outdoors:server:smelterInfo', function()
    local s = smelterReady()
    if not s then return nil end

    local recipes = {}
    for id, r in pairs(s.recipes) do recipes[#recipes + 1] = { id = id, label = r.label } end
    table.sort(recipes, function(a, b) return a.id < b.id end)
    return { coords = s.coords, distance = s.distance, recipes = recipes }
end)

lib.callback.register('som-outdoors:server:smeltBegin', function(source, id)
    local player = core:getPlayer(source)
    if not player then return done(false, 'not available') end

    local s = smelterReady()
    local recipe = s and type(id) == 'string' and s.recipes[id]
    if not recipe then return done(false, 'there is no smelter here') end
    if not near(source, s.coords, s.distance) then return done(false, 'you are too far from the smelter') end

    for item, n in pairs(recipe.input) do
        if (ox:Search(source, 'count', item) or 0) < n then return done(false, 'you do not have enough ore') end
    end

    smelts[player.citizenid] = { id = id, at = now() }
    return done(true, nil, { seconds = s.seconds })
end)

lib.callback.register('som-outdoors:server:smeltFinish', function(source)
    local player = core:getPlayer(source)
    if not player then return done(false, 'not available') end

    local run = smelts[player.citizenid]
    smelts[player.citizenid] = nil
    local s = smelterReady()
    local recipe = run and s and s.recipes[run.id]
    if not recipe then return done(false, 'you have not started') end

    local age = now() - run.at
    if age < s.seconds * 900 or age > M.staleSeconds * 1000 then return done(false, 'you were too quick') end
    if not near(source, s.coords, s.distance) then return done(false, 'you are too far from the smelter') end

    local taken = {}
    local function giveBack()
        for _, t in ipairs(taken) do ox:AddItem(source, t.item, t.count) end
    end

    for item, n in pairs(recipe.input) do
        if not ox:RemoveItem(source, item, n) then
            giveBack()
            return done(false, 'you do not have enough ore')
        end
        taken[#taken + 1] = { item = item, count = n }
    end

    if not ox:AddItem(source, recipe.output[1], recipe.output[2]) then
        giveBack()
        return done(false, 'you cannot carry it')
    end

    return done(true, nil, { item = recipe.output[1], count = recipe.output[2] })
end)

AddEventHandler('som:server:playerUnloaded', function(_, citizenid)
    if type(citizenid) ~= 'string' then return end
    local swing = swings[citizenid]
    if swing and veins[swing.key] and veins[swing.key].by == citizenid then veins[swing.key].by = nil end
    swings[citizenid], smelts[citizenid] = nil, nil
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then veins, swings, smelts = {}, {}, {} end
end)
