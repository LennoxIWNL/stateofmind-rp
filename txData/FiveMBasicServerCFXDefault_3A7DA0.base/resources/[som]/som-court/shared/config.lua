--- som-court configuration. Data only: every value is re-checked server side,
--- so editing this changes what is offered, never what is allowed.

Config = {}

Config.Jobs = {
    police = 'police',
    judge = 'judge',
    prosecutor = 'prosecutor',
    defender = 'defender',
}

-- One threshold per power, never a per-grade table.
Config.Grades = {
    schedule = 0, -- a clerk can docket a hearing
    ruling = 1,   -- may rule on infractions and misdemeanors
    felony = 2,   -- may rule on felonies
}

-- A court can lower a sentence, never raise it, so these are hard ceilings.
Config.Classes = {
    infraction  = { label = 'Infraction',  maxMonths = 0,  maxFine = 5000,   maxTasks = 20 },
    misdemeanor = { label = 'Misdemeanor', maxMonths = 6,  maxFine = 15000,  maxTasks = 40 },
    felony      = { label = 'Felony',      maxMonths = 24, maxFine = 100000, maxTasks = 0 },
}

Config.MaxOpenPerDefendant = 3
Config.FileRange = 8.0
Config.DocketSize = 25

-- Minutes from now. The client picks an entry; the offset is never sent as a number.
Config.HearingOffsets = { 30, 60, 180, 1440 }

-- A scheduled hearing with no ruling this long after it was due can be
-- declared a failure to appear, which issues a warrant.
Config.FailureGraceMinutes = 30
Config.WarrantHours = 72

Config.Bail = { min = 2500, max = 250000 }

-- UNVERIFIED. Walk the courthouse and correct this; /pdcoords prints a position
-- already formatted for a config file.
Config.Desk = {
    coords = vec3(236.4, -407.3, 47.9),
    size = vec3(2.0, 2.0, 2.0),
    rotation = 0.0,
}
