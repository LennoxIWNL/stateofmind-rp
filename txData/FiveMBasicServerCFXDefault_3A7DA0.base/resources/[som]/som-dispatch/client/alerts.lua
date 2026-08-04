-- Receiving calls: the blip, the notification, and the waypoint.
--
-- Only players the SERVER chose to send a call to run any of this. There is no
-- client-side filtering of who may see what, because a filter a client applies
-- is a filter a client can remove.

local blips = {}   -- callId -> blip handle

---@param call table
local function addBlip(call)
    local def = call.blip
    if not def or not call.coords then return end

    -- One blip per call. A duplicate arriving (a reconnect, a resource restart)
    -- must not leave the first one orphaned on the map forever.
    if blips[call.id] and DoesBlipExist(blips[call.id]) then
        RemoveBlip(blips[call.id])
    end

    local blip = AddBlipForCoord(call.coords.x, call.coords.y, call.coords.z)

    SetBlipSprite(blip, def.sprite or 110)
    SetBlipColour(blip, def.colour or 1)
    SetBlipScale(blip, def.scale or 1.0)
    SetBlipAsShortRange(blip, false)
    SetBlipDisplay(blip, 4)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(call.dispatchMessage or 'Call')
    EndTextCommandSetBlipName(blip)

    -- The alert flashes briefly so it is noticed, then settles. A permanently
    -- flashing blip is one people learn to ignore.
    SetBlipFlashes(blip, true)
    SetBlipFlashTimer(blip, 6000)

    blips[call.id] = blip

    local seconds = def.duration or 300

    -- Blips expire on their own. Dispatch calls that never clear turn the map
    -- into a wall of markers within an hour.
    SetTimeout(seconds * 1000, function()
        if blips[call.id] and DoesBlipExist(blips[call.id]) then
            RemoveBlip(blips[call.id])
        end
        blips[call.id] = nil
    end)
end

RegisterNetEvent('som-dispatch:client:call', function(call)
    if type(call) ~= 'table' or not call.id then return end

    addBlip(call)

    -- Dispatch is job radio traffic, not a phone notification. It deliberately
    -- does NOT go through som-phone: an officer hears it because they are on
    -- duty, not because they happened to have their phone out. See the routing
    -- note on som-phone's notifyApp export.
    TriggerEvent('som:client:notify',
        ('%s: %s'):format(call.dispatchCode or 'Call', call.dispatchMessage or ''),
        'inform', 8000)
end)

-- ps-mdt fires this from its own UI when a call is dismissed there, so the map
-- marker and the world blip clear together.
RegisterNetEvent('ps-dispatch:client:removeCallBlip', function(callId)
    local id = tonumber(callId)
    if not id or not blips[id] then return end

    if DoesBlipExist(blips[id]) then RemoveBlip(blips[id]) end
    blips[id] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, blip in pairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
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
