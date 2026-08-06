-- som-hud configuration.
--
-- WHAT IS DELIBERATELY NOT HERE, and why, because the absences are the part
-- most likely to be read as an oversight:
--
--   FUEL. No fuel resource runs on this server. cdn-fuel is on disk but hard
--   depends on qb-target, qb-input, qb-menu and qbx_core's locale, and fails at
--   load; ox_fuel is not installed. GetVehicleFuelLevel on a vanilla vehicle
--   does not meaningfully deplete, so a fuel gauge would sit at the same number
--   forever. A gauge that never moves is worse than no gauge: it teaches the
--   player to ignore the HUD. It goes in when ox_fuel does.
--
--   SEATBELT. There is no seatbelt system on this server either. qb-smallresources
--   ships one and is not ensured. A belt indicator is not a HUD feature, it is
--   an ejection-physics feature with an indicator attached, and building half of
--   it here would be the wrong half.
--
-- Both are recorded in AUDIT.md rather than stubbed.

Config = {}

-- ---------------------------------------------------------------------------
-- Polling
--
-- Two loops rather than one, because the two halves change at very different
-- rates. Speed has to be smooth or the number stutters; hunger moves a point
-- every few minutes and polling it at 100ms would be almost entirely waste.
-- ---------------------------------------------------------------------------

-- Vehicle panel, milliseconds. 100 is smooth enough for a speed readout without
-- being a per-frame loop, which CLAUDE.md rules out for anything but rendering
-- and input.
Config.VehicleInterval = 100

-- Condition rings, milliseconds.
Config.StatusInterval = 500

-- ---------------------------------------------------------------------------
-- Clutter
--
-- The rule from AUDIT 20.4: density without clutter. A ring that is full is
-- telling the player nothing they need, so it stands down and gives its space
-- back. Health is the exception and is always shown, because a HUD whose health
-- indicator only appears once you are hurt has no resting state at all.
-- ---------------------------------------------------------------------------

Config.Hide = {
    -- Armour at zero, which is most of the time for most players.
    armourWhenEmpty = true,

    -- Hunger and thirst above this percentage.
    needsAbove = 90,

    -- The whole HUD, in situations where it is either meaningless or in the
    -- way.
    inPauseMenu = true,
    whenDowned = true,
}

-- ---------------------------------------------------------------------------
-- Thresholds
--
-- Where a ring changes colour. One accent used sparingly is the rule, so
-- nothing here is pink: pink is reserved for the voice ring while actually
-- transmitting, which is the one thing on this HUD that is happening RIGHT NOW
-- rather than merely being true.
-- ---------------------------------------------------------------------------

Config.Low = 35
Config.Critical = 15

-- ---------------------------------------------------------------------------
-- The vehicle panel
-- ---------------------------------------------------------------------------

-- 'mph' or 'kmh'.
Config.SpeedUnit = 'mph'

-- Engine condition is shown only once it has actually taken damage, on the same
-- reasoning as the armour ring. GetVehicleEngineHealth runs 0 to 1000.
Config.EngineWarnBelow = 700
