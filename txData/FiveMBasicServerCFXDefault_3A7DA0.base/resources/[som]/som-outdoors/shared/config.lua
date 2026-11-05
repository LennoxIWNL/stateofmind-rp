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
            a_c_boar = { drops = { { 'venison', 1, 2, 1.0 } } },
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
}
