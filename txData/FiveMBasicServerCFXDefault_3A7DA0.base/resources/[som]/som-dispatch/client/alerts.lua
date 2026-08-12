-- Receiving calls: the blip, the notification, and the waypoint.
--
-- Only players the SERVER chose to send a call to run any of this. There is no
-- client-side filtering of who may see what, because a filter a client applies
-- is a filter a client can remove.

-- callId -> { mark = blip handle }
--
-- ONE blip per call. The pulse is the marker.
local blips = {}

-- THE MARKER IS FIVE-DISPATCH'S, EXACTLY.
--
-- Corrected after checking the reference rather than assuming. An earlier
-- version here used AddBlipForRadius with its alpha walked up and down on a
-- timer, on the reasoning that GTA has no pulsing blip. That reasoning was
-- wrong: `PulseBlip` is a real native, and it is what five-dispatch uses. The
-- expanding ring on the minimap is the game drawing it, not us animating alpha.
--
-- Their values, kept as they are (client.lua:50-59): sprite 161, display 4,
-- scale 1.0, short range, then PulseBlip. The only thing not taken from them is
-- the colour, which stays per alert here because our alerts carry a priority
-- and theirs do not.
local BLIP_SPRITE = 161
local BLIP_SCALE = 1.0

-- PulseBlip fires ONE ring. Re-firing it keeps the call visibly live rather
-- than flashing once and then sitting there as an ordinary dot.
local PULSE_INTERVAL = 3000

local pulsing = false

local function startPulse()
    if pulsing then return end
    pulsing = true

    CreateThread(function()
        while true do
            local any = false

            for _, entry in pairs(blips) do
                if entry.mark and DoesBlipExist(entry.mark) then
                    PulseBlip(entry.mark)
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

    if entry.mark and DoesBlipExist(entry.mark) then RemoveBlip(entry.mark) end
    blips[id] = nil
end

local function addBlip(call)
    local def = call.blip
    if not def or not call.coords then return end

    -- One entry per call. A duplicate arriving (a reconnect, a resource
    -- restart) must not leave the first orphaned on the map forever.
    removeBlip(call.id)

    local mark = AddBlipForCoord(call.coords.x, call.coords.y, call.coords.z)
    SetBlipSprite(mark, def.sprite or BLIP_SPRITE)
    SetBlipDisplay(mark, 4)
    SetBlipScale(mark, def.scale or BLIP_SCALE)
    SetBlipColour(mark, def.colour or 1)
    SetBlipAsShortRange(mark, true)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(call.dispatchMessage or 'Call')
    EndTextCommandSetBlipName(mark)

    PulseBlip(mark)

    blips[call.id] = { mark = mark }

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
