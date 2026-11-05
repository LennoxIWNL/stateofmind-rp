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
            weed_ogkush_seed = { label = 'OG Kush', bag = 'weed_ogkush', minLevel = 5 },
            weed_amnesia_seed = { label = 'Amnesia', bag = 'weed_amnesia', minLevel = 7 },
        },
        spots = {
            { name = 'grow_1', label = 'Grow spot 1', enabled = false, center = nil, radius = nil },
        },
        seedReturnChance = 0.25,  -- a harvest sometimes gives its own seed back
        bagTables = {
            { name = 'bag_1', label = 'Bagging table', enabled = false, coords = nil },
        },
    },

    -- Labs turn items into other items over time. Inputs are consumed at the
    -- start; outputs are collected by the same character once the time is up.
    -- Every lab ships disabled with no coordinates.
    labs = {
        { name = 'lab_1', label = 'Back room lab', enabled = false, coords = nil },
    },
    recipes = {
        cut_coke = { label = 'Cut and bag coke', enabled = true, minutes = 10,
            inputs = { coke_small_brick = 1 }, outputs = { cokebaggy = 4 } },
        press_brick = { label = 'Break down a brick', enabled = true, minutes = 15,
            inputs = { coke_brick = 1 }, outputs = { coke_small_brick = 3 } },
        refine_leaf = { label = 'Refine coca leaves', enabled = true, minutes = 20, minLevel = 2,
            inputs = { coke_leaf = 4, sulfuric_acid = 1 }, outputs = { coke_brick = 1 } },
        cook_meth = { label = 'Cook meth', enabled = true, minutes = 30, minLevel = 4,
            inputs = { ephedrine = 2, acetone = 1, lithium = 1, hydrochloric_acid = 1 }, outputs = { meth = 5 } },
    },
    lab = { distance = 3.0, maxActive = 1 },

    -- Precursors are bought, not found. The money goes to the treasury (a sink),
    -- so nothing is minted. The supplier ships disabled with no coordinates.
    supplier = {
        enabled = false, label = 'Chemical supplier', coords = nil, distance = 3.0, maxQty = 5,
        stock = {
            coke_leaf = 40, acetone = 120, lithium = 90, ephedrine = 150,
            hydrochloric_acid = 140, sulfuric_acid = 110,
            weed_whitewidow_seed = 60, weed_skunk_seed = 60, weed_purplehaze_seed = 80,
            weed_ogkush_seed = 200, weed_amnesia_seed = 300,
        },
    },
}
