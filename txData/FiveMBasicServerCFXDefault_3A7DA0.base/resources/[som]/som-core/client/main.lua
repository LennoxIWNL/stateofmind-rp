-- Client-side player data mirror.
--
-- This is a read-only cache of what the server already decided. Nothing here
-- is authoritative: changing any of it locally changes nothing on the server.

local PlayerData = {}
local isLoaded = false

-- ---------------------------------------------------------------------------
-- Server pushes
-- ---------------------------------------------------------------------------

RegisterNetEvent('som:client:playerLoaded', function(data)
    if type(data) ~= 'table' then return end

    PlayerData = data
    isLoaded = true

    TriggerEvent('som:client:onPlayerLoaded', PlayerData)
end)

RegisterNetEvent('som:client:setMoney', function(money)
    if type(money) ~= 'table' then return end

    PlayerData.money = money
    TriggerEvent('som:client:onMoneyChanged', money)
end)

RegisterNetEvent('som:client:setMetadata', function(metadata)
    if type(metadata) ~= 'table' then return end

    PlayerData.metadata = metadata
    TriggerEvent('som:client:onMetadataChanged', metadata)
end)

-- Job and gang arrive through the replicated state bag rather than an event,
-- so any resource can read them without waiting for som-core to broadcast.
--
-- The bag name is resolved inside the handler rather than passed as a filter:
-- at script load GetPlayerServerId is not reliable yet, so a filter built here
-- would silently never match.
local function ownBagName()
    return ('player:%s'):format(GetPlayerServerId(PlayerId()))
end

AddStateBagChangeHandler('som:job', nil, function(bagName, _, value)
    if bagName ~= ownBagName() then return end
    if type(value) ~= 'table' then return end

    PlayerData.job = value
    TriggerEvent('som:client:onJobChanged', value)
end)

AddStateBagChangeHandler('som:gang', nil, function(bagName, _, value)
    if bagName ~= ownBagName() then return end
    if type(value) ~= 'table' then return end

    PlayerData.gang = value
    TriggerEvent('som:client:onGangChanged', value)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    isLoaded = false
end)

-- ---------------------------------------------------------------------------
-- Exports
--
-- Consumed as: exports['som-core']:getPlayerData()
-- ---------------------------------------------------------------------------

exports('getPlayerData', function() return PlayerData end)
exports('isPlayerLoaded', function() return isLoaded end)

-- Character slots are NOT exposed client side. The cap is per player and a
-- security boundary, so it is resolved server side and fetched with the
-- som:server:getEntitlements callback. See som-core/server/entitlements.lua.

exports('getJob', function() return PlayerData.job end)
exports('getGang', function() return PlayerData.gang end)
exports('getMetadata', function(key)
    if not PlayerData.metadata then return nil end
    if key == nil then return PlayerData.metadata end
    return PlayerData.metadata[key]
end)

---Convenience for the very common "is this player an on duty officer" check.
---Client side only, for UI decisions. Never use it to gate a server action.
exports('hasJob', function(jobName, minGrade, requireDuty)
    local job = PlayerData.job
    if not job or job.name ~= jobName then return false end
    if minGrade and job.grade < minGrade then return false end
    if requireDuty and not job.onduty then return false end
    return true
end)

-- ---------------------------------------------------------------------------
-- Idle camera
--
-- Standing still long enough makes the game swing into its cinematic idle
-- shot, which in an RP server means the camera wanders off mid-conversation.
-- Invalidating it resets the timer, so it never reaches the threshold.
--
-- Both variants are needed: the on-foot one and the in-vehicle one are
-- separate timers and killing only the first still leaves it happening in a
-- parked car.
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        -- Every few seconds is enough. The timer is measured in tens of
        -- seconds, so a per-frame call would be pure waste.
        InvalidateIdleCam()
        InvalidateVehicleIdleCam()
        Wait(5000)
    end
end)

-- ---------------------------------------------------------------------------
-- Vanilla police and the wanted system
--
-- GTA answers crime with its own police: infinite units, helicopters, road
-- blocks and a wanted star system that knows nothing about som-police. Left on,
-- every shooting summons NPC cops who shoot back and arrest nobody, and the
-- player police force is decoration next to them. Turning it off is the single
-- cheapest change that makes a roleplay server feel like one.
--
-- Re-applied on an interval rather than set once. Entering a new session,
-- respawning and some cutscenes reset parts of this, and a setting that
-- silently lapses after the first death is worse than one that was never there.
-- ---------------------------------------------------------------------------

-- The dispatch services GTA can send. Every police, SWAT, army and gang backup
-- response, by index. Fire and ambulance are deliberately absent: they are
-- ambient rather than adversarial, and som-dispatch will own them properly once
-- an EMS job exists.
local SUPPRESSED_DISPATCH = {
    1,   -- police automobile
    2,   -- police helicopter
    4,   -- swat automobile
    6,   -- police riders
    7,   -- police vehicle request
    8,   -- police road block
    9,   -- police automobile waiting, pulled over
    10,  -- police automobile waiting, cruising
    11,  -- gang backup
    12,  -- swat helicopter
    13,  -- police boat
    14,  -- army vehicle
    15,  -- biker backup
}

CreateThread(function()
    local world = Config.World or {}

    if not world.suppressNpcPolice and not world.suppressWantedLevel then return end

    if world.suppressPoliceScanner then
        -- Audio only, and it narrates a wanted system that no longer exists.
        SetAudioFlag('PoliceScannerDisabled', true)
    end

    while true do
        local player = PlayerId()

        if world.suppressWantedLevel then
            -- The ceiling stops stars being gained at all. Clearing on top of
            -- it catches anything scripted that set a level directly.
            SetMaxWantedLevel(0)

            if GetPlayerWantedLevel(player) > 0 then
                SetPlayerWantedLevel(player, 0, false)
                SetPlayerWantedLevelNow(player, false)
            end
        end

        if world.suppressNpcPolice then
            SetPoliceIgnorePlayer(player, true)
            SetCreateRandomCops(false)
            SetCreateRandomCopsNotOnScenarios(false)
            SetCreateRandomCopsOnScenarios(false)

            -- Sirens heard from across the map with no car attached to them.
            DistantCopCarSirens(false)

            for i = 1, #SUPPRESSED_DISPATCH do
                SetDispatchServiceActive(SUPPRESSED_DISPATCH[i], false)
            end
        end

        Wait(world.refreshInterval or 5000)
    end
end)
