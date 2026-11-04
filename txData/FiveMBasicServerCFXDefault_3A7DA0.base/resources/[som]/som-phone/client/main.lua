-- Phone client. It opens and closes the NUI and relays ONE kind of request:
-- (app, action, payload) to the server. Every decision (what apps you see, what
-- a theme costs, whether money moves) is made there.

local isOpen = false

local function open()
    if isOpen then return end

    -- Courtesy check only. The SERVER refuses too, and that refusal is the one
    -- that matters.
    if GetResourceState('som-medical') == 'started' and exports['som-medical']:isDowned() then
        return TriggerEvent('som:client:notify', 'You are in no state to use a phone', 'error')
    end

    local result = lib.callback.await('som-phone:server:action', false, 'system', 'open', {})
    if not result or not result.success then
        TriggerEvent('som:client:notify', result and result.error or 'Cannot open phone', 'error')
        return
    end

    isOpen = true
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

    -- Closing locks the phone again if it has a passcode.
    lib.callback('som-phone:server:action', false, function() end, 'system', 'lock', {})
end

RegisterNUICallback('close', function(_, cb)
    cb({})
    close()
end)

-- The one call every app uses. The page names an app and an action; whether it
-- may is decided on the server.
RegisterNUICallback('action', function(data, cb)
    if type(data) ~= 'table' then return cb({ success = false }) end
    cb(lib.callback.await('som-phone:server:action', false, data.app, data.action, data.payload) or { success = false })
end)

-- Buying a property is done at the door by som-housing, which re-reads the
-- price, the sale status and the distance. The phone only relays the request.
RegisterNUICallback('buyProperty', function(data, cb)
    cb(lib.callback.await('som-housing:server:buy', false, data) or { success = false })
end)

RegisterNetEvent('som-phone:client:refresh', function()
    if isOpen then SendNUIMessage({ action = 'refresh' }) end
end)

---Plays one of Config.Sounds. Front-end, so it is not positional.
---@param kind string a key of Config.Sounds
local function playSound(kind)
    if not Config.Sounds or not Config.Sounds.enabled then return end

    local sound = Config.Sounds[kind]
    if not sound then return end

    PlaySoundFrontend(-1, sound.name, sound.set, true)
end

-- A notification takes no NUI focus: with the phone closed the page shows the
-- banner alone and hides again when it expires.
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

-- ---------------------------------------------------------------------------
-- Calls. The server owns the call and the voice channel; this only rings,
-- shows who is calling, and relays answer and hang up.
-- ---------------------------------------------------------------------------

local callState = nil

local function callAction(action)
    lib.callback('som-phone:server:action', false, function() end, 'phone', action, {})
end

RegisterNetEvent('som-phone:client:call', function(call)
    if type(call) ~= 'table' or type(call.state) ~= 'string' then return end

    local was = callState
    callState = call.state ~= 'ended' and call.state or nil

    SendNUIMessage({ action = 'call', data = call })

    if call.state == 'ringing' then
        CreateThread(function()
            while callState == 'ringing' do
                playSound('call')
                Wait(3000)
            end
        end)
        TriggerEvent('som:client:notify', ('Incoming call: %s  (Y answer, N decline)'):format(call.name or call.number or 'Unknown'), 'inform', 8000)
    elseif call.state == 'active' then
        Anim.Play('call')
    elseif call.state == 'ended' then
        if not isOpen then Anim.Stop() end
        if was then TriggerEvent('som:client:notify', 'Call ended', 'inform') end
    end
end)

RegisterCommand('phoneanswer', function()
    if callState == 'ringing' then callAction('answer') end
end, false)

RegisterCommand('phonehangup', function()
    if callState then callAction('hangup') end
end, false)

RegisterKeyMapping('phoneanswer', 'Answer a call', 'keyboard', 'Y')
RegisterKeyMapping('phonehangup', 'Decline or end a call', 'keyboard', 'N')

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
end)

-- Closing through the pause menu or a death would otherwise leave the prop in
-- hand, so the animation follows the UI state rather than the key.
RegisterNetEvent('som-phone:client:close', close)

RegisterCommand('phone', open, false)
RegisterKeyMapping('phone', 'Open phone', 'keyboard', Config.OpenKey)

exports('openPhone', open)
