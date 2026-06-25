-- =========================================================================
--  Discord Role Allowlist
--  Checks if connecting players have a required Discord role.
--  Set Config.DiscordAllowlist.Enabled = true to activate.
-- =========================================================================

Config.DiscordAllowlist = {
    Enabled       = false,
    BotToken      = '',
    GuildId       = '1518622821746737172',
    RequiredRoles = { '1518792503724212364' },
    AllowNoDiscord = false,
    KickMessage   = 'You must be a member of our Discord and have the required role to join.\n\nDiscord: https://discord.gg/xEqCYMDDVz',
}

local dc = Config.DiscordAllowlist

local function getDiscordId(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if string.sub(id, 1, 8) == 'discord:' then
            return string.sub(id, 9)
        end
    end
    return nil
end

local function checkDiscordRole(discordId, cb)
    if dc.BotToken == '' or dc.GuildId == '' then
        cb(true)
        return
    end

    local url = ('https://discord.com/api/v10/guilds/%s/members/%s'):format(dc.GuildId, discordId)

    PerformHttpRequest(url, function(status, body)
        if status == 200 then
            local data = json.decode(body)
            if data and data.roles then
                for _, playerRole in ipairs(data.roles) do
                    for _, requiredRole in ipairs(dc.RequiredRoles) do
                        if playerRole == requiredRole then
                            cb(true)
                            return
                        end
                    end
                end
            end
            cb(false)
        elseif status == 404 then
            cb(false)
        else
            print(('^3[connectqueue]^7 Discord API returned status %d for user %s — allowing (fail-open)'):format(status, discordId))
            cb(true)
        end
    end, 'GET', '', {
        ['Authorization'] = 'Bot ' .. dc.BotToken,
        ['Content-Type']  = 'application/json',
    })
end

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    if not dc.Enabled then return end

    local src = source
    deferrals.defer()
    Wait(0)

    deferrals.update('Checking Discord membership...')

    local discordId = getDiscordId(src)

    if not discordId then
        if dc.AllowNoDiscord then
            deferrals.done()
            return
        end
        Wait(500)
        deferrals.done('Discord not detected. Please make sure Discord is running and linked to FiveM.\n\nDiscord: https://discord.gg/xEqCYMDDVz')
        return
    end

    if #dc.RequiredRoles == 0 then
        deferrals.done()
        return
    end

    local checked = nil

    checkDiscordRole(discordId, function(hasRole)
        checked = hasRole
    end)

    local waited = 0
    while checked == nil and waited < 5000 do
        Wait(50)
        waited = waited + 50
    end

    if checked == nil then
        deferrals.done()
        return
    end

    if not checked then
        Wait(500)
        deferrals.done(dc.KickMessage)
        return
    end

    deferrals.done()
end)
