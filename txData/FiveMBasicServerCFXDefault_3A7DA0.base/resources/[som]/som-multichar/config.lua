Config = {}

-- ---------------------------------------------------------------------------
-- Character preview scene
--
-- The scene is a SHELL: a vanilla interior prop spawned in the empty space far
-- below the map, with the ped and camera placed inside it. This is the standard
-- approach for character select backdrops and it beats standing in a real world
-- location for three reasons:
--
--   1. Nothing of the live world is visible behind it, so no traffic, weather
--      or other players leak into the shot.
--   2. It needs no streamed assets. The shell models below ship with the base
--      game, so the scene works even in dev mode where [assets-streams] is not
--      loaded. A custom MLO would simply not exist there.
--   3. Nothing has to be reserved on the real map.
--
-- Set Config.Shell.enabled = false to fall back to the plain world location in
-- Config.Fallback instead.
--
-- The offsets below are relative to Config.Shell.coords and WILL need tuning
-- in game: shell models differ in where their floor and walls sit. Nudge
-- pedOffset and camOffset until the framing looks right.
-- ---------------------------------------------------------------------------
Config.Shell = {
    -- OFF by default, and it needs a streamed shell resource to switch on.
    --
    -- Base-game GTA has no spawnable interior shell. The apa_mp_h_* models are
    -- apartment FURNITURE (bathtub, table, lamp), not rooms. Every shell used
    -- for character screens and housing scripts is a downloadable asset pack
    -- that has to be streamed.
    --
    -- Provided by jordqn_free_shells in [assets-streams]/[extras]. That
    -- resource must be started or the model will not exist: dev mode does not
    -- ensure [assets-streams], so server.cfg starts it by name.
    enabled = true,

    -- Others in the same pack: motel_low, warehouse_small, coke_business_empty.
    model = 'apart_luxe_1',

    -- Deep below the map, well clear of any real geometry. This is the area
    -- FiveM shell interiors conventionally occupy.
    coords = vec3(144.58, -1002.36, -100.0),

    -- Where the character stands, relative to the shell origin.
    -- Moved off the origin because the shell's origin sits in the bedroom.
    pedOffset = vec3(0.0, -2.2, 0.0),

    -- The camera sits at +y from the ped, and GTA heading 0 faces +y, so the
    -- character must be at 0 to look INTO the lens. 180 faces them away.
    pedHeading = 0.0,

    -- Camera offset from the SHELL origin. z is chest height, not floor level:
    -- at 0.4 the shot framed the character's knees.
    camOffset = vec3(0.0, 0.5, 1.15),
    camLookAtOffset = vec3(0.0, 0.0, 0.92),
}

-- Live tuning. With this on, a staff member can nudge the scene in game and
-- print values to paste back here, instead of guessing offsets blind and
-- restarting for every attempt. Turn off for production.
Config.SceneTuning = {
    enabled = true,
    ace = 'som.admin',
    step = 0.1,
}

-- The scene used when Config.Shell.enabled is false, which is the default.
--
-- The long-standing qb-multicharacter location. It is outdoors, so the trick is
-- framing: the camera sits close and shallow depth of field throws the city
-- behind the character into a soft wash. That reads as a deliberate portrait
-- rather than a player standing in a street.
Config.Fallback = {
    interior = vec3(-814.89, 181.95, 76.85),
    ped      = vec4(-813.97, 176.22, 76.74, 175.0),

    -- Camera offset from the ped, and what it aims at. Closer than a full body
    -- shot on purpose: less background in frame means less to look wrong.
    camOffset       = vec3(0.0, 1.9, 0.25),
    camLookAtOffset = vec3(0.0, 0.0, 0.05),
}

-- Scene lighting.
--
-- Time and weather are frozen while selecting, so the shot looks the same for
-- every player at every hour instead of being lit by whatever the server clock
-- happens to be doing. Restored on spawn.
Config.Scene = {
    freezeTimeAndWeather = true,
    hour = 20,
    minute = 15,
    weather = 'EXTRASUNNY',
}

-- Idle poses for the preview ped, picked at random so the character screen is
-- not identical every single time. Falls back gracefully if a dict is missing.
Config.IdleAnims = {
    { dict = 'anim@heists@heist_corona@team_idles@male_a', clip = 'idle' },
    { dict = 'amb@world_human_hang_out_street@male_c@idle_a', clip = 'idle_a' },
    { dict = 'anim@amb@nightclub@peds@', clip = 'rcmme_amanda1_stand_loop_cop' },
}

-- Cinematic descent on spawn: the camera starts high above the spawn point and
-- flies down into the player, rather than the world just cutting in.
Config.SpawnCinematic = {
    enabled = true,
    height = 55.0,     -- metres above the spawn point to start from
    distance = 14.0,   -- horizontal offset, so the move sweeps rather than drops
    duration = 2600,   -- milliseconds
}

-- Camera treatment, applied to whichever scene is active.
Config.Camera = {
    fov = 34.0,

    -- Pushes the character off centre so the UI rail on the left never covers
    -- them. Positive moves the character right in frame. In metres.
    subjectShift = 0.55,

    -- Shallow depth of field is what sells the shot. It keeps the character
    -- sharp and reduces the background to colour and shape.
    dof = { enabled = true, near = 0.4, far = 2.4, strength = 1.0 },

    -- Slow drift so the shot is not a dead frame.
    orbit = { enabled = true, degrees = 8.0, seconds = 24.0 },
}

-- Where the real player ped is parked, hidden, during selection. Kept away
-- from the shell so it can never appear in shot.
Config.HiddenCoords  = vec4(-812.23, 182.54, 76.74, 156.5)

-- Fallback spawn when a character has no stored position.
-- Mirrors som-core Config.Characters.defaultSpawn: change both together.
--
-- LSIA upper deck (departures). The z is an ESTIMATE, roughly 7m above the
-- arrivals road the old default sat on. Stand where you actually want the
-- spawn and press F11 to print exact coordinates, then paste them here.
Config.DefaultSpawn  = vec4(-1035.71, -2731.87, 20.17, 328.0)

-- Isolate each player into their own routing bucket during selection so nobody
-- sees preview peds standing in the interior. Reset to 0 once loaded.
Config.UseRoutingBuckets = true

-- Preview ped models. No clothing system exists yet (qb-clothing was removed in
-- the teardown and Phase 7 owns the replacement), so characters render as the
-- default freemode ped for their gender.
Config.PedModels = {
    [0] = 'mp_m_freemode_01',
    [1] = 'mp_f_freemode_01',
}

Config.Nationalities = {
    'American', 'British', 'Canadian', 'German', 'Italian', 'Mexican',
    'Japanese', 'Russian', 'French', 'Spanish', 'Irish', 'Australian',
    'Brazilian', 'Chinese', 'Dutch', 'Nigerian', 'Polish', 'Swedish',
}
