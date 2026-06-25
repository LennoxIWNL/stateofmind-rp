-- =========================================================================
--  Lennox Anti-Cheat v1.0 — Server-Side Damage Model
--  Weapon stat database, per-hit validation, fire rate, range, headshot ratio
-- =========================================================================

local cfg = LACConfig
if not cfg.DamageValidation then return end

-- =========================================================================
--  Weapon Stat Database
--  baseDamage, headshotMult, rpm, effectiveRange (meters), falloffStart
-- =========================================================================
local WeaponStats = {
    -- Pistols
    [0x1B06D571] = { name = 'Pistol',           baseDmg = 26,  hsMult = 4.0, rpm = 310, range = 50,  falloff = 35  },
    [0xBFE256D4] = { name = 'Pistol MK2',       baseDmg = 27,  hsMult = 4.0, rpm = 310, range = 55,  falloff = 40  },
    [0x5EF9FEC4] = { name = 'Combat Pistol',    baseDmg = 27,  hsMult = 4.0, rpm = 310, range = 50,  falloff = 35  },
    [0x22D8FE39] = { name = 'AP Pistol',        baseDmg = 22,  hsMult = 4.0, rpm = 600, range = 40,  falloff = 25  },
    [0x99AEEB3B] = { name = 'Pistol .50',       baseDmg = 51,  hsMult = 4.0, rpm = 155, range = 60,  falloff = 40  },
    [0xBFD21232] = { name = 'SNS Pistol',       baseDmg = 22,  hsMult = 4.0, rpm = 310, range = 35,  falloff = 20  },
    [0x88374054] = { name = 'Heavy Pistol',     baseDmg = 40,  hsMult = 4.0, rpm = 200, range = 55,  falloff = 35  },
    [0x083839C4] = { name = 'Vintage Pistol',   baseDmg = 34,  hsMult = 4.0, rpm = 200, range = 50,  falloff = 30  },
    [0xAF3696A1] = { name = 'Ceramic Pistol',   baseDmg = 36,  hsMult = 4.0, rpm = 240, range = 40,  falloff = 25  },
    -- SMGs
    [0x13532244] = { name = 'Micro SMG',        baseDmg = 21,  hsMult = 4.0, rpm = 700, range = 40,  falloff = 25  },
    [0x2BE6766B] = { name = 'SMG',              baseDmg = 22,  hsMult = 4.0, rpm = 500, range = 55,  falloff = 35  },
    [0x78A97CD0] = { name = 'SMG MK2',          baseDmg = 23,  hsMult = 4.0, rpm = 500, range = 60,  falloff = 40  },
    [0xEFE7E2DF] = { name = 'Assault SMG',      baseDmg = 23,  hsMult = 4.0, rpm = 500, range = 55,  falloff = 35  },
    [0x0A3D4D34] = { name = 'Combat PDW',       baseDmg = 23,  hsMult = 4.0, rpm = 500, range = 55,  falloff = 35  },
    [0xDB1AA450] = { name = 'Mini SMG',         baseDmg = 22,  hsMult = 4.0, rpm = 700, range = 40,  falloff = 25  },
    [0xD205520E] = { name = 'Machine Pistol',   baseDmg = 20,  hsMult = 4.0, rpm = 700, range = 35,  falloff = 20  },
    -- Rifles
    [0xBFEFFF6D] = { name = 'Assault Rifle',    baseDmg = 30,  hsMult = 4.0, rpm = 500, range = 80,  falloff = 60  },
    [0x394F415C] = { name = 'Assault Rifle MK2',baseDmg = 31,  hsMult = 4.0, rpm = 500, range = 90,  falloff = 70  },
    [0x83BF0278] = { name = 'Carbine Rifle',    baseDmg = 32,  hsMult = 4.0, rpm = 500, range = 90,  falloff = 70  },
    [0xFAD1F1C9] = { name = 'Carbine Rifle MK2',baseDmg = 33,  hsMult = 4.0, rpm = 500, range = 100, falloff = 80  },
    [0xAF113F99] = { name = 'Advanced Rifle',   baseDmg = 30,  hsMult = 4.0, rpm = 650, range = 75,  falloff = 55  },
    [0xC0A3098D] = { name = 'Special Carbine',  baseDmg = 32,  hsMult = 4.0, rpm = 500, range = 80,  falloff = 60  },
    [0x969C3D67] = { name = 'Special Carbine MK2',baseDmg = 33, hsMult = 4.0, rpm = 500, range = 90,  falloff = 70  },
    [0x7F229F94] = { name = 'Bullpup Rifle',    baseDmg = 32,  hsMult = 4.0, rpm = 500, range = 80,  falloff = 60  },
    [0x84D6FAFD] = { name = 'Bullpup Rifle MK2',baseDmg = 33,  hsMult = 4.0, rpm = 500, range = 90,  falloff = 70  },
    [0x624FE830] = { name = 'Compact Rifle',    baseDmg = 28,  hsMult = 4.0, rpm = 500, range = 60,  falloff = 40  },
    [0x9D61E50F] = { name = 'Military Rifle',   baseDmg = 32,  hsMult = 4.0, rpm = 450, range = 90,  falloff = 70  },
    [0xC78D71B4] = { name = 'Heavy Rifle',      baseDmg = 40,  hsMult = 4.0, rpm = 350, range = 95,  falloff = 75  },
    -- Shotguns
    [0x1D073A89] = { name = 'Pump Shotgun',     baseDmg = 29,  hsMult = 2.0, rpm = 60,  range = 15,  falloff = 8   },
    [0x555AF99A] = { name = 'Pump Shotgun MK2', baseDmg = 30,  hsMult = 2.0, rpm = 60,  range = 18,  falloff = 10  },
    [0x7846A318] = { name = 'Sawed-Off',        baseDmg = 32,  hsMult = 2.0, rpm = 120, range = 8,   falloff = 4   },
    [0xE284C527] = { name = 'Assault Shotgun',  baseDmg = 32,  hsMult = 2.0, rpm = 300, range = 15,  falloff = 8   },
    [0x12E82D3D] = { name = 'Combat Shotgun',   baseDmg = 54,  hsMult = 2.0, rpm = 120, range = 15,  falloff = 8   },
    -- Sniper
    [0x05FC3C11] = { name = 'Sniper Rifle',     baseDmg = 101, hsMult = 4.0, rpm = 35,  range = 250, falloff = 200 },
    [0x0C472FE2] = { name = 'Heavy Sniper',     baseDmg = 216, hsMult = 4.0, rpm = 25,  range = 300, falloff = 250 },
    [0xA914799] =  { name = 'Heavy Sniper MK2', baseDmg = 216, hsMult = 4.0, rpm = 25,  range = 350, falloff = 300 },
    [0xC734385A] = { name = 'Marksman Rifle',   baseDmg = 65,  hsMult = 4.0, rpm = 160, range = 130, falloff = 100 },
    [0x6A6C02E0] = { name = 'Marksman Rifle MK2',baseDmg = 65, hsMult = 4.0, rpm = 160, range = 150, falloff = 120 },
    -- LMGs
    [0x7FD62962] = { name = 'MG',               baseDmg = 28,  hsMult = 4.0, rpm = 600, range = 80,  falloff = 60  },
    [0xDBBD7280] = { name = 'Combat MG',        baseDmg = 28,  hsMult = 4.0, rpm = 600, range = 90,  falloff = 70  },
    [0xA64DF29C] = { name = 'Combat MG MK2',    baseDmg = 29,  hsMult = 4.0, rpm = 600, range = 100, falloff = 80  },
    [0x61012683] = { name = 'Gusenberg',        baseDmg = 28,  hsMult = 4.0, rpm = 580, range = 70,  falloff = 50  },
    -- Melee (just for reference, damage validation skips these)
    [0xA2719263] = { name = 'Unarmed',          baseDmg = 10,  hsMult = 1.0, rpm = 120, range = 2,   falloff = 1,  melee = true },
    [0x92A27487] = { name = 'Knife',            baseDmg = 25,  hsMult = 1.0, rpm = 120, range = 2,   falloff = 1,  melee = true },
    [0x958A4A8F] = { name = 'Baseball Bat',     baseDmg = 25,  hsMult = 1.0, rpm = 80,  range = 2,   falloff = 1,  melee = true },
}

-- =========================================================================
--  Per-Player Fire Rate Tracking
-- =========================================================================
local FireRateTrack = {}

local function getFireRate(src, weaponHash)
    src = tonumber(src)
    if not FireRateTrack[src] then FireRateTrack[src] = {} end
    local wk = tostring(weaponHash)
    if not FireRateTrack[src][wk] then
        FireRateTrack[src][wk] = { shots = {}, hsCount = 0, totalHits = 0 }
    end
    return FireRateTrack[src][wk]
end

-- =========================================================================
--  Enhanced weaponDamageEvent Hook
-- =========================================================================
AddEventHandler('weaponDamageEvent', function(sender, data)
    local src = tonumber(sender)
    if not src or src <= 0 then return end
    if LAC.isAdmin(src) then return end
    if not data or type(data) ~= 'table' then return end

    local wHash = data.weaponType
    if not wHash then return end
    local stats = WeaponStats[wHash]
    if not stats then return end
    if stats.melee then return end

    local now = GetGameTimer()
    local tolerance = (cfg.DamageTolerancePct or 30) / 100.0
    local fr = getFireRate(src, wHash)

    -- Per-hit damage validation
    if data.weaponDamage and stats.baseDmg then
        local maxExpected = stats.baseDmg * (1 + tolerance) * (data.isHeadShot and stats.hsMult or 1)
        if data.weaponDamage > maxExpected then
            LAC.flagPlayer(src, 'Damage Modifier',
                ('Weapon: %s | Dmg: %.1f (max: %.1f)'):format(stats.name, data.weaponDamage, maxExpected), 5, false)
        end
    end

    -- Fire rate tracking
    fr.shots[#fr.shots + 1] = now
    -- Prune old shots (keep last 30 seconds)
    local pruned = {}
    for _, t in ipairs(fr.shots) do
        if now - t < 30000 then pruned[#pruned + 1] = t end
    end
    fr.shots = pruned

    if #fr.shots >= (cfg.FireRateMinShots or 10) then
        local elapsed = (fr.shots[#fr.shots] - fr.shots[1]) / 1000.0
        if elapsed > 0 then
            local actualRPM = (#fr.shots / elapsed) * 60
            local maxRPM = stats.rpm * ((cfg.FireRateTolerancePct or 130) / 100.0)
            if actualRPM > maxRPM then
                LAC.flagPlayer(src, 'Fire Rate Exploit',
                    ('Weapon: %s | RPM: %.0f (max: %.0f)'):format(stats.name, actualRPM, maxRPM), 5, false)
                fr.shots = {}
            end
        end
    end

    -- Range validation
    if data.hitEntityCoord and data.hitEntityCoord.x then
        local senderPed = GetPlayerPed(src)
        if senderPed and senderPed > 0 then
            local senderPos = GetEntityCoords(senderPed)
            local targetPos = data.hitEntityCoord
            local dx = senderPos.x - targetPos.x
            local dy = senderPos.y - targetPos.y
            local dz = senderPos.z - targetPos.z
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            local maxRange = stats.range * (cfg.DamageRangeMultiplier or 2.0)
            if dist > maxRange then
                LAC.flagPlayer(src, 'Impossible Range',
                    ('Weapon: %s | Dist: %.0fm (max: %.0fm)'):format(stats.name, dist, maxRange), 8, true)
            end
        end
    end

    -- Headshot tracking
    fr.totalHits = fr.totalHits + 1
    if data.isHeadShot then fr.hsCount = fr.hsCount + 1 end

    local hsWindow = cfg.HeadshotWindow or 200
    if fr.totalHits >= hsWindow then
        local hsPct = (fr.hsCount / fr.totalHits) * 100
        if hsPct > (cfg.BehavioralHeadshotThreshold or 65) then
            LAC.sendDiscord('flags', 'Suspicious Headshot Ratio',
                ('**Player:** %s (id: %s)\n**Weapon:** %s\n**Headshot %%:** %.1f%% over %d hits')
                    :format(GetPlayerName(src) or '?', src, stats.name, hsPct, fr.totalHits),
                16776960)
        end
        fr.hsCount = 0
        fr.totalHits = 0
    end

    -- Feed behavioral engine
    if LAC.recordCombatHit then
        LAC.recordCombatHit(src, data.weaponDamage or 0, data.isHeadShot or false, wHash)
    end
end)

-- =========================================================================
--  Cleanup
-- =========================================================================
AddEventHandler('playerDropped', function()
    FireRateTrack[source] = nil
end)

function LAC.getWeaponStats(hash)
    return WeaponStats[hash]
end

exports('GetWeaponStats', function(hash) return LAC.getWeaponStats(hash) end)
