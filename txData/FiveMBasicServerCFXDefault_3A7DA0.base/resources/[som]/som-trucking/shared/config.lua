Config = {
    -- Ships EMPTY, so no contract is offered until coordinates are set
    -- (LAUNCH-TODO.md). One job board entry per route:
    -- { id = 'sand', label = 'Sand to the quarry', depot = vec4 (truck),
    --   trailer = vec4 (trailer), dropoff = vec3, base = 900, minutes = 35 }
    routes = {},

    business = 'postop',
    truckModel = 'phantom',
    trailerModel = 'trailers',

    maxSize = 2,
    slots = 1,
    graceMinutes = 15,

    -- Pay is base times (1 - trailer damage) times the late factor, never
    -- below floor. Penalties shrink the pay and never bill the player.
    maxDamage = 0.5,
    latePenalty = 0.25,
    floor = 0.25,
    groupBonus = 0.2,

    -- A drop cannot be paid sooner than the straight line depot to drop at
    -- maxSpeed (m/s), and a route shorter than minDistance is not offered.
    minDistance = 1500.0,
    maxSpeed = 40.0,

    hourlyCap = 2500,
    abandonCooldown = 900,

    interactDistance = 10.0,
    dropRadius = 25.0,
    shareDistance = 150.0,
    callMs = 2000,
}
