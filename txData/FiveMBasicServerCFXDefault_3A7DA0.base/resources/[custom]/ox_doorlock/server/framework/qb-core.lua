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
