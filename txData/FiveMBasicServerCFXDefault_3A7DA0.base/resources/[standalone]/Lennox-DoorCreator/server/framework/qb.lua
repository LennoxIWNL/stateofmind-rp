local QBCore = exports['qb-core']:GetCoreObject()

QBFramework = {}

function QBFramework.getPlayerName(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return 'Unknown' end
    local info = Player.PlayerData.charinfo
    return (info.firstname or '') .. ' ' .. (info.lastname or '')
end

function QBFramework.getPlayerIdentifier(src)
    local Player = QBCore.Functions.GetPlayer(src)
    return Player and Player.PlayerData.citizenid or 'unknown'
end

function QBFramework.isAdmin(src)
    for _, ace in ipairs(Config.AdminAces) do
        if IsPlayerAceAllowed(src, ace) then return true end
    end

    local identifiers = GetPlayerIdentifiers(src)
    for _, id in ipairs(identifiers) do
        for _, adminId in ipairs(Config.AdminIdentifiers) do
            if id == adminId then return true end
        end
    end

    return false
end

function QBFramework.getJobs()
    local jobs = {}
    for k, v in pairs(QBCore.Shared.Jobs) do
        local grades = {}
        if v.grades then
            for gk, gv in pairs(v.grades) do
                grades[#grades + 1] = { grade = tonumber(gk), name = gv.name or tostring(gk) }
            end
            table.sort(grades, function(a, b) return a.grade < b.grade end)
        end
        jobs[#jobs + 1] = { name = k, label = v.label or k, grades = grades }
    end
    table.sort(jobs, function(a, b) return a.name < b.name end)
    return jobs
end

function QBFramework.getGangs()
    local gangs = {}
    if not QBCore.Shared.Gangs then return gangs end
    for k, v in pairs(QBCore.Shared.Gangs) do
        local grades = {}
        if v.grades then
            for gk, gv in pairs(v.grades) do
                grades[#grades + 1] = { grade = tonumber(gk), name = gv.name or tostring(gk) }
            end
            table.sort(grades, function(a, b) return a.grade < b.grade end)
        end
        gangs[#gangs + 1] = { name = k, label = v.label or k, grades = grades }
    end
    table.sort(gangs, function(a, b) return a.name < b.name end)
    return gangs
end

function QBFramework.getName()
    return 'qb'
end
