ESXFramework = {}

local ESX

function ESXFramework.init()
    if not ESX then
        ESX = exports['es_extended']:getSharedObject()
    end
end

function ESXFramework.getPlayerName(src)
    ESXFramework.init()
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.getName() or 'Unknown'
end

function ESXFramework.getPlayerIdentifier(src)
    ESXFramework.init()
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.getIdentifier() or 'unknown'
end

function ESXFramework.isAdmin(src)
    for _, ace in ipairs(Config.AdminAces) do
        if IsPlayerAceAllowed(src, ace) then return true end
    end

    local identifiers = GetPlayerIdentifiers(src)
    for _, id in ipairs(identifiers) do
        for _, adminId in ipairs(Config.AdminIdentifiers) do
            if id == adminId then return true end
        end
    end

    ESXFramework.init()
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        local group = xPlayer.getGroup()
        if group == 'admin' or group == 'superadmin' then return true end
    end

    return false
end

function ESXFramework.getJobs()
    ESXFramework.init()
    local jobs = {}
    local result = MySQL.query.await('SELECT name, label, grades FROM jobs')
    if result then
        for _, row in ipairs(result) do
            local grades = {}
            local gradeData = json.decode(row.grades or '{}')
            if type(gradeData) == 'table' then
                for gk, gv in pairs(gradeData) do
                    grades[#grades + 1] = { grade = tonumber(gk), name = gv.label or tostring(gk) }
                end
                table.sort(grades, function(a, b) return a.grade < b.grade end)
            end
            jobs[#jobs + 1] = { name = row.name, label = row.label or row.name, grades = grades }
        end
    end
    table.sort(jobs, function(a, b) return a.name < b.name end)
    return jobs
end

function ESXFramework.getGangs()
    return {}
end

function ESXFramework.getName()
    return 'esx'
end
