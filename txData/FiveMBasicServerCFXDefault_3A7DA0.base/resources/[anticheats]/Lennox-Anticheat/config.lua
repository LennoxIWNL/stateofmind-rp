LACConfig = {}

-- =========================================================================
--  Discord Webhooks
-- =========================================================================
LACConfig.Webhooks = {
    bans        = 'https://discord.com/api/webhooks/1519638861846941810/Z3AytSBerim1tirZEoplZBWzYMQh3TWH74rEU75MeSloEVwYt2XmacL9Eqk0NcmuRKZl',
    kicks       = 'https://discord.com/api/webhooks/1519638866091577465/rw2fTXVUetUcOpE4Gx17Uj8OxtqnjJT2kAO4m7XQF72oDoScAjiUBdI141eQkt00J-ax',
    flags       = 'https://discord.com/api/webhooks/1519638868092256356/qBX5jtABSKqF3BRAiK4twJ9t3dFNXGqOPI3n3JBUQGsAnksn03UJQ8HTB4df0M0RcTDM',
    events      = 'https://discord.com/api/webhooks/1519638871019884674/JMGHSltfS1DMOuHUNXjTCINq-24-1zXLT1Ja4-6cC-ncQNwK5OIyXqhoFreh8GvJyDDm',
    connections = 'https://discord.com/api/webhooks/1519638873490194482/Y2u7GmM9qU6AIrxImvKjVVjrylLKR4FjIivlgz5e5TsklAEqivrc_9k6aPQmW67lPDgo',
}

-- =========================================================================
--  Admin Immunity
-- =========================================================================
LACConfig.AdminAces = {
    'qbcore.god',
    'command',
}

LACConfig.AdminIdentifiers = {
    'license:1edd18060d34914e203e0036ff7ea5ae0a06ae7e',
    'steam:11000015634fc51',
}

-- =========================================================================
--  Action Thresholds (severity score)
-- =========================================================================
LACConfig.KickThreshold = 15
LACConfig.BanThreshold  = 25

-- =========================================================================
--  Heartbeat
-- =========================================================================
LACConfig.HeartbeatInterval   = 30000
LACConfig.HeartbeatTimeout    = 12000
LACConfig.MaxMissedHeartbeats = 3

-- =========================================================================
--  Weapon Damage
-- =========================================================================
LACConfig.MaxDamageEventsPerSecond = 25
LACConfig.MaxWeaponDamage          = 500.0

LACConfig.BlacklistedWeapons = {
    [0x42BF8A85] = true,  -- Minigun
    [0x6D544C99] = true,  -- Railgun
    [0xB62D1F67] = true,  -- Widowmaker
    [0x476BF155] = true,  -- Up-n-Atomizer
    [0xCDB56D62] = true,  -- Unholy Hellbringer
}

-- =========================================================================
--  Explosions
-- =========================================================================
LACConfig.MaxExplosionsPer5Sec = 5

LACConfig.BlacklistedExplosions = {
    [26] = true, -- TRAIN
}

-- =========================================================================
--  Entities
-- =========================================================================
LACConfig.MaxEntitiesPer2Sec = 15

-- =========================================================================
--  Movement
-- =========================================================================
LACConfig.PositionCheckInterval     = 2000
LACConfig.TeleportDistanceThreshold = 200.0
LACConfig.MaxOnFootSpeed            = 15.0

-- =========================================================================
--  Honeypot Events (instant ban — no legit client ever fires these)
-- =========================================================================
LACConfig.Honeypots = {
    'admin:giveWeapon',
    'admin:setHealth',
    'admin:giveMoney',
    'admin:setArmour',
    'qb-admin:server:giveitem',
    'qb-admin:server:setmoney',
    'server:addCash',
    'server:giveWeaponAll',
}

-- =========================================================================
--  Blacklisted Client Resources (known cheat menus)
-- =========================================================================
LACConfig.BlacklistedResources = {
    'menyoo', 'cheat', 'hack', 'mod_menu', 'lambda', 'kiddion',
    'lynx', 'eulen', 'skid', 'executor', 'injector', 'bypass',
    'redengine', 'brutan', 'hammafia', 'dopamine', 'impulse',
}
