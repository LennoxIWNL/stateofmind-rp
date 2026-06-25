local QBCore = exports['qb-core']:GetCoreObject()

local function getGrades(type, name)
    local grades = {}
    if type == 'gang' then
        local gang = QBCore.Shared.Gangs[name]
        if gang and gang.grades then
            for k, v in pairs(gang.grades) do
                grades[#grades + 1] = { level = tonumber(k), name = v.name or ('Grade ' .. k) }
            end
        end
    else
        local job = QBCore.Shared.Jobs[name]
        if job and job.grades then
            for k, v in pairs(job.grades) do
                grades[#grades + 1] = { level = tonumber(k), name = v.name or ('Grade ' .. k) }
            end
        end
    end
    table.sort(grades, function(a, b) return a.level < b.level end)
    return grades
end

local function getOnlineMembers(type, name)
    local members = {}
    for _, pid in ipairs(QBCore.Functions.GetPlayers()) do
        local player = QBCore.Functions.GetPlayer(pid)
        if player then
            local data = type == 'gang' and player.PlayerData.gang or player.PlayerData.job
            if data and data.name == name then
                local charinfo = player.PlayerData.charinfo or {}
                members[#members + 1] = {
                    src = player.PlayerData.source,
                    citizenid = player.PlayerData.citizenid,
                    name = (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or ''),
                    grade = data.grade and data.grade.level or 0,
                    gradeName = data.grade and data.grade.name or 'Unknown',
                    online = true,
                }
            end
        end
    end
    return members
end

local function getOfflineMembers(type, name, onlineCids, cb)
    local field = type == 'gang' and 'gang' or 'job'
    MySQL.query('SELECT citizenid, charinfo, ' .. field .. ' FROM players WHERE JSON_EXTRACT(' .. field .. ', "$.name") = ?', { name }, function(results)
        local members = {}
        if not results then cb(members); return end
        for _, row in ipairs(results) do
            if not onlineCids[row.citizenid] then
                local ok1, charinfo = pcall(json.decode, row.charinfo)
                local ok2, fieldData = pcall(json.decode, row[field])
                if ok1 and ok2 then
                    local grade = fieldData.grade or {}
                    members[#members + 1] = {
                        src = nil,
                        citizenid = row.citizenid,
                        name = (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or ''),
                        grade = grade.level or 0,
                        gradeName = grade.name or 'Unknown',
                        online = false,
                    }
                end
            end
        end
        cb(members)
    end)
end

RegisterNetEvent('som-gangboss:server:getRoster', function(type, name)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    local pData = type == 'gang' and player.PlayerData.gang or player.PlayerData.job
    if not pData or pData.name ~= name then return end

    if type == 'job' then
        if not pData.grade or not pData.grade.level then return end
        local jobDef = QBCore.Shared.Jobs[name]
        if not jobDef then return end
        local maxGrade = -1
        for k in pairs(jobDef.grades or {}) do
            if tonumber(k) > maxGrade then maxGrade = tonumber(k) end
        end
        local gradeInfo = jobDef.grades and jobDef.grades[tostring(pData.grade.level)]
        if not gradeInfo or not gradeInfo.isboss then return end
    end

    local onlineMembers = getOnlineMembers(type, name)
    local onlineCids = {}
    for _, m in ipairs(onlineMembers) do onlineCids[m.citizenid] = true end

    getOfflineMembers(type, name, onlineCids, function(offlineMembers)
        local roster = {}
        for _, m in ipairs(onlineMembers) do roster[#roster + 1] = m end
        for _, m in ipairs(offlineMembers) do roster[#roster + 1] = m end
        table.sort(roster, function(a, b)
            if a.online ~= b.online then return a.online end
            return a.grade > b.grade
        end)

        local grades = getGrades(type, name)
        local label = ''
        if type == 'gang' then
            local g = QBCore.Shared.Gangs[name]
            label = g and g.label or name
        else
            local j = QBCore.Shared.Jobs[name]
            label = j and j.label or name
        end

        TriggerClientEvent('som-gangboss:client:rosterData', src, {
            type = type,
            name = name,
            label = label,
            roster = roster,
            grades = grades,
        })
    end)
end)

RegisterNetEvent('som-gangboss:server:getNearby', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    local ped = GetPlayerPed(src)
    if not ped or ped <= 0 then return end
    local myCoords = GetEntityCoords(ped)

    local nearby = {}
    for _, pid in ipairs(QBCore.Functions.GetPlayers()) do
        if tonumber(pid) ~= src then
            local tPed = GetPlayerPed(pid)
            if tPed and tPed > 0 then
                local tCoords = GetEntityCoords(tPed)
                local dist = #(myCoords - tCoords)
                if dist <= Config.MaxHireDistance then
                    local tp = QBCore.Functions.GetPlayer(pid)
                    if tp then
                        local ci = tp.PlayerData.charinfo or {}
                        nearby[#nearby + 1] = {
                            src = tonumber(pid),
                            name = (ci.firstname or '') .. ' ' .. (ci.lastname or ''),
                            dist = math.floor(dist * 10) / 10,
                        }
                    end
                end
            end
        end
    end

    table.sort(nearby, function(a, b) return a.dist < b.dist end)
    TriggerClientEvent('som-gangboss:client:nearbyData', src, nearby)
end)

RegisterNetEvent('som-gangboss:server:hire', function(type, name, targetSrc, grade)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    grade = tonumber(grade) or 0

    local pData = type == 'gang' and player.PlayerData.gang or player.PlayerData.job
    if not pData or pData.name ~= name then return end

    if type == 'job' then
        local gradeInfo = QBCore.Shared.Jobs[name] and QBCore.Shared.Jobs[name].grades[tostring(pData.grade.level)]
        if not gradeInfo or not gradeInfo.isboss then return end
    end

    local target = QBCore.Functions.GetPlayer(tonumber(targetSrc))
    if not target then
        TriggerClientEvent('som-gangboss:client:notify', src, 'Player not found or offline', 'error')
        return
    end

    local label = ''
    local gradeName = ''
    if type == 'gang' then
        target.Functions.SetGang(name, grade)
        local g = QBCore.Shared.Gangs[name]
        label = g and g.label or name
        gradeName = g and g.grades and g.grades[tostring(grade)] and g.grades[tostring(grade)].name or ('Grade ' .. grade)
    else
        target.Functions.SetJob(name, grade)
        local j = QBCore.Shared.Jobs[name]
        label = j and j.label or name
        gradeName = j and j.grades and j.grades[tostring(grade)] and j.grades[tostring(grade)].name or ('Grade ' .. grade)
    end

    TriggerClientEvent('som-gangboss:client:notify', src, ('Hired %s as %s'):format(
        (target.PlayerData.charinfo.firstname or '') .. ' ' .. (target.PlayerData.charinfo.lastname or ''),
        gradeName), 'success')

    TriggerClientEvent('som-gangboss:client:notify', tonumber(targetSrc),
        Config.Notifications.hired:format(label, gradeName), 'success')

    TriggerClientEvent('som-gangboss:client:actionResult', src, { ok = true })
end)

RegisterNetEvent('som-gangboss:server:fire', function(type, name, targetCid)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    local pData = type == 'gang' and player.PlayerData.gang or player.PlayerData.job
    if not pData or pData.name ~= name then return end

    if type == 'job' then
        local gradeInfo = QBCore.Shared.Jobs[name] and QBCore.Shared.Jobs[name].grades[tostring(pData.grade.level)]
        if not gradeInfo or not gradeInfo.isboss then return end
    end

    if targetCid == player.PlayerData.citizenid then
        TriggerClientEvent('som-gangboss:client:notify', src, 'You cannot fire yourself', 'error')
        return
    end

    local label = ''
    if type == 'gang' then
        local g = QBCore.Shared.Gangs[name]
        label = g and g.label or name
    else
        local j = QBCore.Shared.Jobs[name]
        label = j and j.label or name
    end

    local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(targetCid)
    if targetPlayer then
        if type == 'gang' then
            targetPlayer.Functions.SetGang('none', 0)
        else
            targetPlayer.Functions.SetJob('unemployed', 0)
        end
        TriggerClientEvent('som-gangboss:client:notify', targetPlayer.PlayerData.source,
            Config.Notifications.fired:format(label), 'error')
    else
        local field = type == 'gang' and 'gang' or 'job'
        local newVal = type == 'gang'
            and json.encode({ name = 'none', label = 'No Gang', isboss = false, grade = { name = 'Unaffiliated', level = 0 } })
            or json.encode({ name = 'unemployed', label = 'Civilian', isboss = false, onduty = false, type = 'none', grade = { name = 'Freelancer', level = 0 } })
        MySQL.update('UPDATE players SET ' .. field .. ' = ? WHERE citizenid = ?', { newVal, targetCid })
    end

    TriggerClientEvent('som-gangboss:client:notify', src, 'Member removed', 'success')
    TriggerClientEvent('som-gangboss:client:actionResult', src, { ok = true })
end)

RegisterNetEvent('som-gangboss:server:setGrade', function(type, name, targetCid, newGrade)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    newGrade = tonumber(newGrade) or 0

    local pData = type == 'gang' and player.PlayerData.gang or player.PlayerData.job
    if not pData or pData.name ~= name then return end

    if type == 'job' then
        local gradeInfo = QBCore.Shared.Jobs[name] and QBCore.Shared.Jobs[name].grades[tostring(pData.grade.level)]
        if not gradeInfo or not gradeInfo.isboss then return end
    end

    local label = ''
    local gradeName = ''
    if type == 'gang' then
        local g = QBCore.Shared.Gangs[name]
        label = g and g.label or name
        gradeName = g and g.grades and g.grades[tostring(newGrade)] and g.grades[tostring(newGrade)].name or ('Grade ' .. newGrade)
    else
        local j = QBCore.Shared.Jobs[name]
        label = j and j.label or name
        gradeName = j and j.grades and j.grades[tostring(newGrade)] and j.grades[tostring(newGrade)].name or ('Grade ' .. newGrade)
    end

    local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(targetCid)
    if targetPlayer then
        if type == 'gang' then
            targetPlayer.Functions.SetGang(name, newGrade)
        else
            targetPlayer.Functions.SetJob(name, newGrade)
        end

        local oldGrade = (type == 'gang' and targetPlayer.PlayerData.gang or targetPlayer.PlayerData.job)
        local notifKey = newGrade > (oldGrade and oldGrade.grade and oldGrade.grade.level or 0) and 'promoted' or 'demoted'
        TriggerClientEvent('som-gangboss:client:notify', targetPlayer.PlayerData.source,
            Config.Notifications[notifKey]:format(gradeName, label), notifKey == 'promoted' and 'success' or 'inform')
    else
        local field = type == 'gang' and 'gang' or 'job'
        MySQL.single('SELECT ' .. field .. ' FROM players WHERE citizenid = ?', { targetCid }, function(row)
            if not row then return end
            local ok, data = pcall(json.decode, row[field])
            if not ok then return end
            data.grade = { name = gradeName, level = newGrade }
            MySQL.update('UPDATE players SET ' .. field .. ' = ? WHERE citizenid = ?', { json.encode(data), targetCid })
        end)
    end

    TriggerClientEvent('som-gangboss:client:notify', src, ('Set rank to %s'):format(gradeName), 'success')
    TriggerClientEvent('som-gangboss:client:actionResult', src, { ok = true })
end)
