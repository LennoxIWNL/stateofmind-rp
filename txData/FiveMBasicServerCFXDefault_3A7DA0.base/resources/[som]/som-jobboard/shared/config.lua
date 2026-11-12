Config = {
    drawSeconds = 20,
    offerSeconds = 180,

    -- Waiting makes a group likelier to be drawn, but never certain: weight is
    -- 1 plus one point per this many minutes waited, capped at maxWeight.
    minutesPerPoint = 10,
    maxWeight = 4,

    -- Declining (or ignoring) this many offers locks the group out for a while,
    -- so nobody can fish for a better job by refusing.
    declinesBeforeLock = 2,
    lockSeconds = 900,
}
