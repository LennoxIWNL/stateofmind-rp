local QBCore = exports['qb-core']:GetCoreObject()

local rosterResponse = nil
local nearbyResponse = nil
local statusResponse = nil
local actionResponse = nil

RegisterNUICallback('getStatus', function(_, cb)
    local pData = QBCore.Functions.GetPlayerData()
    if not pData then cb({ gang = nil, job = nil }); return end

    local gang = pData.gang
    local job = pData.job

    local result = { gang = nil, job = nil }

    if gang and gang.name ~= 'none' then
        result.gang = {
            name = gang.name,
            label = gang.label or gang.name,
            grade = gang.grade and gang.grade.level or 0,
            gradeName = gang.grade and gang.grade.name or 'Unknown',
        }
    end

    if job and job.isboss then
        result.job = {
            name = job.name,
            label = job.label or job.name,
            grade = job.grade and job.grade.level or 0,
            gradeName = job.grade and job.grade.name or 'Unknown',
        }
    end

    cb(result)
end)

RegisterNUICallback('getRoster', function(data, cb)
    rosterResponse = nil
    TriggerServerEvent('som-gangboss:server:getRoster', data.type, data.name)
    local waited = 0
    while rosterResponse == nil and waited < 5000 do
        Wait(50)
        waited = waited + 50
    end
    cb(rosterResponse or { error = 'timeout' })
end)

RegisterNUICallback('getNearby', function(_, cb)
    nearbyResponse = nil
    TriggerServerEvent('som-gangboss:server:getNearby')
    local waited = 0
    while nearbyResponse == nil and waited < 3000 do
        Wait(50)
        waited = waited + 50
    end
    cb({ nearby = nearbyResponse or {} })
end)

RegisterNUICallback('hire', function(data, cb)
    actionResponse = nil
    TriggerServerEvent('som-gangboss:server:hire', data.type, data.name, tonumber(data.targetSrc), tonumber(data.grade) or 0)
    local waited = 0
    while actionResponse == nil and waited < 3000 do
        Wait(50)
        waited = waited + 50
    end
    cb(actionResponse or { ok = true })
end)

RegisterNUICallback('fire', function(data, cb)
    actionResponse = nil
    TriggerServerEvent('som-gangboss:server:fire', data.type, data.name, data.citizenid)
    local waited = 0
    while actionResponse == nil and waited < 3000 do
        Wait(50)
        waited = waited + 50
    end
    cb(actionResponse or { ok = true })
end)

RegisterNUICallback('setGrade', function(data, cb)
    actionResponse = nil
    TriggerServerEvent('som-gangboss:server:setGrade', data.type, data.name, data.citizenid, tonumber(data.grade))
    local waited = 0
    while actionResponse == nil and waited < 3000 do
        Wait(50)
        waited = waited + 50
    end
    cb(actionResponse or { ok = true })
end)

RegisterNetEvent('som-gangboss:client:rosterData', function(data)
    rosterResponse = data
end)

RegisterNetEvent('som-gangboss:client:nearbyData', function(nearby)
    nearbyResponse = nearby
end)

RegisterNetEvent('som-gangboss:client:actionResult', function(result)
    actionResponse = result
end)

RegisterNetEvent('som-gangboss:client:notify', function(msg, nType)
    lib.notify({ title = 'Management', description = msg, type = nType or 'inform', duration = 5000 })
end)
