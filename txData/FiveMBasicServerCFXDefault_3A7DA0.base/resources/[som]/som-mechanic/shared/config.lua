Config = {
    job = 'mechanic',
    business = 'lscustoms',
    distance = 6.0,         -- mechanic to vehicle
    cooldownSeconds = 30,   -- per vehicle, so one car is not farmed

    -- Each repair needs the part in the mechanic's pockets, damage to fix, and
    -- bills the driver (if a player is driving) this price for the shop.
    -- `below` is the health under which a repair is allowed; `to` is what the
    -- vehicle is set to.
    repairs = {
        engine = { label = 'Repair the engine', item = 'repairkit', count = 1, price = 250, below = 900.0, to = 1000.0, seconds = 12 },
        body = { label = 'Repair the body', minLevel = 2, item = 'steel', count = 2, price = 180, below = 900.0, to = 1000.0, seconds = 10 },
    },

    -- Mechanics sell their kits to other players. The price is theirs to set
    -- inside these limits; the sale goes to the shop's business account and the
    -- mechanic keeps the job's `commission` share of it.
    trade = {
        distance = 5.0,
        expireSeconds = 120,
        items = {
            repairkit = { min = 120, max = 450 },
            tirerepairkit = { min = 80, max = 300 },
            advancedrepairkit = { min = 400, max = 1200 },
            advancedlockpick = { min = 250, max = 900 },
        },
    },

    -- When no mechanic is on duty a roadside desk sells one basic repair kit per
    -- player per hour at a worse price, paid to the treasury. It never opens
    -- while a mechanic is on duty, so mechanics keep the trade. Ships disabled.
    fallback = {
        enabled = false, label = 'Roadside assistance', coords = vec3(-337.20, -136.30, 39.00), distance = 3.0,
        item = 'repairkit', price = 700, perHour = 1,
    },
}
