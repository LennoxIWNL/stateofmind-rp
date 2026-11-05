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
        body = { label = 'Repair the body', item = 'steel', count = 2, price = 180, below = 900.0, to = 1000.0, seconds = 10 },
    },
}
