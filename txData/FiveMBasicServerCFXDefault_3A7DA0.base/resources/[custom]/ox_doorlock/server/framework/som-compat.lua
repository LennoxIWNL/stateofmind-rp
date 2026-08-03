-- SOM framework bridge.
--
-- Byte-for-byte the qb-core bridge, because som-compat answers
-- exports['qb-core']:GetCoreObject() with a SOM-backed object that implements
-- everything this file touches: PlayerData.job, PlayerData.gang and
-- Functions.GetItemByName.
--
-- It is a separate file only because ox_doorlock picks its bridge with
-- GetResourceState(framework), and `provide 'qb-core'` does NOT make
-- GetResourceState('qb-core') report started. Without this, ox_doorlock warned
-- "no compatible framework was loaded" and every job-gated door fell open to
-- everyone.
--
-- Re-apply on an ox_doorlock upgrade, along with the frameworks list in
-- server/utils.lua.

local QBCore = exports['qb-core']:GetCoreObject()

function GetPlayer(playerId)
    return QBCore.Functions.GetPlayer(playerId)
end

function GetCharacterId(player)
    return player.PlayerData.citizenid
end

function IsPlayerInGroup(player, groups)
    local job = player.PlayerData.job
    local gang = player.PlayerData.gang

    if type(groups) == 'table' then
        local jobGrade = groups[job.name]
        if jobGrade and job.grade.level >= jobGrade then
            return job.name, job.grade.level
        end

        local gangGrade = groups[gang.name]
        if gangGrade and gang.grade.level >= gangGrade then
            return gang.name, gang.grade.level
        end
    end

    return false
end

function DoesPlayerHaveItem(player, items)
    if type(items) == 'string' then
        return player.Functions.GetItemByName(items) ~= nil
    end

    if type(items) == 'table' then
        for _, item in pairs(items) do
            local name = type(item) == 'table' and item.name or item
            if player.Functions.GetItemByName(name) then
                return name
            end
        end
    end

    return false
end
