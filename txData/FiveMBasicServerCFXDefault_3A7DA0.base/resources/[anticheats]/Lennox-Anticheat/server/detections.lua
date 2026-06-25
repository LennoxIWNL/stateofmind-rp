-- =========================================================================
--  Lennox Anti-Cheat — Detection Modules
--  Created by Lennox — DO NOT MODIFY THIS FILE
-- =========================================================================

local cfg = LACConfig

-- =========================================================================
--  1. Heartbeat (tamper / resource-kill detection)
-- =========================================================================
local HB_CHALLENGE = LAC.deriveKey('hb:challenge')
local HB_RESPONSE  = LAC.deriveKey('hb:response')
local MAGIC        = LAC.getMagic()
local SEAL         = LAC.getSeal()

local pendingHB = {}

RegisterNetEvent(HB_RESPONSE, function(token, nonce, response)
    local src = source
    local pending = pendingHB[src]
    if not pending then return end

    -- validate session token if provided (backwards-compat: token may be nil during first heartbeat)
    if token and not LAC.validateToken(src, token, nonce) then
        pendingHB[src] = nil
        return
    end

    local expected = ((pending.challenge * MAGIC) % 0x7FFFFFFF) + SEAL
    local pd = LAC.getPlayerData(src)

    if response == expected then
        pendingHB[src] = nil
        pd.hb.missed = 0
    else
        pendingHB[src] = nil
        pd.hb.missed = pd.hb.missed + 1
        LAC.flagPlayer(src, 'Heartbeat Mismatch',
            ('Expected: %d, Got: %s'):format(expected, tostring(response)), 5, false)
    end
end)

CreateThread(function()
    while true do
        Wait(cfg.HeartbeatInterval)

        for _, pid in ipairs(GetPlayers()) do
            local src = tonumber(pid)
            local pd  = LAC.getPlayerData(src)
            if LAC.isAdmin(src) then goto skip end

            local prev = pendingHB[src]
            if prev and (GetGameTimer() - prev.sentAt) > cfg.HeartbeatTimeout then
                pd.hb.missed = pd.hb.missed + 1
                pendingHB[src] = nil

                if pd.hb.missed >= cfg.MaxMissedHeartbeats then
                    -- Soft: a client crash/freeze also misses heartbeats, so this
                    -- escalates to a kick, never a lone auto-ban.
                    LAC.flagPlayer(src, 'Heartbeat Timeout',
                        ('Missed %d consecutive heartbeats — possible resource kill'):format(pd.hb.missed), 8, false)
                end
            end

            math.randomseed(GetGameTimer() + src)
            local challenge = math.random(100000, 999999)
            pendingHB[src] = { challenge = challenge, sentAt = GetGameTimer() }
            TriggerClientEvent(HB_CHALLENGE, src, challenge)

            ::skip::
        end
    end
end)

-- =========================================================================
--  2. Weapon Damage Filtering
-- =========================================================================
AddEventHandler('weaponDamageEvent', function(sender, data)
    local src = tonumber(sender)
    if not src or src <= 0 then return end
    if LAC.isAdmin(src) then return end
    local pd = LAC.getPlayerData(src)

    local now = GetGameTimer()
    if now - pd.dmgReset > 1000 then
        pd.dmgCount = 0
        pd.dmgReset = now
    end
    pd.dmgCount = pd.dmgCount + 1

    -- Blacklisted weapon = deterministic (player physically can't legitimately
    -- have a minigun/railgun in an RP server) -> HARD.
    if cfg.BlacklistedWeapons[data.weaponType] then
        CancelEvent()
        LAC.flagPlayer(src, 'Blacklisted Weapon', ('Hash: 0x%X'):format(data.weaponType or 0), 10, true)
        LAC.sendDiscord('events', 'Blacklisted Weapon Blocked',
            ('**Player:** %s (id: %s)\n**Weapon:** `0x%X`')
                :format(GetPlayerName(src) or '?', src, data.weaponType or 0),
            16711680)
        return
    end

    -- Rapid fire / excessive damage = heuristic (lag spikes, explosive ammo,
    -- shotgun pellets all inflate these) -> SOFT.
    if pd.dmgCount > cfg.MaxDamageEventsPerSecond then
        CancelEvent()
        LAC.flagPlayer(src, 'Rapid Fire',
            ('Weapon: 0x%X | %d dmg events/sec'):format(data.weaponType or 0, pd.dmgCount), 5, false)
        LAC.sendDiscord('events', 'Weapon Damage Blocked',
            ('**Player:** %s (id: %s)\n**Weapon:** `0x%X`\n**Rate:** %d/sec')
                :format(GetPlayerName(src) or '?', src, data.weaponType or 0, pd.dmgCount),
            16744192)
        return
    end

    if data.weaponDamage and data.weaponDamage > cfg.MaxWeaponDamage then
        CancelEvent()
        LAC.flagPlayer(src, 'Excessive Damage',
            ('Weapon: 0x%X | Damage: %.1f'):format(data.weaponType or 0, data.weaponDamage), 5, false)
        return
    end
end)

-- =========================================================================
--  3. Explosion Filtering
-- =========================================================================
AddEventHandler('explosionEvent', function(sender, data)
    local src = tonumber(sender)
    if not src or src <= 0 then return end
    if LAC.isAdmin(src) then return end
    if type(data) ~= 'table' then return end
    local pd = LAC.getPlayerData(src)

    -- Blacklisted explosion type = deterministic -> HARD.
    if cfg.BlacklistedExplosions[data.explosionType] then
        CancelEvent()
        LAC.flagPlayer(src, 'Blacklisted Explosion', ('Type: %d'):format(data.explosionType or -1), 10, true)
        LAC.sendDiscord('events', 'Blacklisted Explosion Blocked',
            ('**Player:** %s (id: %s)\n**Type:** %d')
                :format(GetPlayerName(src) or '?', src, data.explosionType or -1),
            16711680)
        return
    end

    local now = GetGameTimer()
    if now - pd.expReset > 5000 then
        pd.expCount = 0
        pd.expReset = now
    end
    pd.expCount = pd.expCount + 1

    -- Volume-based spam = heuristic (fireworks, legit grenades) -> SOFT.
    if pd.expCount > cfg.MaxExplosionsPer5Sec then
        CancelEvent()
        LAC.flagPlayer(src, 'Explosion Spam',
            ('Type: %d | Count: %d/5s'):format(data.explosionType or -1, pd.expCount), 8, false)
        LAC.sendDiscord('events', 'Explosion Spam Blocked',
            ('**Player:** %s (id: %s)\n**Type:** %d\n**Count:** %d in 5s')
                :format(GetPlayerName(src) or '?', src, data.explosionType or -1, pd.expCount),
            16711680)
        return
    end
end)

-- =========================================================================
--  4. Entity Creation Rate Limiting
-- =========================================================================
AddEventHandler('entityCreating', function(entity)
    local owner = NetworkGetEntityOwner(entity)
    if not owner or owner <= 0 then return end
    if LAC.isAdmin(owner) then return end

    local pd = LAC.getPlayerData(owner)

    local now = GetGameTimer()
    if now - pd.entReset > 2000 then
        pd.entCount = 0
        pd.entReset = now
    end
    pd.entCount = pd.entCount + 1

    -- Spawn rate is heuristic (object-placement scripts, large vehicles) -> SOFT.
    if pd.entCount > cfg.MaxEntitiesPer2Sec then
        CancelEvent()
        LAC.flagPlayer(owner, 'Entity Spam', ('Count: %d/2s'):format(pd.entCount), 8, false)
        LAC.sendDiscord('events', 'Entity Spam Blocked',
            ('**Player:** %s (id: %s)\n**Entities:** %d in 2s')
                :format(GetPlayerName(owner) or '?', owner, pd.entCount),
            16744192)
    end
end)

-- =========================================================================
--  5. Position Tracking (teleport / speed)
-- =========================================================================
CreateThread(function()
    Wait(10000)
    while true do
        Wait(cfg.PositionCheckInterval)

        for _, pid in ipairs(GetPlayers()) do
            local src = tonumber(pid)
            local ped = GetPlayerPed(src)
            if ped and ped > 0 then
                local pd = LAC.getPlayerData(src)
                if LAC.isAdmin(src) then goto cont end

                local now = GetGameTimer()

                -- Exemptions that legitimately cause huge position jumps:
                --   * first 30s after join (spawn/stream-in)
                --   * dead / respawning (death warps you to hospital)
                --   * inside a vehicle (handled per-check below)
                if (now - (pd.joinedAt or 0)) < 30000 then
                    pd.lastPos = GetEntityCoords(ped); pd.lastPosT = now; pd.tpHits = 0
                    goto cont
                end
                if GetEntityHealth(ped) <= 0 then
                    pd.lastPos = GetEntityCoords(ped); pd.lastPosT = now; pd.tpHits = 0
                    goto cont
                end

                local pos = GetEntityCoords(ped)

                if pd.lastPos then
                    local dist    = #(pos - pd.lastPos)
                    local elapsed = (now - pd.lastPosT) / 1000.0
                    local inVeh   = GetVehiclePedIsIn(ped, false) ~= 0

                    if elapsed > 0.5 and not inVeh then
                        -- Require TWO consecutive teleport-sized jumps before flagging.
                        -- A single jump = respawn / interior / admin TP; sustained
                        -- jumping = an actual teleport hack. Always SOFT (kick-max).
                        if dist > cfg.TeleportDistanceThreshold and elapsed < 3.0 then
                            pd.tpHits = (pd.tpHits or 0) + 1
                            if pd.tpHits >= 2 then
                                LAC.flagPlayer(src, 'Teleport', ('%.0fm in %.1fs (x%d)'):format(dist, elapsed, pd.tpHits), 5, false)
                                pd.tpHits = 0
                            end
                        else
                            pd.tpHits = 0
                            local speed = dist / elapsed
                            if speed > cfg.MaxOnFootSpeed then
                                LAC.flagPlayer(src, 'Speed Hack', ('%.1f m/s (%.0f km/h)'):format(speed, speed * 3.6), 3, false)
                            end
                        end
                    end
                end

                pd.lastPos  = pos
                pd.lastPosT = now
                ::cont::
            end
        end
    end
end)

-- =========================================================================
--  6. Honeypot Events (instant ban — no legit client fires these)
-- =========================================================================
for _, hp in ipairs(cfg.Honeypots) do
    RegisterNetEvent(hp, function()
        local src = source
        if LAC.isAdmin(src) then return end

        LAC.sendDiscord('bans', 'HONEYPOT TRIP — AUTO BAN',
            ('**Player:** %s (id: %s)\n**Event:** `%s`\n**Verdict:** Confirmed cheater — no legitimate client triggers this event.')
                :format(GetPlayerName(src) or '?', src, hp),
            16711680, true)

        LAC.banPlayer(src, 'Honeypot Trip', ('Triggered: %s'):format(hp))
    end)
end

-- =========================================================================
--  7. Resource Injection Detection
-- =========================================================================
local baseResourceCount = nil

CreateThread(function()
    Wait(15000)
    baseResourceCount = GetNumResources()

    while true do
        Wait(10000)
        local current = GetNumResources()
        if baseResourceCount and current > baseResourceCount then
            local newRes = {}
            for i = 0, current - 1 do
                local name = GetResourceByFindIndex(i)
                if name and GetResourceState(name) == 'started' then
                    newRes[#newRes + 1] = name
                end
            end

            LAC.sendDiscord('connections', 'Resource Count Changed',
                ('**Previous:** %d\n**Current:** %d\n**Running:** %s')
                    :format(baseResourceCount, current, table.concat(newRes, ', ')),
                16776960)

            baseResourceCount = current
        end
    end
end)

-- =========================================================================
--  8. Client Detector Receivers (token-validated)
-- =========================================================================
local DETECT_GODMODE   = LAC.deriveKey('det:godmode')
local DETECT_RESOURCE  = LAC.deriveKey('det:resource')
local DETECT_NOCLIP    = LAC.deriveKey('det:noclip')
local DETECT_HEALTH    = LAC.deriveKey('det:health')
local DETECT_WEAPON    = LAC.deriveKey('det:weapon')
local DETECT_ANTITAMP  = LAC.deriveKey('det:antitamper')

local function validateClientEvent(src, token, nonce)
    if not token then return true end
    return LAC.validateToken(src, token, nonce)
end

RegisterNetEvent(DETECT_GODMODE, function(token, nonce, detail)
    local src = source
    if LAC.isAdmin(src) then return end
    if not validateClientEvent(src, token, nonce) then return end
    if type(detail) ~= 'string' then return end

    LAC.flagPlayer(src, 'God Mode (client)', detail:sub(1, 100), 8, false)

    LAC.sendDiscord('events', 'God Mode Detected',
        ('**Player:** %s (id: %s)\n**Detail:** %s')
            :format(GetPlayerName(src) or '?', src, detail:sub(1, 100)),
        16711680)
end)

RegisterNetEvent(DETECT_RESOURCE, function(token, nonce, resName)
    local src = source
    if LAC.isAdmin(src) then return end
    if not validateClientEvent(src, token, nonce) then return end
    if type(resName) ~= 'string' then return end

    LAC.sendDiscord('connections', 'Blacklisted Resource Detected',
        ('**Player:** %s (id: %s)\n**Resource:** `%s`')
            :format(GetPlayerName(src) or '?', src, resName:sub(1, 80)),
        16711680, true)

    LAC.banPlayer(src, 'Cheat Menu Detected', ('Resource: %s'):format(resName:sub(1, 80)))
end)

RegisterNetEvent(DETECT_NOCLIP, function(token, nonce, detail)
    local src = source
    if LAC.isAdmin(src) then return end
    if not validateClientEvent(src, token, nonce) then return end
    if type(detail) ~= 'string' then return end

    LAC.flagPlayer(src, 'Noclip (client)', detail:sub(1, 100), 8, false)

    LAC.sendDiscord('events', 'Noclip Detected',
        ('**Player:** %s (id: %s)\n**Detail:** %s')
            :format(GetPlayerName(src) or '?', src, detail:sub(1, 100)),
        16744192)
end)

RegisterNetEvent(DETECT_HEALTH, function(token, nonce, detail)
    local src = source
    if LAC.isAdmin(src) then return end
    if not validateClientEvent(src, token, nonce) then return end
    if type(detail) ~= 'string' then return end

    LAC.flagPlayer(src, 'Health Snap (client)', detail:sub(1, 100), 5, false)

    LAC.sendDiscord('events', 'Suspicious Health Change',
        ('**Player:** %s (id: %s)\n**Detail:** %s')
            :format(GetPlayerName(src) or '?', src, detail:sub(1, 100)),
        16776960)
end)

RegisterNetEvent(DETECT_WEAPON, function(token, nonce, detail)
    local src = source
    if LAC.isAdmin(src) then return end
    if not validateClientEvent(src, token, nonce) then return end
    if type(detail) ~= 'string' then return end

    LAC.flagPlayer(src, 'Blacklisted Weapon (client)', detail:sub(1, 100), 10, true)

    LAC.sendDiscord('events', 'Weapon Injection Detected',
        ('**Player:** %s (id: %s)\n**Weapon:** `%s`')
            :format(GetPlayerName(src) or '?', src, detail:sub(1, 80)),
        16711680)
end)

RegisterNetEvent(DETECT_ANTITAMP, function(token, nonce, detail)
    local src = source
    if LAC.isAdmin(src) then return end
    if not validateClientEvent(src, token, nonce) then return end
    if type(detail) ~= 'string' then return end

    LAC.flagPlayer(src, 'Anti-Tamper / Executor', detail:sub(1, 100), 15, true)

    LAC.sendDiscord('bans', 'EXECUTOR / TAMPER DETECTED',
        ('**Player:** %s (id: %s)\n**Detail:** %s\n**Verdict:** Cheat tool signature or tampered client.')
            :format(GetPlayerName(src) or '?', src, detail:sub(1, 100)),
        16711680, true)
end)

-- Periodic silent integrity re-check
CreateThread(function()
    while true do
        Wait(120000)
        local m = LAC.getMagic()
        local s = LAC.getSeal()
        local check = LAC.deriveKey('hb:challenge')
        if m ~= MAGIC or s ~= SEAL or check ~= HB_CHALLENGE then
            print('^1[Lennox-Anticheat] CRITICAL: signature mismatch — core was tampered. Alerting staff.^7')
            LAC.sendDiscord('connections', 'INTEGRITY VIOLATION',
                'Anti-cheat signature constants no longer match. The core files were modified — restore the original Lennox-Anticheat files.',
                16711680, true)
            return
        end
    end
end)

AddEventHandler('playerDropped', function()
    pendingHB[source] = nil
end)
