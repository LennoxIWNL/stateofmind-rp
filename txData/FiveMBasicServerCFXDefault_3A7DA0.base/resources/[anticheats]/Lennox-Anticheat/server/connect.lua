-- =========================================================================
--  Lennox Anti-Cheat — Connection Handler
--  Created by Lennox — DO NOT MODIFY THIS FILE
-- =========================================================================

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)

    deferrals.update('Lennox Anti-Cheat — checking your account...')

    local identifiers = {}
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        identifiers[#identifiers + 1] = GetPlayerIdentifier(src, i)
    end

    local tokens = {}
    for i = 0, GetNumPlayerTokens(src) - 1 do
        tokens[#tokens + 1] = GetPlayerToken(src, i)
    end

    Wait(100)

    local ban = LAC.checkBan(identifiers, tokens)
    if ban then
        LAC.sendDiscord('connections', 'Banned Player Attempted Connection',
            ('**Player:** %s\n**Ban ID:** `%s`\n**Reason:** %s\n**Banned:** %s\n**Identifiers:** %s')
                :format(name, ban.banId, ban.reason, ban.timestamp or '?',
                    table.concat(identifiers, '\n')),
            16711680)

        deferrals.done(
            ('[Lennox Anti-Cheat] You are banned from this server.\n\n' ..
             'Reason: %s\nBan ID: %s\nDate: %s\n\n' ..
             'Appeal in the server Discord.')
                :format(ban.reason, ban.banId, ban.timestamp or '?'))
        return
    end

    if #identifiers == 0 then
        LAC.sendDiscord('connections', 'No Identifiers',
            ('**Player:** %s — connected with zero identifiers (suspicious)')
                :format(name),
            16776960)

        deferrals.done('[Lennox Anti-Cheat] Could not verify your identity. Please restart FiveM and try again.')
        return
    end

    deferrals.done()

    LAC.sendDiscord('connections', 'Player Connected',
        ('**Player:** %s (id: %s)\n**Identifiers:** %s')
            :format(name, src, table.concat(identifiers, '\n')),
        65280)
end)
