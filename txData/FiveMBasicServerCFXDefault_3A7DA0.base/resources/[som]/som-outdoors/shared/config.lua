Config = {
    -- Buyers pay clean cash out of the treasury and are capped per rolling hour
    -- for the whole server, so a fishing fleet cannot drain the city. The
    -- treasury starts empty (LAUNCH-TODO.md): until it holds money, buyers
    -- pay nothing.
    buyers = {
        fish = {
            label = 'Fish buyer', enabled = false, coords = nil, distance = 3.0, hourlyCap = 6000,
            prices = { codfish = 40, bass = 55, fishingloot = 90, fishinglootbig = 180 },
        },
        scrap = {
            label = 'Scrap yard', enabled = false, coords = nil, distance = 3.0, hourlyCap = 6000,
            prices = { scrapmetal = 8, steel = 20, aluminum = 22, plastic = 10, rubber = 12, copper = 30, glass = 12 },
        },
        quarry = {
            label = 'Quarry buyer', enabled = false, coords = nil, distance = 3.0, hourlyCap = 6000,
            prices = { copper = 30, iron = 24, silveringot = 70, goldingot = 120 },
        },
        -- Stolen goods. `market = true`: the price is som-economy's market quote
        -- (so it saturates), the amounts in `prices` are unused.
        fence = {
            label = 'Fence', enabled = false, coords = nil, distance = 3.0, hourlyCap = 3000, market = true,
            prices = { goldchain = true, silverchain = true, gold_ring = true, silver_ring = true, diamond_ring = true, rolex = true, laptop = true, tablet = true },
        },
        hunt = {
            label = 'Game buyer', enabled = false, coords = nil, distance = 3.0, hourlyCap = 6000,
            prices = { venison = 60, deer_pelt = 120, antlers = 150 },
        },
    },

    fishing = {
        rod = 'fishingrod',
        bait = 'fishbait',
        distance = 25.0,
        minWait = 8, maxWait = 20,   -- seconds the fish takes to bite
        maxWaitGrace = 30,           -- how long after the bite the reel is still accepted
        catches = {
            { item = 'codfish', weight = 50 },
            { item = 'bass', weight = 30 },
            { item = 'fishingloot', weight = 15, rare = true },
            { item = 'fishinglootbig', weight = 5, rare = true },
        },
        -- EVERY spot ships disabled. A spot is a water area to cast into.
        spots = {
            { name = 'pier_1', label = 'Pier', enabled = false, center = nil, radius = nil },
            { name = 'deep_1', label = 'Deep water', enabled = false, center = nil, radius = nil, minLevel = 4 },
        },
    },

    hunting = {
        knife = 'hunting_knife',
        requireLicense = false,   -- needs a hunting_license item when true; nothing issues it yet
        license = 'hunting_license',
        distance = 3.0,
        cooldown = 10,            -- seconds between skinnings for one character
        -- Models are plain names hashed on the server. `drops` are { item, min, max, chance }.
        animals = {
            a_c_deer = { drops = { { 'venison', 2, 3, 1.0 }, { 'deer_pelt', 1, 1, 1.0 }, { 'antlers', 1, 1, 0.25 } } },
            a_c_boar = { minLevel = 3, drops = { { 'venison', 1, 2, 1.0 } } },
        },
    },

    -- Chopping strips an ambient vehicle for parts. A plate that belongs to a
    -- player (som_vehicles) is refused, so nobody loses a car they own.
    chop = {
        distance = 8.0,          -- vehicle to the drop-off centre
        scrubSeconds = 25,       -- minimum time between starting and finishing
        dropoffCooldown = 10,    -- minutes before the same drop-off can be used again
        plateCooldown = 1440,    -- minutes before the same plate can be chopped again
        parts = {
            { 'scrapmetal', 4, 8 }, { 'steel', 2, 4 }, { 'aluminum', 1, 3 }, { 'plastic', 2, 4 },
            { 'rubber', 2, 4 }, { 'copper', 1, 2 }, { 'glass', 1, 3 },
        },
        dropoffs = {
            { name = 'chop_1', label = 'Chop shop', enabled = false, coords = nil },
        },
    },
    -- Mining: strike a vein with a pickaxe, smelt the ore, sell the metal to the
    -- quarry buyer. A site is one ore with a list of node positions placed with
    -- /place and has none until placed; the smelter and the buyer ship disabled.
    mining = {
        tool = 'pickaxe',
        seconds = 8,            -- minimum swing time, enforced on the server
        staleSeconds = 60,
        distance = 3.0,
        cooldown = 600,         -- seconds a struck vein rests, for everybody
        hourlyStrikes = 40,     -- per character
        assistRadius = 6.0,     -- a friend this close, also carrying a pickaxe, adds one ore
        assistMax = 2,
        sites = {
            { name = 'copper_1', label = 'Copper vein', ore = 'copperore', min = 1, max = 3, nodes = {} },
            { name = 'iron_1', label = 'Iron vein', ore = 'ironore', min = 1, max = 3, nodes = {} },
            { name = 'silver_1', label = 'Silver vein', ore = 'silverore', min = 1, max = 3, nodes = {} },
            { name = 'gold_1', label = 'Gold vein', ore = 'goldore', min = 1, max = 3, nodes = {} },
        },
        smelter = {
            enabled = false, coords = nil, distance = 3.0, seconds = 10,
            recipes = {
                copper = { label = 'Smelt copper', input = { copperore = 3 }, output = { 'copper', 2 } },
                iron = { label = 'Smelt iron', input = { ironore = 3 }, output = { 'iron', 2 } },
                silver = { label = 'Cast a silver ingot', input = { silverore = 4 }, output = { 'silveringot', 1 } },
                gold = { label = 'Cast a gold ingot', input = { goldore = 4 }, output = { 'goldingot', 1 } },
            },
        },
    },
}
