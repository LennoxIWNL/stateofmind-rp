Config = {
    -- Ships EMPTY, so the provider refuses every group until coordinates are
    -- set (LAUNCH-TODO.md). A route is { label, pickup = vec3, drops = { vec3, ... } }.
    routes = {},

    business = 'postop',
    dropsPerRun = 3,
    payPerDrop = 120,
    minutes = 25,

    maxSize = 4,
    slots = 2,

    -- How close the server insists the player is, and how close a teammate must
    -- be to share a drop's pay (so an absent member is not paid).
    interactDistance = 8.0,
    shareDistance = 150.0,
}
