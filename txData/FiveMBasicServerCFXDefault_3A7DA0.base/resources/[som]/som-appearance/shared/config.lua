Config = {}

-- ---------------------------------------------------------------------------
-- Character appearance.
--
-- The DATA SHAPE is taken from fivem-appearance / illenium-appearance, which is
-- the de-facto standard: headBlend, faceFeatures, headOverlays, hair, eyeColor,
-- components, props, tattoos. The code is ours, the shape is theirs.
--
-- That matters more than it sounds. Every outfit system, MDT mugshot and
-- clothing shop in the ecosystem speaks it, so adopting it means we can import
-- from or export to any of them later without a translation layer, and
-- som_characters.appearance stays readable by tools nobody has written yet.
--
-- Why it was not adopted wholesale: every free implementation is either
-- archived, two years stale, or bound to qb-core. The maintained ones are all
-- paid. See AUDIT 14.15.
-- ---------------------------------------------------------------------------

-- Only the freemode models are customisable. Anything else has a fixed head
-- and would silently ignore most of this.
Config.Models = {
    [0] = 'mp_m_freemode_01',
    [1] = 'mp_f_freemode_01',
}

-- ---------------------------------------------------------------------------
-- Face features, index 0-19, each -1.0 to 1.0.
--
-- The order is GTA's, not ours, and the indices are what SetPedFaceFeature
-- takes. Grouped for the UI so the list is navigable rather than twenty
-- identical sliders.
-- ---------------------------------------------------------------------------

Config.FaceFeatures = {
    { id = 0,  label = 'Nose Width',        group = 'Nose' },
    { id = 1,  label = 'Nose Height',       group = 'Nose' },
    { id = 2,  label = 'Nose Length',       group = 'Nose' },
    { id = 3,  label = 'Nose Bridge',       group = 'Nose' },
    { id = 4,  label = 'Nose Tip',          group = 'Nose' },
    { id = 5,  label = 'Nose Bridge Shift', group = 'Nose' },
    { id = 6,  label = 'Brow Height',       group = 'Brow' },
    { id = 7,  label = 'Brow Depth',        group = 'Brow' },
    { id = 8,  label = 'Cheekbone Height',  group = 'Cheeks' },
    { id = 9,  label = 'Cheekbone Width',   group = 'Cheeks' },
    { id = 10, label = 'Cheek Width',       group = 'Cheeks' },
    { id = 11, label = 'Eye Opening',       group = 'Eyes' },
    { id = 12, label = 'Lip Thickness',     group = 'Mouth' },
    { id = 13, label = 'Jaw Width',         group = 'Jaw' },
    { id = 14, label = 'Jaw Length',        group = 'Jaw' },
    { id = 15, label = 'Chin Height',       group = 'Jaw' },
    { id = 16, label = 'Chin Depth',        group = 'Jaw' },
    { id = 17, label = 'Chin Width',        group = 'Jaw' },
    { id = 18, label = 'Chin Cleft',        group = 'Jaw' },
    { id = 19, label = 'Neck Thickness',    group = 'Jaw' },
}

-- ---------------------------------------------------------------------------
-- Head overlays, index 0-12.
--
-- `colourType` is what SetPedHeadOverlayColor takes: 1 for anything that uses
-- the hair palette, 2 for makeup. nil means the overlay has no colour at all
-- and passing one is meaningless.
-- ---------------------------------------------------------------------------

Config.HeadOverlays = {
    { id = 2,  key = 'eyebrows',      label = 'Eyebrows',     colourType = 1 },
    { id = 1,  key = 'beard',         label = 'Facial Hair',  colourType = 1 },
    { id = 10, key = 'chestHair',     label = 'Chest Hair',   colourType = 1 },
    { id = 0,  key = 'blemishes',     label = 'Blemishes' },
    { id = 3,  key = 'ageing',        label = 'Ageing' },
    { id = 6,  key = 'complexion',    label = 'Complexion' },
    { id = 7,  key = 'sunDamage',     label = 'Sun Damage' },
    { id = 9,  key = 'moleFreckles',  label = 'Moles & Freckles' },
    { id = 11, key = 'bodyBlemishes', label = 'Body Blemishes' },
    { id = 4,  key = 'makeup',        label = 'Makeup',       colourType = 2 },
    { id = 5,  key = 'blush',         label = 'Blush',        colourType = 2 },
    { id = 8,  key = 'lipstick',      label = 'Lipstick',     colourType = 2 },
}

-- ---------------------------------------------------------------------------
-- Clothing. Component and prop ids are GTA's.
--
-- 3, 4 and 5 are absent from props because the game does not use them.
-- ---------------------------------------------------------------------------

-- `group` splits the clothing tab into sub-tabs. Fifteen steppers in one list
-- is a wall, and the grouping other appearance menus settle on is roughly
-- outfit / accessories / the rest, so that is what this uses.
--
-- The groups are a UI CONCERN ONLY. Server side this is still one `apparel`
-- section, so pricing and the scope merge are unaffected by regrouping.
Config.ApparelGroups = {
    { id = 'outfit',      label = 'Outfit' },
    { id = 'accessories', label = 'Accessories' },
    { id = 'extras',      label = 'Extras' },
}

Config.Components = {
    { id = 11, label = 'Top',        group = 'outfit' },
    { id = 8,  label = 'Undershirt', group = 'outfit' },
    { id = 4,  label = 'Legs',       group = 'outfit' },
    { id = 6,  label = 'Shoes',      group = 'outfit' },
    { id = 3,  label = 'Arms',       group = 'outfit' },

    { id = 7,  label = 'Neck',       group = 'accessories' },
    { id = 1,  label = 'Mask',       group = 'accessories' },

    { id = 5,  label = 'Bag',        group = 'extras' },
    { id = 9,  label = 'Armour',     group = 'extras' },
    { id = 10, label = 'Decals',     group = 'extras' },
}

Config.Props = {
    { id = 0, label = 'Hat',      group = 'accessories' },
    { id = 1, label = 'Glasses',  group = 'accessories' },
    { id = 2, label = 'Earrings', group = 'accessories' },
    { id = 6, label = 'Watch',    group = 'accessories' },
    { id = 7, label = 'Bracelet', group = 'accessories' },
}

-- Hair is component 2 but is edited alongside its colour, so it gets its own
-- section rather than sitting in the clothing list.
Config.HairComponent = 2

-- ---------------------------------------------------------------------------
-- Editor sections.
--
-- `scope` is what a given context is allowed to change. A barber may not
-- restyle your jaw, and a clothing shop may not change your eye colour. The
-- server enforces this, so a client asking to edit heritage in a barber chair
-- is refused rather than trusted.
-- ---------------------------------------------------------------------------

Config.Scopes = {
    -- Character creation: everything.
    creator  = { 'heritage', 'features', 'hair', 'overlays', 'apparel' },

    -- Barber: hair, facial hair, AND the face itself.
    --
    -- Face work is included because a character creator mistake is otherwise
    -- permanent, and "I have to delete and re-roll a character I have played
    -- for a month" is a worse outcome than the alternative.
    --
    -- The alternative is real though, and worth being deliberate about: a face
    -- that can be changed cheaply stops being an identity. Witnesses, mugshots
    -- and "I know who did it" all lean on the face staying put. Config.Pricing
    -- is what keeps it a repair rather than a disguise.
    barber   = { 'heritage', 'features', 'hair', 'overlays' },

    -- Clothing store: what you are wearing, nothing about your body.
    clothing = { 'apparel' },
}

-- ---------------------------------------------------------------------------
-- Camera
--
-- Three framings. The editor moves between them as the player changes section,
-- because adjusting a jaw while looking at boots is useless.
-- ---------------------------------------------------------------------------

Config.Camera = {
    fov = 32.0,
    -- Offsets are relative to the ped, in metres: forward, right, up.
    views = {
        head = { offset = vec3(0.65, 0.0, 0.65),  point = vec3(0.0, 0.0, 0.62) },
        body = { offset = vec3(2.10, 0.0, 0.15),  point = vec3(0.0, 0.0, 0.05) },
        legs = { offset = vec3(1.40, 0.0, -0.45), point = vec3(0.0, 0.0, -0.55) },
    },
    -- Which framing each section wants.
    sectionView = {
        heritage = 'head',
        features = 'head',
        hair     = 'head',
        overlays = 'head',
        apparel  = 'body',
    },
}

-- Rotating the ped is how you check the back of a haircut. Degrees per frame
-- while held.
Config.RotateSpeed = 2.0

-- ---------------------------------------------------------------------------
-- Pricing
--
-- Charged per SECTION actually changed, not per visit, and only for sections
-- outside creation. Creation is free: you have not earned anything yet.
--
-- Face work is priced an order of magnitude above a haircut on purpose. It has
-- to exist so a creation mistake is recoverable, but it must not be the casual
-- way to shed a description the police are circulating. Expensive and traceable
-- makes it a repair; cheap makes it a disguise.
--
-- Charged through som-core's transaction bus, so it lands in the ledger and
-- counts as an economy sink like anything else.
-- ---------------------------------------------------------------------------

Config.Pricing = {
    -- No account here. The player picks cash or card at the counter, the same
    -- control every SOM shop uses, and som-core validates the choice.
    sections = {
        hair     = 75,
        overlays = 50,
        features = 2500,
        heritage = 2500,
        apparel  = 0,      -- clothing shops price per garment, later
    },
}

-- Every face change is written to som_appearance_log with who and when.
-- Nothing reads it yet; som-police and the MDT will. A face that can change
-- silently is a face that cannot be investigated.
Config.LogFaceChanges = true

-- ---------------------------------------------------------------------------
-- World locations
--
-- The editor was reachable from character creation and from NOWHERE ELSE, so a
-- player built a face once and could never change it or their clothes again.
-- This is the missing half: a zone at every vanilla barber and clothing store
-- that calls openEditor with the matching scope.
--
-- SHARED rather than client, because the server distance-checks against the
-- same list before it charges anybody. A zone the client draws is not a
-- permission to edit; see server/main.lua.
--
-- These are the stock GTA V shop entrances. Any of them sitting under a custom
-- MLO wants its coordinate corrected here rather than the zone removed, and
-- `radius` is where the circle appears while the option's own distance is how
-- close you must be to use it.
-- ---------------------------------------------------------------------------

Config.Locations = {
    barber = {
        radius = 1.5,
        distance = 2.0,
        label = 'Barber',
        prompt = 'Take a seat',
        icon = 'fa-solid fa-scissors',
        blip = { sprite = 71, colour = 0, scale = 0.6 },
        coords = {
            vec3(-814.31, -183.84, 37.57),   -- Bob Mulet, Rockford Hills
            vec3(136.83, -1708.4, 29.3),     -- Herr Kutz, Davis
            vec3(-1282.6, -1116.8, 6.99),    -- Beach Combover, Vespucci
            vec3(1931.51, 3729.67, 32.85),   -- Sandy Shores
            vec3(-278.09, 6228.46, 31.71),   -- Paleto Bay
            vec3(1212.83, -472.92, 66.21),   -- Hair on Hawick, Vinewood
        },
    },

    clothing = {
        radius = 1.5,
        distance = 2.0,
        label = 'Clothing Store',
        prompt = 'Browse the racks',
        icon = 'fa-solid fa-shirt',
        blip = { sprite = 73, colour = 0, scale = 0.6 },
        coords = {
            vec3(72.3, -1399.1, 29.38),      -- Binco, Strawberry
            vec3(-703.78, -152.32, 37.41),   -- Ponsonbys, Morningwood
            vec3(-167.86, -298.95, 39.73),   -- Suburban, Hawick
            vec3(428.69, -800.1, 29.49),     -- Suburban, Burton
            vec3(-829.4, -1073.7, 11.32),    -- Suburban, Del Perro
            vec3(-1193.43, -768.54, 17.32),  -- Binco, Del Perro
            vec3(-1447.8, -242.5, 49.82),    -- Ponsonbys, Del Perro Plaza
            vec3(11.63, 6514.22, 31.88),     -- Binco, Paleto Bay
            vec3(123.64, -219.44, 54.56),    -- Discount Store, Pillbox Hill
            vec3(1696.36, 4829.34, 42.06),   -- Binco, Grapeseed
            vec3(618.09, 2759.63, 42.09),    -- Binco, Harmony
            vec3(1190.31, 2713.44, 38.22),   -- Binco, Route 68
            vec3(-3172.5, 1048.1, 20.86),    -- Binco, Chumash
            vec3(-1108.4, 2708.92, 19.11),   -- Binco, Great Chaparral
        },
    },
}

-- How far the SERVER will accept a save from, per scope. Deliberately looser
-- than the interaction distance: the client's coordinates lag the server's, and
-- refusing a real haircut is worse than the metre it gives away.
Config.SaveDistance = 20.0
