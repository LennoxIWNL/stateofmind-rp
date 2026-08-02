Config = {}

-- Maximum distance between thief and victim, enforced SERVER side.
Config.MaxDistance = 2.0

-- How long the search animation runs before the money moves.
Config.SearchDuration = 5000

-- Cooldown per victim, so a downed player cannot be farmed repeatedly.
Config.CooldownMs = 30000

-- A victim can only be robbed while in one of these states. This is what stops
-- cash being pickpocketed off anyone walking down the street.
Config.RequiredVictimState = {
    cuffed = true,
    isdead = true,
    inlaststand = true,
    handsup = true,
}

-- Fraction of the victim's cash taken per successful robbery.
-- 1.0 takes everything.
Config.StealFraction = 1.0

-- Police cannot be robbed of seized cash by a civilian: on-duty officers of
-- these jobs are exempt entirely.
Config.ExemptJobs = {
    police = true,
    ambulance = true,
}
