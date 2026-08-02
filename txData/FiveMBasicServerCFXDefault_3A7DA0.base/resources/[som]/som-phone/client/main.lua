-- Phone client.
--
-- Thin by design: it opens and closes the NUI and relays requests. Every
-- decision (what apps you may see, what a theme costs, whether a bill can be
-- raised, whether money moves) is made server side.

local isOpen = false

local function open()
    if isOpen then return end

    local result = lib.callback.await('som-phone:server:open', false)
    if not result or not result.success then
        TriggerEvent('som:client:notify', result and result.error or 'Cannot open phone', 'error')
        return
    end

    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = result })
end

local function close()
    if not isOpen then return end

    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb)
    cb({})
    close()
end)

RegisterNUICallback('bank', function(_, cb)
    cb(lib.callback.await('som-phone:server:bank', false) or {})
end)

RegisterNUICallback('shareAccount', function(_, cb)
    cb(lib.callback.await('som-phone:server:shareAccount', false) or { success = false })
end)

RegisterNUICallback('createBill', function(data, cb)
    cb(lib.callback.await('som-phone:server:createBill', false, data) or { success = false })
end)

RegisterNUICallback('payBill', function(data, cb)
    cb(lib.callback.await('som-phone:server:payBill', false, data and data.id) or { success = false })
end)

RegisterNUICallback('declineBill', function(data, cb)
    cb(lib.callback.await('som-phone:server:declineBill', false, data and data.id) or { success = false })
end)

RegisterNUICallback('transfer', function(data, cb)
    cb(lib.callback.await('som-phone:server:transfer', false, data) or { success = false })
end)

RegisterNUICallback('setTheme', function(data, cb)
    cb(lib.callback.await('som-phone:server:setTheme', false, data and data.theme) or { success = false })
end)

-- Pushed when something changed while the phone is open, such as a bill
-- arriving or somebody sharing their account number.
RegisterNetEvent('som-phone:client:refresh', function()
    if isOpen then SendNUIMessage({ action = 'refresh' }) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
end)

RegisterCommand('phone', open, false)
RegisterKeyMapping('phone', 'Open phone', 'keyboard', Config.OpenKey)

-- Using the item opens it too, which is the natural interaction now that the
-- phone is something you carry.
exports('openPhone', open)
