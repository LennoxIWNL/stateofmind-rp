-- som-dispatch configuration.
--
-- Data only. The server re-derives everything that matters (coords, the
-- reporting player, the job routing) rather than trusting what the client sent,
-- so editing this changes what is REPORTED, never who may see it.

Config = {}

-- How long a call stays in the store. ps-mdt's map drops markers older than ten
-- minutes on its own (ui/app.js:5820), so anything beyond that is only useful
-- as history in the call list.
Config.CallLifetime = 30 * 60   -- seconds

-- Repeat reports of the same detected crime close together are one call with a
-- count, not a new call each. At `escalateAt` reports a routine call is raised
-- one priority step, so a sustained incident is noticed without a flood.
Config.Merge = { radius = 40.0, window = 120, escalateAt = 3 }

-- A call nobody has attached to for this long is flagged unattended.
Config.UnattendedAfter = 120

-- Detected reports one player may send per minute, across every alert type.
Config.ReportBudget = 30

-- The dispatcher job hears every call and may assign, close and declare a major
-- incident. Responders at or above SupervisorGrade may declare and close too.
Config.DispatcherJob = 'dispatcher'
Config.SupervisorGrade = 4

-- Closed calls leave the board this long after the last service closed.
Config.ClosedKeep = 120

-- Hard cap on stored calls. A busy night must not grow this without bound,
-- because the whole table is serialised to every MDT that opens.
Config.MaxCalls = 100

-- ---------------------------------------------------------------------------
-- Alerts
--
-- `chance` is the probability a given event actually raises a call. Real
-- servers keep this well below 1 so that not every shot brings the whole
-- department; 1.0 means every single one reports.
--
-- `cooldown` is per player per alert type, in seconds. Without it, an automatic
-- weapon files one call per round.
--
-- `code` matters to ps-mdt: "911" and "311" are the two values that make its UI
-- offer a response box (ui/app.js:4414-4418). Anything else renders as a plain
-- call.
-- ---------------------------------------------------------------------------

Config.Alerts = {
    shotsFired = {
        -- Raised by client detection, so the report event may carry it.
        reportable = true,
        label = 'Shots Fired',
        code = '10-13',
        priority = 1,
        -- Set to 1.0 for testing, so every shot registers. Lower it to
        -- something like 0.35 once the loop is proven, or the map fills up.
        chance = 1.0,
        cooldown = 10,
        jobs = { 'police' },
        blip = { sprite = 110, colour = 1, scale = 1.0, duration = 300 },
    },

    driveBy = {
        -- Raised by client detection, so the report event may carry it.
        reportable = true,
        label = 'Shots Fired From a Vehicle',
        code = '10-13',
        priority = 1,
        chance = 1.0,
        cooldown = 10,
        jobs = { 'police' },
        blip = { sprite = 110, colour = 1, scale = 1.0, duration = 300 },
    },

    meleeAttack = {
        -- Raised by client detection, so the report event may carry it.
        reportable = true,
        label = 'Fight In Progress',
        -- The blip is a search area, so repeat reports cannot be averaged to the exact spot.
        offset = 60.0,
        code = '10-10',
        priority = 2,
        chance = 0.4,
        cooldown = 30,
        jobs = { 'police' },
        blip = { sprite = 491, colour = 47, scale = 0.9, duration = 180 },
    },

    vehicleTheft = {
        -- Raised by client detection, so the report event may carry it.
        reportable = true,
        label = 'Vehicle Theft In Progress',
        offset = 60.0,
        code = '10-35',
        priority = 2,
        chance = 0.6,
        cooldown = 30,
        jobs = { 'police' },
        blip = { sprite = 225, colour = 47, scale = 0.9, duration = 240 },
    },

    explosion = {
        -- Raised by client detection, so the report event may carry it.
        reportable = true,
        label = 'Explosion Reported',
        code = '10-80',
        priority = 1,
        chance = 1.0,
        cooldown = 15,
        jobs = { 'police', 'ambulance' },
        blip = { sprite = 436, colour = 1, scale = 1.1, duration = 300 },
    },

    -- Raised by a player deliberately rather than by detection, so it always
    -- goes through. 911 is what makes ps-mdt offer a response box.
    --
    -- NOT `reportable`. It has its own event with its own validation, and
    -- leaving it reachable from the detection report meant any client could
    -- raise a priority 1 call at will, bypassing the 911 path's message
    -- handling entirely.
    emergencyCall = {
        label = 'Emergency Call',
        code = '911',
        priority = 1,
        chance = 1.0,
        cooldown = 20,
        jobs = { 'police', 'ambulance', 'firefighter' },
        blip = { sprite = 280, colour = 5, scale = 1.0, duration = 600 },
    },

    -- Raised by som-medical when a player stays down. NOT `reportable`.
    personDown = {
        label = 'Person Down',
        code = '10-52',
        priority = 2,
        chance = 1.0,
        cooldown = 0,
        jobs = { 'ambulance' },
        blip = { sprite = 61, colour = 1, scale = 1.0, duration = 600 },
    },

    -- Raised by som-fire when a fire starts. NOT `reportable`.
    structureFire = {
        label = 'Fire',
        code = '10-70',
        priority = 1,
        chance = 1.0,
        cooldown = 0,
        jobs = { 'firefighter', 'ambulance', 'police' },
        blip = { sprite = 436, colour = 1, scale = 1.0, duration = 600 },
    },

    -- Raised by som-turf on a street sale, at the seller's position, so most
    -- sales go unseen. NOT `reportable`.
    drugDeal = {
        label = 'Suspicious Exchange',
        code = '10-66',
        priority = 3,
        chance = 0.25,
        cooldown = 120,
        jobs = { 'police' },
        blip = { sprite = 51, colour = 1, scale = 0.9, duration = 240 },
    },

    -- Raised by som-police when a supervisor flags a department weapon missing
    -- from the armoury ledger, at the armoury. NOT `reportable`.
    armouryMissing = {
        label = 'Weapon Missing',
        code = '10-99',
        priority = 2,
        chance = 1.0,
        cooldown = 60,
        jobs = { 'police' },
        blip = { sprite = 110, colour = 1, scale = 0.9, duration = 600 },
    },

    -- Raised by som-anpr when a police plate reader scans a stolen, BOLO'd or
    -- police flagged plate, at the scanned vehicle's position. NOT `reportable`.
    flaggedVehicle = {
        label = 'Flagged Vehicle',
        code = '10-29',
        priority = 2,
        chance = 1.0,
        cooldown = 60,
        jobs = { 'police' },
        blip = { sprite = 225, colour = 47, scale = 0.9, duration = 240 },
    },

    -- Raised by som-outdoors when a vehicle is brought to a chop shop, at the
    -- shop's own coordinates. NOT `reportable`.
    chopShop = {
        label = 'Suspicious Vehicle Activity',
        code = '10-66',
        priority = 2,
        chance = 0.4,
        cooldown = 120,
        jobs = { 'police' },
        blip = { sprite = 225, colour = 1, scale = 0.9, duration = 300 },
    },

    -- Raised by som-heists when a terminal is touched. NOT `reportable`: the
    -- server raises it with the site's own coordinates.
    heistInProgress = {
        label = 'Alarm Triggered',
        code = '10-90',
        priority = 1,
        chance = 1.0,
        cooldown = 30,
        jobs = { 'police' },
        blip = { sprite = 161, colour = 1, scale = 1.2, duration = 600 },
    },

    -- Raised by som-jail's yard-radius check, not by detection. NOT
    -- `reportable` for the same reason emergencyCall isn't: it has its own
    -- trigger with its own validation.
    inmateEscaped = {
        label = 'Inmate Escaped',
        code = '10-80',
        priority = 1,
        chance = 1.0,
        cooldown = 20,
        jobs = { 'police' },
        blip = { sprite = 59, colour = 1, scale = 1.0, duration = 600 },
    },
}

-- Weapons that never raise a shots-fired call. A stun gun is not gunfire, and
-- a firework is its own kind of nuisance rather than a shooting.
Config.SilentWeapons = {
    [`WEAPON_STUNGUN`] = true,
    [`WEAPON_FIREWORK`] = true,
    [`WEAPON_PETROLCAN`] = true,
    [`WEAPON_FIREEXTINGUISHER`] = true,
    [`WEAPON_SNOWBALL`] = true,
    [`WEAPON_FLARE`] = true,
}

-- Suppressed weapons still report, but with a vaguer message and a coarser
-- position, because the point of a suppressor is that nobody is sure where it
-- came from.
Config.SuppressedWeapons = {
    [`WEAPON_PISTOL_MK2`] = true,
    [`WEAPON_HEAVYPISTOL`] = true,
    [`WEAPON_SPECIALCARBINE`] = true,
}

-- How far a suppressed shot's reported position is scattered, in metres.
Config.SuppressedScatter = 60.0

-- Weapons reported as automatic fire. ps-mdt renders this as a flag on the call
-- (`automaticGunfire`), which is the difference between "a shot" and "a
-- contact" to a responding officer.
--
-- Listed explicitly rather than inferred from clip size or weapon group: those
-- heuristics misclassify shotguns and machine pistols, and a wrong flag here
-- sends the wrong number of units.
Config.AutomaticWeapons = {
    [`WEAPON_ASSAULTRIFLE`] = true,
    [`WEAPON_ASSAULTRIFLE_MK2`] = true,
    [`WEAPON_CARBINERIFLE`] = true,
    [`WEAPON_CARBINERIFLE_MK2`] = true,
    [`WEAPON_ADVANCEDRIFLE`] = true,
    [`WEAPON_SPECIALCARBINE`] = true,
    [`WEAPON_SPECIALCARBINE_MK2`] = true,
    [`WEAPON_BULLPUPRIFLE`] = true,
    [`WEAPON_BULLPUPRIFLE_MK2`] = true,
    [`WEAPON_COMPACTRIFLE`] = true,
    [`WEAPON_MILITARYRIFLE`] = true,
    [`WEAPON_MICROSMG`] = true,
    [`WEAPON_SMG`] = true,
    [`WEAPON_SMG_MK2`] = true,
    [`WEAPON_ASSAULTSMG`] = true,
    [`WEAPON_COMBATPDW`] = true,
    [`WEAPON_MACHINEPISTOL`] = true,
    [`WEAPON_MINISMG`] = true,
    [`WEAPON_COMBATMG`] = true,
    [`WEAPON_COMBATMG_MK2`] = true,
    [`WEAPON_MG`] = true,
    [`WEAPON_GUSENBERG`] = true,
    [`WEAPON_MINIGUN`] = true,
}

-- Jobs that may see and respond to calls at all. Checked server side.
Config.RespondingJobs = {
    police = true,
    ambulance = true,
    firefighter = true,
}
