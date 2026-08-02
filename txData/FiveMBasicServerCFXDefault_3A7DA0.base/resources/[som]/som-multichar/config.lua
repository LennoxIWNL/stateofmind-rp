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
    enabled = true,

    -- Vanilla high-end apartment shell. Alternatives worth trying:
    --   apa_mp_h_str_int_shell_01  through  _09   (high end apartments)
    --   ex_mp_h_int_office_...                    (executive offices)
    model = 'apa_mp_h_str_int_shell_01',

    -- Deep below the map, well clear of any real geometry. This is the area
    -- FiveM shell interiors conventionally occupy.
    coords = vec3(144.58, -1002.36, -100.0),

    -- Where the character stands, relative to the shell origin.
    pedOffset = vec3(0.0, 0.0, 0.0),
    pedHeading = 180.0,

    -- Where the camera sits, relative to the shell origin, and what it aims at.
    camOffset = vec3(0.0, 2.6, 0.4),
    camLookAtOffset = vec3(0.0, 0.0, 0.15),

    -- Slow drift so the shot is not a dead still frame.
    orbit = {
        enabled = true,
        degrees = 9.0,    -- total sweep, half either side of centre
        seconds = 26.0,   -- one full there-and-back cycle
    },
}

-- Used only when Config.Shell.enabled is false. The long-standing
-- qb-multicharacter location, kept as a known-good fallback.
Config.Fallback = {
    interior = vec3(-814.89, 181.95, 76.85),
    cam      = vec4(-813.46, 178.95, 76.85, 174.5),
    ped      = vec4(-813.97, 176.22, 76.74, -7.5),
}

-- Where the real player ped is parked, hidden, during selection. Kept away
-- from the shell so it can never appear in shot.
Config.HiddenCoords  = vec4(-812.23, 182.54, 76.74, 156.5)

-- Fallback spawn when a character has no stored position.
-- Mirrors som-core Config.Characters.defaultSpawn.
Config.DefaultSpawn  = vec4(-1035.71, -2731.87, 12.86, 328.0)

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
