Config = {
    claimGrade = 1,        -- lowest gang grade that may tag a wall
    tagSeconds = 20,
    tagDistance = 4.0,
    holdMinutes = 30,      -- a rival must wait this long after contesting, then tag again to take it
    ownerBonus = 0.10,     -- price bonus for selling in your own turf
    sellCooldown = 15,     -- seconds between sales for one character
    policeMin = 0,

    -- Members of a gang that holds at least one zone are paid by the hour from
    -- the gang account, never minted. An empty account pays nobody.
    payrollMinutes = 60,
    payrollCap = 5000,

    gang = {
        maxMembers = 30,
        inviteDistance = 10.0,
        inviteSeconds = 120,
        depositMax = 50000,
    },

    -- Street prices. `base` is the price of the first unit after the market has
    -- recovered; each unit sold in the last hours lowers it by `dropPerUnit`
    -- until `floor`. Sales are paid in marked bills (som-launder), never cash.
    market = { dropPerUnit = 0.02, floor = 0.4, recoverPerHour = 10 },
    drugs = {
        joint = { label = 'Joint', base = 40 },
        weed_whitewidow = { label = 'White Widow', base = 90 },
        weed_skunk = { label = 'Skunk', base = 90 },
        weed_purplehaze = { label = 'Purple Haze', base = 95 },
        weed_ogkush = { label = 'OG Kush', base = 100 },
        weed_amnesia = { label = 'Amnesia', base = 100 },
        cokebaggy = { label = 'Baggy of coke', base = 220 },
        meth = { label = 'Meth', base = 180 },
    },

    -- EVERY zone ships disabled. A zone is usable only when enabled is true and
    -- it has a centre, a radius and a tag point (LAUNCH-TODO.md).
    zones = {
        { name = 'grove', label = 'Grove Street', enabled = false, center = nil, radius = nil, tag = nil },
        { name = 'vespucci_canals', label = 'Vespucci Canals', enabled = false, center = nil, radius = nil, tag = nil },
        { name = 'davis', label = 'Davis', enabled = false, center = nil, radius = nil, tag = nil },
    },

    -- Growing. Plants live in the database and their stage is worked out from
    -- timestamps. A plant can be placed inside a grow spot, or inside a zone
    -- the planter's gang holds. Spots and bag tables ship disabled.
    grow = {
        maxPlants = 6,
        growMinutes = 60,       -- from planting to ready
        witherMinutes = 120,    -- without water for this long, a plant dies
        yield = { min = 3, max = 6, fedBonus = 2 },
        budsPerBag = 3,
        waterItem = 'water_bottle',
        feedItem = 'weed_nutrition',
        budItem = 'weedbud',
        bagItem = 'empty_weed_bag',
        tendDistance = 3.0,
        showDistance = 80.0,
        strains = {
            weed_whitewidow_seed = { label = 'White Widow', bag = 'weed_whitewidow' },
            weed_skunk_seed = { label = 'Skunk', bag = 'weed_skunk' },
            weed_purplehaze_seed = { label = 'Purple Haze', bag = 'weed_purplehaze' },
            weed_ogkush_seed = { label = 'OG Kush', bag = 'weed_ogkush' },
            weed_amnesia_seed = { label = 'Amnesia', bag = 'weed_amnesia' },
        },
        spots = {
            { name = 'grow_1', label = 'Grow spot 1', enabled = false, center = nil, radius = nil },
        },
        bagTables = {
            { name = 'bag_1', label = 'Bagging table', enabled = false, coords = nil },
        },
    },
}
