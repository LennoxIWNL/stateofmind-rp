-- Duty, blips and the shared "am I a working officer" state.
--
-- Nothing here decides anything. The server owns duty; this reflects it, and
-- other client files read Duty.IsOnDuty() to decide what to OFFER.

local core = exports['som-core']

Duty = {}

local onDuty = false
local blips = {}

---@return boolean
function Duty.IsOnDuty()
    return onDuty
end

---@return boolean whether the player is a police employee at all, on duty or not
function Duty.IsOfficer()
    local job = core:getJob()
    return job ~= nil and job.name == Config.Job
end

-- ---------------------------------------------------------------------------
-- Blips
-- ---------------------------------------------------------------------------

local function clearBlips()
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    blips = {}
end

local function createBlips()
    clearBlips()

    for _, station in pairs(Config.Stations) do
        local def = station.blip
        if def then
            local blip = AddBlipForCoord(def.coords.x, def.coords.y, def.coords.z)

            SetBlipSprite(blip, def.sprite)
            SetBlipColour(blip, def.colour)
            SetBlipScale(blip, def.scale)
            SetBlipAsShortRange(blip, true)
            SetBlipDisplay(blip, 4)

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(station.label)
            EndTextCommandSetBlipName(blip)

            blips[#blips + 1] = blip
        end
    end
end

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local function refresh()
    local job = core:getJob()
    local isPolice = job ~= nil and job.name == Config.Job

    onDuty = isPolice and job.onduty == true

    if isPolice then createBlips() else clearBlips() end

    -- Broadcast rather than have every other file poll. Keybinds and the eye
    -- both need to know, and both need to know at the same moment.
    TriggerEvent('som-police:client:dutyChanged', onDuty)
end

Duty.Refresh = refresh

AddEventHandler('som:client:onPlayerLoaded', function()
    -- The job arrives on a state bag that may land after playerLoaded, so this
    -- settles rather than racing it.
    CreateThread(function()
        Wait(1500)
        refresh()
    end)
end)

AddEventHandler('som:client:onJobChanged', refresh)

-- ---------------------------------------------------------------------------
-- The duty point
-- ---------------------------------------------------------------------------

CreateThread(function()
    local station = Config.Stations.mrpd

    exports['som-interact']:addBoxZone({
        name = 'police:duty',
        coords = station.duty.coords,
        size = station.duty.size,
        rotation = station.duty.rotation,
        options = {
            {
                name = 'police:duty',
                icon = 'fa-solid fa-clipboard-user',
                label = 'Sign on or off',
                distance = 2.0,
                -- A UI filter only. The server re-checks the job, and re-checks
                -- that the player is actually standing here.
                canInteract = function() return Duty.IsOfficer() end,
                onSelect = function()
                    local res = lib.callback.await('som-police:server:toggleDuty', false)
                    if not res then return end

                    if not res.success then
                        return TriggerEvent('som:client:notify', res.error or 'Could not sign on', 'error')
                    end

                    TriggerEvent('som:client:notify',
                        res.onduty and 'You are on duty' or 'You are off duty',
                        res.onduty and 'success' or 'inform')

                    refresh()
                end,
            },
            {
                name = 'police:mycerts',
                icon = 'fa-solid fa-certificate',
                label = 'My certifications',
                distance = 2.0,
                canInteract = function() return Duty.IsOfficer() end,
                onSelect = function()
                    local certs = lib.callback.await('som-police:server:myCerts', false) or {}

                    -- Sorted BEFORE the options are built, because pairs() has
                    -- no stable order and the list would otherwise reshuffle
                    -- every time it is opened.
                    local ids = {}
                    for id in pairs(Config.Certifications) do ids[#ids + 1] = id end

                    table.sort(ids, function(a, b)
                        return Config.Certifications[a].label < Config.Certifications[b].label
                    end)

                    local options = {}
                    for _, id in ipairs(ids) do
                        local def = Config.Certifications[id]

                        options[#options + 1] = {
                            title = def.label,
                            description = certs[id] and def.description or 'Not certified',
                            icon = certs[id] and 'circle-check' or 'circle-xmark',
                        }
                    end

                    lib.registerContext({
                        id = 'som_police_mycerts',
                        title = 'Certifications',
                        options = options,
                    })

                    lib.showContext('som_police_mycerts')
                end,
            },
        },
    })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearBlips()
end)

-- Prints coordinates from /pdcoords into the console, so the config can be
-- corrected against the MLO actually installed.
RegisterNetEvent('som-police:client:coords', function(vec3s, vec4s)
    print(('[som-police] %s'):format(vec3s))
    print(('[som-police] %s'):format(vec4s))
    TriggerEvent('som:client:notify', 'Coordinates printed to console (F8)', 'inform')
end)
