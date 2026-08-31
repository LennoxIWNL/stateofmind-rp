-- Phone client.
--
-- Thin by design: it opens and closes the NUI and relays requests. Every
-- decision (what apps you may see, what a theme costs, whether a bill can be
-- raised, whether money moves) is made server side.

local isOpen = false

local function open()
    if isOpen then return end

    -- Courtesy check only. The SERVER refuses too, and that refusal is the one
    -- that matters: this just avoids a round trip and a pointless error toast
    -- for an honest player who pressed the key while bleeding out.
    if GetResourceState('som-medical') == 'started' and exports['som-medical']:isDowned() then
        return TriggerEvent('som:client:notify', 'You are in no state to use a phone', 'error')
    end

    local result = lib.callback.await('som-phone:server:open', false)
    if not result or not result.success then
        TriggerEvent('som:client:notify', result and result.error or 'Cannot open phone', 'error')
        return
    end

    isOpen = true
    -- Taking the phone out is visible to everyone else, which is the point:
    -- other players can see who is on their phone.
    Anim.Play('hold')

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = result })
end

local function close()
    if not isOpen then return end

    isOpen = false
    Anim.Stop()

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb)
    cb({})
    close()
end)

RegisterNUICallback('buyProperty', function(data, cb)
    -- Straight through. The phone decides nothing: som-housing re-reads the
    -- price, the sale status and the distance from the door.
    cb(lib.callback.await('som-housing:server:buy', false, data) or { success = false })
end)

RegisterNUICallback('properties', function(_, cb)
    cb(lib.callback.await('som-phone:server:properties', false) or { success = false })
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

-- Anything phone-shaped announces itself ON the phone.
--
-- NO NUI FOCUS. A notification must never take the mouse, so when the phone is
-- closed the NUI shows the banner alone, floating where the device would be,
-- and hides itself again once it expires. That is what makes it a notification
-- rather than an interruption.
--
-- Deliberately not routed through som-ui: a bill arriving is the phone's
-- business. "You do not have a phone" stays a som-ui toast, because at that
-- point there is no phone to put a banner on.
---Plays one of Config.Sounds. Front-end, so it is not positional: a phone in
---your pocket does not come from somewhere in the world.
---
---A plain local rather than a member of a Phone table, because this file has no
---such table: writing to one would have been an index of nil at load and taken
---the whole client half of the phone down with it.
---@param kind string a key of Config.Sounds
local function playSound(kind)
    if not Config.Sounds or not Config.Sounds.enabled then return end

    local sound = Config.Sounds[kind]
    if not sound then return end

    PlaySoundFrontend(-1, sound.name, sound.set, true)
end

RegisterNetEvent('som-phone:client:banner', function(title, text, iconName)
    if type(title) ~= 'string' or type(text) ~= 'string' then return end

    playSound('notification')

    SendNUIMessage({
        action = 'banner',
        title = title,
        text = text,
        icon = type(iconName) == 'string' and iconName or 'bank',
    })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
end)

-- Closing the phone through the pause menu or a death would otherwise leave
-- the prop in hand, so the animation follows the UI state rather than the key.
RegisterNetEvent('som-phone:client:close', close)

RegisterCommand('phone', open, false)
RegisterKeyMapping('phone', 'Open phone', 'keyboard', Config.OpenKey)

-- Using the item opens it too, which is the natural interaction now that the
-- phone is something you carry.
exports('openPhone', open)
