RegisterNetEvent('som-tow:client:waypoint', function(x, y)
    if type(x) ~= 'number' or type(y) ~= 'number' then return end
    SetNewWaypoint(x + 0.0, y + 0.0)
end)
