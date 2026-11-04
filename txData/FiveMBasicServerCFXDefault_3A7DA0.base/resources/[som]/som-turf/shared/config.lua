Config = {
    claimGrade = 1,        -- lowest gang grade that may tag a wall
    tagSeconds = 20,
    tagDistance = 4.0,
    holdMinutes = 30,      -- a rival must wait this long after contesting, then tag again to take it
    ownerBonus = 0.10,     -- price bonus for selling in your own turf
    sellCooldown = 15,     -- seconds between sales for one character
    policeMin = 0,

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
}
