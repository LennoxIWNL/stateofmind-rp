--- Bolingbroke Penitentiary coordinates (qb-prison's shipped defaults). Vanilla
--- world geometry, always loaded, so there is nothing to stream or isolate.

Config = {}

Config.Job = 'police' -- who may book someone
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

    maxMonths = 24,
    -- Tunable game/real-time compression, so "a month" has a concrete,
    -- known real-world length rather than being whatever the sweep
    -- interval happens to make it.
    secondsPerMonth = 90,
}

Config.Bail = {
    -- Bail-eligible at/above this sentence length. A stand-in for
    -- NoPixel's documented "felony-only" rule: ps-mdt's own charge
    -- classification (Config.PenalCode) isn't exported and isn't
    -- something this resource reaches into (see AUDIT.md's roadmap,
    -- Phase 2's second scope decision). Sentence length is already a
    -- value this resource owns outright and is a reasonable proxy.
    felonyThresholdMonths = 12,

    rateMultiplier = 50, -- $ per second of time remaining
    minAmount = 2500,
    appealHours = 72,    -- NoPixel's own documented window
}

-- The dispatch alert raised when an inmate leaves the yard. A key of
-- som-dispatch's own Config.Alerts, added there alongside this resource
-- since dispatch is reused rather than a second alert system invented here.
Config.AbscondAlert = 'inmateEscaped'
