-- Chat relay.
--
-- Messages are proximity based by default: shouting across the whole map is
-- not roleplay, and a global chat undermines the phone being the way to reach
-- someone you cannot see.

local lastMessage = {}

RegisterNetEvent('som-chat:server:message', function(text)
    local source = source

    if type(text) ~= 'string' then return end
    text = text:sub(1, Config.MaxLength)
    if text:gsub('%s', '') == '' then return end

    -- Rate limit. Without it a client can spam the event as fast as it likes.
    local now = GetGameTimer()
    if lastMessage[source] and now - lastMessage[source] < Config.CooldownMs then return end
    lastMessage[source] = now

    local player = exports['som-core']:getPlayer(source)
    -- Before a character is loaded there is nobody to attribute a message to.
    if not player then return end

    local author = ('%s %s'):format(player.charinfo.firstname, player.charinfo.lastname)
    local payload = { author = author, text = text, kind = 'say' }

    if not Config.Proximity then
        TriggerClientEvent('som-chat:client:message', -1, payload)
        return
    end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end
    local origin = GetEntityCoords(ped)

    for _, target in ipairs(GetPlayers()) do
        local targetId = tonumber(target)
        local targetPed = targetId and GetPlayerPed(targetId)

        if targetPed and targetPed ~= 0 then
            if #(origin - GetEntityCoords(targetPed)) <= Config.Range then
                TriggerClientEvent('som-chat:client:message', targetId, payload)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    lastMessage[source] = nil
end)

---Server-side helper so other resources can post to a player's chat.
---@param source number|nil -1 for everyone
---@param text string
---@param kind string|nil
exports('post', function(source, text, kind)
    if type(text) ~= 'string' then return end
    TriggerClientEvent('som-chat:client:message', source or -1, {
        text = text, kind = kind or 'system',
    })
end)
