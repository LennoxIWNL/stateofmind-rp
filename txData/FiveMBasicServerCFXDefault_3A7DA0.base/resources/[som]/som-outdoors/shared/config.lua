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
}
