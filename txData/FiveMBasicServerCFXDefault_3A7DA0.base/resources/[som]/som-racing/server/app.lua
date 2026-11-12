--- The phone app. Every tap is checked again here; the client never says who it is,
--- what a race costs or which track is meant beyond an id.

local core = exports['som-core']
local done = Racing.Done

local function boardRows(trackId)
    local rows = {}
    for _, t in ipairs(MySQL.query.await('SELECT alias, best_ms FROM som_race_times WHERE track_id = ? ORDER BY best_ms ASC LIMIT ?',
        { trackId, Config.boardRows }) or {}) do
        rows[#rows + 1] = { title = t.alias, sub = ('%d.%03d s'):format(t.best_ms // 1000, t.best_ms % 1000) }
    end
    return rows
end

local function view(source, player)
    Racing.Collect(player.citizenid)
    if not Config.enabled then return { sections = {}, empty = 'Street racing is closed' } end
    local tier = Racing.Tier(source, player)
    if not tier then return { sections = {}, empty = 'You need a racing dongle' } end

    local alias = Racing.Alias(player.citizenid)
    local sections, buttons = {}, {}

    local owed = MySQL.scalar.await("SELECT COALESCE(SUM(owed), 0) FROM som_race_entries WHERE citizenid = ? AND state = 'owed'", { player.citizenid })
    local me = { { title = alias or 'No alias yet', sub = tier == 'creator' and 'Creator dongle' or 'Racer dongle' } }
    if owed > 0 then me[#me + 1] = { title = ('$%d waiting'):format(owed), sub = 'Could not be paid yet, open this again' } end
    sections[#sections + 1] = { title = 'You', rows = me }

    if not alias then
        buttons[#buttons + 1] = { label = 'Pick an alias', action = 'alias', prompt = { field = 'text', label = 'Alias', maxLength = Config.alias.max } }
        return { sections = sections, buttons = buttons }
    end

    local mine = Racing.live[Racing.byRacer[source]]
    if mine then
        local joined = 0
        for _ in pairs(mine.racers) do joined = joined + 1 end
        sections[#sections + 1] = { title = 'Your race', rows = { {
            title = mine.name, sub = ('%d racers, $%d each, %d laps, %s'):format(joined, mine.stake, mine.laps, mine.status),
        } } }
        if mine.status == 'open' then
            if mine.host == source then buttons[#buttons + 1] = { label = 'Start now', action = 'start' } end
            buttons[#buttons + 1] = { label = mine.host == source and 'Cancel race' or 'Leave race', action = 'leave', danger = true }
        end
    else
        local open = {}
        for id, race in pairs(Racing.live) do
            if race.status == 'open' then
                open[#open + 1] = { title = race.name, sub = ('$%d buy-in, %d laps'):format(race.stake, race.laps), action = 'join', payload = { id = id } }
            end
        end
        sections[#sections + 1] = { title = 'Open races', rows = open }
    end

    local tracks = {}
    for _, t in ipairs(MySQL.query.await('SELECT id, name, length_m FROM som_race_tracks WHERE active = 1 ORDER BY name') or {}) do
        tracks[#tracks + 1] = { title = t.name, sub = ('%d m'):format(t.length_m), action = 'pick', payload = { id = t.id } }
    end
    sections[#sections + 1] = { title = 'Tracks', rows = tracks }

    local picked = Racing.picked[source]
    local track = picked and MySQL.single.await('SELECT id, name, creator_cid FROM som_race_tracks WHERE id = ? AND active = 1', { picked })
    if track then
        sections[#sections + 1] = { title = 'Lap board: ' .. track.name, rows = boardRows(track.id) }
        if not mine then
            buttons[#buttons + 1] = { label = 'Host on ' .. track.name:sub(1, 20), action = 'host', payload = { id = track.id },
                prompt = { field = 'text', label = 'laps and buy-in, for example 3 500', maxLength = 16 } }
        end
        if track.creator_cid == player.citizenid then
            buttons[#buttons + 1] = { label = 'Delete ' .. track.name:sub(1, 20), action = 'delete', payload = { id = track.id }, danger = true }
        end
    end
    if tier == 'creator' then buttons[#buttons + 1] = { label = 'Record a track', action = 'record' } end
    return { sections = sections, buttons = buttons, empty = 'No tracks yet' }
end

local actions = {}

function actions.alias(source, payload, player) return Racing.SetAlias(player, payload.text) end
function actions.record(source, _, player) return Racing.Record(source, player) end
function actions.leave(source) return Racing.Leave(source) end

function actions.pick(source, payload)
    local id = math.tointeger(payload.id)
    if not id or not MySQL.scalar.await('SELECT 1 FROM som_race_tracks WHERE id = ? AND active = 1', { id }) then return done(false, 'no such track') end
    Racing.picked[source] = id
    return done(true)
end

function actions.host(source, payload, player)
    local laps, stake = tostring(payload.text):match('^%s*(%d+)%s*(%d*)%s*$')
    return Racing.Host(source, player, math.tointeger(payload.id), tonumber(laps), stake == '' and 0 or tonumber(stake))
end

function actions.join(source, payload, player)
    local id = math.tointeger(payload.id)
    if not id then return done(false, 'no such race') end
    return Racing.Join(source, player, id)
end

function actions.start(source)
    local race = Racing.live[Racing.byRacer[source]]
    if not race or race.host ~= source then return done(false, 'only the host starts a race') end
    return Racing.Start(race.id)
end

function actions.delete(source, payload, player)
    local id = math.tointeger(payload.id)
    if not id then return done(false, 'no such track') end
    local res = Racing.DeleteTrack(player, id)
    if res.success and Racing.picked[source] == id then Racing.picked[source] = nil end
    return res
end

exports['som-phone']:registerApp({
    id = 'racing', label = 'Street Racing', icon = 'briefcase', colour = '#ff9f0a', order = 68,
    reads = { view = true },
    handler = function(source, action, payload)
        local player = core:getPlayer(source)
        if not player then return done(false, 'not available') end
        payload = type(payload) == 'table' and payload or {}
        if action == 'view' then return { success = true, view = view(source, player) } end

        local fn = type(action) == 'string' and actions[action]
        if not fn then return done(false, 'not available') end
        return fn(source, payload, player)
    end,
})
