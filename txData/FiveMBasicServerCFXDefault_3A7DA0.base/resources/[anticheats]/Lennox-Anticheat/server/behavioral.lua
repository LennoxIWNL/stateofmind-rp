-- =========================================================================
--  Lennox Anti-Cheat v1.0 — Behavioral Analysis Engine
--  Informational only: Discord alerts, never auto-ban.
-- =========================================================================

local cfg = LACConfig
if not cfg.BehavioralAnalysis then return end

local BehaviorData = {}

local function getBD(src)
    src = tonumber(src)
    if not BehaviorData[src] then
        BehaviorData[src] = {
            -- Movement profiling
            posBuf     = {},
            posIdx     = 1,
            posBufSize = cfg.BehavioralPositionSamples or 30,
            -- Combat profiling
            combat = {
                damageDealt   = {},  -- circular buffer of {amount, time, headshot, weapon}
                damageIdx     = 1,
                damageSize    = 500,
                kills         = 0,
                deaths        = 0,
                killTimes     = {},  -- timestamps for K/D velocity
                hitWindow     = {},  -- last N hits for headshot %
                hitIdx        = 1,
                hitSize       = 100,
                weaponDPS     = {},  -- weapon -> {totalDmg, startTime}
            },
            -- Economy profiling
            economy = {
                sources     = {},  -- source -> {total, entries: {amount, time}}
                totalEarned = 0,
                windowStart = GetGameTimer(),
            },
            -- Anomaly scores (0-100 per dimension)
            anomaly = {
                movement = 0,
                combat   = 0,
                economy  = 0,
            },
            lastAlertTime = 0,
        }
    end
    return BehaviorData[src]
end

-- =========================================================================
--  Movement Analysis
-- =========================================================================
CreateThread(function()
    Wait(30000)
    while true do
        Wait(cfg.BehavioralPositionInterval or 2000)
        for _, pid in ipairs(GetPlayers()) do
            local src = tonumber(pid)
            if not LAC.isAdmin(src) then
                local ped = GetPlayerPed(src)
                if ped and ped > 0 then
                    local pos = GetEntityCoords(ped)
                    local bd = getBD(src)
                    bd.posBuf[bd.posIdx] = { x = pos.x, y = pos.y, z = pos.z, t = GetGameTimer() }
                    bd.posIdx = (bd.posIdx % bd.posBufSize) + 1
                end
            end
        end
    end
end)

local function analyzeMovement(src)
    local bd = getBD(src)
    local buf = bd.posBuf
    local count = 0
    for _ in pairs(buf) do count = count + 1 end
    if count < 10 then return 0 end

    local distances = {}
    local sorted = {}
    for i, p in pairs(buf) do sorted[#sorted + 1] = p end
    table.sort(sorted, function(a, b) return a.t < b.t end)

    for i = 2, #sorted do
        local dx = sorted[i].x - sorted[i-1].x
        local dy = sorted[i].y - sorted[i-1].y
        local dz = sorted[i].z - sorted[i-1].z
        local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
        local dt = (sorted[i].t - sorted[i-1].t) / 1000.0
        if dt > 0 then
            distances[#distances + 1] = dist / dt
        end
    end

    if #distances < 5 then return 0 end

    -- Variance calculation (teleporter = high variance, speed hack = high mean + low variance)
    local sum, sumSq = 0, 0
    for _, v in ipairs(distances) do sum = sum + v; sumSq = sumSq + v * v end
    local mean = sum / #distances
    local variance = (sumSq / #distances) - (mean * mean)

    -- Entropy for bot detection (very low variance + steady speed = bot-like)
    local score = 0
    if variance > 500 then
        score = math.min(100, variance / 50)
    elseif mean > 20 then
        score = math.min(80, mean * 2)
    elseif variance < 0.1 and mean > 2 and mean < 10 then
        score = math.min(60, 30 + (1 / (variance + 0.01)) * 0.5)
    end

    return math.floor(score)
end

-- =========================================================================
--  Combat Analysis
-- =========================================================================
function LAC.recordCombatHit(src, damage, headshot, weaponHash)
    local bd = getBD(src)
    local c = bd.combat
    local now = GetGameTimer()

    c.damageDealt[c.damageIdx] = { amount = damage, time = now, headshot = headshot, weapon = weaponHash }
    c.damageIdx = (c.damageIdx % c.damageSize) + 1

    c.hitWindow[c.hitIdx] = { headshot = headshot, time = now }
    c.hitIdx = (c.hitIdx % c.hitSize) + 1

    local wk = tostring(weaponHash)
    if not c.weaponDPS[wk] then c.weaponDPS[wk] = { totalDmg = 0, startTime = now } end
    c.weaponDPS[wk].totalDmg = c.weaponDPS[wk].totalDmg + damage
end

function LAC.recordKill(src)
    local bd = getBD(src)
    bd.combat.kills = bd.combat.kills + 1
    bd.combat.killTimes[#bd.combat.killTimes + 1] = GetGameTimer()
end

function LAC.recordDeath(src)
    local bd = getBD(src)
    bd.combat.deaths = bd.combat.deaths + 1
end

local function analyzeCombat(src)
    local bd = getBD(src)
    local c = bd.combat
    local now = GetGameTimer()
    local windowMs = (cfg.BehavioralCombatWindow or 300) * 1000
    local score = 0

    -- Headshot % over hit window
    local hsCount, totalHits = 0, 0
    for _, hit in pairs(c.hitWindow) do
        if hit and (now - hit.time) < windowMs then
            totalHits = totalHits + 1
            if hit.headshot then hsCount = hsCount + 1 end
        end
    end
    if totalHits >= 50 then
        local hsPct = (hsCount / totalHits) * 100
        if hsPct > (cfg.BehavioralHeadshotThreshold or 65) then
            score = math.max(score, math.min(100, hsPct))
        end
    end

    -- K/D velocity (kills per minute in rolling window)
    local recentKills = 0
    for _, t in ipairs(c.killTimes) do
        if (now - t) < windowMs then recentKills = recentKills + 1 end
    end
    local kpm = recentKills / ((windowMs / 1000) / 60)
    if kpm > 5 then
        score = math.max(score, math.min(90, kpm * 10))
    end

    return math.floor(score)
end

-- =========================================================================
--  Economy Analysis
-- =========================================================================
function LAC.recordEarning(src, source_name, amount)
    local bd = getBD(src)
    local e = bd.economy
    local now = GetGameTimer()

    if not e.sources[source_name] then
        e.sources[source_name] = { total = 0, entries = {} }
    end
    local s = e.sources[source_name]
    s.total = s.total + amount
    s.entries[#s.entries + 1] = { amount = amount, time = now }
    e.totalEarned = e.totalEarned + amount
end

local ServerEarningAvg = { total = 0, count = 0 }

local function analyzeEconomy(src)
    local bd = getBD(src)
    local e = bd.economy
    local now = GetGameTimer()
    local windowMs = (cfg.BehavioralEconWindow or 1800) * 1000

    -- Calculate earning rate in window
    local windowTotal = 0
    for _, s in pairs(e.sources) do
        for _, entry in ipairs(s.entries) do
            if (now - entry.time) < windowMs then
                windowTotal = windowTotal + entry.amount
            end
        end
    end

    if ServerEarningAvg.count < 2 then return 0 end

    local avg = ServerEarningAvg.total / ServerEarningAvg.count
    local stdDevs = cfg.BehavioralEconStdDevs or 3
    if avg > 0 and windowTotal > avg * stdDevs then
        return math.min(100, math.floor((windowTotal / avg) * 20))
    end

    return 0
end

-- =========================================================================
--  Periodic Analysis & Alerting
-- =========================================================================
CreateThread(function()
    Wait(120000)
    while true do
        Wait(60000)

        local allEarnings = {}
        for _, pid in ipairs(GetPlayers()) do
            local src = tonumber(pid)
            if BehaviorData[src] then
                local bd = BehaviorData[src]
                bd.anomaly.movement = analyzeMovement(src)
                bd.anomaly.combat = analyzeCombat(src)
                bd.anomaly.economy = analyzeEconomy(src)

                allEarnings[#allEarnings + 1] = bd.economy.totalEarned

                local maxScore = math.max(bd.anomaly.movement, bd.anomaly.combat, bd.anomaly.economy)
                local now = GetGameTimer()

                if maxScore >= 60 and (now - bd.lastAlertTime) > 300000 then
                    bd.lastAlertTime = now
                    local channel = (cfg.BehavioralWebhook and cfg.BehavioralWebhook ~= '') and 'behavioral' or 'flags'
                    LAC.sendDiscord(channel, 'Behavioral Anomaly',
                        ('**Player:** %s (id: %s)\n**Movement:** %d/100\n**Combat:** %d/100\n**Economy:** %d/100\n**Note:** Informational only — not auto-banning.')
                            :format(GetPlayerName(src) or '?', src,
                                bd.anomaly.movement, bd.anomaly.combat, bd.anomaly.economy),
                        16776960)
                end
            end
        end

        -- Update server earning average
        if #allEarnings > 0 then
            local sum = 0
            for _, e in ipairs(allEarnings) do sum = sum + e end
            ServerEarningAvg.total = sum
            ServerEarningAvg.count = #allEarnings
        end
    end
end)

-- =========================================================================
--  Exports
-- =========================================================================
function LAC.getBehavioralData(src)
    local bd = BehaviorData[tonumber(src)]
    if not bd then return nil end
    return {
        movement = bd.anomaly.movement,
        combat = bd.anomaly.combat,
        economy = bd.anomaly.economy,
    }
end

exports('GetBehavioralData', function(src) return LAC.getBehavioralData(src) end)

-- Cleanup
AddEventHandler('playerDropped', function()
    BehaviorData[source] = nil
end)
