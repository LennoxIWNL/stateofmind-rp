Config = {}

-- ---------------------------------------------------------------------------
-- Loop rates.
--
-- Four loops rather than one, because these change at wildly different speeds
-- and a single loop fast enough for the speedometer would poll the clock two
-- hundred times a second for nothing. Every loop sends only on change, so the
-- cost of a fast rate is the read, not the message.
-- ---------------------------------------------------------------------------

Config.Interval = {
    vehicle = 100,   -- the speedometer is the one thing that must not stutter
    status  = 500,
    world   = 500,   -- street and zone, at a rate a human can read
    -- HEADING IS ITS OWN LOOP AND MUCH FASTER.
    --
    -- It used to ride along with the street name at 500ms, which is why the
    -- compass moved in visible steps: a compass is watched WHILE TURNING, so
    -- its update rate is a smoothness requirement rather than a reading rate.
    -- Street and zone are the opposite and stay slow, because re-querying them
    -- at this rate would be three expensive natives for a string that changes
    -- once a block.
    heading = 60,
    player  = 2000,  -- money, job, clock
}

-- ---------------------------------------------------------------------------
-- Subtractive display.
--
-- The rule the old HUD established and this one keeps: an element that is
-- always full is noise, and noise teaches players to stop reading the row it
-- sits in. Anything at a resting value stands down.
-- ---------------------------------------------------------------------------

Config.Hide = {
    armourWhenEmpty = true,
    needsAbove = 90,
    stressBelow = 10,
    inPauseMenu = true,
    whenDowned = true,
}

Config.Low = 35
Config.Critical = 15

Config.SpeedUnit = 'mph'
Config.EngineWarnBelow = 700

-- ---------------------------------------------------------------------------
-- Fuel.
--
-- NOT WIRED, and deliberately so. No fuel resource runs on this server:
-- cdn-fuel hard-depends on qb-target, qb-input, qb-menu and qbx_core's locale
-- and fails at load, and ox_fuel is not installed. GetVehicleFuelLevel on a
-- vanilla vehicle does not meaningfully deplete, so the gauge would sit at one
-- number forever, which is exactly what teaches a player to ignore a HUD.
--
-- The gauge is BUILT. Set this to the fuel resource's name once one exists and
-- it starts reading.
-- ---------------------------------------------------------------------------

Config.FuelResource = false

-- ---------------------------------------------------------------------------
-- Seatbelt.
--
-- The threshold is a DELTA, not a speed: braking hard from 40 is not a crash,
-- going from 40 to 5 in one frame is.
-- ---------------------------------------------------------------------------

Config.SeatbeltKey = 'B'

Config.Seatbelt = {
    -- Below this there is nothing to be thrown from. m/s.
    minSpeed = 8.0,
    -- Speed lost in a single frame that counts as hitting something. m/s.
    ejectDelta = 12.0,
    -- How much of the lost speed the ped carries out through the glass.
    launch = 0.8,
    damage = 22,
}
