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

---@param def table { coords, sprite, colour, scale }
---@param label string
local function addBlip(def, label)
    local blip = AddBlipForCoord(def.coords.x, def.coords.y, def.coords.z)

    SetBlipSprite(blip, def.sprite)
    SetBlipColour(blip, def.colour)
    SetBlipScale(blip, def.scale or 0.7)
    SetBlipAsShortRange(blip, true)
    SetBlipDisplay(blip, 4)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)

    blips[#blips + 1] = blip
end

---@param isPolice boolean whether the player works here
local function createBlips(isPolice)
    clearBlips()

    for _, station in pairs(Config.Stations) do
        -- The station itself is visible to EVERYONE. It was previously drawn
        -- only for officers, which meant a citizen could not find the police
        -- station on the map at all.
        if station.blip then addBlip(station.blip, station.label) end

        -- The working parts of the building are only useful to somebody who
        -- can actually use them, so those stay officer-only.
        if isPolice then
            for _, entry in ipairs(Config.StaffBlips or {}) do
                local target = station[entry.from]

                if target and target.coords then
                    addBlip({
                        coords = target.coords,
                        sprite = entry.sprite,
                        colour = entry.colour,
                        scale = entry.scale,
                    }, entry.label)
                end
            end
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

    createBlips(isPolice)

    -- Broadcast rather than have every other file poll. Keybinds and the eye
    -- both need to know, and both need to know at the same moment.
    TriggerEvent('som-police:client:dutyChanged', onDuty)

    -- The radial caches its entries and only refetches on a job or gang change,
    -- so going on duty left the MDT slice missing until a relog. som-radial
    -- exposes this event for exactly that and had no callers.
    TriggerEvent('som-radial:client:refresh')
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
-- Certifications, readable by any officer
-- ---------------------------------------------------------------------------

function Duty.ShowCerts()
    local certs = lib.callback.await('som-police:server:myCerts', false) or {}

    -- Sorted BEFORE the list is built: pairs() has no stable order, so the card
    -- would reshuffle every time it was opened.
    local ids = {}
    for id in pairs(Config.Certifications) do ids[#ids + 1] = id end

    table.sort(ids, function(a, b)
        return Config.Certifications[a].label < Config.Certifications[b].label
    end)

    local list = {}
    for _, id in ipairs(ids) do
        local def = Config.Certifications[id]

        list[#list + 1] = {
            id = id,
            label = def.label,
            description = def.description,
            held = certs[id] == true,
        }
    end

    local data = core:getPlayerData() or {}
    local info = data.charinfo or {}
    local job = data.job or {}

    Armoury.ShowCerts({
        certifications = list,
        name = ('%s %s  %s'):format(
            info.firstname or '', info.lastname or '', job.gradeLabel or ''),
        badge = 'LSPD',
    })
end

exports('showCerts', Duty.ShowCerts)

---Opens the MDT.
---
---ps-mdt registers /mdt as a client command and does its own job check, so
---this hands off rather than reimplementing the open. It exists so the radial
---has something to call: a radial entry naming a command would let the client
---choose the command.
exports('openMDT', function()
    if GetResourceState('ps-mdt') ~= 'started' then
        return TriggerEvent('som:client:notify', 'The MDT is not available', 'error')
    end

    ExecuteCommand('mdt')
end)

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
                onSelect = Duty.ShowCerts,
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
