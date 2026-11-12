--- House burglary as job board providers. A crew is sent to a house, picks the
--- lock (som-hack holds the answer), goes into an instanced shell and searches
--- fixed spots. The server claims each spot in the database, rolls the loot and
--- counts the noise; the client only shows where to go. Loot is stolen goods:
--- nothing here pays money, the fence in som-outdoors does.

local core = exports['som-core']
local ox = exports.ox_inventory

Burglary = {}

local runs = {}
local byCitizen = {}
local returnTo = {}

local function done(ok, err, extra)
    local out = extra or {}
    out.success = ok == true
    out.error = (not ok) and err or nil
    return out
end

local function houseIndex(house)
    for i, h in ipairs(Config.houses) do if h == house then return i end end
end

local function spotsOf(house)
    local shell = Config.shells[house.shell]
    return shell and shell.spots or {}
end

local function usable(house)
    return house.enabled == true and house.coords ~= nil and #spotsOf(house) > 0
        and exports['som-housing']:shellOffset(house.shell) ~= nil
end

local function isNight()
    local n = Config.night
    if not n.enabled then return true end

    local hour = n.hour and n.hour()
    if not hour then return false end
    if n.from <= n.to then return hour >= n.from and hour < n.to end
    return hour >= n.from or hour < n.to
end

local function voidOf(run)
    local v = Config.void
    return vec3(v.origin.x + run.index * v.spacing, v.origin.y, v.origin.z)
end

local function inShell(run, offset)
    local v = voidOf(run)
    return vec3(v.x + offset.x, v.y + offset.y, v.z + offset.z)
end

local function near(source, coords, distance)
    local ped = GetPlayerPed(source)
    return ped ~= 0 and #(GetEntityCoords(ped) - coords) <= distance
end

local function policeOnDuty()
    return #core:getPlayersByJob('police', true)
end

local function runOf(source)
    local player = core:getPlayer(source)
    return player and runs[byCitizen[player.citizenid]], player
end

-- ---------------------------------------------------------------------------
-- Run state
-- ---------------------------------------------------------------------------

local function objective(run)
    local h = run.house
    if run.stage == 'door' then return { kind = 'door', coords = h.coords, label = h.label .. ' door' } end
    return { kind = 'enter', coords = h.coords, label = h.label .. ' door' }
end

local function sendObjective(run)
    for _, s in pairs(run.members) do TriggerClientEvent('som-burglary:client:objective', s, objective(run)) end
end

---Puts a player back in the world. Safe for somebody who is not inside.
local function sendOut(run, source)
    if not run.inside[source] then return end
    run.inside[source] = nil
    run.sessions[source] = nil
    SetPlayerRoutingBucket(source, 0)

    local back = returnTo[source] or run.house.coords
    returnTo[source] = nil
    return back
end

local function clear(groupId)
    local run = runs[groupId]
    if not run then return end

    runs[groupId] = nil
    for cid, source in pairs(run.members) do
        byCitizen[cid] = nil
        local back = sendOut(run, source)
        TriggerClientEvent('som-burglary:client:exit', source, back and { x = back.x, y = back.y, z = back.z })
        TriggerClientEvent('som-burglary:client:objective', source, nil)
    end
end

local function close(groupId, status)
    local run = runs[groupId]
    if not run then return end

    MySQL.update.await("UPDATE som_burglary_runs SET status = ? WHERE id = ? AND status = 'active'", { status, run.id })
    clear(groupId)
    exports['som-jobboard']:finish(groupId)
end

local function addNoise(run, source, points)
    run.noise = run.noise + points
    if run.alerted then return end

    local n = Config.noise
    if math.random() >= math.min(n.maxChance, run.noise * n.perPoint) then return end

    run.alerted = true
    exports['som-dispatch']:alert(source, 'burglary', {
        coords = run.house.coords,
        message = ('A neighbour reports someone breaking in at %s'):format(run.house.label),
    })
end

-- ---------------------------------------------------------------------------
-- Starting a run
-- ---------------------------------------------------------------------------

---A free house for the tier. One conditional insert claims it, so two crews
---cannot take the same place, and it is also the cooldown: a house stays shut for
---a while after a run, longer after a failed one.
---@return table|nil house, number|nil runId
local function claimHouse(tier, info)
    local cfg = Config.tiers[tier]
    local candidates = {}
    for _, house in ipairs(Config.houses) do
        if house.tier == tier and usable(house) then candidates[#candidates + 1] = house end
    end

    for i = #candidates, 2, -1 do
        local j = math.random(i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end

    for _, house in ipairs(candidates) do
        local id = MySQL.insert.await([[
            INSERT INTO som_burglary_runs (house, tier, group_id)
            SELECT ?, ?, ? FROM DUAL
            WHERE NOT EXISTS (
                SELECT 1 FROM som_burglary_runs
                WHERE house = ? AND (status = 'active'
                    OR created_at > DATE_SUB(NOW(), INTERVAL ? MINUTE)
                    OR (status = 'failed' AND created_at > DATE_SUB(NOW(), INTERVAL ? MINUTE)))
            )
        ]], { house.id, tier, info.id, house.id, cfg.cooldownMinutes, cfg.failCooldownMinutes })

        if id and id > 0 then return house, id end
    end
end

local function start(tier, info)
    local cfg = Config.tiers[tier]
    if policeOnDuty() < cfg.policeMin or not info.leader or not isNight() then return false end

    local house, runId = claimHouse(tier, info)
    if not house then return false end

    local run = {
        id = runId, group = info.id, tier = tier, house = house, index = houseIndex(house), stage = 'door',
        members = {}, inside = {}, sessions = {}, looted = 0, noise = 0, alerted = false, attempts = 2, picking = false,
        expires = os.time() + Config.minutes * 60,
    }

    for _, m in ipairs(info.members) do
        if m.source then
            run.members[m.citizenid] = m.source
            byCitizen[m.citizenid] = info.id
        end
    end

    runs[info.id] = run
    sendObjective(run)
    return true
end

-- ---------------------------------------------------------------------------
-- The door
-- ---------------------------------------------------------------------------

lib.callback.register('som-burglary:server:breakIn', function(source)
    local run = runOf(source)
    if not run then return done(false, 'you are not on a job') end
    if run.stage ~= 'door' then return done(false, 'the door is already open') end
    if not near(source, run.house.coords, Config.interactDistance) then return done(false, 'you are too far away') end
    if not isNight() then return done(false, 'it is too bright to try this') end

    local cfg = Config.tiers[run.tier]
    if (ox:Search(source, 'count', cfg.tool) or 0) < 1 then return done(false, 'you need a better pick for this lock') end
    if run.picking then return done(false, 'someone is already on it') end
    run.picking = true

    local ran, won = pcall(function() return exports['som-hack']:run(source, cfg.hack.kind, cfg.hack.level) end)
    run.picking = false

    if not ran then
        print(('[som-burglary] lock pick failed: %s'):format(tostring(won)))
        return done(false, 'try again in a moment')
    end

    if runs[run.group] ~= run then return done(false, 'the job is over') end

    if won then
        run.stage = 'open'
        sendObjective(run)
        return done(true)
    end

    addNoise(run, source, Config.noise.fail)
    if math.random() < cfg.breakChance then ox:RemoveItem(source, cfg.tool, 1) end

    run.attempts = run.attempts - 1
    if run.attempts <= 0 then
        close(run.group, 'failed')
        return done(false, 'the lock beat you and the street is awake')
    end

    return done(false, 'that did not work')
end)

-- ---------------------------------------------------------------------------
-- Inside
-- ---------------------------------------------------------------------------

lib.callback.register('som-burglary:server:enter', function(source)
    local run = runOf(source)
    if not run then return done(false, 'you are not on a job') end
    if run.stage ~= 'open' or run.inside[source] then return done(false, 'not now') end
    if not near(source, run.house.coords, Config.interactDistance) then return done(false, 'you are too far away') end

    local offset = exports['som-housing']:shellOffset(run.house.shell)
    if not offset then return done(false, 'this interior is not available yet') end

    local spots = {}
    for i, spot in ipairs(spotsOf(run.house)) do
        local c = inShell(run, spot.offset)
        spots[i] = { x = c.x, y = c.y, z = c.z, label = spot.label }
    end

    returnTo[source] = GetEntityCoords(GetPlayerPed(source))
    run.inside[source] = true
    SetPlayerRoutingBucket(source, Config.bucketBase + run.index)

    local void = voidOf(run)
    return done(true, nil, { shell = run.house.shell, void = { x = void.x, y = void.y, z = void.z }, offset = offset, spots = spots })
end)

lib.callback.register('som-burglary:server:leave', function(source)
    local run = runOf(source)
    if not run or not run.inside[source] then return done(false, 'not inside') end

    local offset = exports['som-housing']:shellOffset(run.house.shell)
    local exit = inShell(run, offset)
    -- Near the door outside too, so a shell that failed to load on the client can still be left.
    if not near(source, exit, Config.exitDistance) and not near(source, run.house.coords, Config.interactDistance) then
        return done(false, 'you are too far from the door')
    end

    local back = sendOut(run, source)
    return done(true, nil, { coords = { x = back.x, y = back.y, z = back.z } })
end)

local function validSpot(run, source, spot)
    if math.type(spot) ~= 'integer' or not spotsOf(run.house)[spot] then return false, 'bad request' end
    if not run.inside[source] then return false, 'you are not inside' end
    if not near(source, inShell(run, spotsOf(run.house)[spot].offset), Config.spotDistance) then return false, 'you are too far away' end
    return true
end

local function taken(run, spot)
    return MySQL.scalar.await('SELECT 1 FROM som_burglary_loot WHERE run_id = ? AND spot = ?', { run.id, spot }) ~= nil
end

lib.callback.register('som-burglary:server:searchStart', function(source, spot)
    local run = runOf(source)
    if not run then return done(false, 'you are not on a job') end

    local ok, err = validSpot(run, source, spot)
    if not ok then return done(false, err) end
    if taken(run, spot) then return done(false, 'there is nothing left here') end

    run.sessions[source] = { spot = spot, started = GetGameTimer() }
    return done(true, nil, { seconds = Config.searchSeconds })
end)

lib.callback.register('som-burglary:server:searchCancel', function(source)
    local run = runOf(source)
    if run then run.sessions[source] = nil end
    return done(true)
end)

local function roll(cfg)
    local out = {}
    for _ = 1, cfg.rolls do
        local total = 0
        for _, entry in ipairs(cfg.loot) do total = total + entry.weight end

        local pick = math.random() * total
        for _, entry in ipairs(cfg.loot) do
            pick = pick - entry.weight
            if pick <= 0 then
                out[#out + 1] = { item = entry.item, count = math.random(entry.min, entry.max) }
                break
            end
        end
    end
    return out
end

lib.callback.register('som-burglary:server:searchDone', function(source, spot)
    local run = runOf(source)
    if not run then return done(false, 'you are not on a job') end

    local session = run.sessions[source]
    if not session or session.spot ~= spot then return done(false, 'start searching first') end
    run.sessions[source] = nil

    local ok, err = validSpot(run, source, spot)
    if not ok then return done(false, err) end
    if GetGameTimer() - session.started < Config.searchSeconds * 1000 then return done(false, 'you were too quick') end

    local player = core:getPlayer(source)
    if MySQL.update.await('INSERT IGNORE INTO som_burglary_loot (run_id, spot, citizenid) VALUES (?, ?, ?)',
        { run.id, spot, player.citizenid }) ~= 1 then
        return done(false, 'there is nothing left here')
    end

    local drops, given = roll(Config.tiers[run.tier]), {}
    for _, drop in ipairs(drops) do
        if not ox:AddItem(source, drop.item, drop.count) then
            for _, g in ipairs(given) do ox:RemoveItem(source, g.item, g.count) end
            MySQL.update.await('DELETE FROM som_burglary_loot WHERE run_id = ? AND spot = ?', { run.id, spot })
            return done(false, 'you cannot carry any more')
        end
        given[#given + 1] = drop
    end

    addNoise(run, source, Config.noise.search)

    run.looted = run.looted + 1
    if run.looted >= #spotsOf(run.house) then close(run.group, 'done') end
    return done(true, nil, { items = given })
end)

-- ---------------------------------------------------------------------------
-- Upkeep
-- ---------------------------------------------------------------------------

function Burglary.Sweep()
    for groupId, run in pairs(runs) do
        if run.expires <= os.time() then close(groupId, 'failed') end
    end
end

---Running inside is noise. Speed is read on the server, never reported.
function Burglary.Listen()
    for _, run in pairs(runs) do
        for source in pairs(run.inside) do
            local ped = GetPlayerPed(source)
            if ped ~= 0 and GetEntitySpeed(ped) > Config.noise.runSpeed then addNoise(run, source, Config.noise.run) end
        end
    end
end

AddEventHandler('som-groups:server:changed', function(groupId)
    local run = runs[groupId]
    if not run then return end

    local info = exports['som-groups']:getGroupById(groupId)
    if not info then return clear(groupId) end

    local still = {}
    for _, m in ipairs(info.members) do still[m.citizenid] = true end

    for cid, source in pairs(run.members) do
        if not still[cid] then
            run.members[cid] = nil
            byCitizen[cid] = nil
            local back = sendOut(run, source)
            TriggerClientEvent('som-burglary:client:exit', source, back and { x = back.x, y = back.y, z = back.z })
            TriggerClientEvent('som-burglary:client:objective', source, nil)
        end
    end
end)

AddEventHandler('som:server:playerUnloaded', function(source, citizenid)
    if type(citizenid) ~= 'string' then return end
    local run = runs[byCitizen[citizenid]]
    if not run then return end

    local s = run.members[citizenid]
    if s then sendOut(run, s) end
    run.members[citizenid] = nil
    byCitizen[citizenid] = nil
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for groupId in pairs(runs) do clear(groupId) end
end)

for tier, cfg in pairs(Config.tiers) do
    exports['som-jobboard']:registerProvider({
        id = 'burglary_' .. tier, label = cfg.label, summary = ('Needs %s, at night'):format(cfg.tool),
        minSize = cfg.minSize, maxSize = cfg.maxSize, slots = cfg.slots,
        canStart = function(info)
            if policeOnDuty() < cfg.policeMin then return false, 'the city is too quiet for this' end
            if not isNight() then return false, 'wait for dark' end

            local any = false
            for _, house in ipairs(Config.houses) do
                if house.tier == tier and usable(house) then any = true end
            end
            if not any then return false, 'no houses are open yet' end

            if not info.leader or (ox:Search(info.leader, 'count', cfg.tool) or 0) < 1 then
                return false, ('the leader needs %s'):format(cfg.tool)
            end
            return true
        end,
        start = function(info) return start(tier, info) end,
    })
end

CreateThread(function()
    MySQL.update.await("UPDATE som_burglary_runs SET status = 'failed' WHERE status = 'active'")
end)

CreateThread(function()
    while true do
        Wait(2000)
        pcall(Burglary.Listen)
    end
end)

CreateThread(function()
    while true do
        Wait(30000)
        pcall(Burglary.Sweep)
    end
end)

CreateThread(function() SomPlacements.Apply(Config) end)
