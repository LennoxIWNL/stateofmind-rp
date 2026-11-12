Config = {
    -- What can be borrowed and for how long. The phone only ever offers these, and the server
    -- accepts nothing else.
    amounts = { 500, 1000, 2500, 5000, 10000 },
    weeks = { 4, 6, 8, 12 },

    -- A flat share of the amount, charged once. Not compound: nothing grows while it is owed.
    feeRate = 0.10,
    intervalDays = 7,

    -- Missed weeks (offline or short of money) before the loan is in default.
    defaultAfterMissed = 3,

    -- Loans never take the treasury below this, and the total still owed across everyone never goes
    -- above the cap. The treasury starts empty, so nothing is lent until it has filled.
    treasuryFloor = 50000,
    globalCap = 100000,

    -- How often instalments and collection run.
    sweepMinutes = 30,
}
