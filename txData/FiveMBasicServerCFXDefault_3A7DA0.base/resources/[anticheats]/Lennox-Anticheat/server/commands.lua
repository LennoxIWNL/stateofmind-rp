-- =========================================================================
--  Lennox Anti-Cheat v1.0 — Admin Commands
-- =========================================================================

local function chatMsg(src, msg)
    if src > 0 then
        TriggerClientEvent('chat:addMessage', src, { color = { 255, 20, 147 }, args = { 'Lennox AC', msg } })
    else
        print('^5[Lennox-Anticheat]^7 ' .. msg)
    end
end

local function requireAdmin(src)
    if src > 0 and not LAC.isAdmin(src) then
        chatMsg(src, 'You do not have permission to use this command.')
        return false
    end
    return true
end

-- Exemption system
local Exemptions = {}

function LAC.isExempt(src)
    src = tonumber(src)
    local ex = Exemptions[src]
    if not ex then return false end
    if ex.until_time and GetGameTimer() > ex.until_time then
        Exemptions[src] = nil
        return false
    end
    return true
end

function LAC.setExempt(src, duration)
    src = tonumber(src)
    if duration and duration > 0 then
        Exemptions[src] = { until_time = GetGameTimer() + (duration * 1000) }
    else
        Exemptions[src] = { until_time = nil }
    end
end

function LAC.removeExempt(src)
    Exemptions[tonumber(src)] = nil
end

-- Patch isAdmin to also check exemption
local _origIsAdmin = LAC.isAdmin
LAC.isAdmin = function(src)
    if LAC.isExempt(src) then return true end
    return _origIsAdmin(src)
end

-- Warp expectation system
local WarpExpected = {}

function LAC.expectWarp(src)
    src = tonumber(src)
    WarpExpected[src] = GetGameTimer() + 5000
    TriggerClientEvent(LAC.deriveKey('lac:warp:expect'), src)
end

function LAC.isWarpExpected(src)
    src = tonumber(src)
    local w = WarpExpected[src]
    if not w then return false end
    if GetGameTimer() > w then WarpExpected[src] = nil; return false end
    return true
end

-- =========================================================================
--  /cheater [id]
-- =========================================================================
RegisterCommand('cheater', function(source, args)
    local src = source
    if not requireAdmin(src) then return end
    local target = tonumber(args[1])
    if not target then chatMsg(src, 'Usage: /cheater [serverId]'); return end
    if not GetPlayerName(target) then chatMsg(src, ('No player with id %d'):format(target)); return end
    local banId = LAC.banPlayer(target, 'Manual Ban',
        ('Issued by %s'):format(src > 0 and (GetPlayerName(src) or ('id ' .. src)) or 'SERVER CONSOLE'), true)
    chatMsg(src, ('Banned id %d (Ban ID: %s)'):format(target, tostring(banId)))
end, true)

-- =========================================================================
--  /lac_unban [banId | identifier]
-- =========================================================================
RegisterCommand('lac_unban', function(source, args)
    local src = source
    if not requireAdmin(src) then return end
    local query = args[1]
    if not query then chatMsg(src, 'Usage: /lac_unban [banId | identifier]'); return end
    local removed = LAC.removeBan(query)
    chatMsg(src, ('Removed %d ban(s) matching "%s"'):format(removed, query))
end, true)

-- =========================================================================
--  /lac_score [id]
-- =========================================================================
RegisterCommand('lac_score', function(source, args)
    local src = source
    if not requireAdmin(src) then return end
    local target = tonumber(args[1])
    if not target then chatMsg(src, 'Usage: /lac_score [serverId]'); return end
    if not GetPlayerName(target) then chatMsg(src, ('No player with id %d'):format(target)); return end
    local pd = LAC.getPlayerData(target)
    chatMsg(src, ('Player %s (id %d): Hard=%d Soft=%d Total=%d | Flags=%d'):format(
        GetPlayerName(target), target, pd.hardScore, pd.softScore, pd.hardScore + pd.softScore, #pd.flags))
end, true)

-- =========================================================================
--  /lac_info [id]
-- =========================================================================
RegisterCommand('lac_info', function(source, args)
    local src = source
    if not requireAdmin(src) then return end
    local target = tonumber(args[1])
    if not target then chatMsg(src, 'Usage: /lac_info [serverId]'); return end
    if not GetPlayerName(target) then chatMsg(src, ('No player with id %d'):format(target)); return end

    local pd = LAC.getPlayerData(target)
    local ids = {}
    for i = 0, GetNumPlayerIdentifiers(target) - 1 do ids[#ids + 1] = GetPlayerIdentifier(target, i) end
    local hwid = LAC.getHWID and LAC.getHWID(target) or 'N/A'
    local sessionMins = math.floor((GetGameTimer() - (pd.joinedAt or GetGameTimer())) / 60000)
    local exempt = LAC.isExempt(target) and 'YES' or 'no'

    chatMsg(src, ('--- %s (id %d) ---'):format(GetPlayerName(target), target))
    chatMsg(src, ('Identifiers: %s'):format(table.concat(ids, ', ')))
    chatMsg(src, ('HWID: %s'):format(hwid))
    chatMsg(src, ('Hard: %d | Soft: %d | Flags: %d | Session: %dm | Exempt: %s'):format(
        pd.hardScore, pd.softScore, #pd.flags, sessionMins, exempt))

    if #pd.flags > 0 then
        local recent = pd.flags[#pd.flags]
        chatMsg(src, ('Last flag: %s at %s (sev %d, %s)'):format(
            recent.reason, recent.time, recent.severity, recent.hard and 'HARD' or 'soft'))
    end
end, true)

-- =========================================================================
--  /lac_status
-- =========================================================================
local StartTime = GetGameTimer()
local TotalBans = 0
local TotalKicks = 0

local _origBanForStats = LAC.banPlayer
LAC.banPlayer = function(...)
    TotalBans = TotalBans + 1
    return _origBanForStats(...)
end

local _origKickForStats = LAC.kickPlayer
LAC.kickPlayer = function(...)
    TotalKicks = TotalKicks + 1
    return _origKickForStats(...)
end

RegisterCommand('lac_status', function(source, args)
    local src = source
    if not requireAdmin(src) then return end
    local uptime = math.floor((GetGameTimer() - StartTime) / 60000)
    local players = #GetPlayers()
    local exemptCount = 0
    for _ in pairs(Exemptions) do exemptCount = exemptCount + 1 end

    chatMsg(src, '--- Lennox Anti-Cheat v1.0 Status ---')
    chatMsg(src, ('Uptime: %dm | Players: %d | Bans: %d | Kicks: %d | Exemptions: %d'):format(
        uptime, players, TotalBans, TotalKicks, exemptCount))
end, true)

-- =========================================================================
--  /lac_exempt [id] [duration_seconds]
-- =========================================================================
RegisterCommand('lac_exempt', function(source, args)
    local src = source
    if not requireAdmin(src) then return end
    local target = tonumber(args[1])
    if not target then chatMsg(src, 'Usage: /lac_exempt [serverId] [duration_secs]'); return end
    if not GetPlayerName(target) then chatMsg(src, ('No player with id %d'):format(target)); return end
    local duration = tonumber(args[2]) or 300
    LAC.setExempt(target, duration)
    chatMsg(src, ('Exempted %s for %ds'):format(GetPlayerName(target), duration))
end, true)

-- =========================================================================
--  /lac_unexempt [id]
-- =========================================================================
RegisterCommand('lac_unexempt', function(source, args)
    local src = source
    if not requireAdmin(src) then return end
    local target = tonumber(args[1])
    if not target then chatMsg(src, 'Usage: /lac_unexempt [serverId]'); return end
    LAC.removeExempt(target)
    chatMsg(src, ('Removed exemption for id %d'):format(target))
end, true)

-- =========================================================================
--  /lac_expectwarp [id]
-- =========================================================================
RegisterCommand('lac_expectwarp', function(source, args)
    local src = source
    if not requireAdmin(src) then return end
    local target = tonumber(args[1])
    if not target then chatMsg(src, 'Usage: /lac_expectwarp [serverId]'); return end
    if not GetPlayerName(target) then chatMsg(src, ('No player with id %d'):format(target)); return end
    LAC.expectWarp(target)
    chatMsg(src, ('Warp expected for %s (5s window)'):format(GetPlayerName(target)))
end, true)

-- =========================================================================
--  /lac_screenshot [id]
-- =========================================================================
RegisterCommand('lac_screenshot', function(source, args)
    local src = source
    if not requireAdmin(src) then return end
    local target = tonumber(args[1])
    if not target then chatMsg(src, 'Usage: /lac_screenshot [serverId]'); return end
    if not GetPlayerName(target) then chatMsg(src, ('No player with id %d'):format(target)); return end

    if GetResourceState('screenshot-basic') ~= 'started' then
        chatMsg(src, 'screenshot-basic is not running')
        return
    end

    exports['screenshot-basic']:requestClientScreenshot(target, {
        encoding = 'png', quality = 0.8,
    }, function(err, data)
        if err then
            chatMsg(src, ('Screenshot failed: %s'):format(tostring(err)))
        else
            chatMsg(src, ('Screenshot captured for %s'):format(GetPlayerName(target) or target))
            LAC.sendDiscord('events', 'Admin Screenshot',
                ('**Target:** %s (id: %s)\n**Requested by:** %s\n[Screenshot captured]')
                    :format(GetPlayerName(target) or '?', target, src > 0 and GetPlayerName(src) or 'CONSOLE'), 65280)
        end
    end)
end, true)

-- =========================================================================
--  /lac_dump [id] — Console only, dumps all AC data for a player
-- =========================================================================
RegisterCommand('lac_dump', function(source, args)
    if source > 0 then return end
    local target = tonumber(args[1])
    if not target then print('^5[LAC]^7 Usage: lac_dump [serverId]'); return end
    if not GetPlayerName(target) then print('^5[LAC]^7 No player with id ' .. target); return end

    local pd = LAC.getPlayerData(target)
    local hwid = LAC.getHWID and LAC.getHWID(target) or 'N/A'
    print('^5[LAC DUMP]^7 ==========================================')
    print('^5[LAC DUMP]^7 Player: ' .. (GetPlayerName(target) or '?') .. ' (id ' .. target .. ')')
    print('^5[LAC DUMP]^7 HWID: ' .. hwid)
    print('^5[LAC DUMP]^7 Scores: Hard=' .. pd.hardScore .. ' Soft=' .. pd.softScore)
    print('^5[LAC DUMP]^7 Flags (' .. #pd.flags .. '):')
    for i, f in ipairs(pd.flags) do
        print(('  [%d] %s at %s (sev %d, %s)'):format(i, f.reason, f.time, f.severity, f.hard and 'HARD' or 'soft'))
    end
    print('^5[LAC DUMP]^7 ==========================================')
end, false)

-- =========================================================================
--  Exports
-- =========================================================================
exports('ExpectWarp', function(src) LAC.expectWarp(src) end)
exports('IsExempt', function(src) return LAC.isExempt(src) end)
exports('SetExempt', function(src, duration) LAC.setExempt(src, duration) end)
exports('RemoveExempt', function(src) LAC.removeExempt(src) end)
exports('GetHWID', function(src) return LAC.getHWID and LAC.getHWID(src) or nil end)
exports('GetPlayerInfo', function(src)
    local pd = LAC.getPlayerData(src)
    return {
        hardScore = pd.hardScore, softScore = pd.softScore,
        totalScore = pd.hardScore + pd.softScore,
        flagCount = #pd.flags, flags = pd.flags,
        hwid = LAC.getHWID and LAC.getHWID(src) or nil,
        exempt = LAC.isExempt(src),
        sessionMinutes = math.floor((GetGameTimer() - (pd.joinedAt or GetGameTimer())) / 60000),
    }
end)
exports('GetStats', function()
    return {
        uptime = math.floor((GetGameTimer() - StartTime) / 60000),
        totalBans = TotalBans, totalKicks = TotalKicks,
        playerCount = #GetPlayers(),
        version = '1.0.0',
    }
end)
exports('IsWarpExpected', function(src) return LAC.isWarpExpected(src) end)

-- =========================================================================
--  /lac_banlist [page]
-- =========================================================================
RegisterCommand('lac_banlist', function(source, args)
    local src = source
    if not requireAdmin(src) then return end
    local page = tonumber(args[1]) or 1
    local perPage = 10
    local bans = LAC._getBans and LAC._getBans() or {}
    local total = #bans
    local pages = math.ceil(total / perPage)
    if pages == 0 then pages = 1 end
    if page > pages then page = pages end

    chatMsg(src, ('--- Ban List (Page %d/%d, %d total) ---'):format(page, pages, total))
    local startIdx = (page - 1) * perPage + 1
    local endIdx = math.min(startIdx + perPage - 1, total)
    for i = startIdx, endIdx do
        local b = bans[i]
        if b then
            chatMsg(src, ('%d. [%s] %s — %s (%s)'):format(
                i, b.banId or '?', b.playerName or '?', b.reason or '?', b.timestamp or '?'))
        end
    end
    if page < pages then
        chatMsg(src, ('Use /lac_banlist %d for next page'):format(page + 1))
    end
end, true)

-- =========================================================================
--  /lac_baninfo [banId]
-- =========================================================================
RegisterCommand('lac_baninfo', function(source, args)
    local src = source
    if not requireAdmin(src) then return end
    local query = args[1]
    if not query then chatMsg(src, 'Usage: /lac_baninfo [banId]'); return end

    local bans = LAC._getBans and LAC._getBans() or {}
    for _, b in ipairs(bans) do
        if b.banId == query then
            chatMsg(src, ('--- Ban Details: %s ---'):format(b.banId))
            chatMsg(src, ('Player: %s'):format(b.playerName or '?'))
            chatMsg(src, ('Reason: %s'):format(b.reason or '?'))
            chatMsg(src, ('Details: %s'):format(b.details or 'N/A'))
            chatMsg(src, ('Date: %s'):format(b.timestamp or '?'))
            chatMsg(src, ('Banned By: %s'):format(b.bannedBy or '?'))
            chatMsg(src, ('Identifiers: %s'):format(table.concat(b.identifiers or {}, ', ')))
            if b.hwid then chatMsg(src, ('HWID: %s'):format(b.hwid)) end
            return
        end
    end
    chatMsg(src, ('No ban found with ID "%s"'):format(query))
end, true)

-- =========================================================================
--  /lac_reload — reload config without restart
-- =========================================================================
RegisterCommand('lac_reload', function(source, args)
    local src = source
    if not requireAdmin(src) then return end

    local configFile = LoadResourceFile(GetCurrentResourceName(), 'config.lua')
    if configFile then
        local fn, err = load(configFile)
        if fn then
            local ok, loadErr = pcall(fn)
            if ok then
                chatMsg(src, 'Config reloaded successfully.')
                LAC.sendDiscord('events', 'Config Reloaded',
                    ('**Reloaded by:** %s'):format(
                        src > 0 and (GetPlayerName(src) or ('id ' .. src)) or 'CONSOLE'),
                    65280)
            else
                chatMsg(src, ('Config reload error: %s'):format(tostring(loadErr)))
            end
        else
            chatMsg(src, ('Config parse error: %s'):format(tostring(err)))
        end
    else
        chatMsg(src, 'Could not read config.lua')
    end
end, true)

-- =========================================================================
--  /lac_hash_resources — compute resource hashes for integrity system
-- =========================================================================
RegisterCommand('lac_hash_resources', function(source, args)
    local src = source
    if not requireAdmin(src) then return end

    chatMsg(src, 'Computing resource hashes...')
    local hashes = {}
    local count = 0
    for i = 0, GetNumResources() - 1 do
        local resName = GetResourceByFindIndex(i)
        if resName and GetResourceState(resName) == 'started' and resName ~= GetCurrentResourceName() then
            local manifest = LoadResourceFile(resName, 'fxmanifest.lua') or LoadResourceFile(resName, '__resource.lua') or ''
            local h = 0x5A3C
            for j = 1, #manifest do h = (h * 33 + string.byte(manifest, j)) % 0x7FFFFFFF end
            hashes[resName] = ('%08x'):format(h)
            count = count + 1
        end
    end

    LACConfig.ResourceIntegrityHashes = hashes
    chatMsg(src, ('Computed hashes for %d resources. Set ResourceIntegrity = true in config to enable checking.'):format(count))

    LAC.sendDiscord('events', 'Resource Hashes Computed',
        ('**Resources:** %d\n**By:** %s')
            :format(count, src > 0 and (GetPlayerName(src) or ('id ' .. src)) or 'CONSOLE'),
        65280)
end, true)

-- =========================================================================
--  Periodic Status Embed (configurable)
-- =========================================================================
CreateThread(function()
    Wait(30000)
    while true do
        local interval = (LACConfig.StatusEmbedInterval or 0)
        if interval <= 0 then Wait(60000); goto cont end
        Wait(interval * 1000)

        local players = #GetPlayers()
        local uptime = math.floor((GetGameTimer() - StartTime) / 60000)
        local flaggedCount = 0
        for _, pid in ipairs(GetPlayers()) do
            local pd = LAC.getPlayerData(tonumber(pid))
            if pd.hardScore + pd.softScore > 0 then flaggedCount = flaggedCount + 1 end
        end

        LAC.sendDiscord('events', 'Lennox AC — Status Report',
            ('**Uptime:** %dm\n**Players:** %d\n**Flagged:** %d\n**Total Bans:** %d\n**Total Kicks:** %d')
                :format(uptime, players, flaggedCount, TotalBans, TotalKicks),
            65280)
        ::cont::
    end
end)

AddEventHandler('playerDropped', function()
    Exemptions[source] = nil
    WarpExpected[source] = nil
end)
