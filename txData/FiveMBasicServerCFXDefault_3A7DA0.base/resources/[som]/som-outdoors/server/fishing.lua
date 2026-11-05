--- Fishing. Casting records a bite time chosen by the server; reeling in
--- before that time catches nothing, and the catch is rolled here. The client
--- shows the wait and nothing more.

local core = exports['som-core']
local ox = exports.ox_inventory
local F = Config.fishing

local casts = {}

local function done(ok, err, extra) return Buyer.Done(ok, err, extra) end

local function spotAt(source)
    local ped = GetPlayerPed(source)
    if ped == 0 then return nil end
    local pos = GetEntityCoords(ped)
    for _, s in ipairs(F.spots) do
        if s.enabled and s.center and s.radius and #(pos - s.center) <= s.radius then return s end
    end
end

lib.callback.register('som-outdoors:server:fishSpots', function()
    local out = {}
    for _, s in ipairs(F.spots) do
        if s.enabled and s.center and s.radius then out[#out + 1] = { name = s.name, label = s.label, center = s.center, radius = s.radius } end
    end
    return out
end)

lib.callback.register('som-outdoors:server:cast', function(source)
    local player = core:getPlayer(source)
    if not player then return done(false, 'not available') end
    if not spotAt(source) then return done(false, 'there is nothing to catch here') end
    if (ox:Search(source, 'count', F.rod) or 0) < 1 then return done(false, 'you need a fishing rod') end
    if (ox:Search(source, 'count', F.bait) or 0) < 1 then return done(false, 'you need bait') end

    local wait = math.random(F.minWait, F.maxWait)
    casts[player.citizenid] = { at = GetGameTimer(), wait = wait }
    return done(true, nil, { wait = wait })
end)

local function roll()
    local total = 0
    for _, c in ipairs(F.catches) do total = total + c.weight end
    local r = math.random(total)
    for _, c in ipairs(F.catches) do
        r = r - c.weight
        if r <= 0 then return c.item end
    end
end

lib.callback.register('som-outdoors:server:reel', function(source)
    local player = core:getPlayer(source)
    if not player then return done(false, 'not available') end

    local cast = casts[player.citizenid]
    casts[player.citizenid] = nil
    if not cast then return done(false, 'you have not cast') end

    local elapsed = GetGameTimer() - cast.at
    if elapsed < cast.wait * 1000 then return done(false, 'nothing is biting yet') end
    if elapsed > (cast.wait + F.maxWaitGrace) * 1000 then return done(false, 'the fish got away') end
    if not spotAt(source) then return done(false, 'you moved away') end

    if not ox:RemoveItem(source, F.bait, 1) then return done(false, 'you need bait') end

    local item = roll()
    if not ox:AddItem(source, item, 1) then
        ox:AddItem(source, F.bait, 1)
        return done(false, 'you cannot carry it')
    end
    return done(true, nil, { item = item })
end)

AddEventHandler('som:server:playerUnloaded', function(_, citizenid)
    if type(citizenid) == 'string' then casts[citizenid] = nil end
end)
