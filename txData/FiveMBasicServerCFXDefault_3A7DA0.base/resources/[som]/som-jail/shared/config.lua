--- Bolingbroke Penitentiary coordinates (qb-prison's shipped defaults). Vanilla
--- world geometry, always loaded, so there is nothing to stream or isolate.

Config = {}

Config.Job = 'police' -- who may book someone
Config.BookCooldown = 5 -- seconds between bookings by one officer
Config.Business = 'lspd' -- receives bail, as a fine is paid to the department

Config.Cell = {
    freedom = vec4(1740.88, 2476.57, 44.85, 299.49), -- release point
    outside = vec4(1848.13, 2586.05, 44.67, 269.5),  -- prison gate
    yard    = vec3(1765.67, 2565.91, 44.56),

    -- Booking picks one of these at random, same as qb-prison does.
    spawns = {
        vec4(1661.05, 2524.68, 45.56, 260.55),
        vec4(1650.81, 2540.58, 45.56, 230.44),
        vec4(1654.96, 2545.54, 45.56, 230.44),
        vec4(1697.11, 2525.56, 45.56, 187.21),
        vec4(1673.08, 2519.82, 45.56, 229.54),
        vec4(1666.03, 2511.37, 45.56, 233.89),
        vec4(1691.23, 2509.64, 45.56, 52.43),
    },

    -- Leaving this radius of `yard` while status = 'serving' flags the
    -- sentence absconded. Not a hard lock (fighting the engine is out of
    -- scope); a real consequence instead of one.
    yardRadius = 120.0,

    -- Held in a per-citizen stash while serving and handed back on release.
    keepItems = { phone = true, id_card = true, driver_license = true, identification = true },
    stashSlots = 100,
    stashWeight = 1000000,

    maxMonths = 24,
    -- Tunable game/real-time compression, so "a month" has a concrete,
    -- known real-world length rather than being whatever the sweep
    -- interval happens to make it.
    secondsPerMonth = 90,
}

Config.Bail = {
    rateMultiplier = 50, -- $ per second of time remaining, for a convicted felon
    minAmount = 2500,
    appealHours = 72,
}

Config.Jail = {
    -- A booking with no court case is for minor matters only. Anything longer
    -- needs a conviction in som-court.
    directMaxMonths = 3,
    -- Custody before trial. It ends on its own, so a court that never hears
    -- the case cannot hold someone indefinitely.
    remandHours = 2,
}

-- Community service. Every coordinate here is UNVERIFIED (taken from a script
-- written for another map layout); walk the area and correct it. /pdcoords
-- prints a position formatted for a config file.
Config.Service = {
    maxTasks = 60,
    officerMaxTasks = 10,    -- what an officer may hand out without a court case
    zone = { center = vec3(170.43, -990.70, 30.09), radius = 70.0 },
    spawn = vec4(170.43, -990.70, 30.09, 0.0),
    release = vec4(427.33, -979.51, 30.20, 90.0),

    range = 3.0,             -- how close to a spot a task may be started and finished
    minGap = 6,              -- seconds between two counted tasks
    tolerance = 1500,        -- ms a task may finish early (latency)
    escapePenalty = 3,       -- tasks added when the worker is found outside the zone
    penaltyGap = 60,         -- seconds between two penalties
    maxStrikes = 4,          -- penalties before the worker counts as absconded

    kinds = {
        clean  = { label = 'Sweeping', duration = 9000,  scenario = 'WORLD_HUMAN_JANITOR' },
        garden = { label = 'Planting', duration = 12000, scenario = 'WORLD_HUMAN_GARDENER_PLANT' },
    },

    spots = {
        { id = 1, kind = 'clean',  coords = vec3(176.2, -993.5, 29.3) },
        { id = 2, kind = 'clean',  coords = vec3(163.9, -988.4, 29.5) },
        { id = 3, kind = 'clean',  coords = vec3(170.8, -1001.2, 29.3) },
        { id = 4, kind = 'garden', coords = vec3(182.4, -985.6, 29.9) },
        { id = 5, kind = 'garden', coords = vec3(158.1, -996.9, 29.4) },
        { id = 6, kind = 'garden', coords = vec3(172.5, -977.3, 30.1) },
    },
}

-- The dispatch alert raised when an inmate leaves the yard. A key of
-- som-dispatch's own Config.Alerts, added there alongside this resource
-- since dispatch is reused rather than a second alert system invented here.
Config.AbscondAlert = 'inmateEscaped'
