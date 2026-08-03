-- Rental client.
--
-- Spawns the counter ped, registers the eye options on it, and shows the
-- catalogue. It never decides a price and never spawns a vehicle: both come
-- back from the server.

local peds = {}

---@param model string
---@return number|nil hash
local function loadModel(model)
    local hash = joaat(model)
    if not IsModelValid(hash) then return nil end

    RequestModel(hash)

    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end

    return HasModelLoaded(hash) and hash or nil
end

local function spawnPeds()
    for id, location in pairs(Config.Locations) do
        local hash = loadModel(location.ped.model)
        if hash then
            local c = location.ped.coords
            local ped = CreatePed(4, hash, c.x, c.y, c.z - 1.0, c.w, false, false)

            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            FreezeEntityPosition(ped, true)
            SetPedDiesWhenInjured(ped, false)

            if location.ped.scenario then
                TaskStartScenarioInPlace(ped, location.ped.scenario, 0, true)
            end

            SetModelAsNoLongerNeeded(hash)
            peds[id] = ped

            -- A ZONE, not an entity target, and that is deliberate.
            --
            -- ox_target draws its indicator circle for zones only. Registered
            -- against the ped as an entity there would be no circle at all,
            -- just an eye that happens to change when you look at it. The ped
            -- is frozen at fixed coordinates so a sphere here behaves
            -- identically and earns the marker.
            --
            -- radius is how far away the circle appears; the per-option
            -- distance is how close you must be to actually use it.
            exports['som-interact']:addSphereZone({
                name = ('som_rental_%s'):format(id),
                coords = vec3(c.x, c.y, c.z),
                radius = Config.MarkerRadius,
                options = {
                    {
                        name = 'som_rental_rent',
                        label = 'Rent a vehicle',
                        icon = 'fa-solid fa-car',
                        distance = 2.5,
                        onSelect = function() Rentals.Open(id) end,
                    },
                    {
                        name = 'som_rental_return',
                        label = 'Return vehicle',
                        icon = 'fa-solid fa-rotate-left',
                        distance = 2.5,
                        onSelect = function() Rentals.Return(id) end,
                    },
                },
            })

            if location.blip then
                local blip = AddBlipForCoord(c.x, c.y, c.z)
                SetBlipSprite(blip, location.blip.sprite)
                SetBlipColour(blip, location.blip.colour)
                SetBlipScale(blip, location.blip.scale)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(location.label)
                EndTextCommandSetBlipName(blip)
            end
        end
    end
end

Rentals = {}

local isOpen = false
local currentLocation

function Rentals.Open(locationId)
    if isOpen then return end

    local data = lib.callback.await('som-rentals:server:catalogue', false, locationId)
    if not data then return end

    isOpen = true
    currentLocation = locationId

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end

function Rentals.Return(locationId)
    local res = lib.callback.await('som-rentals:server:return', false, locationId)

    if not res or not res.success then
        TriggerEvent('som:client:notify', (res and res.error) or 'Could not return that', 'error')
        return
    end

    TriggerEvent('som:client:notify',
        res.refund > 0 and ('Returned. $%d deposit back'):format(res.refund) or 'Returned',
        'success')
end

local function close()
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb)
    cb({})
    close()
end)

RegisterNUICallback('rent', function(data, cb)
    local res = lib.callback.await('som-rentals:server:rent', false, {
        location = currentLocation,
        model = type(data) == 'table' and data.model or nil,
    })

    cb(res or { success = false })

    if res and res.success then
        close()
        TriggerEvent('som:client:notify',
            ('%s is outside, plate %s'):format(res.label, res.plate), 'success', 8000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if isOpen then SetNuiFocus(false, false) end
    for _, ped in pairs(peds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
end)

CreateThread(spawnPeds)
