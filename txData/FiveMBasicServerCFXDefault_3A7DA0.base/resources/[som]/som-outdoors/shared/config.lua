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
            { item = 'fishingloot', weight = 15 },
            { item = 'fishinglootbig', weight = 5 },
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
}
