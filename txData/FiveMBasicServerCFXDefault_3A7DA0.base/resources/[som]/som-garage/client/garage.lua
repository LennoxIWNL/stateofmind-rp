-- Garage zones and the UI around them.
--
-- Thin by design. It shows what the server sent and posts back an id; it never
-- decides who may take what, and it never spawns anything: the server creates
-- the entity and hands back a net id.

local core = exports['som-core']

local isOpen = false
local currentGarage = nil
local blips = {}

local function handle(res, failure)
    if not res or not res.success then
        TriggerEvent('som:client:notify',
            (res and res.error) or failure or 'That did not work', 'error')
        return false
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Opening
-- ---------------------------------------------------------------------------

local function close()
    if not isOpen then return end

    isOpen = false
    currentGarage = nil

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    Preview.Stop()
end

---@param garageId string
local function open(garageId)
    if isOpen then return end

    local res = lib.callback.await('som-garage:server:list', false, garageId)
    if not handle(res) then return end

    isOpen = true
    currentGarage = garageId

    local garage = Config.Garages[garageId]
    Preview.Start(garage.preview or garage.spawn)

    -- The first vehicle is shown immediately, so the podium is never empty
    -- while the player reads the list.
    local first = res.vehicles[1]
    if first then Preview.Show(first.model, first.props) end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data = {
            label = res.label,
            vehicles = res.vehicles,
            catalogue = res.catalogue,
            payment = res.payment,
        },
    })
end

-- ---------------------------------------------------------------------------
-- NUI
-- ---------------------------------------------------------------------------

RegisterNUICallback('select', function(data, cb)
    cb({})
    if not isOpen or type(data) ~= 'table' then return end

    Preview.Show(data.model, data.props)
end)

RegisterNUICallback('rotate', function(data, cb)
    cb({})
    Preview.Drag(type(data) == 'table' and data.delta or 0)
end)

RegisterNUICallback('rotateEnd', function(_, cb)
    cb({})
    Preview.EndDrag()
end)

RegisterNUICallback('close', function(_, cb)
    cb({})
    close()
end)

RegisterNUICallback('take', function(data, cb)
    if not isOpen or type(data) ~= 'table' then
        return cb({ success = false, error = 'invalid request' })
    end

    local res = lib.callback.await('som-garage:server:take', false, {
        garage = currentGarage,
        id = data.id,
    })

    cb(res or { success = false })
    if not res or not res.success then return end

    close()

    -- The server created the entity; this only waits for it to stream in and
    -- puts the player behind the wheel. Nothing about the vehicle is decided
    -- here.
    local deadline = GetGameTimer() + 5000
    local entity

    while GetGameTimer() < deadline do
        if NetworkDoesNetworkIdExist(res.netId) then
            entity = NetworkGetEntityFromNetworkId(res.netId)
            if entity and entity ~= 0 and DoesEntityExist(entity) then break end
        end
        Wait(50)
    end

    if not entity or entity == 0 then return end

    -- Properties are applied client side because lib.setVehicleProperties is a
    -- client native. The server already decided WHICH properties.
    if res.props then pcall(lib.setVehicleProperties, entity, res.props) end
    if res.fuel then SetVehicleFuelLevel(entity, res.fuel + 0.0) end

    SetPedIntoVehicle(cache.ped, entity, -1)

    TriggerEvent('som:client:notify', ('%s is ready'):format(res.plate), 'success')
end)

RegisterNUICallback('buy', function(data, cb)
    if not isOpen or type(data) ~= 'table' then
        return cb({ success = false, error = 'invalid request' })
    end

    local res = lib.callback.await('som-garage:server:buyFleetVehicle', false, {
        garage = currentGarage,
        model = data.model,
        account = data.account,
    })

    cb(res or { success = false })

    if res and res.success then
        TriggerEvent('som:client:notify',
            ('Bought. Plate %s, parked here.'):format(res.plate), 'success')
        close()
    end
end)

-- ---------------------------------------------------------------------------
-- Storing
-- ---------------------------------------------------------------------------

---@param garageId string
local function store(garageId)
    local vehicle = cache.vehicle
        or lib.getClosestVehicle(GetEntityCoords(cache.ped), 8.0, false)

    if not vehicle or vehicle == 0 then
        return TriggerEvent('som:client:notify', 'No vehicle here', 'error')
    end

    local res = lib.callback.await('som-garage:server:store', false, {
        garage = garageId,
        netId = NetworkGetNetworkIdFromEntity(vehicle),
        props = lib.getVehicleProperties(vehicle),
        fuel = GetVehicleFuelLevel(vehicle),
    })

    if not handle(res) then return end
    TriggerEvent('som:client:notify', 'Vehicle stored', 'success')
end

-- ---------------------------------------------------------------------------
-- Zones and blips
-- ---------------------------------------------------------------------------

CreateThread(function()
    for id, garage in pairs(Config.Garages) do
        exports['som-interact']:addBoxZone({
            name = ('garage:%s'):format(id),
            coords = garage.coords,
            size = vec3(4.0, 4.0, 3.0),
            rotation = 0.0,
            options = {
                {
                    name = ('garage:%s:open'):format(id),
                    icon = 'fa-solid fa-warehouse',
                    label = garage.label,
                    distance = 3.0,
                    -- A UI filter only. The server re-checks access and
                    -- distance on every list, take and store.
                    canInteract = function()
                        if not garage.groups then return true end

                        local job = core:getJob()
                        local gang = core:getGang()

                        for name, minGrade in pairs(garage.groups) do
                            if job and job.name == name and (job.grade or 0) >= minGrade then
                                return true
                            end
                            if gang and gang.name == name and (gang.grade or 0) >= minGrade then
                                return true
                            end
                        end

                        return false
                    end,
                    onSelect = function() open(id) end,
                },
                {
                    name = ('garage:%s:store'):format(id),
                    icon = 'fa-solid fa-square-parking',
                    label = 'Store vehicle',
                    distance = 4.0,
                    onSelect = function() store(id) end,
                },
            },
        })

        if garage.blip then
            local blip = AddBlipForCoord(garage.coords.x, garage.coords.y, garage.coords.z)

            SetBlipSprite(blip, garage.blip.sprite)
            SetBlipColour(blip, garage.blip.colour)
            SetBlipScale(blip, garage.blip.scale)
            SetBlipAsShortRange(blip, true)
            SetBlipDisplay(blip, 4)

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(garage.label)
            EndTextCommandSetBlipName(blip)

            blips[#blips + 1] = blip
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if isOpen then SetNuiFocus(false, false) end

    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
end)

-- Prints a position formatted for shared/config.lua. The coordinates in there
-- are unverified and this is how they get corrected.
RegisterCommand('garagecoords', function()
    local c = GetEntityCoords(cache.ped)
    local h = GetEntityHeading(cache.ped)

    print(('[som-garage] coords = vec3(%.2f, %.2f, %.2f)'):format(c.x, c.y, c.z))
    print(('[som-garage] spawn  = vec4(%.2f, %.2f, %.2f, %.2f)'):format(c.x, c.y, c.z, h))

    TriggerEvent('som:client:notify', 'Printed to console (F8)', 'inform')
end, false)
