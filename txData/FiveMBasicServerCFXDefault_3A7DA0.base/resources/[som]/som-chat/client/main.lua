-- Command line.
--
-- Deliberately NOT a chat. The stock cfx `chat` resource is absent from this
-- server, so no typed command was reachable at all; this restores that and
-- nothing more.
--
-- There is no message log and nothing is drawn unless the player is typing.
-- Players communicate through voice, the phone and interactions. A visible
-- text chat would compete with all three and pull roleplay out of the world
-- and into a text box.
--
-- Script output goes to som-ui as a notification instead, so there is exactly
-- one place feedback appears.

local isOpen = false

local function open()
    if isOpen then return end
    isOpen = true

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
end

local function close()
    if not isOpen then return end
    isOpen = false

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('send', function(data, cb)
    cb({})

    local text = type(data) == 'table' and data.text or nil
    if type(text) ~= 'string' then return end

    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then return end

    if text:sub(1, 1) ~= '/' then
        if Config.CommandsOnly then
            TriggerEvent('som:client:notify',
                'Commands only. Use voice, your phone, or an interaction to talk.', 'info')
            return
        end
        return
    end

    -- ExecuteCommand handles client and server commands, and strips the slash.
    ExecuteCommand(text:sub(2))
end)

RegisterNUICallback('close', function(_, cb)
    cb({})
    close()
end)

-- Compatibility with the stock chat API.
--
-- Preserved third-party resources post through chat:addMessage. With no log to
-- put it in, route it to som-ui so the player still sees it rather than the
-- message vanishing.
RegisterNetEvent('chat:addMessage', function(data)
    if type(data) ~= 'table' then return end

    local text = data.args and table.concat(data.args, ' ') or data.text
    if type(text) ~= 'string' or text == '' then return end

    -- Strip the colour and formatting codes the old chat understood, since a
    -- notification renders them literally.
    text = text:gsub('%^%d', ''):gsub('<[^>]->', '')

    TriggerEvent('som:client:notify', text, 'info', 7000)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
end)

RegisterCommand('somchat', open, false)
RegisterKeyMapping('somchat', 'Open command line', 'keyboard', Config.OpenKey)
