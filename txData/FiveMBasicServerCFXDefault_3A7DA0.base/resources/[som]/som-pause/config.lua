Config = {}

-- ---------------------------------------------------------------------------
-- som-pause replaces the GTA pause menu outright.
--
-- The native menu is suppressed the moment it opens and this NUI takes over.
-- That is what removes the beige frontend wash: it is part of the native menu
-- render, so it cannot be recoloured, only replaced. We call the screen blur
-- ourselves and put the tint in CSS instead.
-- ---------------------------------------------------------------------------

-- Tint drawn over the blurred world. Pure CSS, so any rgba value works.
-- Raise the alpha for a heavier wash.
Config.Overlay = {
    tint = 'rgba(255, 20, 147, 0.13)',
    blurMs = 150,
}

-- ---------------------------------------------------------------------------
-- Map
--
-- The map tab shows the real game map through a transparent hole in the NUI,
-- using the expanded radar. That means live blips, live player position and
-- the streamed map textures, with no image asset to keep in sync.
--
-- The coloured map with no street names comes from the karma-minimap resource
-- already in [assets-streams]/[graphics]. It replaces minimap_main_map.gfx,
-- which is the pause map, so both the minimap and this tab pick it up.
-- ---------------------------------------------------------------------------

Config.Map = {
    -- Set false to leave the expanded radar wherever the game puts it, which
    -- is the safe fallback if the values below fight your resolution.
    reposition = true,

    -- Anchored left/bottom, normalised to screen size. Tune these to line the
    -- map up with the hole in the UI, then restart the resource. They are
    -- deliberately config rather than computed: aspect ratios vary and there
    -- is no native that reports where the expanded radar actually landed.
    posX = 0.150,
    posY = 0.075,
    sizeX = 0.820,
    sizeY = 0.780,

    -- Street names are a HUD component, not part of the map texture, so they
    -- are hidden here rather than by swapping the map.
    hideStreetNames = true,
}

-- ---------------------------------------------------------------------------
-- Tabs
--
-- Order is the display order. `ace` restricts a tab to a permission group,
-- checked server side before the tab is ever sent.
-- ---------------------------------------------------------------------------

Config.Tabs = {
    { id = 'map',        label = 'Map',        icon = 'map' },
    { id = 'character',  label = 'Character',  icon = 'user' },
    { id = 'server',     label = 'Server',     icon = 'globe' },
    { id = 'staff',      label = 'Staff',      icon = 'shield', ace = 'som.mod' },
    { id = 'disconnect', label = 'Disconnect', icon = 'power' },
}

Config.Server = {
    name = 'State of Mind RP',
    tagline = 'Los Santos, on your terms.',
    discord = 'discord.gg/stateofmind',
}

-- ---------------------------------------------------------------------------
-- Destinations
--
-- Replacing the native menu costs one thing: you can no longer click the map
-- to drop a waypoint, because NUI holds the cursor and the game never sees the
-- click. There is no native that converts a screen point on the expanded radar
-- back to world coordinates, so it cannot be recreated faithfully.
--
-- This is the replacement, and for the destinations people actually pick it is
-- faster than hunting across a map. Add entries as the map fills out.
--
-- Coordinates are approximate street-level anchors, not precise door markers.
-- ---------------------------------------------------------------------------

Config.Waypoints = {
    { label = 'Legion Square',        category = 'City',     coords = vec2(195.0, -933.0) },
    { label = 'Pillbox Medical',      category = 'Services', coords = vec2(298.0, -584.0) },
    { label = 'Mission Row PD',       category = 'Services', coords = vec2(441.0, -982.0) },
    { label = 'Pacific Standard',     category = 'Services', coords = vec2(235.0, 216.0) },
    { label = 'Los Santos Customs',   category = 'Vehicles', coords = vec2(731.0, -1088.0) },
    { label = "Benny's Motorworks",   category = 'Vehicles', coords = vec2(-205.0, -1310.0) },
    { label = 'LS International',     category = 'Transit',  coords = vec2(-1037.0, -2737.0) },
    { label = 'Del Perro Pier',       category = 'City',     coords = vec2(-1850.0, -1230.0) },
    { label = 'Vespucci Beach',       category = 'City',     coords = vec2(-1230.0, -1500.0) },
    { label = 'Vinewood Hills',       category = 'City',     coords = vec2(300.0, 180.0) },
    { label = 'Diamond Casino',       category = 'City',     coords = vec2(925.0, 46.0) },
    { label = 'Sandy Shores',         category = 'County',   coords = vec2(1961.0, 3740.0) },
    { label = 'Grapeseed',            category = 'County',   coords = vec2(1700.0, 4900.0) },
    { label = 'Paleto Bay',           category = 'County',   coords = vec2(-110.0, 6470.0) },
}
