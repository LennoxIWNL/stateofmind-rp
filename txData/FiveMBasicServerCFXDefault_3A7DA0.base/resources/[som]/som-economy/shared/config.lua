Config = {}

-- ---------------------------------------------------------------------------
-- ECONOMY SCALE
--
-- Anchored to the owner's targets. No public figures exist for NoPixel,
-- Prodigy or Echo to copy, so these are derived from the anchors rather than
-- borrowed:
--
--   cheapest vehicle, a work van      2,000
--   high-end car                    200,000
--   market ceiling for a car        350,000
--   cheapest house                  200,000
--
-- That is a deliberately wide spread. Something drivable is reachable in under
-- an hour, so a new player is never stuck on foot, while the top of the market
-- stays a genuine long-term goal.
--
-- Wages work backwards from it, per 10 minute paycheck:
--
--   entry            ~400     ~2.4k/hour   a van inside an hour
--   experienced      ~900     ~5.4k/hour
--   owner or boss   ~1,500    ~9k/hour
--
-- A 200k car or house is therefore roughly 80 hours at entry level, or under
-- 30 for someone established. Grindy, but not mind-numbing, and reachable
-- without needing to commit crime.
--
-- CRIME IS DELIBERATELY NOT A JACKPOT. Illegal work pays roughly 1.5 to 2x
-- legal per hour before losses, and carries seizure, heat and downtime. It
-- should be the interesting choice, not the obvious one: an economy where
-- crime pays ten times better turns every player into a criminal and empties
-- the legal side of the server.
--
-- EVERY NUMBER HERE IS TUNABLE and should be revisited once there is real
-- player behaviour to look at. Nothing reads a hardcoded value elsewhere.
-- ---------------------------------------------------------------------------

Config.Scale = {
    -- Reference points, for sanity checking new prices against each other.
    cheapestVehicle = 2000,
    highEndVehicle  = 200000,
    vehicleCeiling  = 350000,
    cheapHouse      = 200000,
    entryWage       = 400,     -- per paycheck interval
}

-- ---------------------------------------------------------------------------
-- Sinks and faucets
--
-- Target ratio is sinks divided by faucets over a rolling window. Below 1.0
-- the money supply grows, above 1.0 it shrinks. 0.85 means wealth accumulates
-- slowly, which suits a server where a house is a long-term goal.
--
-- som-economy only measures this. It does not auto-correct: an economy that
-- silently retunes itself is impossible to reason about.
-- ---------------------------------------------------------------------------

Config.Balance = {
    targetSinkFaucetRatio = 0.85,
    reportIntervalMinutes = 60,
    warnDeviation = 0.25,     -- log when the ratio drifts this far from target
}

-- ---------------------------------------------------------------------------
-- Tax
--
-- Collected from business revenue into the treasury, never from a player's
-- balance directly: income tax on wages feels punitive and is invisible.
--
-- The mayor system on the roadmap will make these adjustable in game, with a
-- hard floor above zero so tax can never be abolished.
-- ---------------------------------------------------------------------------

Config.Tax = {
    default = 0.08,
    minimum = 0.02,           -- a mayor may never set tax below this
    maximum = 0.35,
}

-- ---------------------------------------------------------------------------
-- Market
--
-- Selling drops the price, time restores it. Saturation is per unit, so
-- dumping 100 units at 0.3% costs roughly 26% of the price, and recovery is a
-- fraction of the gap back to base per hour, so a flooded market takes hours
-- rather than minutes to be worth working again.
-- ---------------------------------------------------------------------------

Config.Market = {
    tickMinutes = 5,          -- how often recovery is applied
    defaultSaturation = 0.003,
    defaultRecovery = 0.05,

    -- Floor and ceiling as fractions of base price, so no item can crash to
    -- nothing or spike to an exploitable high.
    floorRatio = 0.35,
    ceilingRatio = 1.40,
}

-- Starting catalogue. Illegal goods saturate faster and recover slower: they
-- reward finding a fresh market rather than grinding one flat.
--
-- Sanity check against the wage scale: a risky run of 50 weed bags nets a bit
-- over 4k after saturation, against ~2.4k for an hour of honest work. Better,
-- but not life-changing, and that is the intent. Nothing here should let a
-- player buy a 200k car in an evening.
Config.MarketItems = {
    -- item              label                  category    base   saturation  recovery
    { 'weed_bag',        'Bag of Weed',         'drugs',      90,   0.0045,     0.040 },
    { 'cocaine_bag',     'Bag of Cocaine',      'drugs',     220,   0.0060,     0.035 },
    { 'meth_bag',        'Bag of Meth',         'drugs',     180,   0.0055,     0.035 },
    { 'oxy_bottle',      'Oxy Bottle',          'drugs',      70,   0.0040,     0.045 },

    { 'gold_chain',      'Gold Chain',          'stolen',    180,   0.0050,     0.040 },
    { 'rolex',           'Rolex',               'stolen',    400,   0.0060,     0.035 },
    { 'stolen_parts',    'Stolen Parts',        'stolen',    120,   0.0045,     0.045 },

    { 'scrap_metal',     'Scrap Metal',         'legal',      12,   0.0015,     0.080 },
    { 'copper',          'Copper',              'legal',      18,   0.0015,     0.080 },
    { 'fish',            'Fish',                'legal',      25,   0.0020,     0.070 },
    { 'crate_delivery',  'Delivered Crate',     'legal',      40,   0.0010,     0.090 },
}

-- ---------------------------------------------------------------------------
-- Fines
--
-- The officer receives NOTHING. The whole amount goes to the department, minus
-- the treasury's share. Paying officers per ticket would reward writing as
-- many as possible; the point of routing it to the department is that the
-- incentive is to fund the department, not to shake people down.
-- ---------------------------------------------------------------------------

Config.Fines = {
    officerShare = 0.0,       -- MUST stay zero. See above.
    treasuryShare = 0.30,
    departmentShare = 0.70,

    minimum = 50,
    maximum = 25000,

    -- Unpaid fines are pursued rather than forgiven, but that is a Phase 5
    -- concern: warrants, impounds and licence suspension hang off this.
    lateAfterHours = 72,
}

-- ---------------------------------------------------------------------------
-- Departments
--
-- Only LSPD is active. BCSO and SASP exist so they can be enabled by flipping
-- `active` in som_businesses when the population justifies them, rather than
-- needing a migration and a code change later.
-- ---------------------------------------------------------------------------

-- The three police departments are FUNCTIONALLY IDENTICAL by design. They
-- differ only in identity: name, blip colour, livery. Anything that behaves
-- differently between them is a bug, not a feature, because it would mean
-- writing the police script three times.
--
-- blip is a GTA blip colour index, used by Phase 5.
Config.Departments = {
    lspd = {
        label = 'Los Santos Police Department',
        short = 'LSPD',
        job = 'police',
        active = true,
        blip = 38,          -- blue
        canFine = true,
    },
    bcso = {
        label = 'Blaine County Sheriff Office',
        short = 'BCSO',
        job = nil,          -- set when the job is created in Phase 5
        active = false,
        blip = 46,          -- orange
        canFine = true,
    },
    sasp = {
        label = 'San Andreas State Police',
        short = 'SASP',
        job = nil,
        active = false,
        blip = 5,           -- yellow
        canFine = true,
    },
    ems = {
        label = 'San Andreas Medical Services',
        short = 'EMS',
        job = 'ambulance',
        active = true,
        blip = 1,           -- red
        canFine = false,    -- medics do not write tickets
    },
}

-- ---------------------------------------------------------------------------
-- Armoury
--
-- Split deliberately. Protective equipment is issued by the department because
-- an officer who cannot afford armour is a safety problem, and charging for it
-- pushes people to work unprotected. Weapons and ammunition are personal, so
-- there is a real cost to spraying rounds around.
-- ---------------------------------------------------------------------------

Config.Armoury = {
    -- Paid for by the department account. Free to the officer.
    departmentIssue = {
        ifak = 0,
        bandage = 0,
        armour = 0,
        radio = 0,
        handcuffs = 0,
    },

    -- Charged to the officer personally.
    personal = {
        weapon_pistol = 2500,
        weapon_stungun = 1200,
        weapon_carbinerifle = 12000,
        ammo_pistol = 45,
        ammo_rifle = 90,
    },

    -- Department pays this share of personal equipment. 0.0 means the officer
    -- pays in full.
    departmentSubsidy = 0.0,
}
