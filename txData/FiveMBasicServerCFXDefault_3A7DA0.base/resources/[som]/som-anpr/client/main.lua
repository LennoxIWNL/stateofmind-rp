--- Shows an ANPR hit the server decided on and locks the reader on the plate.
--- Nothing here is a decision.

RegisterNetEvent('som-anpr:client:hit', function(cam, plate, reasons)
    if type(cam) ~= 'string' or type(plate) ~= 'string' or type(reasons) ~= 'table' then return end

    TriggerEvent('som:client:notify', ('Plate %s: %s'):format(plate, table.concat(reasons, ', ')), 'error', 8000)
    TriggerEvent('wk:togglePlateLock', cam, true, 1)
end)
