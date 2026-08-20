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

        -- ON THE EMERGENCY CAR PACK, and NOT on origen_police.
        --
        -- The origen models were pulled at the owner's request and are not
        -- coming back. The pool runs on Zerofour04's Emergency Car Pack, which
        -- is what lspd-Police-Cars, lspd-Police-Bike and lspd-Police-SWAT
        -- stream and what som-police's fleet config already points at.
        --
        -- Those packs REPLACE vanilla police models rather than adding spawn
        -- names, which is why these read as ordinary GTA names: police2 is a
        -- Buffalo cruiser because the pack replaced it.
        --
        -- retireFleet() deletes rows for any model no longer listed and
        -- seedFleet() creates them on the next boot, so this list IS the pool.
        vehicles = {
            -- LABELS DESCRIBE THE PACK'S CARS, NOT THE VANILLA ONES THEY REPLACE.
            --
            -- The previous labels were derived from what police2/police3/etc.
            -- are in stock GTA, which is wrong the moment a pack replaces the
            -- model. Reading lspd-Police-Cars' own vehicles.meta settles two of
            -- them outright: police3's handlingId is `libertychar` and
            -- police4's is `libertyvic`, so those are a Charger and a Crown
            -- Victoria rather than an "Interceptor" and a generic unmarked.
            -- pranger is a Taurus, reported from in game.
            --
            -- police2, fbi and fbi2 are NOT confirmed. Their handling ids map
            -- to themselves, which tells us nothing about the body, so they
            -- carry role-only names rather than a body style I would be
            -- guessing at for the second time.
            { model = 'police2',   label = 'Marked Cruiser',        count = 3, price = 50000 },
            { model = 'police3',   label = 'Charger',               count = 3, price = 55000 },
            { model = 'pranger',   label = 'Taurus',                count = 2, price = 65000 },
            { model = 'police4',   label = 'Crown Victoria',        count = 2, price = 70000, cert = 'cert.detective' },
            { model = 'fbi',       label = 'Unmarked, Detective',   count = 1, price = 75000, cert = 'cert.detective' },
            { model = 'fbi2',      label = 'Unmarked, Command',     count = 1, price = 80000, cert = 'cert.detective' },
            { model = 'policeb',   label = 'Police Motorcycle',     count = 2, price = 45000, cert = 'cert.motorcycle' },
            { model = 'pitbullbb', label = 'SWAT Armoured',         count = 1, price = 120000, cert = 'cert.swat' },
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

-- Pool vehicles KEEP their appearance.
--
-- This was true and is now false, deliberately. Resetting to stock meant a
-- livery set on a department car was thrown away the next time anyone took it
-- out, which makes liveries pointless on exactly the vehicles that most need
-- them: a marked unit should look the same every shift.
--
-- Condition is a separate question. Damage and fuel are still stored per
-- vehicle when it is put away, so wrecking a pool car does pass the damage on,
-- which is the accountability half of a shared fleet.
Config.ResetPoolProps = false

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

-- ---------------------------------------------------------------------------
-- Dealerships
--
-- Two shop TYPES, at the owner's decision of 2026-08-20:
--
--   free    self serve. Buy from a terminal, no staff, any hour. Limited to a
--           cheap range, so a new player is never stuck waiting for somebody to
--           log in, but a real car is still a transaction with a person.
--   managed a player with the dealer job has to be present and hand the car
--           over, and takes a commission for it. This is the roleplay version
--           and it is where everything above the free range is sold.
--
-- WHY THIS LIVES IN som-garage AND NOT IN A som-dealership RESOURCE.
-- DEALERSHIP-RESEARCH.md called for a separate resource, and it was written
-- before this resource had a panel. It now has one, with a live 3D preview
-- podium, a search, a Buy tab and a cash-or-card footer, and the police fleet
-- already BUYS through it. A dealership is that panel with a different
-- catalogue. A second resource could not reuse the page either: a NUI callback
-- only answers for the resource that SERVED the frame, which is the trap AUDIT
-- records against som-inventory. Duplicating a 384 line stylesheet and a 313
-- line renderer to sell civilian cars instead of police ones is the exact
-- duplication section 7.4 exists to stop.
--
-- COORDINATES. `pdm` is the stock Premium Deluxe showroom and is NOT verified
-- in game. `beachlot` is derived from the `beach` garage coordinate above,
-- which is, so it is the safer of the two. Correct either here.
--
-- THERE IS NO SPAWN POINT, deliberately. A bought car is delivered to a real
-- garage rather than materialised on the forecourt, which means a shop needs no
-- verified bay, cannot drop a car into a wall, and leaves the player with a
-- vehicle where they already know to look for it. `preview` is a local,
-- non-networked ghost and doubles as where a test drive starts.
-- ---------------------------------------------------------------------------

Config.Shops = {
    pdm = {
        label = 'Premium Deluxe Motorsport',
        type = 'managed',
        job = 'cardealer',
        business = 'pdm',

        -- UNVERIFIED. The showroom floor.
        coords = vec3(-56.7, -1098.5, 26.4),
        preview = vec4(-47.5, -1095.5, 26.4, 30.0),

        -- Everything. The free lot's range is a subset of this one.
        deliverTo = 'legion',
        blip = { sprite = 326, colour = 3, scale = 0.75 },
    },

    beachlot = {
        label = 'Beachfront Used Cars',
        type = 'free',
        business = 'pdm',

        -- Derived from the verified `beach` garage a few metres away, so a car
        -- bought here is collected from the garage you are standing next to.
        coords = vec3(-1176.5, -1499.8, 4.4),
        preview = vec4(-1180.0, -1505.0, 4.4, 125.0),

        deliverTo = 'beach',
        blip = { sprite = 326, colour = 46, scale = 0.6 },

        -- The cheap range, and the whole reason this shop exists. A price cap
        -- rather than a model list: adding a car to the catalogue under the cap
        -- puts it here automatically, and raising its price takes it away
        -- again, so the two shops can never disagree about what they sell.
        maxPrice = 26000,
    },
}

Config.Dealership = {
    -- How close the server insists you are to the shop counter. Looser than the
    -- interaction, because client coordinates lag the server's.
    distance = 20.0,

    -- A managed sale is agreed between two people standing together. Checked
    -- server side against BOTH of them, so neither half can be spoofed.
    saleDistance = 8.0,

    -- The dealer's cut of a managed sale, paid by the business out of the sale
    -- rather than minted. Zero would make the job pointless; too high and a
    -- dealer earns more than the business does.
    commission = 0.08,

    -- Test drives.
    testDrive = {
        -- Seconds. The despawn is enforced SERVER side: the reference scripts
        -- lean on the client for it, and a test drive a player can keep is a
        -- free car.
        seconds = 120,

        -- Cars a test drive may not be taken in. Anything over this is looked
        -- at rather than driven, which is also how it works in a real showroom.
        maxPrice = 250000,

        -- One at a time per player, and refused while one is already out.
        cooldownSeconds = 30,
    },
}
