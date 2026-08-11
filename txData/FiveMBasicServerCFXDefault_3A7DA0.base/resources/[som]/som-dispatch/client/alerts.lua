-- Receiving calls: the blip, the notification, and the waypoint.
--
-- Only players the SERVER chose to send a call to run any of this. There is no
-- client-side filtering of who may see what, because a filter a client applies
-- is a filter a client can remove.

-- callId -> { area = radius blip, mark = sprite blip }
--
-- TWO blips per call, not one. The radius is the pulsing circle that says
-- roughly where; the small sprite in the middle is what makes it identifiable
-- on a crowded map and what the player actually clicks. A radius alone is a
-- coloured smear with no name attached.
local blips = {}

-- How wide the circle is drawn, in metres.
--
-- Deliberately not precise. A dispatch call is "somewhere around here", and a
-- pinpoint marker on the exact coordinate tells officers where the shooter is
-- standing, which is information the caller never had.
local AREA_RADIUS = 80.0

-- The pulse.
--
-- GTA has no pulsing blip, so it is animated: alpha walked up and down on an
-- interval. SetBlipFlashes exists and is not this, it hard-blinks the icon on
-- and off, which reads as an error state rather than as a live scene.
local PULSE_MIN, PULSE_MAX, PULSE_STEP = 60, 180, 12
local PULSE_INTERVAL = 60

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

            -- The thread stops itself once the map is clear rather than
            -- spinning forever at sixty wakeups a second for nothing.
            if not any then
                pulsing = false
                return
            end

            Wait(PULSE_INTERVAL)
        end
    end)
end

---@param id number
local function removeBlip(id)
    local entry = blips[id]
    if not entry then return end

    if entry.area and DoesBlipExist(entry.area) then RemoveBlip(entry.area) end
    if entry.mark and DoesBlipExist(entry.mark) then RemoveBlip(entry.mark) end

    blips[id] = nil
end

---@param call table
local function addBlip(call)
    local def = call.blip
    if not def or not call.coords then return end

    -- One entry per call. A duplicate arriving (a reconnect, a resource
    -- restart) must not leave the first one orphaned on the map forever.
    removeBlip(call.id)

    local colour = def.colour or 1

    local area = AddBlipForRadius(call.coords.x, call.coords.y, call.coords.z, AREA_RADIUS)
    SetBlipHighDetail(area, true)
    SetBlipColour(area, colour)
    SetBlipAlpha(area, PULSE_MIN)

    local mark = AddBlipForCoord(call.coords.x, call.coords.y, call.coords.z)
    SetBlipSprite(mark, def.sprite or 110)
    SetBlipColour(mark, colour)
    SetBlipScale(mark, def.scale or 0.85)
    SetBlipAsShortRange(mark, false)
    SetBlipDisplay(mark, 4)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(call.dispatchMessage or 'Call')
    EndTextCommandSetBlipName(mark)

    blips[call.id] = { area = area, mark = mark }

    startPulse()

    local seconds = def.duration or 300

    -- Blips expire on their own. Dispatch calls that never clear turn the map
    -- into a wall of markers within an hour.
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

    -- Each entry is a PAIR now, the radius and the sprite, so both handles have
    -- to be released. Treating an entry as a bare handle here would leave every
    -- circle painted on the map until the client reconnected.
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
