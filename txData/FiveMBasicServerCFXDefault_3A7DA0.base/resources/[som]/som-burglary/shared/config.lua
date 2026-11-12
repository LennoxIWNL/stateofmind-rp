Config = {
    minutes = 40,
    interactDistance = 3.0,
    spotDistance = 1.8,
    exitDistance = 3.0,
    searchSeconds = 8,

    -- Houses are told apart by their routing bucket and by where their shell is
    -- spawned. Housing uses bucket 20000 and up and the void at y 1000.
    bucketBase = 40000,
    void = { origin = vec3(1000.0, 3000.0, -500.0), spacing = 150.0 },

    -- Staff measure the spots inside a shell with /burglarysurvey and /burglaryspot. The survey
    -- bucket is apart from the runs' (bucketBase + index), so staff never share a room with a crew.
    survey = { maxSpots = 12, maxLabel = 40, maxRadius = 60.0, bucketOffset = 500 },

    -- Night is the game hour from som-core's server clock. `from` to `to` may wrap midnight.
    -- Enabled is safe to ship: nothing starts until a house is placed.
    night = { enabled = true, from = 22, to = 5, hour = function() return exports['som-core']:getGameHour() end },

    -- Noise is counted by the server: a failed pick, each search, and running
    -- inside (server sampled speed in m/s). Every rise rolls once for a
    -- neighbour's call, until one has been made.
    noise = { fail = 25, search = 8, run = 3, runSpeed = 4.5, perPoint = 0.01, maxChance = 0.6 },

    tiers = {
        low = {
            label = 'House burglary', policeMin = 1, minSize = 1, maxSize = 3, slots = 1,
            tool = 'lockpick', breakChance = 0.3, hack = { kind = 'memory', level = 'easy' },
            cooldownMinutes = 120, failCooldownMinutes = 240,
            rolls = 1,
            loot = {
                { item = 'silver_ring', min = 1, max = 2, weight = 30 },
                { item = 'silverchain', min = 1, max = 1, weight = 25 },
                { item = 'gold_ring', min = 1, max = 1, weight = 15 },
                { item = 'tablet', min = 1, max = 1, weight = 20 },
                { item = 'laptop', min = 1, max = 1, weight = 10 },
            },
        },
        high = {
            label = 'High end burglary', policeMin = 2, minSize = 2, maxSize = 4, slots = 1,
            tool = 'advancedlockpick', breakChance = 0.2, hack = { kind = 'crack', level = 'normal' },
            cooldownMinutes = 240, failCooldownMinutes = 480,
            rolls = 2,
            loot = {
                { item = 'gold_ring', min = 1, max = 2, weight = 25 },
                { item = 'goldchain', min = 1, max = 1, weight = 25 },
                { item = 'diamond_ring', min = 1, max = 1, weight = 15 },
                { item = 'rolex', min = 1, max = 1, weight = 15 },
                { item = 'laptop', min = 1, max = 1, weight = 20 },
            },
        },
    },

    -- Where to stand inside each shell is not recorded anywhere (som-housing only
    -- knows the doorway), so spots ship empty. A spot is
    -- { offset = vec3 from the shell origin, label = 'Search the drawers' }.
    shells = {
        shell_frankaunt = { spots = {} },
        shell_michael = { spots = {} },
    },

    -- Every house ships disabled. Place the door with /place and fill the shell's
    -- spots above. A house with no spots cannot be picked.
    houses = {
        { id = 'house_1', tier = 'low', label = 'Suburban house', shell = 'shell_frankaunt', enabled = false, coords = vec3(179.29, -1923.98, 21.37) },
        { id = 'house_2', tier = 'high', label = 'Hillside villa', shell = 'shell_michael', enabled = false, coords = vec3(-174.65, 502.47, 137.42) },
    },
}
