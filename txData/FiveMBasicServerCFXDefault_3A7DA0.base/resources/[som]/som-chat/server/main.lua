-- som-chat is a command line, not a chat, so there is no message relay here.
--
-- The client sends nothing to the server: input either resolves to a command,
-- which FiveM routes itself, or it is rejected. That removes the whole class of
-- problem a text chat brings, since there is no player-authored text crossing
-- the network for the server to rate limit, filter or attribute.
--
-- Script output reaches players through som-ui notifications.

---Sends a line to a player, or everyone with -1.
---
---Kept so server code has an obvious way to reach a player without needing to
---know that the delivery mechanism is som-ui rather than a chat log.
---@param source number|nil -1 for everyone
---@param text string
---@param kind string|nil success, error, warning or info
exports('post', function(source, text, kind)
    if type(text) ~= 'string' or text == '' then return end
    TriggerClientEvent('som:client:notify', source or -1, text, kind or 'info')
end)
