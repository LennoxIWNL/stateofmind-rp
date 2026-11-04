--- som-launder configuration. Data only: every value is re-checked server side,
--- so editing this changes what is offered, never what is allowed.

Config = {}

Config.Item = 'markedbills'

-- What the server will mint for a bill, and how many it will mint in one call.
Config.Mint = { maxWorth = 5000, maxBills = 40 }

-- The cut is value that is simply never created: a wash of 1000 face pays at
-- most 700. Every other number here throttles how fast marked bills can become
-- spendable, because laundering is where this money enters the economy.
Config.Wash = {
    cut = 0.30,
    delayMinutes = 15,       -- an order is ready this long after it is placed
    maxBills = 10,           -- bills in one order
    dailyCap = 20000,        -- face value one citizen may wash in 24 hours
    hourlyBudget = 40000,    -- face value all fronts together take in an hour
    priceFloor = 0.5,        -- the payout factor once the hourly budget is nearly used
}

-- Fronts ship disabled. A front is only usable once `set` is true, which means
-- someone has walked to it, corrected the coordinates and enabled it. See
-- LAUNCH-TODO.md.
Config.Fronts = {
    laundromat = {
        label = 'Laundromat',
        enabled = false,
        set = false,
        -- UNVERIFIED placeholder. /pdcoords prints a position formatted for this file.
        coords = vec3(0.0, 0.0, 0.0),
        range = 2.5,
    },
}
