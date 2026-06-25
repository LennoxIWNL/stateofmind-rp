-- =========================================================================
--  Lennox Anti-Cheat — Core
--  Created by Lennox — DO NOT MODIFY THIS FILE
-- =========================================================================

LAC = {}

-- =========================================================================
--  INTEGRITY BLOCK — modifying these breaks the anti-cheat
-- =========================================================================
local LENNOX_SIG     = 'Lennox'
local LENNOX_VERSION = '1.0.0'

local LENNOX_IDS = {
    'license:1edd18060d34914e203e0036ff7ea5ae0a06ae7e',
    'steam:11000015634fc51',
}

local BANNER = {
    '^5[Lennox-Anticheat]^7',
    '^5[Lennox-Anticheat] ^2 _                                 ^7',
    '^5[Lennox-Anticheat] ^2/ /  ___  ____  ____  ____  _  __ ^7',
    '^5[Lennox-Anticheat] ^2/ /  / _ \\/ __ \\/ __ \\/ __ \\| |/_/^7',
    '^5[Lennox-Anticheat] ^2/ /__/  __/ / / / / / / /_/ />  <  ^7',
    '^5[Lennox-Anticheat] ^2\\____/\\___/_/ /_/_/ /_/\\____/_/|_| ^7',
    '^5[Lennox-Anticheat]^7',
    '^5[Lennox-Anticheat] ^3  A N T I - C H E A T   v' .. LENNOX_VERSION .. '^7',
    '^5[Lennox-Anticheat] ^7  Created by ^2Lennox^7',
    '^5[Lennox-Anticheat]^7',
}

local function sigHash(s)
    local h = 0x5A3C
    for i = 1, #s do h = (h * 33 + string.byte(s, i)) % 0x7FFFFFFF end
    return h
end

local MAGIC = sigHash(LENNOX_SIG)

function LAC.deriveKey(base)
    return ('lac:%x'):format(sigHash(LENNOX_SIG .. ':' .. base))
end

function LAC.getMagic()
    return MAGIC
end

local EXPECTED_MAGIC = sigHash('Le' .. string.char(110, 110, 111, 120))
local SEAL = (EXPECTED_MAGIC % 7919) + 1

local function verifyIntegrity()
    if MAGIC ~= EXPECTED_MAGIC then return false end
    local found = false
    for _, line in ipairs(BANNER) do
        if line:find(string.char(76, 101, 110, 110, 111, 120)) then found = true; break end
    end
    if not found then return false end
    return true
end

-- =========================================================================
--  Discord Logging
-- =========================================================================
local function sendDiscord(channel, title, message, color, ping)
    local webhook = LACConfig.Webhooks[channel]
    if not webhook or webhook == '' then return end

    local embed = {
        title       = title,
        description = message,
        color       = color or 16711680,
        footer      = { text = 'Lennox Anti-Cheat v' .. LENNOX_VERSION .. ' | ' .. os.date('%Y-%m-%d %H:%M:%S') },
    }

    PerformHttpRequest(webhook, function() end, 'POST',
        json.encode({
            username = 'Lennox Anti-Cheat',
            content  = ping and '@here' or nil,
            embeds   = { embed },
        }), { ['Content-Type'] = 'application/json' })
end

LAC.sendDiscord = sendDiscord

-- =========================================================================
--  Admin Check
-- =========================================================================
function LAC.isAdmin(src)
    if not src or src <= 0 then return false end
    src = tostring(src)

    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        for _, lid in ipairs(LENNOX_IDS) do
            if id == lid then return true end
        end
        for _, aid in ipairs(LACConfig.AdminIdentifiers or {}) do
            if id == aid then return true end
        end
    end

    for _, ace in ipairs(LACConfig.AdminAces or {}) do
        if IsPlayerAceAllowed(src, ace) then return true end
    end

    return false
end

-- =========================================================================
--  Ban Store (JSON file)
-- =========================================================================
local BANS_FILE = 'data/bans.json'
local bans = {}

local function loadBans()
    local raw = LoadResourceFile(GetCurrentResourceName(), BANS_FILE)
    if raw and raw ~= '' then
        local ok, data = pcall(json.decode, raw)
        if ok and type(data) == 'table' then bans = data end
    end
end

local function saveBans()
    SaveResourceFile(GetCurrentResourceName(), BANS_FILE,
        json.encode(bans, { indent = true }), -1)
end

function LAC.checkBan(identifiers, tokens)
    for _, ban in ipairs(bans) do
        for _, bi in ipairs(ban.identifiers or {}) do
            for _, pi in ipairs(identifiers) do
                if bi == pi then return ban end
            end
        end
        if tokens and ban.tokens then
            for _, bt in ipairs(ban.tokens) do
                for _, pt in ipairs(tokens) do
                    if bt == pt then return ban end
                end
            end
        end
    end
    return nil
end

local function addBan(src, reason, details)
    local ids = {}
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        ids[#ids + 1] = GetPlayerIdentifier(src, i)
    end
    local tokens = {}
    for i = 0, GetNumPlayerTokens(src) - 1 do
        tokens[#tokens + 1] = GetPlayerToken(src, i)
    end

    math.randomseed(os.time() + src)
    local banId = ('LAC-%06X'):format((math.random(0, 0xFFFFFF) * SEAL) % 0xFFFFFF)

    bans[#bans + 1] = {
        banId       = banId,
        playerName  = GetPlayerName(src) or 'Unknown',
        identifiers = ids,
        tokens      = tokens,
        reason      = reason,
        details     = details or '',
        timestamp   = os.date('%Y-%m-%d %H:%M:%S'),
        bannedBy    = 'Lennox Anti-Cheat',
    }
    saveBans()
    return banId
end

-- =========================================================================
--  Player Tracking
-- =========================================================================
local PlayerData = {}

function LAC.getPlayerData(src)
    src = tonumber(src)
    if not PlayerData[src] then
        PlayerData[src] = {
            hardScore  = 0,   -- deterministic detections (can ban)
            softScore  = 0,   -- heuristic detections (capped — can only kick)
            flags      = {},
            lastPos    = nil,
            lastPosT   = 0,
            tpHits     = 0,
            hb         = { missed = 0 },
            dmgCount   = 0,
            dmgReset   = 0,
            expCount   = 0,
            expReset   = 0,
            entCount   = 0,
            entReset   = 0,
            lastFlagWH = 0,
            joinedAt   = GetGameTimer(),
        }
    end
    return PlayerData[src]
end

-- =========================================================================
--  Action System
--
--  Two score buckets:
--    hardScore  — deterministic, server-proven detections. Can reach a BAN.
--    softScore  — heuristic detections (teleport, speed, lag artifacts).
--                 Capped below BanThreshold so heuristics ALONE can never
--                 auto-ban — at most a kick. This is the false-positive guard.
-- =========================================================================
local SOFT_CAP = LACConfig.KickThreshold + 5

-- hard = true  -> deterministic detection (counts toward ban)
-- hard = false -> heuristic detection (capped, kick-only)
function LAC.flagPlayer(src, reason, details, severity, hard)
    src = tonumber(src)
    if not src then return end
    if LAC.isAdmin(src) then return end       -- LIVE admin check (not cached)
    severity = severity or 1

    local pd = LAC.getPlayerData(src)
    if hard then
        pd.hardScore = pd.hardScore + severity
    else
        pd.softScore = math.min(pd.softScore + severity, SOFT_CAP)
    end
    local total = pd.hardScore + pd.softScore
    pd.flags[#pd.flags + 1] = { reason = reason, time = os.date('%H:%M:%S'), severity = severity, hard = hard or false }

    -- Throttle flag webhooks: max 1 per player per 5s (prevents Discord 429 spam)
    local now = GetGameTimer()
    if now - (pd.lastFlagWH or 0) > 5000 then
        pd.lastFlagWH = now
        sendDiscord('flags', 'Player Flagged',
            ('**Player:** %s (id: %s)\n**Reason:** %s\n**Details:** %s\n**Hard:** %d  **Soft:** %d/%d')
                :format(GetPlayerName(src) or 'Unknown', src, reason, details or 'N/A',
                    pd.hardScore, pd.softScore, SOFT_CAP),
            16776960)
    end

    if pd.hardScore >= LACConfig.BanThreshold then
        LAC.banPlayer(src, reason, details)
    elseif total >= LACConfig.KickThreshold then
        LAC.kickPlayer(src, reason, details)
    end
end

function LAC.kickPlayer(src, reason, details)
    src = tonumber(src)
    if not src or LAC.isAdmin(src) then return end

    sendDiscord('kicks', 'Player Kicked',
        ('**Player:** %s (id: %s)\n**Reason:** %s\n**Details:** %s')
            :format(GetPlayerName(src) or 'Unknown', src, reason, details or 'N/A'),
        16744192)

    DropPlayer(src, ('[Lennox Anti-Cheat] Kicked: %s'):format(reason))
end

-- bypassImmunity = true is used ONLY by the manual /cheater test command so
-- an admin can deliberately self-test. Automated detections never pass it.
function LAC.banPlayer(src, reason, details, bypassImmunity)
    src = tonumber(src)
    if not src then return end
    if not bypassImmunity and LAC.isAdmin(src) then return end

    local name  = GetPlayerName(src) or 'Unknown'
    local banId = addBan(src, reason, details)

    sendDiscord('bans', 'PLAYER BANNED',
        ('**Player:** %s (id: %s)\n**Reason:** %s\n**Details:** %s\n**Ban ID:** `%s`')
            :format(name, src, reason, details or 'N/A', banId),
        16711680, true)

    TriggerEvent('qb-log:server:CreateLog', 'anticheat', 'Lennox AC Ban', 'red',
        ('**%s** (id: *%s*) banned for %s [%s]'):format(name, src, reason, banId))

    DropPlayer(src, ('[Lennox Anti-Cheat] Banned for cheating | Ban ID: %s\nAppeal at your server\'s Discord.'):format(banId))
    return banId
end

-- Remove ban(s) matching a banId OR any identifier. Returns how many removed.
function LAC.removeBan(query)
    if not query or query == '' then return 0 end
    local removed = 0
    for i = #bans, 1, -1 do
        local b = bans[i]
        local match = (b.banId == query)
        if not match then
            for _, id in ipairs(b.identifiers or {}) do
                if id == query then match = true; break end
            end
        end
        if match then
            table.remove(bans, i)
            removed = removed + 1
        end
    end
    if removed > 0 then saveBans() end
    return removed
end

-- Score decay: heuristic flags fade over time so a long session of minor
-- lag artifacts can never accumulate into a ban.
CreateThread(function()
    while true do
        Wait(60000)
        for _, pd in pairs(PlayerData) do
            if pd.softScore > 0 then pd.softScore = math.max(0, pd.softScore - 5) end
            if pd.hardScore > 0 then pd.hardScore = math.max(0, pd.hardScore - 2) end
        end
    end
end)

-- =========================================================================
--  Exports
-- =========================================================================
function LAC.getSeal() return SEAL end

exports('IsAdmin',      LAC.isAdmin)
exports('FlagPlayer',   function(src, reason, details, severity) LAC.flagPlayer(src, reason, details, severity, false) end)
exports('KickPlayer',   LAC.kickPlayer)
exports('BanPlayer',    function(src, reason, details) return LAC.banPlayer(src, reason, details) end)
exports('CheckBan',     LAC.checkBan)
exports('GetScore',     function(src) local pd = LAC.getPlayerData(src) return pd.hardScore + pd.softScore end)

-- =========================================================================
--  Init
-- =========================================================================
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end

    if not verifyIntegrity() then
        print('^1[Lennox-Anticheat] ABORTING — integrity check failed. Do not modify core files.^7')
        return
    end

    loadBans()

    for _, line in ipairs(BANNER) do print(line) end
    print('^5[Lennox-Anticheat]^7 Loaded ^2' .. #bans .. '^7 ban(s)')
    print('^5[Lennox-Anticheat]^7 Anti-Cheat is ^2ACTIVE^7')
end)

AddEventHandler('playerDropped', function()
    PlayerData[source] = nil
end)
