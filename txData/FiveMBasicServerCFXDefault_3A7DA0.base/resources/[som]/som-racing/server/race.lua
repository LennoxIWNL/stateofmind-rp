--- Races and their money. A buy-in is a row in som_race_entries, never a number
--- in memory: pending (inserted, not yet debited) -> held (debited) -> owed
--- (settled, waiting to be paid) -> paid. A crash leaves pending rows, which
--- startup voids, so nothing is ever paid that was not taken. Each hop is one
--- conditional UPDATE, so a double settle or a double collect pays once.
--- The client reports "I passed checkpoint n"; whether it did, and who won, is
--- decided here from the server's own view of the car and clock.

local core = exports['som-core']
local C = Config.checkpoint

local live, byRacer = Racing.live, Racing.byRacer

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- ---------------------------------------------------------------------------
-- Paying
-- ---------------------------------------------------------------------------

---Claims one owed entry, then credits it. A failed credit puts the claim back.
local function pay(entryId, citizenid, amount)
    local player = core:getPlayerByCitizenId(citizenid)
    if not player then return false end
    if MySQL.update.await("UPDATE som_race_entries SET state = 'paid' WHERE id = ? AND state = 'owed'", { entryId }) ~= 1 then return false end
    if amount > 0 then
        local ok, credited = pcall(function() return core:addMoney(player.source, Config.account, amount, 'street-race') end)
        if not ok or not credited then
            MySQL.update.await("UPDATE som_race_entries SET state = 'owed' WHERE id = ? AND state = 'paid'", { entryId })
            return false
        end
        Racing.Tell(player.source, ('Race money: $%d'):format(amount), 'success')
    end
    return true
end

function Racing.Collect(citizenid)
    for _, e in ipairs(MySQL.query.await("SELECT id, owed FROM som_race_entries WHERE citizenid = ? AND state = 'owed'", { citizenid }) or {}) do
        pay(e.id, citizenid, e.owed)
    end
end

local function payRace(raceId)
    for _, e in ipairs(MySQL.query.await("SELECT id, citizenid, owed FROM som_race_entries WHERE race_id = ? AND state = 'owed'", { raceId }) or {}) do
        pay(e.id, e.citizenid, e.owed)
    end
end

local function refundRace(raceId)
    MySQL.update.await("UPDATE som_race_entries SET state = 'owed', owed = stake WHERE race_id = ? AND state = 'held'", { raceId })
    payRace(raceId)
end

local function refundEntry(entryId, citizenid)
    if MySQL.update.await("UPDATE som_race_entries SET state = 'owed', owed = stake WHERE id = ? AND state = 'held'", { entryId }) == 1 then
        local row = MySQL.single.await('SELECT owed FROM som_race_entries WHERE id = ?', { entryId })
        pay(entryId, citizenid, row and row.owed or 0)
    end
end

-- ---------------------------------------------------------------------------
-- Ending a race
-- ---------------------------------------------------------------------------

local function drop(race)
    live[race.id] = nil
    for source in pairs(race.racers) do
        byRacer[source] = nil
        TriggerClientEvent('som-racing:client:stop', source)
    end
end

function Racing.Cancel(raceId)
    local race = live[raceId]
    if MySQL.update.await("UPDATE som_races SET status = 'cancelled' WHERE id = ? AND status IN ('open', 'running')", { raceId }) ~= 1 then return false end
    refundRace(raceId)
    if race then drop(race) end
    return true
end

---Pays the finishers on the split and keeps the stakes of everyone else in the pot.
function Racing.Settle(raceId)
    local race = live[raceId]
    if not race or race.status ~= 'running' then return false end
    race.status = 'settling'
    if MySQL.update.await("UPDATE som_races SET status = 'done' WHERE id = ? AND status = 'running'", { raceId }) ~= 1 then return false end

    local order = race.order
    if #order == 0 then
        refundRace(raceId)
    else
        local pot = MySQL.scalar.await("SELECT COALESCE(SUM(stake), 0) FROM som_race_entries WHERE race_id = ? AND state = 'held'", { raceId }) or 0
        local split = Config.split[math.min(#order, #Config.split)]
        local shares, given = {}, 0
        for i, pct in ipairs(split) do
            shares[i] = pot * pct // 100
            given = given + shares[i]
        end
        shares[1] = shares[1] + (pot - given)

        for i = 1, #split do
            local r = order[i]
            MySQL.update.await("UPDATE som_race_entries SET state = 'owed', owed = ?, position = ?, total_ms = ? WHERE id = ? AND state = 'held'",
                { shares[i], i, r.ms, r.entry })
        end
        MySQL.update.await("UPDATE som_race_entries SET state = 'paid', owed = 0 WHERE race_id = ? AND state = 'held'", { raceId })
        payRace(raceId)
    end
    drop(race)
    return true
end

---Takes a racer out before the start with their stake back.
local function leaveOpen(race, source)
    local r = race.racers[source]
    race.racers[source], byRacer[source] = nil, nil
    refundEntry(r.entry, r.cid)
    TriggerClientEvent('som-racing:client:stop', source)
end

local function settleIfDone(race)
    for _, r in pairs(race.racers) do
        if not r.done and not r.dnf then return end
    end
    Racing.Settle(race.id)
end

-- ---------------------------------------------------------------------------
-- Opening, joining, starting
-- ---------------------------------------------------------------------------

---One atomic claim decides whether the seat is free; the debit comes second and the
---row only becomes held once the money is really taken.
function Racing.Enter(source, player, race)
    local alias = Racing.Alias(player.citizenid)
    if not alias then return Racing.Done(false, 'pick an alias first') end
    if not Racing.NearStart(source, race.points[1]) then return Racing.Done(false, 'get to the start line first') end
    if not Racing.InVehicle(source) then return Racing.Done(false, 'you need to be in a car') end

    local id = MySQL.insert.await([[
        INSERT IGNORE INTO som_race_entries (race_id, citizenid, alias, stake, state)
        SELECT r.id, ?, ?, r.stake, 'pending' FROM som_races r
        WHERE r.id = ? AND r.status = 'open' AND r.join_until > NOW()
        AND (SELECT COUNT(*) FROM som_race_entries e WHERE e.race_id = r.id AND e.state IN ('pending', 'held')) < ?
        AND NOT EXISTS (
            SELECT 1 FROM som_race_entries e2 JOIN som_races r2 ON r2.id = e2.race_id
            WHERE e2.citizenid = ? AND e2.state IN ('pending', 'held') AND r2.status IN ('open', 'running')
        )
    ]], { player.citizenid, alias, race.id, Config.maxRacers, player.citizenid })
    if not id or id < 1 then return Racing.Done(false, 'you cannot join that race') end

    if race.stake > 0 then
        local ok, taken = pcall(function() return core:removeMoney(source, Config.account, race.stake, 'street-race') end)
        if not ok or not taken then
            MySQL.update.await("DELETE FROM som_race_entries WHERE id = ? AND state = 'pending'", { id })
            return Racing.Done(false, ('you need $%d on you'):format(race.stake))
        end
    end
    if MySQL.update.await("UPDATE som_race_entries SET state = 'held' WHERE id = ? AND state = 'pending'", { id }) ~= 1 then
        Racing.Log(('MONEY LOST: entry %d of %s was debited but could not be held'):format(id, player.citizenid))
        return Racing.Done(false, 'could not join, ask staff')
    end

    -- The race may have started or been cancelled while the debit was in flight.
    if live[race.id] ~= race or race.status ~= 'open' then
        refundEntry(id, player.citizenid)
        return Racing.Done(false, 'that race is no longer open')
    end
    race.racers[source] = { cid = player.citizenid, alias = alias, entry = id, seq = 0, bad = 0, lastAt = 0 }
    byRacer[source] = race.id
    return Racing.Done(true)
end

function Racing.Host(source, player, trackId, laps, stake)
    if not Config.enabled then return Racing.Done(false, 'street racing is closed') end
    local tier, uid = Racing.Tier(source, player)
    if not tier then return Racing.Done(false, 'you need a racing dongle') end
    if byRacer[source] then return Racing.Done(false, 'you are already in a race') end
    if not laps or laps < 1 or laps > Config.maxLaps then return Racing.Done(false, ('laps are 1 to %d'):format(Config.maxLaps)) end
    if not stake or stake < Config.stake.min or stake > Config.stake.max then
        return Racing.Done(false, ('the stake is $%d to $%d'):format(Config.stake.min, Config.stake.max))
    end

    local track = trackId and MySQL.single.await('SELECT id, name, points FROM som_race_tracks WHERE id = ? AND active = 1', { trackId })
    if not track then return Racing.Done(false, 'pick a track first') end
    local points = {}
    for i, p in ipairs(json.decode(track.points)) do points[i] = vec3(p.x, p.y, p.z) end

    local id = MySQL.insert.await([[
        INSERT INTO som_races (track_id, host_cid, laps, stake, join_until)
        SELECT ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? SECOND) FROM DUAL
        WHERE NOT EXISTS (SELECT 1 FROM som_races WHERE host_cid = ? AND status IN ('open', 'running'))
        AND (SELECT COUNT(*) FROM som_races WHERE status = 'open') < ?
    ]], { track.id, player.citizenid, laps, stake, Config.joinSeconds, player.citizenid, Config.maxOpenRaces })
    if not id or id < 1 then return Racing.Done(false, 'you cannot open another race right now') end

    local race = { id = id, trackId = track.id, name = track.name, points = points, laps = laps, stake = stake,
        host = source, status = 'open', racers = {}, order = {} }
    live[id] = race
    Racing.Log(('race %d hosted by %s with dongle %s'):format(id, player.citizenid, uid))
    local entered = Racing.Enter(source, player, race)
    if not entered.success then
        MySQL.update.await("UPDATE som_races SET status = 'cancelled' WHERE id = ? AND status = 'open'", { id })
        live[id] = nil
        return entered
    end
    return Racing.Done(true, nil, { id = id })
end

function Racing.Join(source, player, raceId)
    if not Config.enabled then return Racing.Done(false, 'street racing is closed') end
    if not Racing.Tier(source, player) then return Racing.Done(false, 'you need a racing dongle') end
    if byRacer[source] then return Racing.Done(false, 'you are already in a race') end
    local race = live[raceId]
    if not race or race.status ~= 'open' then return Racing.Done(false, 'that race is no longer open') end
    return Racing.Enter(source, player, race)
end

function Racing.Leave(source)
    local race = live[byRacer[source]]
    if not race then return Racing.Done(false, 'you are not in a race') end
    if race.status == 'running' then
        race.racers[source].dnf = true
        settleIfDone(race)
        return Racing.Done(true)
    end
    if race.status ~= 'open' then return Racing.Done(false, 'too late') end
    if race.host == source then Racing.Cancel(race.id) else leaveOpen(race, source) end
    return Racing.Done(true)
end

function Racing.Start(raceId)
    local race = live[raceId]
    if not race or race.status ~= 'open' then return Racing.Done(false, 'that race is not open') end
    if count(race.racers) < 2 then return Racing.Done(false, 'a race needs two racers') end
    if MySQL.update.await("UPDATE som_races SET status = 'running', started_at = NOW() WHERE id = ? AND status = 'open'", { raceId }) ~= 1 then
        return Racing.Done(false, 'that race is not open')
    end
    race.status = 'running'

    for source in pairs(race.racers) do
        if not (Racing.NearStart(source, race.points[1]) and Racing.InVehicle(source)) then
            leaveOpen(race, source)
            Racing.Tell(source, 'You were not on the start line, stake returned', 'error')
        end
    end
    if count(race.racers) < 2 then
        Racing.Cancel(raceId)
        return Racing.Done(false, 'not enough racers on the line')
    end

    race.startMs = GetGameTimer() + Config.countdownSeconds * 1000
    local view = {}
    for i, p in ipairs(race.points) do view[i] = { x = p.x, y = p.y, z = p.z } end
    local any
    for source, r in pairs(race.racers) do
        r.acceptAt, r.lapAt = race.startMs, race.startMs
        TriggerClientEvent('som-racing:client:begin', source,
            { points = view, laps = race.laps, countdown = Config.countdownSeconds, radius = C.radius })
        any = source
    end
    if math.random() < Config.dispatch.chance then
        exports['som-dispatch']:alert(any, 'streetRace', { coords = race.points[1], message = 'Engines revving, a street race is starting' })
    end
    return Racing.Done(true)
end

-- ---------------------------------------------------------------------------
-- Judging checkpoints
-- ---------------------------------------------------------------------------

local function refuse(race, source, r)
    r.bad = r.bad + 1
    if r.bad >= C.maxBad then
        r.dnf = true
        Racing.Tell(source, 'You are out of the race', 'error')
        TriggerClientEvent('som-racing:client:stop', source)
        settleIfDone(race)
    end
end

function Racing.Checkpoint(source, idx)
    local race = live[byRacer[source]]
    local r = race and race.racers[source]
    local now = GetGameTimer()
    if not r or race.status ~= 'running' or r.done or r.dnf or now < race.startMs or now - r.lastAt < C.minGapMs then return end
    r.lastAt = now

    local n, want = #race.points, r.seq + 1
    local at, prev = race.points[want % n + 1], race.points[(want - 1) % n + 1]
    local ped = GetPlayerPed(source)
    local floorMs = #(at - prev) / C.maxSpeed * 1000
    if math.tointeger(idx) ~= want or #(GetEntityCoords(ped) - at) > C.radius + C.slack
        or GetVehiclePedIsIn(ped, false) == 0 or now - r.acceptAt < floorMs then
        return refuse(race, source, r)
    end

    r.seq = want
    if want % n == 0 then
        local lap = now - r.lapAt
        r.best, r.lapAt = math.min(r.best or lap, lap), now
    end
    r.acceptAt = now
    TriggerClientEvent('som-racing:client:progress', source, want)
    if want < n * race.laps then return end

    r.done, r.ms = true, now - race.startMs
    race.order[#race.order + 1] = r
    race.firstFinishAt = race.firstFinishAt or now
    local best = race.laps == 1 and r.ms or r.best
    MySQL.insert.await([[
        INSERT INTO som_race_times (track_id, citizenid, alias, best_ms) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE best_ms = LEAST(best_ms, VALUES(best_ms)), alias = VALUES(alias)
    ]], { race.trackId, r.cid, r.alias, best })
    Racing.Tell(source, ('Finished in place %d'):format(#race.order), 'success')
    settleIfDone(race)
end

RegisterNetEvent('som-racing:server:checkpoint', function(idx)
    Racing.Checkpoint(source, idx)
end)

-- ---------------------------------------------------------------------------
-- Timers and restarts
-- ---------------------------------------------------------------------------

function Racing.Tick()
    local ids = {}
    for id in pairs(live) do ids[#ids + 1] = id end
    local now = GetGameTimer()
    for _, id in ipairs(ids) do
        local race = live[id]
        if race and race.status == 'open' then
            if MySQL.scalar.await("SELECT 1 FROM som_races WHERE id = ? AND status = 'open' AND join_until <= NOW()", { id }) then
                if not Racing.Start(id).success and live[id] and live[id].status == 'open' then Racing.Cancel(id) end
            end
        elseif race and race.status == 'running' then
            local late = race.firstFinishAt and now - race.firstFinishAt > Config.graceSeconds * 1000
            if late or now - race.startMs > Config.maxRaceSeconds * 1000 then Racing.Settle(id) end
        end
    end
end

---Nothing carries over a restart: stakes that were taken go back to their owners.
function Racing.Reset()
    MySQL.update.await("UPDATE som_race_entries SET state = 'void' WHERE state = 'pending'")
    MySQL.update.await("UPDATE som_race_entries SET state = 'owed', owed = stake WHERE state = 'held' AND race_id IN (SELECT id FROM som_races WHERE status IN ('open', 'running'))")
    MySQL.update.await("UPDATE som_races SET status = 'cancelled' WHERE status IN ('open', 'running')")
end

AddEventHandler('playerDropped', function() Racing.Leave(source) end)
AddEventHandler('som:server:playerUnloaded', function(src) Racing.Leave(src) end)

CreateThread(function()
    Racing.Reset()
    while true do
        Wait(1000)
        Racing.Tick()
    end
end)
