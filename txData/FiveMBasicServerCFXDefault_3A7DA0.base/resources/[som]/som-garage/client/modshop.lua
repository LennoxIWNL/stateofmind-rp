-- A temporary mod bay.
--
-- Deliberately minimal and deliberately FREE: this exists so liveries, extras
-- and colours can be checked on the addon police models, not as an economy
-- feature. A real Los Santos Customs charges money, books revenue to the
-- business and validates every mod server side, and none of that is here.
--
-- The menus apply changes locally, and every change is then SAVED through a
-- server callback that re-derives ownership from the vehicle's own statebag.
-- Applying locally is safe because appearance is not authority; persisting is
-- what makes it worth doing, since anything not saved was lost at the next
-- restart. Somebody changing a car they do not own still saves nothing.
--
-- Pool cars save too, now that Config.ResetPoolProps is off. They are only
-- refused while that is on, because a livery written to a car that gets reset
-- on its next spawn would be stored and then immediately ignored.
--
-- Reached from the RADIAL rather than the eye, because ox_target does not work
-- from a driver's seat and you have to be in the car for the bay to be any use.
-- The zone is kept for anyone standing beside a vehicle instead.

local function currentVehicle()
    local vehicle = cache.vehicle
    if not vehicle or vehicle == 0 then return nil end
    if GetPedInVehicleSeat(vehicle, -1) ~= cache.ped then return nil end

    return vehicle
end

local function needVehicle()
    TriggerEvent('som:client:notify', 'Sit in the driver seat first', 'error')
end

---Persists what was just changed.
---
---Called after every modification rather than on closing the menu, because the
---menu can be closed by dying, by a resource restart, or by simply driving off,
---and a save that only happens on a tidy exit is a save that mostly does not
---happen.
---
---Silent on success. The server refuses pool cars, which is expected rather
---than an error worth interrupting somebody for, so only a real failure speaks.
local function persist(vehicle)
    if not vehicle or vehicle == 0 then return end

    local res = lib.callback.await('som-garage:server:saveProps', false, {
        netId = NetworkGetNetworkIdFromEntity(vehicle),
        props = lib.getVehicleProperties(vehicle),
    })

    if res and not res.success and res.error ~= 'pool vehicles are reset to stock each time' then
        TriggerEvent('som:client:notify', res.error or 'Could not save that', 'error')
    end
end

-- Two livery systems exist and addon packs use either: the mod-kit livery at
-- index 48, and the older SetVehicleLivery. A pack using one reports zero for
-- the other, so both are listed rather than guessed between.
local function liveryMenu()
    local vehicle = currentVehicle()
    if not vehicle then return needVehicle() end

    SetVehicleModKit(vehicle, 0)

    local options = {}
    local modLiveries = GetNumVehicleMods(vehicle, 48)
    local oldLiveries = GetVehicleLiveryCount(vehicle)

    for i = 0, modLiveries - 1 do
        options[#options + 1] = {
            title = ('Livery %d'):format(i + 1),
            description = 'Mod kit livery',
            onSelect = function()
                SetVehicleMod(vehicle, 48, i, false)
                persist(vehicle)
                TriggerEvent('som:client:notify', ('Livery %d'):format(i + 1), 'inform', 1200)
            end,
        }
    end

    for i = 0, oldLiveries - 1 do
        options[#options + 1] = {
            title = ('Legacy livery %d'):format(i + 1),
            description = 'SetVehicleLivery',
            onSelect = function()
                SetVehicleLivery(vehicle, i)
                persist(vehicle)
                TriggerEvent('som:client:notify', ('Legacy livery %d'):format(i + 1), 'inform', 1200)
            end,
        }
    end

    if #options == 0 then
        return TriggerEvent('som:client:notify', 'This model has no liveries', 'inform')
    end

    options[#options + 1] = {
        title = 'None',
        description = 'Clear the livery',
        onSelect = function()
            SetVehicleMod(vehicle, 48, -1, false)
            SetVehicleLivery(vehicle, -1)
            persist(vehicle)
        end,
    }

    lib.registerContext({
        id = 'som_modshop_livery',
        title = 'Liveries',
        menu = 'som_modshop',
        options = options,
    })

    lib.showContext('som_modshop_livery')
end

-- Extras carry the light bars, push bars and unit numbers on most police
-- models, so this is the other half of judging a pack.
local function extrasMenu()
    local vehicle = currentVehicle()
    if not vehicle then return needVehicle() end

    local options = {}

    for extra = 1, 14 do
        if DoesExtraExist(vehicle, extra) then
            local on = IsVehicleExtraTurnedOn(vehicle, extra)

            options[#options + 1] = {
                title = ('Extra %d'):format(extra),
                description = on and 'On' or 'Off',
                icon = on and 'circle-check' or 'circle',
                onSelect = function()
                    -- SetVehicleExtra takes DISABLE, so the boolean is inverted
                    -- against what the label says. This trips everyone once.
                    SetVehicleExtra(vehicle, extra, on)
                    persist(vehicle)
                    extrasMenu()
                end,
            }
        end
    end

    if #options == 0 then
        return TriggerEvent('som:client:notify', 'This model has no extras', 'inform')
    end

    lib.registerContext({
        id = 'som_modshop_extras',
        title = 'Extras',
        menu = 'som_modshop',
        options = options,
    })

    lib.showContext('som_modshop_extras')
end

local PERFORMANCE = {
    { label = 'Engine', mod = 11 },
    { label = 'Brakes', mod = 12 },
    { label = 'Transmission', mod = 13 },
    { label = 'Suspension', mod = 15 },
    { label = 'Armour', mod = 16 },
}

local function performanceMenu()
    local vehicle = currentVehicle()
    if not vehicle then return needVehicle() end

    SetVehicleModKit(vehicle, 0)

    local options = {}

    for _, kind in ipairs(PERFORMANCE) do
        local max = GetNumVehicleMods(vehicle, kind.mod)

        options[#options + 1] = {
            title = kind.label,
            -- GetVehicleMod returns -1 for stock, so +2 reads as a human level.
            description = max > 0
                and ('Level %d of %d'):format(GetVehicleMod(vehicle, kind.mod) + 2, max)
                or 'Not available on this model',
            disabled = max == 0,
            onSelect = function()
                -- Straight to maximum. This is a test bay, not a shop.
                SetVehicleMod(vehicle, kind.mod, max - 1, false)
                persist(vehicle)
                TriggerEvent('som:client:notify', ('%s maxed'):format(kind.label), 'success', 1500)
                performanceMenu()
            end,
        }
    end

    options[#options + 1] = {
        title = 'Turbo',
        description = IsToggleModOn(vehicle, 18) and 'Fitted' or 'Not fitted',
        onSelect = function()
            ToggleVehicleMod(vehicle, 18, not IsToggleModOn(vehicle, 18))
            persist(vehicle)
            performanceMenu()
        end,
    }

    lib.registerContext({
        id = 'som_modshop_perf',
        title = 'Performance',
        menu = 'som_modshop',
        options = options,
    })

    lib.showContext('som_modshop_perf')
end

local function open()
    if not currentVehicle() then return needVehicle() end

    lib.registerContext({
        id = 'som_modshop',
        title = 'Mod Bay (temporary)',
        options = {
            {
                title = 'Liveries',
                description = 'Step through every livery on this model',
                icon = 'palette',
                onSelect = liveryMenu,
            },
            {
                title = 'Extras',
                description = 'Light bars, push bars, unit numbers',
                icon = 'sliders',
                onSelect = extrasMenu,
            },
            {
                title = 'Performance',
                description = 'Max out engine, brakes and the rest',
                icon = 'gauge-high',
                onSelect = performanceMenu,
            },
            {
                title = 'Repair and clean',
                icon = 'wrench',
                onSelect = function()
                    local vehicle = currentVehicle()
                    if not vehicle then return needVehicle() end

                    SetVehicleFixed(vehicle)
                    SetVehicleDirtLevel(vehicle, 0.0)
                    TriggerEvent('som:client:notify', 'Repaired', 'success')
                end,
            },
        },
    })

    lib.showContext('som_modshop')
end

---Whether the player is parked in the bay.
---
---Used by the radial, because the EYE cannot reach this: ox_target does not
---work from a driver's seat, and you have to be in the car for the bay to be
---any use. That made the zone below unreachable in practice, which is the whole
---reason this is on F1 instead.
local function inBay()
    local bay = Config.ModShop
    if not bay then return false end
    if not currentVehicle() then return false end

    return #(GetEntityCoords(cache.ped) - bay.coords) < 8.0
end

exports('hasModBayNear', inBay)
exports('openModBay', function()
    if not inBay() then
        return TriggerEvent('som:client:notify', 'Drive into the bay first', 'error')
    end

    open()
end)

-- Making it findable.
--
-- The bay had no blip and no marker, so the only way to discover it was to
-- already know the coordinate. A radial slice that appears in one 8m circle and
-- nowhere else is invisible unless something says "here".
--
-- Three cues, because each covers a different distance: the blip finds the bay
-- from across the map, the floor marker finds it from across the car park, and
-- the prompt says which key to press once you are sitting in it.

local blip

CreateThread(function()
    local bay = Config.ModShop
    if not bay then return end

    blip = AddBlipForCoord(bay.coords.x, bay.coords.y, bay.coords.z)

    SetBlipSprite(blip, 72)
    SetBlipColour(blip, 29)
    SetBlipScale(blip, 0.6)
    SetBlipAsShortRange(blip, true)
    SetBlipDisplay(blip, 4)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Mod Bay')
    EndTextCommandSetBlipName(blip)
end)

CreateThread(function()
    local bay = Config.ModShop
    if not bay then return end

    local prompting = false

    local function prompt(on)
        if on == prompting then return end

        prompting = on

        if on then
            exports['som-interact']:showTextUI('Mod Bay', { key = 'F1' })
        else
            exports['som-interact']:hideTextUI()
        end
    end

    -- The configured Z is a PED position captured with /garagecoords, not the
    -- floor, and how far above the floor it sits depends on whether whoever
    -- captured it was standing or sitting in a car. A fixed offset would
    -- therefore bury the marker on one reading and float it on the other, so
    -- the floor is measured instead.
    --
    -- Resolved lazily rather than at boot because the collision has to be
    -- streamed in for the trace to hit anything, and cached because the floor
    -- of a car park does not move.
    local floorZ

    while true do
        -- Idles at 1.5s and only goes per-frame inside a 30m bubble, which is
        -- the whole of the lower car park and nothing else on the map.
        local wait = 1500
        local dist = #(GetEntityCoords(cache.ped) - bay.coords)

        if dist < 30.0 then
            wait = 0

            if not floorZ then
                local hit, z = GetGroundZFor_3dCoord(bay.coords.x, bay.coords.y, bay.coords.z + 1.0, false)
                if hit then floorZ = z + 0.03 end
            end

            DrawMarker(1, bay.coords.x, bay.coords.y, floorZ or (bay.coords.z - 0.95),
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                5.5, 5.5, 0.4,
                255, 20, 147, 90,
                false, false, 2, false, nil, nil, false)

            prompt(dist < 8.0 and currentVehicle() ~= nil)
        else
            prompt(false)
        end

        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if blip then RemoveBlip(blip) end
    exports['som-interact']:hideTextUI()
end)

-- The zone stays as well, for anyone standing beside a car rather than sitting
-- in it. It costs nothing and covers the case the radial cannot.
CreateThread(function()
    local bay = Config.ModShop
    if not bay then return end

    exports['som-interact']:addBoxZone({
        name = 'garage:modshop',
        coords = bay.coords,
        size = vec3(6.0, 6.0, 3.0),
        rotation = bay.rotation or 0.0,
        options = {
            {
                name = 'garage:modshop:open',
                icon = 'fa-solid fa-screwdriver-wrench',
                label = 'Mod bay',
                distance = 6.0,
                onSelect = open,
            },
        },
    })
end)
