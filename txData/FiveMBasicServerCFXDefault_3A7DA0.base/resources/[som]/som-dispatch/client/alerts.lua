-- Receiving calls: the blip, the notification, and the waypoint.
--
-- Only players the SERVER chose to send a call to run any of this. There is no
-- client-side filtering of who may see what, because a filter a client applies
-- is a filter a client can remove.

-- callId -> { mark = blip handle }
--
-- ONE blip per call. The pulse is the marker.
local blips = {}

-- AN AREA, AND NOTHING ELSE.
--
-- Two corrections in one, both from play testing:
--
--   * There is NO icon blip. The per-alert `sprite` in shared/config.lua is
--     deliberately ignored: sprite 110 is a gun, so every shots-fired call put
--     a firearm icon on the exact coordinate. That tells officers where the
--     shooter is standing, which is information the caller never had.
--   * The AREA is back. A radius is the whole marker, because "somewhere around
--     here" is what a 911 call actually contains.
--
-- The pulse is an alpha walk rather than PulseBlip. PulseBlip is what
-- five-dispatch calls, and it animates a coord blip's ICON; there is no icon
-- here to animate. Walking the radius alpha is what makes an area breathe.
local AREA_RADIUS = 80.0

local PULSE_MIN, PULSE_MAX, PULSE_STEP = 45, 165, 10
local PULSE_INTERVAL = 55

local pulsing = false

local function startPulse()
    if pulsing then return end
    pulsing = true

    CreateThread(function()
        local alpha, direction = PULSE_MIN, 1

        while true do
            local any = false
            alpha = alpha + (PULSE_STEP * direction)

            if alpha >= PULSE_MAX then
                alpha, direction = PULSE_MAX, -1
            elseif alpha <= PULSE_MIN then
                alpha, direction = PULSE_MIN, 1
            end

            for _, entry in pairs(blips) do
                if entry.area and DoesBlipExist(entry.area) then
                    SetBlipAlpha(entry.area, alpha)
                    any = true
                end
            end

            -- Stops itself once the map is clear rather than waking forever.
            if not any then
                pulsing = false
                return
            end

            Wait(PULSE_INTERVAL)
        end
    end)
end

local function removeBlip(id)
    local entry = blips[id]
    if not entry then return end

    if entry.area and DoesBlipExist(entry.area) then RemoveBlip(entry.area) end
    blips[id] = nil
end

local function addBlip(call)
    local def = call.blip
    if not def or not call.coords then return end

    -- One entry per call. A duplicate arriving (a reconnect, a resource
    -- restart) must not leave the first orphaned on the map forever.
    removeBlip(call.id)

    local area = AddBlipForRadius(call.coords.x, call.coords.y, call.coords.z, AREA_RADIUS)
    SetBlipHighDetail(area, true)
    SetBlipColour(area, def.colour or 1)
    SetBlipAlpha(area, PULSE_MIN)

    blips[call.id] = { area = area }

    startPulse()

    local seconds = def.duration or 300

    -- Areas expire on their own. Calls that never clear turn the map into a
    -- wall of circles within an hour.
    SetTimeout(seconds * 1000, function() removeBlip(call.id) end)
end

RegisterNetEvent('som-dispatch:client:call', function(call)
    if type(call) ~= 'table' or not call.id then return end

    addBlip(call)

    -- No som:client:notify here any more.
    --
    -- client/nui.lua draws the call as its own card, which says everything the
    -- toast said and more. Firing both put two notifications on screen for one
    -- event, in two different styles, in two different corners.
    --
    -- Dispatch is still job radio traffic rather than a phone notification, and
    -- deliberately does NOT go through som-phone: an officer hears it because
    -- they are on duty, not because they happened to have their phone out.
end)

-- ps-mdt fires this from its own UI when a call is dismissed there, so the map
-- marker and the world blip clear together.
RegisterNetEvent('ps-dispatch:client:removeCallBlip', function(callId)
    local id = tonumber(callId)
    if not id then return end

    removeBlip(id)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for id in pairs(blips) do removeBlip(id) end

    blips = {}
end)

-- ---------------------------------------------------------------------------
-- Reporting a crime as a civilian
--
-- The one deliberate, player-initiated call; everything else here is detection.
--
-- A COMMAND on purpose. AUDIT §10.1 exists to replace commands with
-- interactions, but that applies to verbs aimed at something you are looking
-- at. Ringing the police is free text aimed at nobody in particular, so there
-- is nothing to point the eye at and a command is the honest shape.
--
-- No chat:addSuggestion: som-chat provides 'chat' but implements only
-- chat:addMessage, so a suggestion would be dead code advertising a feature
-- that does not exist.
-- ---------------------------------------------------------------------------

RegisterCommand('911', function(_, args)
    local message = table.concat(args, ' ')

    if #message < 3 then
        return TriggerEvent('som:client:notify', 'Usage: /911 <what is happening>', 'error')
    end

    TriggerServerEvent('som-dispatch:server:emergency', message)
end, false)
