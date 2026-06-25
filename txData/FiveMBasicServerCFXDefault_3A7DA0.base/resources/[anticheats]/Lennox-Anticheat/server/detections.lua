-- =========================================================================
--  Lennox Anti-Cheat — Detection Modules
--  Created by Lennox — DO NOT MODIFY THIS FILE
-- =========================================================================

local cfg = LACConfig

-- =========================================================================
--  Shared: Token Validation Helper
-- =========================================================================
local function validateClientEvent(src, token, nonce)
    if not token then return true end
    return LAC.validateToken(src, token, nonce)
end

-- =========================================================================
--  Helper: Register Client Event (shorthand for standard detection receiver)
-- =========================================================================
function _rce(eventName, displayName, severity, hard, webhookChannel, color)
    RegisterNetEvent(eventName, function(token, nonce, detail)
        local src = source
        if LAC.isAdmin(src) then return end
        if not validateClientEvent(src, token, nonce) then return end
        if type(detail) ~= 'string' then return end
        LAC.flagPlayer(src, displayName, detail:sub(1, 100), severity, hard)
        LAC.sendDiscord(webhookChannel or 'events', displayName,
            ('**Player:** %s (id: %s)\n**Detail:** %s')
                :format(GetPlayerName(src) or '?', src, detail:sub(1, 100)),
            color or 16711680)
    end)
end

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

-- =========================================================================
--  9. Server-Side Ped Model Validation
-- =========================================================================
local ALLOWED_PED_MODELS = {
    [GetHashKey('mp_m_freemode_01')] = true,
    [GetHashKey('mp_f_freemode_01')] = true,
}

CreateThread(function()
    Wait(30000)
    while true do
        Wait(15000)
        for _, pid in ipairs(GetPlayers()) do
            local src = tonumber(pid)
            if not LAC.isAdmin(src) then
                local ped = GetPlayerPed(src)
                if ped and ped > 0 then
                    local model = GetEntityModel(ped)
                    if model and model ~= 0 and not ALLOWED_PED_MODELS[model] then
                        LAC.flagPlayer(src, 'Invalid Ped Model',
                            ('Model: 0x%X'):format(model), 10, true)
                        LAC.sendDiscord('events', 'Invalid Ped Model',
                            ('**Player:** %s (id: %s)\n**Model:** `0x%X`\n**Verdict:** Player is using a non-freemode ped model.')
                                :format(GetPlayerName(src) or '?', src, model),
                            16711680)
                    end
                end
            end
        end
    end
end)

-- =========================================================================
--  10. Server-Side Health/Armor Monitoring
-- =========================================================================
local PlayerHealthCache = {}

CreateThread(function()
    Wait(20000)
    while true do
        Wait(5000)
        for _, pid in ipairs(GetPlayers()) do
            local src = tonumber(pid)
            if not LAC.isAdmin(src) then
                local ped = GetPlayerPed(src)
                if ped and ped > 0 then
                    local health = GetEntityHealth(ped)
                    local armor = GetPedArmour(ped)
                    local cache = PlayerHealthCache[src]

                    if cache then
                        -- Max health is 200, max armor is 100
                        if health > 200 then
                            LAC.flagPlayer(src, 'Impossible Health',
                                ('Health: %d (max 200)'):format(health), 10, true)
                        end
                        if armor > 100 then
                            LAC.flagPlayer(src, 'Impossible Armor',
                                ('Armor: %d (max 100)'):format(armor), 10, true)
                        end
                        -- Detect large health gain without medical item (>50 HP in 5s while not dead)
                        if cache.health > 100 and health > cache.health + 50 then
                            LAC.flagPlayer(src, 'Suspicious Heal (server)',
                                ('Health: %d -> %d in 5s'):format(cache.health, health), 3, false)
                        end
                    end

                    PlayerHealthCache[src] = { health = health, armor = armor }
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    PlayerHealthCache[source] = nil
end)

-- =========================================================================
--  11. New Client Detection Receivers
-- =========================================================================
local DETECT_SUPERJUMP  = LAC.deriveKey('det:superjump')
local DETECT_VEHSPEED   = LAC.deriveKey('det:vehspeed')
local DETECT_AMMO       = LAC.deriveKey('det:ammo')
local DETECT_VISION     = LAC.deriveKey('det:vision')
local DETECT_PEDFLAG    = LAC.deriveKey('det:pedflag')
local DETECT_RESPAWN    = LAC.deriveKey('det:rapidrespawn')

RegisterNetEvent(DETECT_SUPERJUMP, function(token, nonce, detail)
    local src = source
    if LAC.isAdmin(src) then return end
    if not validateClientEvent(src, token, nonce) then return end
    if type(detail) ~= 'string' then return end
    LAC.flagPlayer(src, 'Super Jump', detail:sub(1, 100), 8, false)
    LAC.sendDiscord('events', 'Super Jump Detected',
        ('**Player:** %s (id: %s)\n**Detail:** %s'):format(GetPlayerName(src) or '?', src, detail:sub(1, 100)), 16744192)
end)

RegisterNetEvent(DETECT_VEHSPEED, function(token, nonce, detail)
    local src = source
    if LAC.isAdmin(src) then return end
    if not validateClientEvent(src, token, nonce) then return end
    if type(detail) ~= 'string' then return end
    LAC.flagPlayer(src, 'Vehicle Speed Hack', detail:sub(1, 100), 5, false)
    LAC.sendDiscord('events', 'Vehicle Speed Exceeded',
        ('**Player:** %s (id: %s)\n**Detail:** %s'):format(GetPlayerName(src) or '?', src, detail:sub(1, 100)), 16744192)
end)

RegisterNetEvent(DETECT_AMMO, function(token, nonce, detail)
    local src = source
    if LAC.isAdmin(src) then return end
    if not validateClientEvent(src, token, nonce) then return end
    if type(detail) ~= 'string' then return end
    LAC.flagPlayer(src, 'Infinite Ammo', detail:sub(1, 100), 8, true)
    LAC.sendDiscord('events', 'Infinite Ammo Detected',
        ('**Player:** %s (id: %s)\n**Detail:** %s'):format(GetPlayerName(src) or '?', src, detail:sub(1, 100)), 16711680)
end)

RegisterNetEvent(DETECT_VISION, function(token, nonce, detail)
    local src = source
    if LAC.isAdmin(src) then return end
    if not validateClientEvent(src, token, nonce) then return end
    if type(detail) ~= 'string' then return end
    LAC.flagPlayer(src, 'Unauthorized Vision Mode', detail:sub(1, 100), 5, false)
    LAC.sendDiscord('events', 'Vision Mode Exploit',
        ('**Player:** %s (id: %s)\n**Detail:** %s'):format(GetPlayerName(src) or '?', src, detail:sub(1, 100)), 16776960)
end)

RegisterNetEvent(DETECT_PEDFLAG, function(token, nonce, detail)
    local src = source
    if LAC.isAdmin(src) then return end
    if not validateClientEvent(src, token, nonce) then return end
    if type(detail) ~= 'string' then return end
    LAC.flagPlayer(src, 'Suspicious Ped Flags', detail:sub(1, 100), 8, false)
    LAC.sendDiscord('events', 'Ped Flag Manipulation',
        ('**Player:** %s (id: %s)\n**Detail:** %s'):format(GetPlayerName(src) or '?', src, detail:sub(1, 100)), 16744192)
end)

RegisterNetEvent(DETECT_RESPAWN, function(token, nonce, detail)
    local src = source
    if LAC.isAdmin(src) then return end
    if not validateClientEvent(src, token, nonce) then return end
    if type(detail) ~= 'string' then return end
    LAC.flagPlayer(src, 'Rapid Respawn', detail:sub(1, 100), 10, true)
    LAC.sendDiscord('events', 'Rapid Respawn Detected',
        ('**Player:** %s (id: %s)\n**Detail:** %s'):format(GetPlayerName(src) or '?', src, detail:sub(1, 100)), 16711680)
end)

-- =========================================================================
--  v4.0 — New Detection Receivers
-- =========================================================================
local DETECT_ENVTAMPER   = LAC.deriveKey('det:envtamper')
local DETECT_CANARY      = LAC.deriveKey('det:canary')
local DETECT_COMBAT      = LAC.deriveKey('det:combat')
local DETECT_VEHFLY      = LAC.deriveKey('det:vehfly')
local DETECT_SWIMSPEED   = LAC.deriveKey('det:swimspeed')
local DETECT_PTFXSPAM    = LAC.deriveKey('det:particlespam')
local DETECT_SHOOTDEAD   = LAC.deriveKey('det:shootdead')

RegisterNetEvent(DETECT_ENVTAMPER, function(token, nonce, detail)
    local src = source
    if LAC.isAdmin(src) then return end
    if not validateClientEvent(src, token, nonce) then return end
    if type(detail) ~= 'string' then return end
    LAC.flagPlayer(src, 'Environment Tampering', detail:sub(1, 100), 20, true)
    LAC.sendDiscord('bans', 'ENVIRONMENT TAMPERING — EXECUTOR DETECTED',
        ('**Player:** %s (id: %s)\n**Detail:** %s\n**Verdict:** Core Lua functions or FiveM natives have been hooked/replaced. This is definitive proof of an executor.')
            :format(GetPlayerName(src) or '?', src, detail:sub(1, 100)), 16711680, true)
end)

RegisterNetEvent(DETECT_CANARY, function(token, nonce, detail)
    local src = source
    if LAC.isAdmin(src) then return end
    if not validateClientEvent(src, token, nonce) then return end
    if type(detail) ~= 'string' then return end
    LAC.flagPlayer(src, 'Canary Tripped', detail:sub(1, 100), 15, true)
    LAC.sendDiscord('bans', 'MEMORY TAMPERING DETECTED',
        ('**Player:** %s (id: %s)\n**Detail:** %s\n**Verdict:** Planted canary values were modified — indicates memory editor or cheat tool scanning globals.')
            :format(GetPlayerName(src) or '?', src, detail:sub(1, 100)), 16711680, true)
end)

RegisterNetEvent(DETECT_COMBAT, function(token, nonce, detail)
    local src = source
    if LAC.isAdmin(src) then return end
    if not validateClientEvent(src, token, nonce) then return end
    if type(detail) ~= 'string' then return end
    LAC.flagPlayer(src, 'Combat Exploit', detail:sub(1, 100), 8, false)
    LAC.sendDiscord('events', 'Combat Exploit Detected',
        ('**Player:** %s (id: %s)\n**Detail:** %s'):format(GetPlayerName(src) or '?', src, detail:sub(1, 100)), 16711680)
end)

RegisterNetEvent(DETECT_VEHFLY, function(token, nonce, detail)
    local src = source
    if LAC.isAdmin(src) then return end
    if not validateClientEvent(src, token, nonce) then return end
    if type(detail) ~= 'string' then return end
    LAC.flagPlayer(src, 'Vehicle Fly Hack', detail:sub(1, 100), 8, true)
    LAC.sendDiscord('events', 'Vehicle Fly Hack',
        ('**Player:** %s (id: %s)\n**Detail:** %s\n**Verdict:** Non-aircraft vehicle gaining sustained altitude.')
            :format(GetPlayerName(src) or '?', src, detail:sub(1, 100)), 16711680)
end)

RegisterNetEvent(DETECT_SWIMSPEED, function(token, nonce, detail)
    local src = source
    if LAC.isAdmin(src) then return end
    if not validateClientEvent(src, token, nonce) then return end
    if type(detail) ~= 'string' then return end
    LAC.flagPlayer(src, 'Swim Speed Hack', detail:sub(1, 100), 5, false)
    LAC.sendDiscord('events', 'Swim Speed Exceeded',
        ('**Player:** %s (id: %s)\n**Detail:** %s'):format(GetPlayerName(src) or '?', src, detail:sub(1, 100)), 16744192)
end)

RegisterNetEvent(DETECT_PTFXSPAM, function(token, nonce, detail)
    local src = source
    if LAC.isAdmin(src) then return end
    if not validateClientEvent(src, token, nonce) then return end
    if type(detail) ~= 'string' then return end
    LAC.flagPlayer(src, 'Particle Effect Spam', detail:sub(1, 100), 8, true)
    LAC.sendDiscord('events', 'Particle Spam Detected',
        ('**Player:** %s (id: %s)\n**Detail:** %s'):format(GetPlayerName(src) or '?', src, detail:sub(1, 100)), 16711680)
end)

RegisterNetEvent(DETECT_SHOOTDEAD, function(token, nonce, detail)
    local src = source
    if LAC.isAdmin(src) then return end
    if not validateClientEvent(src, token, nonce) then return end
    if type(detail) ~= 'string' then return end
    LAC.flagPlayer(src, 'Shooting While Dead', detail:sub(1, 100), 10, true)
    LAC.sendDiscord('events', 'Shooting While Dead',
        ('**Player:** %s (id: %s)\n**Detail:** %s'):format(GetPlayerName(src) or '?', src, detail:sub(1, 100)), 16711680)
end)

-- =========================================================================
--  v1.0 Full Release — New Detection Receivers
-- =========================================================================
local DETECT_HWSPOOF     = LAC.deriveKey('det:hwfingerprint')
local DETECT_FREECAM     = LAC.deriveKey('det:freecam')
local DETECT_PROGTELE    = LAC.deriveKey('det:progteleport')
local DETECT_WORLDMANIP  = LAC.deriveKey('det:worldmanip')
local DETECT_OBJSPAM     = LAC.deriveKey('det:objectspam')

_rce(DETECT_HWSPOOF, 'HWID Spoof (mid-session)', 15, true, 'bans', 16711680)
_rce(DETECT_FREECAM, 'Freecam Detected', 10, true, 'events', 16711680)
_rce(DETECT_PROGTELE, 'Progressive Teleport', 8, false, 'events', 16744192)
_rce(DETECT_WORLDMANIP, 'World Manipulation', 5, false, 'events', 16776960)
_rce(DETECT_OBJSPAM, 'Object Spam', 8, false, 'events', 16744192)

-- =========================================================================
--  Pass 2 — New Detection Receivers
-- =========================================================================
local DETECT_GODTEST    = LAC.deriveKey('det:godtest')
local DETECT_VEHHANDLE  = LAC.deriveKey('det:vehhandle')
local DETECT_NOCLIPWALL = LAC.deriveKey('det:noclipwall')
local DETECT_SPECTADV   = LAC.deriveKey('det:spectadv')
local DETECT_OBJMANIP   = LAC.deriveKey('det:objmanip')
local DETECT_PEDMANIP   = LAC.deriveKey('det:pedmanip')
local DETECT_NETMANIP   = LAC.deriveKey('det:netmanip')
local DETECT_VEHADV     = LAC.deriveKey('det:vehadv')
local DETECT_PERF       = LAC.deriveKey('det:perf')
local DETECT_RESINTEG   = LAC.deriveKey('det:resinteg')

_rce(DETECT_GODTEST, 'God Mode (server test)', 10, true, 'bans', 16711680)
_rce(DETECT_VEHHANDLE, 'Vehicle Handling Exploit', 8, false, 'events', 16744192)
_rce(DETECT_NOCLIPWALL, 'Advanced Noclip', 8, false, 'events', 16744192)
_rce(DETECT_SPECTADV, 'Advanced Spectate', 5, false, 'events', 16776960)
_rce(DETECT_OBJMANIP, 'Object/Prop Manipulation', 8, false, 'events', 16744192)
_rce(DETECT_PEDMANIP, 'Ped Manipulation', 8, false, 'events', 16711680)
_rce(DETECT_NETMANIP, 'Network Manipulation', 8, false, 'events', 16711680)
_rce(DETECT_VEHADV, 'Advanced Vehicle Exploit', 8, true, 'events', 16711680)
_rce(DETECT_PERF, 'Performance Attack', 5, false, 'events', 16776960)
_rce(DETECT_RESINTEG, 'Resource Integrity Failure', 15, true, 'bans', 16711680)

-- =========================================================================
--  Pass 2 — Advanced God Mode: Server-Instrumented Health Test
-- =========================================================================
local GOD_TEST_REQ  = LAC.deriveKey('lac:godtest:req')
local GOD_TEST_RESP = LAC.deriveKey('lac:godtest:resp')
local RAG_TEST_REQ  = LAC.deriveKey('lac:ragtest:req')
local RAG_TEST_RESP = LAC.deriveKey('lac:ragtest:resp')

local PendingGodTests = {}
local PendingRagTests = {}

RegisterNetEvent(GOD_TEST_RESP, function(token, nonce, healthBefore, healthAfter)
    local src = source
    if LAC.isAdmin(src) then return end
    if not validateClientEvent(src, token, nonce) then return end
    local pending = PendingGodTests[src]
    if not pending then return end
    PendingGodTests[src] = nil

    healthBefore = tonumber(healthBefore) or 0
    healthAfter = tonumber(healthAfter) or 0

    if healthAfter >= healthBefore and healthBefore > 100 then
        LAC.flagPlayer(src, 'God Mode (server test)',
            ('Health did not decrease: before=%d after=%d'):format(healthBefore, healthAfter), 10, true)
        LAC.sendDiscord('bans', 'GOD MODE CONFIRMED — SERVER TEST',
            ('**Player:** %s (id: %s)\n**Health:** %d → %d (expected decrease)\n**Verdict:** Server-instrumented damage test failed.')
                :format(GetPlayerName(src) or '?', src, healthBefore, healthAfter), 16711680, true)
    end
end)

RegisterNetEvent(RAG_TEST_RESP, function(token, nonce, didRagdoll)
    local src = source
    if LAC.isAdmin(src) then return end
    if not validateClientEvent(src, token, nonce) then return end
    local pending = PendingRagTests[src]
    if not pending then return end
    PendingRagTests[src] = nil

    if not didRagdoll then
        LAC.flagPlayer(src, 'Ragdoll Resistance',
            'Server-initiated ragdoll test failed — ped did not ragdoll', 8, false)
    end
end)

CreateThread(function()
    Wait(60000)
    while true do
        Wait(cfg.GodModeTestInterval or 120000)
        for _, pid in ipairs(GetPlayers()) do
            local src = tonumber(pid)
            if not LAC.isAdmin(src) then
                local ped = GetPlayerPed(src)
                if ped and ped > 0 and GetEntityHealth(ped) > 100 then
                    PendingGodTests[src] = { sentAt = GetGameTimer(), expectedHealth = GetEntityHealth(ped) }
                    TriggerClientEvent(GOD_TEST_REQ, src, cfg.GodModeTestDamage or 1)
                end
            end
        end
    end
end)

CreateThread(function()
    Wait(90000)
    while true do
        Wait(cfg.RagdollTestInterval or 180000)
        for _, pid in ipairs(GetPlayers()) do
            local src = tonumber(pid)
            if not LAC.isAdmin(src) then
                local ped = GetPlayerPed(src)
                if ped and ped > 0 and GetEntityHealth(ped) > 100 then
                    PendingRagTests[src] = { sentAt = GetGameTimer() }
                    TriggerClientEvent(RAG_TEST_REQ, src)
                end
            end
        end
    end
end)

-- Timeout pending tests
CreateThread(function()
    while true do
        Wait(30000)
        local now = GetGameTimer()
        for src, test in pairs(PendingGodTests) do
            if now - test.sentAt > 15000 then PendingGodTests[src] = nil end
        end
        for src, test in pairs(PendingRagTests) do
            if now - test.sentAt > 15000 then PendingRagTests[src] = nil end
        end
    end
end)

-- Server-side health authoritativeness
local ServerHealthTrack = {}

CreateThread(function()
    Wait(30000)
    while true do
        Wait(5000)
        for _, pid in ipairs(GetPlayers()) do
            local src = tonumber(pid)
            if not LAC.isAdmin(src) then
                local ped = GetPlayerPed(src)
                if ped and ped > 0 then
                    local health = GetEntityHealth(ped)
                    local prev = ServerHealthTrack[src]
                    if prev then
                        if health > prev.health + 100 and prev.health > 100 then
                            local veh = GetVehiclePedIsIn(ped, false)
                            if veh == 0 then
                                LAC.flagPlayer(src, 'Server Health Authority',
                                    ('Health jumped %d→%d without known heal'):format(prev.health, health), 5, false)
                            end
                        end
                    end
                    ServerHealthTrack[src] = { health = health, time = GetGameTimer() }
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    PendingGodTests[src] = nil
    PendingRagTests[src] = nil
    ServerHealthTrack[src] = nil
end)

-- =========================================================================
--  Pass 2 — Vehicle God Mode Detection
-- =========================================================================
local VehicleHealthTrack = {}

CreateThread(function()
    Wait(30000)
    while true do
        Wait(5000)
        for _, pid in ipairs(GetPlayers()) do
            local src = tonumber(pid)
            if not LAC.isAdmin(src) then
                local ped = GetPlayerPed(src)
                if ped and ped > 0 then
                    local veh = GetVehiclePedIsIn(ped, false)
                    if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                        local vehHealth = GetEntityHealth(veh)
                        local vehId = NetworkGetNetworkIdFromEntity(veh)
                        local prev = VehicleHealthTrack[src]
                        if prev and prev.vehId == vehId then
                            if vehHealth > prev.health + 500 and prev.health > 0 then
                                LAC.flagPlayer(src, 'Vehicle God Mode',
                                    ('Vehicle health jumped %d→%d'):format(prev.health, vehHealth), 8, false)
                            end
                        end
                        VehicleHealthTrack[src] = { health = vehHealth, time = GetGameTimer(), vehId = vehId }
                    else
                        VehicleHealthTrack[src] = nil
                    end
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    VehicleHealthTrack[source] = nil
end)

-- =========================================================================
--  12. Global Event Rate Limiter
-- =========================================================================
local EventRates = {}

AddEventHandler('__cfx_internal:commandFallback', function(name)
    local src = source
    if not src or src <= 0 then return end
    if LAC.isAdmin(src) then return end

    local now = GetGameTimer()
    if not EventRates[src] then EventRates[src] = { count = 0, reset = now } end
    local er = EventRates[src]

    if now - er.reset > (cfg.GlobalEventRateWindow or 1000) then
        er.count = 0; er.reset = now
    end
    er.count = er.count + 1

    if er.count > (cfg.GlobalEventRateLimit or 100) then
        LAC.flagPlayer(src, 'Event Rate Limit',
            ('%d events/sec'):format(er.count), 5, false)
    end
end)

AddEventHandler('playerDropped', function()
    EventRates[source] = nil
end)

-- =========================================================================
--  13. Server-Side Vehicle Teleport Detection
-- =========================================================================
local VehiclePositions = {}

CreateThread(function()
    Wait(20000)
    while true do
        Wait(3000)
        for _, pid in ipairs(GetPlayers()) do
            local src = tonumber(pid)
            if not LAC.isAdmin(src) then
                local ped = GetPlayerPed(src)
                if ped and ped > 0 then
                    local veh = GetVehiclePedIsIn(ped, false)
                    if veh ~= 0 then
                        local pos = GetEntityCoords(veh)
                        local vehId = NetworkGetNetworkIdFromEntity(veh)
                        local prev = VehiclePositions[src]

                        if prev and prev.vehId == vehId then
                            local dist = #(pos - prev.pos)
                            local elapsed = (GetGameTimer() - prev.time) / 1000.0
                            if elapsed > 0.5 and dist > 500.0 and elapsed < 3.0 then
                                local pd = LAC.getPlayerData(src)
                                if (GetGameTimer() - (pd.joinedAt or 0)) > 30000 then
                                    LAC.flagPlayer(src, 'Vehicle Teleport',
                                        ('%.0fm in %.1fs'):format(dist, elapsed), 5, false)
                                end
                            end
                        end

                        VehiclePositions[src] = { pos = pos, time = GetGameTimer(), vehId = vehId }
                    else
                        VehiclePositions[src] = nil
                    end
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    VehiclePositions[source] = nil
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
