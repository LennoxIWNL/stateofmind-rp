-- Station services: armoury, lockers, garage, helipad and the impound lot.
--
-- Every zone here is registered once at start. `canInteract` decides what is
-- SHOWN, and every onSelect is a request the server re-checks.

---@return boolean
local function onDutyOfficer()
    return Duty.IsOnDuty()
end

---Notifies from a { success, error } response and returns whether it worked.
local function handle(res, failure)
    if not res or not res.success then
        TriggerEvent('som:client:notify',
            (res and res.error) or failure or 'That did not work', 'error')
        return false
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Armoury
-- ---------------------------------------------------------------------------

local function openArmoury()
    local res = lib.callback.await('som-police:server:armoury', false)
    if not handle(res) then return end

    Armoury.Open(res)
end

-- ---------------------------------------------------------------------------
-- Stashes
-- ---------------------------------------------------------------------------

---@param stashId string
local function openStash(stashId)
    -- The server registers the stash and decides its NAME, which for a personal
    -- locker is derived from the citizenid it resolved. The client never gets
    -- to say whose locker it is opening.
    local res = lib.callback.await('som-police:server:openStash', false, stashId)
    if not handle(res) then return end

    exports.ox_inventory:openInventory('stash', res.stash)
end

-- ---------------------------------------------------------------------------
-- Vehicles
-- ---------------------------------------------------------------------------

---@param kind string 'garage' or 'helipad'
local function openMotorPool(kind)
    local res = lib.callback.await('som-police:server:fleet', false, kind)
    if not handle(res) then return end

    if #res.vehicles == 0 then
        return TriggerEvent('som:client:notify',
            'Nothing here you are certified for', 'inform')
    end

    local options = {}
    for _, vehicle in ipairs(res.vehicles) do
        options[#options + 1] = {
            title = vehicle.label,
            description = vehicle.model,
            icon = kind == 'helipad' and 'helicopter' or 'car',
            onSelect = function()
                local out = lib.callback.await('som-police:server:takeVehicle', false, {
                    kind = kind, model = vehicle.model,
                })

                if not handle(out) then return end

                TriggerEvent('som:client:notify',
                    ('%s signed out, plate %s'):format(vehicle.label, out.plate), 'success')
            end,
        }
    end

    lib.registerContext({
        id = 'som_police_fleet',
        title = kind == 'helipad' and 'Air Support' or 'Motor Pool',
        options = options,
    })

    lib.showContext('som_police_fleet')
end

---@param kind string
local function storeVehicle(kind)
    local vehicle = cache.vehicle or lib.getClosestVehicle(GetEntityCoords(cache.ped), 8.0, false)
    if not vehicle or vehicle == 0 then
        return TriggerEvent('som:client:notify', 'No vehicle here', 'error')
    end

    local res = lib.callback.await('som-police:server:storeVehicle', false, {
        kind = kind,
        netId = NetworkGetNetworkIdFromEntity(vehicle),
    })

    if not handle(res) then return end
    TriggerEvent('som:client:notify', 'Vehicle returned', 'success')
end

-- ---------------------------------------------------------------------------
-- Impound
--
-- Used by the OWNER of an impounded vehicle, not by the police, so it is not
-- duty gated. Paying the fee is how you get your car back.
-- ---------------------------------------------------------------------------

local function openImpound()
    local res = lib.callback.await('som-police:server:impoundList', false)
    if not handle(res) then return end

    if #res.vehicles == 0 then
        return TriggerEvent('som:client:notify', 'Nothing of yours is impounded', 'inform')
    end

    local options = {}
    for _, vehicle in ipairs(res.vehicles) do
        options[#options + 1] = {
            title = ('%s  [%s]'):format(vehicle.model, vehicle.plate),
            description = ('%s. Release fee $%s'):format(vehicle.reason, vehicle.fee),
            icon = 'car-burst',
            onSelect = function()
                -- Cash or card, so the fee is paid with what the player picked
                -- rather than always the bank. Same choice as every other shop,
                -- offered here as a dialog because there is no panel to put a
                -- switcher along the top of.
                local picked = lib.inputDialog('Release ' .. vehicle.plate, {
                    { type = 'select', label = 'Pay with', required = true,
                      options = (function()
                          local out = {}
                          for _, option in ipairs(res.payment) do
                              out[#out + 1] = {
                                  value = option.account,
                                  label = ('%s ($%s)'):format(option.label, option.balance),
                              }
                          end
                          return out
                      end)() },
                })

                if not picked or not picked[1] then return end

                local out = lib.callback.await('som-police:server:releaseImpound', false, {
                    id = vehicle.id, account = picked[1],
                })

                if not handle(out) then return end

                TriggerEvent('som:client:notify',
                    ('%s released. Collect it from your garage.'):format(out.plate), 'success')
            end,
        }
    end

    lib.registerContext({
        id = 'som_police_impound',
        title = 'Impound Lot',
        options = options,
    })

    lib.showContext('som_police_impound')
end

-- ---------------------------------------------------------------------------
-- Zones
-- ---------------------------------------------------------------------------

CreateThread(function()
    local station = Config.Stations.mrpd

    exports['som-interact']:addBoxZone({
        name = 'police:armoury',
        coords = station.armoury.coords,
        size = station.armoury.size,
        rotation = station.armoury.rotation,
        options = {
            {
                name = 'police:armoury',
                icon = 'fa-solid fa-gun',
                label = 'Armoury',
                distance = 2.0,
                canInteract = onDutyOfficer,
                onSelect = openArmoury,
            },
        },
    })

    for _, stash in ipairs(station.stashes) do
        exports['som-interact']:addBoxZone({
            name = ('police:stash:%s'):format(stash.id),
            coords = stash.coords,
            size = stash.size,
            rotation = stash.rotation,
            options = {
                {
                    name = ('police:stash:%s'):format(stash.id),
                    icon = stash.id == 'trash' and 'fa-solid fa-trash' or 'fa-solid fa-box-archive',
                    label = stash.label,
                    distance = 2.0,
                    canInteract = onDutyOfficer,
                    onSelect = function() openStash(stash.id) end,
                },
            },
        })
    end

    exports['som-interact']:addBoxZone({
        name = 'police:garage',
        coords = station.garage.coords,
        size = station.garage.size,
        rotation = station.garage.rotation,
        options = {
            {
                name = 'police:garage:take',
                icon = 'fa-solid fa-car',
                label = 'Motor pool',
                distance = 3.0,
                canInteract = onDutyOfficer,
                onSelect = function() openMotorPool('garage') end,
            },
            {
                name = 'police:garage:store',
                icon = 'fa-solid fa-square-parking',
                label = 'Return vehicle',
                distance = 3.0,
                canInteract = onDutyOfficer,
                onSelect = function() storeVehicle('garage') end,
            },
        },
    })

    exports['som-interact']:addBoxZone({
        name = 'police:helipad',
        coords = station.helipad.coords,
        size = station.helipad.size,
        rotation = station.helipad.rotation,
        options = {
            {
                name = 'police:helipad:take',
                icon = 'fa-solid fa-helicopter',
                label = 'Air support',
                distance = 3.0,
                canInteract = onDutyOfficer,
                onSelect = function() openMotorPool('helipad') end,
            },
            {
                name = 'police:helipad:store',
                icon = 'fa-solid fa-square-parking',
                label = 'Return aircraft',
                distance = 3.0,
                canInteract = onDutyOfficer,
                onSelect = function() storeVehicle('helipad') end,
            },
        },
    })

    exports['som-interact']:addBoxZone({
        name = 'police:impound',
        coords = station.impound.coords,
        size = station.impound.size,
        rotation = station.impound.rotation,
        options = {
            {
                name = 'police:impound',
                icon = 'fa-solid fa-car-burst',
                label = 'Collect impounded vehicle',
                distance = 3.0,
                -- Deliberately no job check: this is where a CITIZEN pays to
                -- get their own car back.
                onSelect = openImpound,
            },
        },
    })
end)

-- ---------------------------------------------------------------------------
-- Coordinate check
--
-- The config coordinates come from other servers' MLOs and are expected to be
-- wrong somewhere. This draws a marker and a label at every one of them, so a
-- point buried in a wall or floating in the car park is visible rather than
-- merely not working. See the banner in shared/config.lua.
-- ---------------------------------------------------------------------------

local showingZones = false

---@return table[] { coords, label }
local function configuredPoints()
    local station = Config.Stations.mrpd
    local points = {
        { coords = station.duty.coords,    label = 'duty' },
        { coords = station.armoury.coords, label = 'armoury' },
        { coords = station.garage.coords,  label = 'garage' },
        { coords = station.helipad.coords, label = 'helipad' },
        { coords = station.impound.coords, label = 'impound' },
        { coords = vector3(station.garage.spawn.x, station.garage.spawn.y, station.garage.spawn.z),
          label = 'garage spawn' },
        { coords = vector3(station.helipad.spawn.x, station.helipad.spawn.y, station.helipad.spawn.z),
          label = 'helipad spawn' },
        { coords = vector3(station.impound.spawn.x, station.impound.spawn.y, station.impound.spawn.z),
          label = 'impound spawn' },
    }

    for _, stash in ipairs(station.stashes) do
        points[#points + 1] = { coords = stash.coords, label = 'stash: ' .. stash.id }
    end

    return points
end

RegisterCommand('pdzones', function()
    if showingZones then
        showingZones = false
        return TriggerEvent('som:client:notify', 'Zone markers off', 'inform')
    end

    showingZones = true
    TriggerEvent('som:client:notify', 'Zone markers on. /pdzones again to stop.', 'inform')

    local points = configuredPoints()

    CreateThread(function()
        -- A per-frame loop is the only way to draw a marker, and it stops the
        -- moment the command is toggled off rather than running forever.
        while showingZones do
            local here = GetEntityCoords(cache.ped)

            for _, point in ipairs(points) do
                if #(here - point.coords) < 60.0 then
                    DrawMarker(1, point.coords.x, point.coords.y, point.coords.z - 0.95,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.6, 0.6, 0.4,
                        255, 20, 147, 120, false, false, 2, false, nil, nil, false)

                    SetTextScale(0.32, 0.32)
                    SetTextFont(4)
                    SetTextColour(255, 255, 255, 220)
                    SetTextCentre(true)
                    SetTextOutline()
                    SetDrawOrigin(point.coords.x, point.coords.y, point.coords.z + 0.4, 0)
                    BeginTextCommandDisplayText('STRING')
                    AddTextComponentSubstringPlayerName(point.label)
                    EndTextCommandDisplayText(0.0, 0.0)
                    ClearDrawOrigin()
                end
            end

            Wait(0)
        end
    end)
end, false)
