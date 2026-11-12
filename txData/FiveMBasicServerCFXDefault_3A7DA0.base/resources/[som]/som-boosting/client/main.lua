--- Shows the search circle, the car's lock and the drop-off, and asks the server
--- to act. The timing, the distance, the plate and the pay are the server's.

local blip, areaBlip, dropBlip, carZone, dropZone, current

local function notify(text, kind) TriggerEvent('som:client:notify', text, kind or 'error') end

local function clear()
    if blip then RemoveBlip(blip) end
    if areaBlip then RemoveBlip(areaBlip) end
    if dropBlip then RemoveBlip(dropBlip) end
    if carZone then exports['som-interact']:removeZone(carZone) end
    if dropZone then exports['som-interact']:removeZone(dropZone) end
    blip, areaBlip, dropBlip, carZone, dropZone, current = nil, nil, nil, nil, nil, nil
end

local function unlock()
    local began = lib.callback.await('som-boosting:server:unlock', false, 'begin')
    if not began or not began.success then return notify(began and began.error or 'Not available') end

    local ok = lib.progressBar({
        duration = (current.unlockSeconds + 1) * 1000, label = 'Picking the lock', canCancel = true,
        disable = { move = true, combat = true },
    })
    if not ok then return end

    local result = lib.callback.await('som-boosting:server:unlock', false, 'finish')
    if not result or not result.success then notify(result and result.error or 'Not available') end
end

RegisterNetEvent('som-boosting:client:contract', function(data)
    clear()
    if type(data) ~= 'table' then return end
    current = data

    areaBlip = AddBlipForRadius(data.area.x, data.area.y, data.area.z, data.radius)
    SetBlipColour(areaBlip, 1)
    SetBlipAlpha(areaBlip, 120)

    notify(('%s: find a %s, plate %s, somewhere in the marked area'):format(data.label, data.model, data.plate), 'inform')

    -- The lock zone follows the car only once the game has streamed it in.
    CreateThread(function()
        local mine = data
        while current == mine and not carZone do
            Wait(1000)
            if NetworkDoesNetworkIdExist(mine.netId) then
                local car = NetToVeh(mine.netId)
                if car ~= 0 and DoesEntityExist(car) then
                    local c = GetEntityCoords(car)
                    carZone = exports['som-interact']:addSphereZone({
                        name = 'som_boost_car', coords = c, radius = mine.interactDistance,
                        options = { { name = 'som_boost_unlock', label = 'Pick the lock', icon = 'fa-solid fa-key', distance = mine.interactDistance, onSelect = unlock } },
                    })
                end
            end
        end
    end)
end)

RegisterNetEvent('som-boosting:client:deliver', function(drop)
    if not current or type(drop) ~= 'table' or not drop.coords then return end
    local c = drop.coords

    if areaBlip then RemoveBlip(areaBlip) areaBlip = nil end
    if carZone then exports['som-interact']:removeZone(carZone) carZone = nil end

    dropBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(dropBlip, 225)
    SetBlipColour(dropBlip, 1)
    SetBlipRoute(dropBlip, true)

    notify('Take it to the drop-off. Expect company.', 'inform')

    dropZone = exports['som-interact']:addSphereZone({
        name = 'som_boost_drop', coords = vec3(c.x, c.y, c.z), radius = 8.0,
        options = { {
            name = 'som_boost_hand', label = 'Hand over the car', icon = 'fa-solid fa-car', distance = 8.0,
            onSelect = function()
                local car = GetVehiclePedIsIn(PlayerPedId(), false)
                if car == 0 then return notify('You need to be driving it') end

                local r = lib.callback.await('som-boosting:server:deliver', false, NetworkGetNetworkIdFromEntity(car))
                if r and not r.success then notify(r.error or 'Not available') end
            end,
        } },
    })
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then clear() end
end)
