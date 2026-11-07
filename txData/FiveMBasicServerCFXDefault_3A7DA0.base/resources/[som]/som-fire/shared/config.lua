Config = {
    job = 'firefighter',
    business = 'ems',               -- the firefighters are paid from the medical services account
    tool = 'WEAPON_FIREEXTINGUISHER',
    trucks = { 'firetruk' },        -- spraying from the seat of one of these also counts

    maxIncidents = 3,
    maxPoints = 6,                  -- flames per incident
    lifetime = 720,                 -- seconds before an unfought fire burns out (nobody is paid)
    spreadSeconds = 30,             -- a growing fire may add a flame this often
    spreadRadius = { min = 2.0, max = 4.0 },

    pointHp = 100,
    sprayDamage = 10,               -- per accepted spray tick
    sprayMinMs = 900,               -- the client sends one tick a second
    sprayDistance = 8.0,

    rescue = { seconds = 5, staleSeconds = 60, distance = 3.0, fireRadius = 8.0, clear = 12.0 },

    pay = {
        perPoint = 40,              -- split between the firefighters who sprayed the flame
        minTicks = 3,
        hourlyCap = 1500,           -- per character
        drawCapHourly = 4000,       -- most the treasury tops the account up in an hour
    },

    -- Fires nobody starts by hand. Off until locations are placed.
    ambient = { enabled = false, minutes = 30, chance = 0.5, locations = {} },
}
