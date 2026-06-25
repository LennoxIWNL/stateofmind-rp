local QBCore = exports['qb-core']:GetCoreObject()

-- =========================================================================
--  Custom Ranks Cache
-- =========================================================================
local CustomRanks = {}

local function loadCustomRanks()
    MySQL.query('SELECT type, name, grade, custom_label FROM som_custom_ranks', {}, function(results)
        CustomRanks = {}
        if not results then return end
        for _, row in ipairs(results) do
            local key = ('%s:%s:%d'):format(row.type, row.name, row.grade)
            CustomRanks[key] = row.custom_label
        end
    end)
end

local function getCustomLabel(type, name, grade)
    local key = ('%s:%s:%d'):format(type, name, grade)
    return CustomRanks[key]
end

local function resolveGradeName(type, name, grade)
    local custom = getCustomLabel(type, name, grade)
    if custom then return custom end
    local def = type == 'gang' and QBCore.Shared.Gangs[name] or QBCore.Shared.Jobs[name]
    if def and def.grades and def.grades[tostring(grade)] then
        return def.grades[tostring(grade)].name or ('Grade ' .. grade)
    end
    return 'Grade ' .. grade
end

-- =========================================================================
--  Grade List (with custom labels overlaid)
-- =========================================================================
local function getGrades(type, name)
    local grades = {}
    local def = type == 'gang' and QBCore.Shared.Gangs[name] or QBCore.Shared.Jobs[name]
    if def and def.grades then
        for k, v in pairs(def.grades) do
            local level = tonumber(k)
            local label = getCustomLabel(type, name, level) or v.name or ('Grade ' .. k)
            grades[#grades + 1] = { level = level, name = label, defaultName = v.name or ('Grade ' .. k) }
        end
    end
    table.sort(grades, function(a, b) return a.level < b.level end)
    return grades
end

-- =========================================================================
--  Roster Helpers
-- =========================================================================
local function getOnlineMembers(type, name)
    local members = {}
    for _, pid in ipairs(QBCore.Functions.GetPlayers()) do
        local player = QBCore.Functions.GetPlayer(pid)
        if player then
            local data = type == 'gang' and player.PlayerData.gang or player.PlayerData.job
            if data and data.name == name then
                local charinfo = player.PlayerData.charinfo or {}
                local grade = data.grade and data.grade.level or 0
                members[#members + 1] = {
                    src = player.PlayerData.source,
                    citizenid = player.PlayerData.citizenid,
                    name = (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or ''),
                    grade = grade,
                    gradeName = resolveGradeName(type, name, grade),
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
                    local grade = fieldData.grade and fieldData.grade.level or 0
                    members[#members + 1] = {
                        src = nil,
                        citizenid = row.citizenid,
                        name = (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or ''),
                        grade = grade,
                        gradeName = resolveGradeName(type, name, grade),
                        online = false,
                    }
                end
            end
        end
        cb(members)
    end)
end

-- =========================================================================
--  Permission Check
-- =========================================================================
local function hasPermission(player, type, name)
    local pData = type == 'gang' and player.PlayerData.gang or player.PlayerData.job
    if not pData or pData.name ~= name then return false end
    if type == 'job' then
        local gradeInfo = QBCore.Shared.Jobs[name] and QBCore.Shared.Jobs[name].grades[tostring(pData.grade.level)]
        if not gradeInfo or not gradeInfo.isboss then return false end
    end
    return true
end

-- =========================================================================
--  Events
-- =========================================================================
RegisterNetEvent('som-gangboss:server:getRoster', function(type, name)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    local pData = type == 'gang' and player.PlayerData.gang or player.PlayerData.job
    if not pData or pData.name ~= name then return end

    if type == 'job' then
        if not pData.grade or not pData.grade.level then return end
        local gradeInfo = QBCore.Shared.Jobs[name] and QBCore.Shared.Jobs[name].grades[tostring(pData.grade.level)]
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
    if not hasPermission(player, type, name) then return end

    local target = QBCore.Functions.GetPlayer(tonumber(targetSrc))
    if not target then
        TriggerClientEvent('som-gangboss:client:notify', src, 'Player not found or offline', 'error')
        TriggerClientEvent('som-gangboss:client:actionResult', src, { ok = false })
        return
    end

    local label = ''
    local gradeName = resolveGradeName(type, name, grade)
    if type == 'gang' then
        target.Functions.SetGang(name, grade)
        local g = QBCore.Shared.Gangs[name]
        label = g and g.label or name
    else
        target.Functions.SetJob(name, grade)
        local j = QBCore.Shared.Jobs[name]
        label = j and j.label or name
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
    if not hasPermission(player, type, name) then return end

    if targetCid == player.PlayerData.citizenid then
        TriggerClientEvent('som-gangboss:client:notify', src, 'You cannot fire yourself', 'error')
        TriggerClientEvent('som-gangboss:client:actionResult', src, { ok = false })
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
    if not hasPermission(player, type, name) then return end

    local gradeName = resolveGradeName(type, name, newGrade)
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

-- =========================================================================
--  Custom Rank Management
-- =========================================================================
RegisterNetEvent('som-gangboss:server:getCustomRanks', function(type, name)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    if not hasPermission(player, type, name) then return end

    local grades = getGrades(type, name)
    TriggerClientEvent('som-gangboss:client:customRanksData', src, grades)
end)

RegisterNetEvent('som-gangboss:server:setCustomRank', function(orgType, name, grade, customLabel)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    if not hasPermission(player, orgType, name) then return end

    grade = tonumber(grade)
    if not grade then return end
    if type(customLabel) ~= 'string' then return end
    customLabel = customLabel:sub(1, 50):gsub('[<>]', '')

    if customLabel == '' then
        MySQL.query('DELETE FROM som_custom_ranks WHERE type = ? AND name = ? AND grade = ?', { orgType, name, grade })
        local key = ('%s:%s:%d'):format(orgType, name, grade)
        CustomRanks[key] = nil
    else
        MySQL.query([[
            INSERT INTO som_custom_ranks (type, name, grade, custom_label, created_by)
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE custom_label = VALUES(custom_label), created_by = VALUES(created_by)
        ]], { orgType, name, grade, customLabel, player.PlayerData.citizenid })
        local key = ('%s:%s:%d'):format(orgType, name, grade)
        CustomRanks[key] = customLabel
    end

    TriggerClientEvent('som-gangboss:client:notify', src,
        customLabel == '' and 'Rank label reset to default' or ('Rank renamed to "%s"'):format(customLabel), 'success')
    TriggerClientEvent('som-gangboss:client:actionResult', src, { ok = true })
end)

-- =========================================================================
--  Init
-- =========================================================================
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `som_custom_ranks` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `type` ENUM('gang', 'job') NOT NULL,
            `name` VARCHAR(50) NOT NULL,
            `grade` INT NOT NULL,
            `custom_label` VARCHAR(50) NOT NULL,
            `created_by` VARCHAR(50) NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY `unique_rank` (`type`, `name`, `grade`)
        )
    ]], {}, function()
        loadCustomRanks()
        print('^5[som-gangboss-app]^7 Custom ranks table ready')
    end)
end)
