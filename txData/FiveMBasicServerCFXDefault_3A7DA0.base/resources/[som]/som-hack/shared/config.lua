--- som-hack configuration. Data only.

Config = {}

-- A challenge that has not been answered by now is gone, and so is its token.
Config.ExpireMs = 120000

-- Memory: numbers are shown on some cells for `showMs`, hidden, and the player
-- picks the cells back in ascending number order.
Config.Memory = {
    easy   = { size = 3, count = 4, showMs = 3500 },
    normal = { size = 4, count = 6, showMs = 3000 },
    hard   = { size = 5, count = 8, showMs = 2500 },
    -- Floor on how fast a human can pick one cell. The whole answer cannot
    -- arrive sooner than showMs plus this many ms per pick.
    minClickMs = 250,
}

-- Crack: the server holds a digit code; each guess comes back as hit (right
-- digit, right place), near (right digit, wrong place) or miss.
Config.Crack = {
    easy   = { length = 4, attempts = 8 },
    normal = { length = 5, attempts = 7 },
    hard   = { length = 6, attempts = 6 },
    guessGapMs = 400,
}
