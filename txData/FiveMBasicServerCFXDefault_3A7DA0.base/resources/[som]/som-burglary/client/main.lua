--- Shows where to go and builds the shell. Every decision (the lock, the spot
--- claim, the loot, the noise) is the server's; nothing here is trusted.

local doorZone, doorBlip, door
local interior

local function clearDoor()
    if doorZone then exports['som-interact']:removeZone(doorZone) end
    if doorBlip then RemoveBlip(doorBlip) end
    doorZone, doorBlip, door = nil, nil, nil
end

local function clearInterior()
    if not interior then return end
    for _, z in ipairs(interior.zones) do exports['som-interact']:removeZone(z) end
    if DoesEntityExist(interior.shell) then DeleteEntity(interior.shell) end
    interior = nil
end

local function say(result)
    if result and not result.success and result.error then TriggerEvent('som:client:notify', result.error, 'error') end
end

local function build(data)
    -- A staff survey leaves through its own callback: it has no run.
    local leaveName = data.survey and 'som-burglary:server:surveyLeave' or 'som-burglary:server:leave'
    local hash = joaat(data.shell)
    if not IsModelValid(hash) or not IsModelInCdimage(hash) or not lib.requestModel(hash, 10000) then
        TriggerEvent('som:client:notify', 'That interior failed to load', 'error')
        lib.callback.await(leaveName, false)
        return
    end

    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(10) end

    local v, o = data.void, data.offset
    local shell = CreateObject(hash, v.x, v.y, v.z, false, false, false)
    FreezeEntityPosition(shell, true)
    SetEntityInvincible(shell, true)
    local ped = PlayerPedId()
    interior = { shell = shell, zones = {}, back = GetEntityCoords(ped) }

    SetEntityCoords(ped, v.x + o.x, v.y + o.y, v.z + o.z, false, false, false, false)
    SetEntityHeading(ped, o.h)

    local waited = 0
    while not HasCollisionLoadedAroundEntity(ped) and waited < 3000 do
        Wait(50)
        waited = waited + 50
    end

    for i, spot in ipairs(data.spots) do
        interior.zones[#interior.zones + 1] = exports['som-interact']:addSphereZone({
            name = 'som_burglary_spot_' .. i,
            coords = vec3(spot.x, spot.y, spot.z),
            radius = 1.5,
            options = { {
                name = 'som_burglary_search', label = spot.label or 'Search', icon = 'fa-solid fa-magnifying-glass', distance = 1.8,
                onSelect = function()
                    local started = lib.callback.await('som-burglary:server:searchStart', false, i)
                    if not started or not started.success then return say(started) end

                    local finished = lib.progressBar({
                        duration = started.seconds * 1000, label = 'Searching', canCancel = true,
                        disable = { move = true, combat = true },
                    })
                    if not finished then return lib.callback.await('som-burglary:server:searchCancel', false) end

                    say(lib.callback.await('som-burglary:server:searchDone', false, i))
                end,
            } },
        })
    end

    interior.zones[#interior.zones + 1] = exports['som-interact']:addSphereZone({
        name = 'som_burglary_exit',
        coords = vec3(v.x + o.x, v.y + o.y, v.z + o.z),
        radius = 1.5,
        options = { {
            name = 'som_burglary_leave', label = 'Leave', icon = 'fa-solid fa-door-open', distance = 1.8,
            onSelect = function()
                local result = lib.callback.await(leaveName, false)
                if not result or not result.success then return say(result) end

                clearInterior()
                SetEntityCoords(PlayerPedId(), result.coords.x, result.coords.y, result.coords.z, false, false, false, false)
            end,
        } },
    })

    DoScreenFadeIn(600)
    SetModelAsNoLongerNeeded(hash)
end

RegisterNetEvent('som-burglary:client:objective', function(goal)
    clearDoor()
    if type(goal) ~= 'table' or not goal.coords then return end

    door = goal
    local c = goal.coords

    doorBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(doorBlip, 40)
    SetBlipColour(doorBlip, 1)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(goal.label or 'Burglary')
    EndTextCommandSetBlipName(doorBlip)

    doorZone = exports['som-interact']:addSphereZone({
        name = 'som_burglary_door',
        coords = vec3(c.x, c.y, c.z),
        radius = 2.5,
        options = { {
            name = 'som_burglary_door_do',
            label = goal.kind == 'door' and 'Pick the lock' or 'Go inside',
            icon = goal.kind == 'door' and 'fa-solid fa-key' or 'fa-solid fa-door-open',
            distance = 2.5,
            onSelect = function()
                if not door then return end

                if door.kind == 'door' then return say(lib.callback.await('som-burglary:server:breakIn', false)) end

                local result = lib.callback.await('som-burglary:server:enter', false)
                if result and result.success then build(result) else say(result) end
            end,
        } },
    })
end)

RegisterNetEvent('som-burglary:client:survey', function(data)
    if type(data) == 'table' and data.survey and data.shell and data.void and data.offset then build(data) end
end)

RegisterNetEvent('som-burglary:client:exit', function(coords)
    clearInterior()
    if type(coords) == 'table' then
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, false)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    clearDoor()
    -- The server cannot always reach the client while the resource stops, so
    -- walk the player out of the void here.
    if interior then SetEntityCoords(PlayerPedId(), interior.back.x, interior.back.y, interior.back.z, false, false, false, false) end
    clearInterior()
end)
