Config = {
    -- Ships EMPTY, so the job is refused until coordinates are set
    -- (LAUNCH-TODO.md). A route is:
    -- { depot = vec4 (truck), dump = vec3 (general waste), recycle = vec3 (recycling centre),
    --   stops = { { label, coords = vec3, bins = { { id = 'a1', kind = 'general' | 'recycle', coords = vec3 }, ... } }, ... } }
    -- Bin ids are unique within a route.
    routes = {},

    business = 'sanitation',
    truckModel = 'trash',

    maxSize = 3,
    slots = 2,
    minutes = 40,
    graceMinutes = 15,

    -- A recycling bag put in the recycling compartment pays payPerBag plus
    -- recycleBonus. A bag in the wrong compartment counts as general waste.
    payPerBag = 12,
    recycleBonus = 10,

    -- The most the city budget may top Sanitation up by in 30 days.
    monthlyBudget = 150000,
    hourlyCap = 2000,
    abandonCooldown = 900,

    binDistance = 4.0,
    truckRange = 40.0,
    interactDistance = 10.0,
    dumpRadius = 25.0,
    shareDistance = 150.0,
    minBagSeconds = 4,
    callMs = 2500,
}
