--- Medic options for transport (check, load, unload, admit) and what the
--- patient sees on admission. The server decides every one of them.

local core = exports['som-core']

local function say(text, kind) TriggerEvent('som:client:notify', text, kind) end

local function onDuty()
    local job = core:getJob()
    return job ~= nil and job.name == Config.job and job.onduty == true
end

local function serverIdOf(ped)
    local index = NetworkGetPlayerIndexFromPed(ped)
    if index == -1 then return nil end
    local id = GetPlayerServerId(index)
    return id > 0 and id or nil
end

local function isDowned(ped)
    local id = serverIdOf(ped)
    if not id then return false end
    local down = Player(id).state['som:downed']
    return down ~= nil and down ~= false
end

local function report(result)
    if result and not result.success then say(result.error or 'Failed', 'error') end
    return result and result.success
end

CreateThread(function()
    exports['som-interact']:addGlobalPlayer({
        {
            name = 'som_ems_check', label = 'Check patient', icon = 'fa-solid fa-stethoscope', distance = Config.distance,
            canInteract = function(entity) return onDuty() and isDowned(entity) end,
            onSelect = function(data)
                local id = data and data.entity and serverIdOf(data.entity)
                if not id then return end
                local r = lib.callback.await('som-ems:server:inspect', false, id)
                if not report(r) then return end
                local why = r.cause == 'violence' and 'hurt by another person' or 'an accident'
                say(('Down for %d seconds, %s'):format(r.seconds, why), 'inform')
            end,
        },
        {
            name = 'som_ems_load', label = 'Load into ambulance', icon = 'fa-solid fa-truck-medical', distance = Config.distance,
            canInteract = function(entity) return onDuty() and isDowned(entity) end,
            onSelect = function(data)
                local id = data and data.entity and serverIdOf(data.entity)
                if not id then return end
                local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), Config.hospital.loadDistance, false)
                if not vehicle then return say('No ambulance here', 'error') end
                if report(lib.callback.await('som-ems:server:load', false, id, NetworkGetNetworkIdFromEntity(vehicle))) then
                    say('Patient loaded', 'success')
                end
            end,
        },
    })

    exports['som-interact']:addGlobalVehicle({
        {
            name = 'som_ems_unload', label = 'Unload patient', icon = 'fa-solid fa-person-walking-arrow-right', distance = 3.0,
            canInteract = function() return onDuty() end,
            onSelect = function() report(lib.callback.await('som-ems:server:unload', false)) end,
        },
    })
end)

local zone
local function buildDesk()
    if zone then exports['som-interact']:removeZone(zone); zone = nil end
    local info = lib.callback.await('som-ems:server:deskInfo', false)
    if type(info) ~= 'table' then return end
    zone = exports['som-interact']:addSphereZone({
        name = 'som_ems_desk',
        coords = vec3(info.coords.x, info.coords.y, info.coords.z),
        radius = 1.5,
        options = { { name = 'som_ems_desk_admit', label = ('%s: admit patient'):format(info.label), icon = 'fa-solid fa-hospital', distance = 2.5,
            onSelect = function()
                if report(lib.callback.await('som-ems:server:admit', false)) then say('Patient admitted', 'success') end
            end } },
    })
end

AddEventHandler('som:client:playerLoaded', buildDesk)
CreateThread(function() Wait(4000); buildDesk() end)
AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and zone then exports['som-interact']:removeZone(zone) end
end)

RegisterNetEvent('som-ems:client:admitted', function(bed, seconds)
    if type(bed) ~= 'table' or type(seconds) ~= 'number' then return end
    local ped = cache.ped

    DoScreenFadeOut(600)
    while not IsScreenFadedOut() do Wait(0) end

    SetEntityCoordsNoOffset(ped, bed.x + 0.0, bed.y + 0.0, bed.z + 0.0, false, false, false)
    SetEntityHeading(ped, bed.w + 0.0)
    FreezeEntityPosition(ped, true)
    local anim = Config.hospital.bedAnim
    RequestAnimDict(anim.dict)
    local waited = 0
    while not HasAnimDictLoaded(anim.dict) and waited < 2000 do Wait(50); waited = waited + 50 end
    TaskPlayAnim(ped, anim.dict, anim.clip, 2.0, 2.0, -1, 1, 0, false, false, false)

    DoScreenFadeIn(800)
    Wait(seconds * 1000)

    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    say('Treated and admitted. Billed to your card.', 'success')
end)
