-- som-garage configuration.
--
-- COORDINATES ARE UNVERIFIED, with the exception of the LSPD entry which reuses
-- som-police's already-corrected motor pool. Walk each one and fix it before
-- trusting it; `/garagecoords` prints your position formatted for this file.
--
-- Access is decided by `groups`, which covers jobs AND gangs with one field, so
-- there is no separate gang code path to keep in step. Every value here is
-- re-checked server side: this decides what is OFFERED, never what is allowed.

Config = {}

-- Personally owned vehicles. Distinct from RENT (som-rentals) and LSPD
-- (som-police pool) so a plate says which system issued it.
Config.PlatePrefix = 'SOM'

-- Share of the recorded purchase price returned when a job-restricted vehicle
-- is sold back because its owner left the job. Deliberately below 1: leaving
-- the force should cost something, but not everything.
Config.RefundRate = 0.6

-- ---------------------------------------------------------------------------
-- The preview
-- ---------------------------------------------------------------------------

Config.Preview = {
    -- 0-255, but the game only honours multiples of 51, so 153 is the nearest
    -- real value to "slightly transparent". Anything between 153 and 203 looks
    -- identical.
    alpha = 153,

    fov = 42.0,

    -- Camera distance and height from the vehicle centre, in metres.
    distance = 5.6,
    height = 1.5,

    -- Degrees per second while nobody is dragging. Slow enough to read as
    -- presentation rather than a spinning showroom turntable.
    idleSpin = 6.0,

    -- Mouse drag sensitivity, degrees per pixel.
    dragSpeed = 0.4,
}

-- ---------------------------------------------------------------------------
-- Garages
--
-- `groups`      job or gang name -> minimum grade. Absent means public.
-- `shared`      everyone in the group sees the same vehicles, rather than only
--               their own. This is what makes a department fleet a fleet.
-- `fleet`       the pool definition, see Config.Fleets below.
-- `preview`     where the ghost vehicle is rendered, and where the camera sits.
-- ---------------------------------------------------------------------------

Config.Garages = {
    legion = {
        label = 'Legion Square Parking',
        type = 'public',
        coords = vec3(215.9, -809.9, 30.7),
        spawn = vec4(228.5, -800.2, 30.5, 158.0),
        preview = vec4(228.5, -800.2, 30.5, 158.0),
        blip = { sprite = 357, colour = 3, scale = 0.7 },
    },

    beach = {
        label = 'Vespucci Parking',
        type = 'public',
        coords = vec3(-1183.9, -1509.2, 4.4),
        spawn = vec4(-1187.5, -1502.3, 4.3, 125.0),
        preview = vec4(-1187.5, -1502.3, 4.3, 125.0),
        blip = { sprite = 357, colour = 3, scale = 0.7 },
    },

    -- Verified: reuses som-police's corrected motor pool position.
    lspd = {
        label = 'Mission Row Motor Pool',
        type = 'job',
        groups = { police = 0 },
        shared = true,
        fleet = 'lspd',
        business = 'lspd',
        coords = vec3(449.27, -978.18, 28.47),

        -- Four measured bays, tried in order.
        --
        -- A single spawn point means the second car of a shift materialises
        -- inside the first. The server walks this list and takes the first bay
        -- with nothing parked in it, so a busy motor pool fills up rather than
        -- stacking vehicles on one another.
        --
        -- `spawn` is kept as the first bay so anything reading a single point
        -- still works.
        spawn = vec4(445.46, -986.26, 25.70, 272.73),
        bays = {
            vec4(445.46, -986.26, 25.70, 272.73),
            vec4(445.15, -988.65, 25.70, 274.14),
            vec4(445.60, -991.65, 25.70, 293.55),
            vec4(445.52, -994.01, 25.70, 273.09),
        },

        -- The preview stands in the first bay. It is a local, non-networked
        -- ghost, so it never blocks a real car from spawning there.
        preview = vec4(445.46, -986.26, 25.70, 272.73),
        -- No blip: som-police already draws one for the motor pool, and two
        -- markers on one door is worse than none.
    },

    lscustoms = {
        label = 'Los Santos Customs Yard',
        type = 'job',
        groups = { mechanic = 0 },
        shared = true,
        business = 'lscustoms',
        coords = vec3(-337.2, -136.3, 39.0),
        spawn = vec4(-329.5, -122.4, 38.7, 250.0),
        preview = vec4(-329.5, -122.4, 38.7, 250.0),
        blip = { sprite = 357, colour = 5, scale = 0.6 },
    },
}

-- ---------------------------------------------------------------------------
-- Fleets
--
-- A pool is REAL ROWS, not a spawner. Five cruisers means five rows with five
-- plates, so taking the fifth leaves none until one comes back. That is the
-- whole point of a pool, and a config-list spawner cannot express it.
--
-- Rows are created on first boot and topped up if the count is raised, so
-- changing `count` here is the only thing needed to grow the fleet.
--
-- `cert` gates taking one, checked against som-police server side.
-- `price` is what an officer pays to own one personally; nil means it is not
-- for sale and only ever exists in the pool.
-- ---------------------------------------------------------------------------

Config.Fleets = {
    lspd = {
        platePrefix = 'LSPD',

        -- origen_police only.
        --
        -- TIG-PACK was dropped: its models do not spawn at all, so an officer
        -- picking one got nothing and the pool silently lost a slot. ex-cars
        -- went earlier for broken liveries and misaligned headlights.
        --
        -- No vanilla models here either. A shared department garage full of
        -- base-game cruisers next to custom ones looks like an oversight, and
        -- the transport van and helicopter belong at the helipad rather than in
        -- the motor pool list.
        vehicles = {
            { model = 'polbuffalo4', label = 'Buffalo STX',   count = 3, price = 50000 },
            { model = 'polcaracara', label = 'Caracara 4x4',  count = 2, price = 65000 },
            { model = 'poldom',      label = 'Dominator',     count = 2, price = 55000 },

            -- Pursuit rated. The two quickest models in the pack.
            {
                model = 'polcomet', label = 'Interceptor Comet',
                count = 2, price = 95000, cert = 'cert.interceptor',
            },
            {
                model = 'polvstr', label = 'Interceptor Vectre',
                count = 2, price = 95000, cert = 'cert.interceptor',
            },
        },
    },
}

-- ---------------------------------------------------------------------------
-- Buying
-- ---------------------------------------------------------------------------

Config.Purchase = {
    -- A bought department vehicle is genuinely the officer's, but it only
    -- leaves the department garage. A marked cruiser parked outside a bank by
    -- an off-duty officer is the thing this prevents.
    groupRestricted = true,

    -- Bought vehicles keep their modifications. Pool cars are reset to stock on
    -- every spawn, which is what makes buying one worth the money.
    keepProps = true,
}

-- Pool vehicles are handed out at stock condition every time, so an officer
-- who wrecks one is not passing the damage to the next shift, and nobody can
-- park a tuned cruiser in the pool.
Config.ResetPoolProps = true

-- ---------------------------------------------------------------------------
-- Temporary mod bay
--
-- Exists so liveries and extras on the addon police models can be checked. It
-- is FREE and client-only; a real Los Santos Customs charges money and books
-- revenue to the business, and none of that is here.
--
-- UNVERIFIED coordinate, taken from the LSC garage entrance. /garagecoords to
-- correct it. Set to nil to remove the bay entirely.
-- ---------------------------------------------------------------------------

Config.ModShop = {
    -- Verified in game.
    coords = vec3(452.05, -976.92, 25.70),
    rotation = 84.88,
}
