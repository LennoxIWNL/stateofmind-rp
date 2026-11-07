Config = {
    minutes = 40,               -- a contract fails this long after it starts
    interactDistance = 4.0,     -- crew to the car for the unlock
    deliverDistance = 8.0,      -- car to the drop-off centre
    shareDistance = 60.0,       -- a crew member this close to the drop-off shares the pay
    searchRadius = 150.0,       -- the blip circle shown to the crew; the car is somewhere inside it
    unlockSeconds = 12,         -- minimum time the unlock takes
    deliverAfterSeconds = 45,   -- minimum time between the unlock and a delivery

    -- Pay is marked bills only: som-launder mints them against its own ledger
    -- and they become spendable only by washing at a front. Nothing here draws
    -- on the treasury. `face` (count * worth) is reserved against the hourly cap
    -- when the contract starts, so a bad hour of contracts cannot flood the wash.
    -- Class A ships off until it has been tuned.
    classes = {
        C = {
            label = 'Class C contract', enabled = true, policeMin = 1, minSize = 1, maxSize = 2, slots = 1,
            models = { 'blista', 'asea', 'premier' }, bills = { count = 4, worth = 250 }, hourlyCap = 6000,
        },
        B = {
            label = 'Class B contract', enabled = true, policeMin = 2, minSize = 1, maxSize = 3, slots = 1,
            models = { 'sultan', 'jackal', 'fugitive' }, bills = { count = 6, worth = 400 }, hourlyCap = 9600,
        },
        A = {
            label = 'Class A contract', enabled = false, policeMin = 3, minSize = 2, maxSize = 3, slots = 1,
            models = { 'comet2', 'feltzer2' }, bills = { count = 8, worth = 750 }, hourlyCap = 12000,
        },
    },

    -- EVERY place ships disabled. Stand there and use `/place som-boosting pickups.<id>.coords`
    -- (LAUNCH-TODO.md). A pickup is where a car appears, a dropoff is where it is handed over.
    pickups = {
        { id = 'pickup_1', label = 'Pickup 1', enabled = false, coords = nil, heading = 0.0, cooldownMinutes = 30 },
        { id = 'pickup_2', label = 'Pickup 2', enabled = false, coords = nil, heading = 0.0, cooldownMinutes = 30 },
    },
    dropoffs = {
        { id = 'dropoff_1', label = 'Drop-off 1', enabled = false, coords = nil },
    },
}
