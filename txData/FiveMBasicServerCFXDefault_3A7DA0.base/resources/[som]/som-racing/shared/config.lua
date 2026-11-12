Config = {
    -- Ships closed. Tracks are recorded in game by whoever holds the dongle, so there is nothing to place.
    enabled = false,

    item = 'racing_dongle',     -- held, never consumed; staff give it out
    account = 'cash',           -- buy-ins and winnings

    alias = { min = 3, max = 16 },
    stake = { min = 0, max = 25000 },
    maxLaps = 10,
    maxRacers = 8,
    maxOpenRaces = 5,
    joinSeconds = 120,          -- how long a race stays open for joining
    startRadius = 60.0,         -- a racer must be this close to the start line to join and to start
    countdownSeconds = 5,
    graceSeconds = 90,          -- after the first finisher the rest have this long
    maxRaceSeconds = 1200,

    -- Share of the pot by finishing order, keyed by how many finished (more finishers than the
    -- last row use the last row; finishers past its length get nothing). Each row sums to 100.
    split = { { 100 }, { 70, 30 }, { 55, 30, 15 }, { 50, 30, 15, 5 } },

    checkpoint = {
        radius = 12.0,          -- the ring drawn for the racer
        slack = 10.0,           -- extra distance the server accepts for lag
        maxSpeed = 90.0,        -- metres a second; passing faster than this between rings is refused
        minGapMs = 500,         -- events closer together than this are dropped
        maxBad = 5,             -- refused reports before the racer is out
    },

    track = {
        minPoints = 6, maxPoints = 40,
        minGap = 40.0, maxGap = 800.0,      -- between neighbouring points, last point back to the first included
        minLength = 800.0,
        maxPerPerson = 5,
        nameMin = 4, nameMax = 32,
        recordSeconds = 600,
    },

    dispatch = { chance = 0.25 },           -- one roll per race, when it starts
    boardRows = 10,
}
