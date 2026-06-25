-- =========================================================================
--  Lennox Anti-Cheat v1.0 — Hardware Fingerprint System
-- =========================================================================

local HWIDStore = {}     -- src -> hwid
local HWIDHistory = {}   -- identifier -> { hwid, timestamp }[]
local HWIDIndex = {}     -- hwid -> { identifier, timestamp }[]

local HWID_SUBMIT = LAC.deriveKey('lac:hwid:submit')

RegisterNetEvent(HWID_SUBMIT, function(token, nonce, hwid)
    local src = source
    if not LAC.validateToken(src, token, nonce) then return end
    if type(hwid) ~= 'string' or #hwid ~= 32 then
        LAC.flagPlayer(src, 'Invalid HWID Format', ('len=%d'):format(#(hwid or '')), 10, true)
        return
    end

    local existing = HWIDStore[src]
    if existing and existing ~= hwid then
        LAC.flagPlayer(src, 'HWID Changed Mid-Session',
            ('old=%s new=%s'):format(existing:sub(1, 16), hwid:sub(1, 16)), 15, true)
        LAC.sendDiscord('bans', 'HWID SPOOF DETECTED',
            ('**Player:** %s (id: %s)\n**Old HWID:** `%s`\n**New HWID:** `%s`\n**Verdict:** Hardware fingerprint changed during active session.')
                :format(GetPlayerName(src) or '?', src, existing, hwid), 16711680, true)
    end

    HWIDStore[src] = hwid

    -- Store in player data for ban records
    local pd = LAC.getPlayerData(src)
    pd.hwid = hwid

    -- Track HWID history per identifier
    local identifiers = {}
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        identifiers[#identifiers + 1] = GetPlayerIdentifier(src, i)
    end

    for _, id in ipairs(identifiers) do
        if not HWIDHistory[id] then HWIDHistory[id] = {} end
        local dominated = false
        for _, entry in ipairs(HWIDHistory[id]) do
            if entry.hwid == hwid then dominated = true; entry.timestamp = os.time(); break end
        end
        if not dominated then
            HWIDHistory[id][#HWIDHistory[id] + 1] = { hwid = hwid, timestamp = os.time() }
        end
    end

    -- Track identifiers per HWID
    if not HWIDIndex[hwid] then HWIDIndex[hwid] = {} end
    for _, id in ipairs(identifiers) do
        local found = false
        for _, entry in ipairs(HWIDIndex[hwid]) do
            if entry.identifier == id then found = true; entry.timestamp = os.time(); break end
        end
        if not found then
            HWIDIndex[hwid][#HWIDIndex[hwid] + 1] = { identifier = id, timestamp = os.time() }
        end
    end

    -- Check for HWID shared across too many identifier sets (possible spoofer)
    local uniqueIds = {}
    for _, entry in ipairs(HWIDIndex[hwid] or {}) do
        if entry.identifier:find('^license:') then
            uniqueIds[entry.identifier] = true
        end
    end
    local idCount = 0
    for _ in pairs(uniqueIds) do idCount = idCount + 1 end

    if idCount >= (LACConfig.HWIDSpoofThreshold or 3) then
        LAC.sendDiscord('connections', 'HWID SHARED ACROSS MULTIPLE IDENTITIES',
            ('**HWID:** `%s`\n**Identities:** %d unique license identifiers\n**Action:** Admin review recommended — possible ban evader with HWID spoofer')
                :format(hwid, idCount), 16776960, true)
    end

    LAC.sendDiscord('connections', 'HWID Registered',
        ('**Player:** %s (id: %s)\n**HWID:** `%s`')
            :format(GetPlayerName(src) or '?', src, hwid), 65280)
end)

-- Include HWID in ban records
local _origAddBan = nil

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end

    -- Wrap the ban function to include HWID
    local origBan = LAC.banPlayer
    LAC.banPlayer = function(src, reason, details, bypassImmunity)
        -- Ensure HWID is in the ban record (added via player data)
        return origBan(src, reason, details, bypassImmunity)
    end
end)

-- Ban matching enhancement: also check HWID
local _origCheckBan = LAC.checkBan
LAC.checkBan = function(identifiers, tokens, hwid)
    local result = _origCheckBan(identifiers, tokens)
    if result then return result end

    -- If no match by identifiers/tokens, try HWID
    if hwid and hwid ~= '' then
        -- Lookup HWID in index to find associated identifiers
        local assocIds = HWIDIndex[hwid]
        if assocIds then
            for _, entry in ipairs(assocIds) do
                local banResult = _origCheckBan({entry.identifier}, {})
                if banResult then
                    LAC.sendDiscord('connections', 'BAN EVASION — HWID MATCH',
                        ('**HWID:** `%s`\n**Matched Identifier:** %s\n**Original Ban:** %s')
                            :format(hwid, entry.identifier, banResult.banId or '?'), 16711680, true)
                    return banResult
                end
            end
        end
    end

    return nil
end

function LAC.getHWID(src)
    return HWIDStore[tonumber(src)]
end

AddEventHandler('playerDropped', function()
    HWIDStore[source] = nil
end)
