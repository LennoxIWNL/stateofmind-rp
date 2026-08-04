-- qb-core compatibility shim, client side.
-- Same contract as the server half: only what preserved resources actually call.

-- Items, Weapons and Vehicles are deliberately ABSENT from this literal. They
-- are built on first read (see shared/lazy.lua, shared/items.lua and
-- shared/vehicles.lua), and the metamethod that serves them only fires for keys
-- the table does not already have.
local QBCore = {
    Functions = {},
    Shared = {},
}

local core = exports['som-core']

function QBCore.Functions.GetPlayerData()
    local data = core:getPlayerData()
    if not data or not data.job then return {} end

    local gang = data.gang or {}

    -- Every string below is defaulted rather than passed through.
    --
    -- Legacy resources CONCATENATE these without checking. ps-mdt builds its
    -- header as "Welcome, " .. job.grade.name .. ' ' .. lastname, so one nil
    -- field throws before SendNUIMessage runs and the whole MDT sits on
    -- "loading..." with no clue as to why. A shim handing out nils to code that
    -- cannot cope with them is a shim that has not finished its job.
    return {
        citizenid = data.citizenid,
        charinfo = data.charinfo,
        money = data.money,
        metadata = data.metadata,
        job = {
            name = data.job.name or 'unemployed',
            label = data.job.label or 'Civilian',
            type = data.job.type,
            onduty = data.job.onduty,
            isboss = data.job.isboss or false,
            grade = {
                name = data.job.gradeLabel or 'Employee',
                level = data.job.grade or 0,
            },
        },
        gang = {
            name = gang.name or 'none',
            label = gang.label or 'No Gang',
            isboss = gang.isboss or false,
            grade = {
                name = gang.gradeLabel or 'Member',
                level = gang.grade or 0,
            },
        },
    }
end

function QBCore.Functions.Notify(message, notifyType, duration)
    TriggerEvent('som:client:notify', message, notifyType, duration)
end

-- Legacy resources notify by EVENT as often as by function, and nothing on this
-- server registered it, so every one of those notifications was being dropped
-- on the floor. ps-mdt, r14-evidence, elixir-petshop and som-spray all fire it.
--
-- RegisterNetEvent also serves resources that raise it locally with
-- TriggerEvent, which ps-mdt's client does.
RegisterNetEvent('QBCore:Notify', function(text, notifyType, duration)
    if type(text) ~= 'string' then return end
    QBCore.Functions.Notify(text, notifyType, duration)
end)

function QBCore.Functions.TriggerCallback(name, cb, ...)
    lib.callback(name, false, cb, ...)
end

function QBCore.Functions.GetPlate(vehicle)
    if not vehicle or vehicle == 0 then return nil end
    -- The parentheses truncate gsub to its first return. Without them this
    -- hands back (plate, replacementCount), and any caller that builds a table
    -- or a query parameter list from it gets a stray number appended.
    return (GetVehicleNumberPlateText(vehicle):gsub('^%s*(.-)%s*$', '%1'))
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

---Progress bar. r14-evidence uses this for every collection action.
---
---Mapped onto ox_lib, which is already a dependency, rather than reproducing
---qb-progressbar. The callback fires only on success, matching qb's behaviour.
function QBCore.Functions.Progressbar(name, label, duration, useWhileDead, canCancel, disableControls, anim, prop, propTwo, onFinish, onCancel)
    local disable = disableControls or {}

    local ok = lib.progressBar({
        duration = duration or 1000,
        label = label or '',
        useWhileDead = useWhileDead or false,
        canCancel = canCancel ~= false,
        disable = {
            move = disable.disableMovement,
            car = disable.disableCarMovement,
            combat = disable.disableCombat,
            mouse = disable.disableMouse,
        },
        anim = anim and {
            dict = anim.animDict,
            clip = anim.anim,
            flag = anim.flags,
        } or nil,
        prop = prop and prop.model and {
            model = prop.model,
            pos = prop.coords,
            rot = prop.rotation,
        } or nil,
    })

    if ok then
        if onFinish then onFinish() end
    elseif onCancel then
        onCancel()
    end

    return ok
end

---@param coords vector3|nil defaults to the player
function QBCore.Functions.GetClosestVehicle(coords)
    coords = coords or GetEntityCoords(cache.ped)

    local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 10.0, 0, 71)
    if not vehicle or vehicle == 0 then return nil, nil end

    return vehicle, #(coords - GetEntityCoords(vehicle))
end

-- Shared.Items, Shared.Weapons and Shared.Vehicles are projected on first read.
SomCompatShared.attach(QBCore.Shared)
SomCompatVehicles.attach(QBCore.Shared)

-- See the note in server/qbcore.lua: `provide` does not forward exports, the
-- __cfx_export_<resource>_<name> event is what actually publishes under
-- another resource's name.
---@param name string
---@param fn function
local function qbExport(name, fn)
    AddEventHandler(('__cfx_export_qb-core_%s'):format(name), function(setCB)
        setCB(fn)
    end)
end

qbExport('GetCoreObject', function()
    return QBCore
end)

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
