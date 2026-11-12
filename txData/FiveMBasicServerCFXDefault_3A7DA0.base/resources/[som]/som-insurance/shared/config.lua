Config = {
    -- The insurer's own business account (seeded on start). Premiums and excess fees go in, replacement
    -- costs go out to the treasury. It can never pay more than it holds.
    business = 'insurer',
    label = 'San Andreas Insurance',

    -- A policy period, and how long before it ends renewal is tried.
    periodDays = 7,
    renewAheadHours = 12,

    -- Prices are shares of the vehicle's recorded purchase_price: flat, no risk score.
    premiumRate = 0.01,
    minPremium = 25,
    excessRate = 0.10,
    minExcess = 250,
    replacementShare = 0.8,
    -- Below this recorded value a vehicle cannot be insured, so a car with no real price cannot be
    -- restored for pennies.
    minValue = 1000,

    -- Cover starts this long after it is bought, and only covers a car taken out after it started.
    waitingDays = 2,
    -- A car must have been out of the garage this long (from the database timestamp) before a claim.
    minOutMinutes = 15,
    claimsPerVehicle = 1,
    claimsPerOwner = 2,
    claimWindowDays = 30,

    -- true: any vehicle in the world with the plate blocks a claim, wrecks included. false: a wreck
    -- (engine health zero or less) counts as gone.
    wreckBlocksClaim = true,

    -- Staff /insurerfund, most per use.
    fundMax = 100000,
    sweepMinutes = 30,
}
