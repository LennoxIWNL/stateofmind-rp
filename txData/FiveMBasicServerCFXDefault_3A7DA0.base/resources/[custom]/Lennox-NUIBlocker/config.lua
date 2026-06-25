NUIBlocker = NUIBlocker or {}

NUIBlocker.Config = {
    RateLimitMax    = 30,
    RateLimitWindow = 2000,

    LogSource = 'Lennox-NUIBlocker',

    UseDiscordLogs = true,
    DiscordWebhook = 'https://discord.com/api/webhooks/1519638871019884674/JMGHSltfS1DMOuHUNXjTCINq-24-1zXLT1Ja4-6cC-ncQNwK5OIyXqhoFreh8GvJyDDm',

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
