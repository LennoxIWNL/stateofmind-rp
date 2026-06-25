-- =========================================================================
--  Lennox Anti-Cheat — Admin / Test Commands
--  Created by Lennox
-- =========================================================================

-- -------------------------------------------------------------------------
--  /cheater [id]   — TEST COMMAND
--  Force-bans the target player to verify the ban pipeline end-to-end.
--  Restricted to ace `command.cheater` (group.admin has it) and the server
--  console. Passes bypassImmunity=true so you can deliberately ban yourself
--  for testing even though you're normally immune.
-- -------------------------------------------------------------------------
RegisterCommand('cheater', function(source, args)
    local src = source

    -- In-game callers must be admins; console (src 0) is always allowed.
    if src > 0 and not LAC.isAdmin(src) then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 255, 20, 147 },
            args = { 'Lennox AC', 'You do not have permission to use this command.' }
        })
        return
    end

    local target = tonumber(args[1])
    if not target then
        local msg = 'Usage: /cheater [serverId]'
        if src > 0 then
            TriggerClientEvent('chat:addMessage', src, { color = { 255, 20, 147 }, args = { 'Lennox AC', msg } })
        else
            print('^5[Lennox-Anticheat]^7 ' .. msg)
        end
        return
    end

    if not GetPlayerName(target) then
        local msg = ('No player online with id %d'):format(target)
        if src > 0 then
            TriggerClientEvent('chat:addMessage', src, { color = { 255, 20, 147 }, args = { 'Lennox AC', msg } })
        else
            print('^5[Lennox-Anticheat]^7 ' .. msg)
        end
        return
    end

    local banId = LAC.banPlayer(target, 'Manual Ban (Lennox AC test)',
        ('Issued by %s'):format(src > 0 and (GetPlayerName(src) or ('id ' .. src)) or 'SERVER CONSOLE'), true)

    print(('^5[Lennox-Anticheat]^7 Test-banned id %d (Ban ID: %s)'):format(target, tostring(banId)))
end, true)  -- restricted = true -> requires ace command.cheater

-- -------------------------------------------------------------------------
--  lac_unban [banId | identifier]
--  Removes matching ban(s). Run from the SERVER CONSOLE / txAdmin live
--  console — that works even while you are banned from joining the game.
-- -------------------------------------------------------------------------
RegisterCommand('lac_unban', function(source, args)
    local src = source
    if src > 0 and not LAC.isAdmin(src) then return end

    local query = args[1]
    if not query then
        print('^5[Lennox-Anticheat]^7 Usage: lac_unban [banId | identifier]   e.g. lac_unban license:abc123')
        return
    end

    local removed = LAC.removeBan(query)
    print(('^5[Lennox-Anticheat]^7 Removed ^2%d^7 ban entry(ies) matching "%s"'):format(removed, query))
    if src > 0 then
        TriggerClientEvent('chat:addMessage', src, {
            color = { 255, 20, 147 },
            args = { 'Lennox AC', ('Removed %d ban(s) matching %s'):format(removed, query) }
        })
    end
end, true)
