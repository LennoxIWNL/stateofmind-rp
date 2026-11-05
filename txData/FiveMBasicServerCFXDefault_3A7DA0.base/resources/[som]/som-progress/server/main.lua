--- Skill tracks. Experience is only ever added by other server resources
--- (`addXp` is an export, there is no client event), capped per track per day
--- by one SQL statement so the cap cannot be raced. Levels are computed from the
--- experience, never stored. Made by Lennox.

local core = exports['som-core']

local function levelFor(xp)
    local level = 1
    for n = 2, Config.maxLevel do
        if xp >= Config.base * (n - 1) ^ 2 then level = n else break end
    end
    return level
end

local function needed(level)
    if level >= Config.maxLevel then return nil end
    return Config.base * level ^ 2
end

local function xpOf(citizenid, track)
    return tonumber(MySQL.scalar.await('SELECT xp FROM som_skills WHERE citizenid = ? AND track = ?', { citizenid, track })) or 0
end

---@return number gained, number level, boolean leveledUp
local function addXp(source, track, amount)
    local player = core:getPlayer(source)
    if not player or not Config.tracks[track] then return 0, 1, false end

    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 or amount > 500 then return 0, 1, false end

    local before = xpOf(player.citizenid, track)
    MySQL.update.await([[
        INSERT INTO som_skills (citizenid, track, xp, day_xp, day) VALUES (?, ?, LEAST(?, ?), LEAST(?, ?), CURDATE())
        ON DUPLICATE KEY UPDATE
            xp = xp + LEAST(?, GREATEST(0, ? - IF(day = CURDATE(), day_xp, 0))),
            day_xp = IF(day = CURDATE(), day_xp, 0) + LEAST(?, GREATEST(0, ? - IF(day = CURDATE(), day_xp, 0))),
            day = CURDATE()
    ]], { player.citizenid, track, amount, Config.dailyCap, amount, Config.dailyCap, amount, Config.dailyCap, amount, Config.dailyCap })

    local after = xpOf(player.citizenid, track)
    local was, now = levelFor(before), levelFor(after)
    if now > was then
        TriggerClientEvent('som:client:notify', source, ('%s level %d'):format(Config.tracks[track].label, now), 'success')
    end
    return after - before, now, now > was
end

exports('addXp', addXp)

exports('getLevel', function(source, track)
    local player = core:getPlayer(source)
    if not player or not Config.tracks[track] then return 1 end
    return levelFor(xpOf(player.citizenid, track))
end)

local function view(player)
    local owned = {}
    for _, r in ipairs(MySQL.query.await('SELECT track, xp FROM som_skills WHERE citizenid = ?', { player.citizenid }) or {}) do
        owned[r.track] = tonumber(r.xp) or 0
    end

    local rows = {}
    for id, t in pairs(Config.tracks) do
        local xp = owned[id] or 0
        local level = levelFor(xp)
        local nextAt = needed(level)
        rows[#rows + 1] = {
            id = id,
            title = ('%s, level %d'):format(t.label, level),
            sub = nextAt and ('%d of %d to the next level. %s'):format(xp, nextAt, t.blurb) or ('Mastered. ' .. t.blurb),
        }
    end
    table.sort(rows, function(a, b) return a.id < b.id end)
    for _, r in ipairs(rows) do r.id = nil end
    return { sections = { { title = 'Your skills', rows = rows } } }
end

exports['som-phone']:registerApp({
    id = 'skills', label = 'Skills', icon = 'briefcase', colour = '#30d158', order = 70,
    reads = { view = true },
    handler = function(source, action)
        local player = core:getPlayer(source)
        if action ~= 'view' or not player then return { success = false, error = 'not available' } end
        return { success = true, view = view(player) }
    end,
})

Progress = { LevelFor = levelFor, Needed = needed }
