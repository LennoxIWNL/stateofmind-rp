--- A first hour. Every step is read from data the server already holds, at the
--- moment it is asked for. The settling-in payment is claimed first (one row per
--- character, inside a global monthly cap), then paid from the treasury.

local core = exports['som-core']

local function done(ok, err, extra)
    local r = extra or {}
    r.success, r.error = ok == true, (not ok) and err or nil
    return r
end

-- ---------------------------------------------------------------------------
-- Which job someone holds, and since when
-- ---------------------------------------------------------------------------

local function track(citizenid, job)
    if type(citizenid) ~= 'string' or type(job) ~= 'string' then return end
    MySQL.update.await([[
        INSERT INTO som_welcome_jobs (citizenid, job) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE since = IF(job = VALUES(job), since, NOW()), job = VALUES(job)
    ]], { citizenid, job })
end

AddEventHandler('som:server:playerLoaded', function(source, citizenid)
    local player = core:getPlayer(source)
    if player then track(citizenid, player.job.name) end
end)

AddEventHandler('som:server:jobChanged', function(_, citizenid, job)
    if type(job) == 'table' then track(citizenid, job.name) end
end)

-- ---------------------------------------------------------------------------
-- Steps
-- ---------------------------------------------------------------------------

local function steps(player)
    local cid = player.citizenid
    local licence = MySQL.scalar.await([[
        SELECT 1 FROM som_licenses
        WHERE citizenid = ? AND type = 'driver' AND revoked = 0 AND (suspended_until IS NULL OR suspended_until <= NOW())
    ]], { cid })

    local job = player.job.name ~= 'unemployed' and MySQL.scalar.await([[
        SELECT 1 FROM som_welcome_jobs
        WHERE citizenid = ? AND job = ? AND since <= DATE_SUB(NOW(), INTERVAL ? MINUTE)
    ]], { cid, player.job.name, Config.jobMinutes })

    local home = MySQL.scalar.await(
        "SELECT 1 FROM som_property_owners WHERE citizenid = ? AND role IN ('owner', 'tenant') LIMIT 1", { cid })

    return { licence = licence ~= nil, job = job ~= nil and job ~= false, home = home ~= nil }
end

local function claimed(cid)
    return MySQL.scalar.await('SELECT 1 FROM som_welcome_claims WHERE citizenid = ?', { cid }) ~= nil
end

-- ---------------------------------------------------------------------------
-- The settling-in payment
-- ---------------------------------------------------------------------------

local function claim(player)
    local s = steps(player)
    if not (s.licence and s.job and s.home) then return done(false, 'finish every step first') end

    if claimed(player.citizenid) then return done(false, 'you have already had it') end

    -- Inserted before any money moves. The primary key is the once per character
    -- rule; the subquery is the global cap, in the same statement.
    local ok, inserted = pcall(MySQL.update.await, [[
        INSERT INTO som_welcome_claims (citizenid, amount)
        SELECT ?, ? FROM DUAL
        WHERE (SELECT COALESCE(SUM(amount), 0) FROM som_welcome_claims WHERE created_at > DATE_SUB(NOW(), INTERVAL 30 DAY)) + ? <= ?
    ]], { player.citizenid, Config.payment, Config.payment, Config.monthlyCap })
    if not ok then return done(false, 'you have already had it') end
    if (inserted or 0) < 1 then return done(false, 'the city cannot pay any more settling-in payments this month') end

    local function release() MySQL.update.await('DELETE FROM som_welcome_claims WHERE citizenid = ?', { player.citizenid }) end

    local took, drawn = pcall(core.treasuryTransact, core, -Config.payment, 'welcome:settling-in')
    if not (took and drawn) then
        release()
        return done(false, 'the city cannot pay it right now')
    end

    local paidOk, paid = pcall(core.addMoney, core, player.source, 'bank', Config.payment, 'welcome:settling-in', { counterparty = 'treasury', flow = 'transfer' })
    if not (paidOk and paid) then
        local undone, back = pcall(core.treasuryTransact, core, Config.payment, 'welcome:settling-in:undo')
        if not (undone and back) then print(('[som-welcome] treasury refund of %d failed for %s'):format(Config.payment, player.citizenid)) end
        release()
        return done(false, 'the payment could not be made, try again')
    end

    return done(true, nil, { paid = Config.payment })
end

-- ---------------------------------------------------------------------------
-- Phone app
-- ---------------------------------------------------------------------------

local function view(player)
    local s = steps(player)
    local rows = function(title, sub, ok) return { title = title, sub = ('%s. %s'):format(ok and 'Done' or 'Not yet', sub) } end
    local got = claimed(player.citizenid)

    local sections = {
        { title = 'Welcome', rows = Config.guide },
        { title = 'Settling in', rows = {
            rows('Get a driver licence', 'Pass the theory and driving tests at the driving school.', s.licence),
            rows('Hold a job', ('Keep a job for %d minutes. The job centre has ordinary jobs.'):format(Config.jobMinutes), s.job),
            rows('Have a place to live', 'Buy a home or rent one.', s.home),
        } },
    }

    if got then
        sections[#sections + 1] = { title = 'Settling-in payment', rows = { { title = 'Received', sub = 'It is paid once.' } } }
    elseif s.licence and s.job and s.home then
        sections[#sections + 1] = { title = 'Settling-in payment', rows = {
            { title = ('Claim $%d'):format(Config.payment), sub = 'From the city, once.', action = 'claim' },
        } }
    end

    return { sections = sections, empty = '' }
end

exports['som-phone']:registerApp({
    id = 'welcome', label = 'Getting Started', icon = 'receipt', colour = '#0a84ff', order = 3,
    reads = { view = true },
    handler = function(source, action, _)
        local player = core:getPlayer(source)
        if not player then return done(false, 'not available') end
        if action == 'view' then return done(true, nil, { view = view(player) }) end
        if action == 'claim' then
            local r = claim(player)
            if r.success then TriggerClientEvent('som:client:notify', source, ('You received $%d'):format(r.paid), 'success') end
            return r
        end
        return done(false, 'not available')
    end,
})

-- ---------------------------------------------------------------------------
-- Job centre
-- ---------------------------------------------------------------------------

local function atDesk(source)
    local d = Config.desk
    if not d.enabled or not d.coords then return false end
    local ped = GetPlayerPed(source)
    return ped ~= 0 and #(GetEntityCoords(ped) - d.coords) <= d.distance
end

lib.callback.register('som-welcome:server:desk', function()
    local d = Config.desk
    if not d.enabled or not d.coords then return nil end
    return { label = d.label, coords = { x = d.coords.x, y = d.coords.y, z = d.coords.z }, distance = d.distance }
end)

lib.callback.register('som-welcome:server:jobs', function(source)
    local player = core:getPlayer(source)
    if not player then return done(false, 'not loaded') end
    if not atDesk(source) then return done(false, 'you are not at the counter') end

    local out = {}
    for _, job in ipairs(Config.jobs) do out[#out + 1] = { name = job.name, label = job.label } end
    return done(true, nil, { jobs = out, current = player.job.name })
end)

lib.callback.register('som-welcome:server:setJob', function(source, name)
    local player = core:getPlayer(source)
    if not player then return done(false, 'not loaded') end
    if type(name) ~= 'string' then return done(false, 'bad request') end
    if not atDesk(source) then return done(false, 'you are not at the counter') end

    local listed = name == 'unemployed'
    for _, job in ipairs(Config.jobs) do if job.name == name then listed = true end end
    if not listed or not core:getJobs()[name] then return done(false, 'the job centre cannot place you there') end

    local current = core:getJobs()[player.job.name]
    if not current or current.whitelisted then return done(false, 'you cannot leave that job here') end
    if player.job.name == name then return done(false, 'you already have that') end

    track(player.citizenid, player.job.name)
    local claimedSlot = MySQL.update.await([[
        UPDATE som_welcome_jobs SET centre_at = NOW()
        WHERE citizenid = ? AND (centre_at IS NULL OR centre_at < DATE_SUB(NOW(), INTERVAL ? MINUTE))
    ]], { player.citizenid, Config.desk.cooldownMinutes })
    if (claimedSlot or 0) < 1 then return done(false, ('you can change jobs here once every %d minutes'):format(Config.desk.cooldownMinutes)) end

    local ok, err = core:setJob(source, name, 0)
    if not ok then
        MySQL.update.await('UPDATE som_welcome_jobs SET centre_at = NULL WHERE citizenid = ?', { player.citizenid })
        return done(false, err or 'could not change your job')
    end
    return done(true, nil, { job = name })
end)

CreateThread(function() SomPlacements.Apply(Config) end)
