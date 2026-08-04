-- som-police configuration.
--
-- Data only. Every value here is re-checked server side before it does
-- anything, so editing this file changes what is OFFERED, never what is
-- ALLOWED. An option appearing in the eye grants nothing.
--
-- ---------------------------------------------------------------------------
-- COORDINATES ARE UNVERIFIED
--
-- These are harvested from the qbx_police and qb-policejob configs, both GPL
-- and both targeting Gabz MRPD. MLO versions drift, and a duty marker inside a
-- wall is worse than no duty marker at all.
--
-- Walk MRPD and correct anything that is off before trusting this. `/pdcoords`
-- prints your current position already formatted for this file, and
-- `/pdzones` draws every zone so a wrong one is visible rather than merely
-- broken.
-- ---------------------------------------------------------------------------

Config = {}

Config.Job = 'police'
Config.Business = 'lspd'

-- ---------------------------------------------------------------------------
-- Certifications
--
-- An axis SEPARATE from rank. Rank is seniority and decides pay and who may
-- promote whom; a certification decides what an officer is trusted to do. A
-- Lieutenant with no rifle certification still cannot draw a rifle, which is
-- the point: promotion is not a competence test.
--
-- Stored as som_licenses rows with the type below, so every grant already
-- carries issued_by, issued_at and revoked without another table.
-- ---------------------------------------------------------------------------

Config.Certifications = {
    ['cert.rifle']       = { label = 'Rifle Certified',   description = 'Carbine and heavier at the armoury' },
    ['cert.interceptor'] = { label = 'Interceptor',       description = 'Pursuit rated vehicles' },
    ['cert.helicopter']  = { label = 'Air Support',       description = 'Helipad access' },
    ['cert.audit']       = { label = 'Financial Audit',   description = 'Audit a citizen through the phone' },
    -- Reserved. Gates nothing yet, and is listed so it can be granted and
    -- tracked before the feature that reads it exists.
    ['cert.k9']          = { label = 'K9 Handler',        description = 'Reserved for K9' },
}

-- Minimum GRADE that may grant or revoke a certification. Grade 5 is
-- Lieutenant, the first boss rank. See som-core/shared/jobs.lua.
Config.CertGrantGrade = 5

-- Minimum grade for the supervisory verbs: voiding fines, releasing an impound
-- without the fee, clearing another officer's plate flag.
Config.SupervisorGrade = 5

-- ---------------------------------------------------------------------------
-- Stations
-- ---------------------------------------------------------------------------

Config.Stations = {
    mrpd = {
        label = 'Mission Row Police Department',

        blip = {
            coords = vec3(441.0, -982.0, 30.68),
            sprite = 60, colour = 29, scale = 0.8,
        },

        -- Duty is a zone rather than a ped, so it cannot be blocked by
        -- somebody parking a car on the desk.
        -- Verified in game.
        duty = {
            coords = vec3(441.97, -981.85, 30.94),
            size = vec3(1.8, 1.8, 2.0),
            rotation = 8.92,
        },

        -- Verified in game.
        armoury = {
            coords = vec3(480.73, -995.31, 30.69),
            size = vec3(1.8, 1.4, 2.0),
            rotation = 351.15,
        },

        stashes = {
            -- Verified in game.
            {
                id = 'locker', label = 'Personal Locker', kind = 'personal',
                slots = 50, weight = 100000,
                coords = vec3(462.91, -999.64, 30.69),
                size = vec3(2.0, 4.0, 2.0), rotation = 1.97,
            },
            {
                id = 'evidence', label = 'Evidence Locker', kind = 'shared',
                slots = 100, weight = 500000,
                coords = vec3(472.15, -996.55, 26.27),
                size = vec3(2.0, 3.0, 2.0), rotation = 0.0,
            },
            {
                id = 'trash', label = 'Disposal', kind = 'shared',
                slots = 30, weight = 100000,
                coords = vec3(477.15, -996.55, 26.27),
                size = vec3(1.6, 1.6, 2.0), rotation = 0.0,
            },
        },

        -- Verified in game. som-garage owns this door when it is running; these
        -- coordinates are kept in step so the fallback lands in the same place.
        garage = {
            coords = vec3(449.27, -978.18, 28.47),
            size = vec3(4.0, 4.0, 3.0),
            rotation = 333.37,
            spawn = vec4(449.27, -978.18, 28.47, 333.37),
            -- Where a vehicle must be brought back to, and how close.
            returnRadius = 30.0,
        },

        helipad = {
            coords = vec3(449.0, -981.0, 43.69),
            size = vec3(3.0, 3.0, 2.0),
            rotation = 0.0,
            spawn = vec4(449.0, -981.0, 43.69, 180.0),
            returnRadius = 30.0,
        },

        -- Where an impounded vehicle is released from.
        impound = {
            coords = vec3(407.9, -1633.5, 29.29),
            size = vec3(3.0, 3.0, 2.0),
            rotation = 0.0,
            spawn = vec4(401.5, -1630.1, 29.29, 230.0),
        },
    },
}

-- Blips for the working parts of a station, drawn only for officers.
--
-- `from` names a key on the station table above, so moving a location moves its
-- blip with it and there is one set of coordinates rather than two that drift.
-- The station blip itself is separate and is shown to EVERYONE: a citizen who
-- cannot find the police station on the map is a bug, not a security measure.
Config.StaffBlips = {
    { from = 'armoury', label = 'Armoury',      sprite = 110, colour = 29, scale = 0.6 },
    { from = 'garage',  label = 'Motor Pool',   sprite = 357, colour = 29, scale = 0.6 },
    { from = 'helipad', label = 'Air Support',  sprite = 43,  colour = 29, scale = 0.6 },
    { from = 'impound', label = 'Impound Lot',  sprite = 68,  colour = 29, scale = 0.6 },
}

-- ---------------------------------------------------------------------------
-- Armoury
--
-- Prices and who pays live in som-economy (Config.Armoury), which owns the
-- department account. This list is what is STOCKED and what gates it, so the
-- two concerns stay apart: economy decides cost, police decides eligibility.
--
-- `cert` is checked server side against som_licenses. `grade` is a rank floor.
-- ---------------------------------------------------------------------------

Config.Armoury = {
    -- Department issue. Free to the officer, paid for by the LSPD account.
    issue = {
        { item = 'ifaks',      label = 'IFAK',       count = 3 },
        { item = 'bandage',    label = 'Bandage',    count = 5 },
        { item = 'armour',     label = 'Body Armour', count = 1 },
        { item = 'radio',      label = 'Radio',      count = 1 },
        { item = 'handcuffs',  label = 'Handcuffs',  count = 1 },
    },

    -- Bought by the officer, cash or card. `weapon` items are given with a
    -- serial so evidence can tie a casing back to them later.
    personal = {
        { item = 'weapon_nightstick',  label = 'Nightstick',    count = 1 },
        { item = 'weapon_stungun',     label = 'Taser',         count = 1 },
        -- One shot per cartridge. ox_inventory's stungun had no ammo type at
        -- all, so it fired forever; it now consumes these.
        { item = 'ammo-taser',         label = 'Taser Cartridges', count = 5 },
        { item = 'weapon_pistol',      label = 'Service Pistol', count = 1 },
        { item = 'ammo-9',             label = '9mm Ammo',      count = 30 },
        { item = 'weapon_carbinerifle', label = 'Carbine Rifle', count = 1, cert = 'cert.rifle' },
        { item = 'ammo-rifle',         label = 'Rifle Ammo',    count = 30, cert = 'cert.rifle' },
    },
}

-- ---------------------------------------------------------------------------
-- Vehicles
-- ---------------------------------------------------------------------------

Config.Vehicles = {
    -- Only used when som-garage is NOT running; it owns the motor pool
    -- otherwise. Kept in step with som-garage's fleet.
    garage = {
        { model = 'polbuffalo4', label = 'Buffalo STX' },
        { model = 'polcaracara', label = 'Caracara 4x4' },
        { model = 'poldom',      label = 'Dominator' },
        { model = 'polcomet',    label = 'Interceptor Comet',  cert = 'cert.interceptor' },
        { model = 'polvstr',     label = 'Interceptor Vectre', cert = 'cert.interceptor' },
    },

    -- Vanilla, because no addon helicopter is streamed and the helipad is a
    -- separate zone from the motor pool.
    helipad = {
        { model = 'polmav', label = 'Police Maverick', cert = 'cert.helicopter' },
    },
}

-- Plates issued to department vehicles. Eight characters is the GTA maximum,
-- so the prefix plus four digits is the whole plate.
Config.PlatePrefix = 'LSPD'

-- ---------------------------------------------------------------------------
-- Custody
--
-- NOT job gated. Cuffing needs handcuffs in the inventory and proximity, and
-- nothing else. A kidnapping is meant to be possible: if only the police could
-- restrain or move somebody, crime would have no counterplay.
-- ---------------------------------------------------------------------------

Config.Custody = {
    -- The item that must be PRESENT. Not used, not equipped, not consumed:
    -- carrying a pair is what makes you able to cuff, so there is no item-use
    -- flow to fight with and nothing to drop mid-arrest.
    item = 'handcuffs',

    -- Maximum distance, re-measured server side on every action.
    distance = 2.5,

    cuffDuration = 3000,
    uncuffDuration = 2000,
    searchDuration = 4000,

    -- A cuffed player can still run. Restraint is a roleplay state, not a
    -- paralysis: a suspect who can move can still be chased, bundled into a
    -- car or walked into a cell rather than parked on a pavement.
    --
    -- What they cannot do is enter a vehicle unaided. They have to be put in.
    allowRun = true,

    anim = {
        dict = 'mp_arresting',
        clip = 'idle',
        prop = 'p_cs_cuffs_02_s',
    },
}

-- ---------------------------------------------------------------------------
-- Fines
--
-- Amounts and the split live in som-economy. These are the presets an officer
-- picks from, so a ticket is two clicks rather than a typed number, plus a
-- free-text option for anything not listed.
-- ---------------------------------------------------------------------------

Config.Fines = {
    presets = {
        { label = 'Speeding',                 amount = 500 },
        { label = 'Reckless driving',         amount = 1200 },
        { label = 'Illegal parking',          amount = 250 },
        { label = 'Driving without a licence', amount = 1500 },
        { label = 'Public disorder',          amount = 800 },
        { label = 'Assault',                  amount = 3500 },
        { label = 'Possession of a firearm',  amount = 7500 },
    },

    -- Delivered as a phone bill that settles itself after this long. A fine is
    -- not an offer, so refusing to open your phone cannot be a way to dodge
    -- one. See som_phone_bills.auto_collect.
    dueDays = 7,
}

-- ---------------------------------------------------------------------------
-- Impound
-- ---------------------------------------------------------------------------

Config.Impound = {
    -- Charged to the owner to get the vehicle back, not to the officer.
    fee = 2500,

    reasons = {
        'Abandoned',
        'Illegally parked',
        'Evidence',
        'Unlicensed driver',
        'Reckless driving',
    },
}

-- ---------------------------------------------------------------------------
-- Keybinds
--
-- The same validated request the eye sends, just faster to send. Never a
-- shortcut around a check: handcuffs, proximity and cuffed state are all still
-- verified server side.
--
-- Registered once at start and disabled whenever the player is not an on-duty
-- officer, so an arrow key can never quietly do something to a passer-by.
-- Rebindable in FiveM's own key settings, which lib.addKeybind gives for free.
-- ---------------------------------------------------------------------------

Config.Keybinds = {
    enabled = true,

    cuff    = { key = 'UP',    description = 'Cuff or uncuff the nearest person' },
    vehicle = { key = 'DOWN',  description = 'Put in or pull from the nearest vehicle' },
    escort  = { key = 'LEFT',  description = 'Escort the nearest person' },
    release = { key = 'RIGHT', description = 'Stop escorting' },

    -- In-vehicle controls.
    --
    -- LMENU is also ox_target's eye, and that is FINE: the eye cannot be used
    -- from a driver's seat, so the two never contend. These binds are disabled
    -- unless the player is in a department vehicle, so a civilian pressing Q
    -- does nothing.
    lights = { key = 'Q',     description = 'Toggle emergency lights' },
    siren  = { key = 'LMENU', description = 'Toggle siren' },
}

-- ---------------------------------------------------------------------------
-- Emergency vehicles
--
-- Which models count as police vehicles for the light and siren binds. Derived
-- from the fleet rather than listed twice, plus the base-game ones so a
-- commandeered cruiser still works.
-- ---------------------------------------------------------------------------

Config.EmergencyModels = {
    -- origen_police
    polbuffalo4 = true, polcaracara = true, polcomet = true,
    poldom = true, polvigero2 = true, polvstr = true,
    -- TIG-PACK
    scpolstang = true, scpolc7 = true, scpolvic = true,
    scpolchal = true, scpolacr = true, scpolm4 = true,
    -- Base game
    police = true, police2 = true, police3 = true, police4 = true,
    policeb = true, policet = true, sheriff = true, sheriff2 = true,
    fbi = true, fbi2 = true, riata = true, polmav = true,
    ambulance = true, firetruk = true,
}
