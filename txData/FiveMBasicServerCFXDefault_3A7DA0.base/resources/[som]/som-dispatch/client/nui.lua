-- The dispatch feed's client half.
--
-- Forwards calls the server already decided this player may see, and nothing
-- else. There is no filtering here, because a filter a client applies is a
-- filter a client can remove: server/main.lua picks recipients and this only
-- draws what arrives.
--
-- The page NEVER takes NUI focus. An alert feed that stole the mouse every time
-- a shot was fired somewhere in the city would make the game unplayable during
-- a busy shift, so the one verb attached to a call, setting a waypoint, is a
-- keybind rather than a button.

-- The most recent call carrying usable coordinates, for the waypoint bind.
local latest = nil

RegisterNetEvent('som-dispatch:client:call', function(call)
    if type(call) ~= 'table' or not call.id then return end

    if call.coords and call.coords.x then latest = call end

    SendNUIMessage({ action = 'dispatch:call', data = call })
end)

-- Going off duty empties the feed.
--
-- Without this an officer who clocks out keeps a wall of calls on screen that
-- they can no longer act on, and which the server has already stopped sending
-- them updates for.
AddEventHandler('som-police:client:dutyChanged', function(onDuty)
    if onDuty then return end

    latest = nil
    SendNUIMessage({ action = 'dispatch:clear' })
end)

-- Waypoint to the newest call.
--
-- A keybind, so it appears in the FiveM keybind menu and the player can rebind
-- it. Unbound by default: the last argument to RegisterKeyMapping is the
-- suggested key, and picking one that collides with something an officer
-- already uses is worse than making them choose.
RegisterCommand('dispatchwaypoint', function()
    if not latest or not latest.coords then
        return TriggerEvent('som:client:notify', 'No recent call to route to', 'error')
    end

    SetNewWaypoint(latest.coords.x + 0.0, latest.coords.y + 0.0)

    TriggerEvent('som:client:notify',
        ('Routing to %s'):format(latest.street or latest.dispatchMessage or 'the call'),
        'success')
end, false)

RegisterKeyMapping('dispatchwaypoint', 'Route to the newest dispatch call', 'keyboard', '')

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    latest = nil
end)
