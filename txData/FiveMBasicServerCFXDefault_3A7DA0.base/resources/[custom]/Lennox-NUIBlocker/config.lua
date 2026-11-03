NUIBlocker = NUIBlocker or {}

NUIBlocker.Config = {
    RateLimitMax    = 30,
    RateLimitWindow = 2000,

    LogSource = 'Lennox-NUIBlocker',

    UseDiscordLogs = true,
    -- Same webhook Lennox-Anticheat uses for its "events" channel. Read from
    -- a convar, not committed; set the real value in server.cfg.
    DiscordWebhook = GetConvar('lac_webhook_events', ''),

    BanOnThreshold     = false,
    BanThreshold       = 10,
    BanMessage         = 'You have been banned for NUI exploitation.',

    ProtectedEvents = {
        'inventory:server:UseItem',
        'inventory:server:UseItemSlot',
        'inventory:server:SetInventoryData',
        'inventory:server:GiveItem',
        'inventory:server:SaveInventory',
    },

    WhitelistedResources = {
        'qb-core',
        'ox_lib',
    },
}
