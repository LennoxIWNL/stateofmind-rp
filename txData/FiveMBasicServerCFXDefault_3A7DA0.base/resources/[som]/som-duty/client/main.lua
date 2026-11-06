exports('toggle', function()
    local r = lib.callback.await('som-duty:server:toggle', false)
    if not r then return end
    TriggerEvent('som:client:notify', r.success and (r.onduty and 'You are on duty' or 'You are off duty') or r.error,
        r.success and 'success' or 'error')
end)
