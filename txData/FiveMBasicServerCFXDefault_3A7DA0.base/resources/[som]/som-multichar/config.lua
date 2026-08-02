Config = {}

-- Character preview scene.
-- These are the long-standing qb-multicharacter defaults, kept because they are
-- a known-good enclosed interior with clean sightlines. Phase 7 can replace the
-- scene without touching any logic: only these five values move.
Config.Interior      = vec3(-814.89, 181.95, 76.85)
Config.CamCoords     = vec4(-813.46, 178.95, 76.85, 174.5)
Config.PedCoords     = vec4(-813.97, 176.22, 76.74, -7.5)
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
