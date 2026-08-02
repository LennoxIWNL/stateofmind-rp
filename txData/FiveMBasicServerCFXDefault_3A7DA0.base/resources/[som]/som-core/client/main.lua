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
