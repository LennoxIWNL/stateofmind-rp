-- qb-core compatibility shim, client side.
-- Same contract as the server half: only what preserved resources actually call.

local QBCore = {
    Functions = {},
    Shared = { Vehicles = {}, Items = {} },
}

local core = exports['som-core']

function QBCore.Functions.GetPlayerData()
    local data = core:getPlayerData()
    if not data or not data.job then return {} end

    return {
        citizenid = data.citizenid,
        charinfo = data.charinfo,
        money = data.money,
        metadata = data.metadata,
        job = {
            name = data.job.name,
            label = data.job.label,
            type = data.job.type,
            onduty = data.job.onduty,
            isboss = data.job.isboss,
            grade = { name = data.job.gradeLabel, level = data.job.grade },
        },
        gang = {
            name = data.gang.name,
            label = data.gang.label,
            isboss = data.gang.isboss,
            grade = { name = data.gang.gradeLabel, level = data.gang.grade },
        },
    }
end

function QBCore.Functions.Notify(message, notifyType, duration)
    TriggerEvent('som:client:notify', message, notifyType, duration)
end

function QBCore.Functions.TriggerCallback(name, cb, ...)
    lib.callback(name, false, cb, ...)
end

function QBCore.Functions.GetPlate(vehicle)
    if not vehicle or vehicle == 0 then return nil end
    return GetVehicleNumberPlateText(vehicle):gsub('^%s*(.-)%s*$', '%1')
end

function QBCore.Functions.RequestAnimDict(dict)
    if HasAnimDictLoaded(dict) then return end

    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(0)
    end
end

function QBCore.Functions.SpawnVehicle(model, cb, coords, isnetworked)
    local hash = type(model) == 'string' and joaat(model) or model

    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(0)
    end

    coords = coords or GetEntityCoords(cache.ped)
    local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, coords.w or 0.0, isnetworked ~= false, false)
    SetModelAsNoLongerNeeded(hash)

    if cb then cb(veh) end
    return veh
end

function QBCore.Functions.SetVehicleProperties(vehicle, props)
    if not vehicle or vehicle == 0 or type(props) ~= 'table' then return end
    lib.setVehicleProperties(vehicle, props)
end

exports('GetCoreObject', function()
    return QBCore
end)

AddEventHandler('QBCore:GetObject', function(cb)
    cb(QBCore)
end)

-- ps-mdt/client/cl_impound.lua fires this after spawning a released vehicle.
-- Vehicle keys are a Phase 5 concern, so for now it is a no-op that exists
-- only so the call does not error.
RegisterNetEvent('vehiclekeys:client:SetOwner', function() end)
