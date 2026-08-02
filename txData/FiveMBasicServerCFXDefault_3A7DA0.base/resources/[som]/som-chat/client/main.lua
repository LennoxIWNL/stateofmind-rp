-- Chat.
--
-- The stock cfx `chat` resource is absent from this server, so no typed
-- command has been reachable at all. Rather than restore it and have an
-- unstyled box clash with everything else, this is a minimal replacement in
-- the SOM palette.
--
-- Scope is deliberately small. SOM is phone and interaction driven, so chat
-- exists for commands, staff work, and the roleplay verbs that genuinely have
-- no physical anchor. It is not meant to become the main way players talk.

local isOpen = false
local history = {}

local function open()
    if isOpen then return end
    isOpen = true

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', history = history })
end

local function close()
    if not isOpen then return end
    isOpen = false

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

---@param message table { author, text, colour, type }
local function addMessage(message)
    history[#history + 1] = message
    -- Bounded, or a long session grows this forever.
    if #history > Config.MaxHistory then
        table.remove(history, 1)
    end

    SendNUIMessage({ action = 'message', message = message })
end

RegisterNUICallback('send', function(data, cb)
    cb({})

    local text = type(data) == 'table' and data.text or nil
    if type(text) ~= 'string' then return end

    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then return end

    if text:sub(1, 1) == '/' then
        -- ExecuteCommand handles both client and server commands, and strips
        -- the slash itself.
        ExecuteCommand(text:sub(2))
        return
    end

    TriggerServerEvent('som-chat:server:message', text)
end)

RegisterNUICallback('close', function(_, cb)
    cb({})
    close()
end)

RegisterNetEvent('som-chat:client:message', function(message)
    if type(message) ~= 'table' then return end
    addMessage(message)
end)

-- Compatibility with the stock chat API, so preserved third-party resources
-- that post through chat:addMessage still appear rather than silently failing.
RegisterNetEvent('chat:addMessage', function(data)
    if type(data) ~= 'table' then return end

    local text = data.args and table.concat(data.args, ' ') or data.text or ''
    addMessage({
        author = data.args and data.args[1] or nil,
        text = tostring(text),
        colour = data.color and ('rgb(%d,%d,%d)'):format(
            data.color[1] or 255, data.color[2] or 255, data.color[3] or 255) or nil,
        kind = 'system',
    })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
end)

RegisterCommand('somchat', open, false)
RegisterKeyMapping('somchat', 'Open chat', 'keyboard', Config.OpenKey)

-- The stock chat bound T, and muscle memory is worth respecting.
RegisterCommand('+somchatAlt', open, false)
RegisterKeyMapping('+somchatAlt', 'Open chat (alternate)', 'keyboard', Config.AltKey)
