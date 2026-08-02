Config = {}

-- ---------------------------------------------------------------------------
-- som-pause is a BAR, not a menu.
--
-- A full custom pause menu was built and thrown away: it was a lot of chrome
-- around things the game already does better, and replacing the native menu
-- cost click-to-waypoint with nothing to show for it.
--
-- What is left is the part worth keeping. Escape shows a slim branded bar over
-- the blurred world, and the map and settings hand straight back to the native
-- frontend. That is also the only way to get a pink overlay instead of the
-- beige one: the beige is part of the native menu render and cannot be
-- recoloured, only avoided.
-- ---------------------------------------------------------------------------

-- Tint drawn over the blurred world. Pure CSS, so any rgba value works.
Config.Overlay = {
    tint = 'rgba(255, 20, 147, 0.13)',
    blurMs = 150,
}

-- ---------------------------------------------------------------------------
-- Actions
--
-- `frontend` is the last argument to ActivateFrontendMenu. Opening one hands
-- control back to the game and closes this bar.
--   -1  map
--    6  settings
-- ---------------------------------------------------------------------------

Config.Actions = {
    { id = 'map',        label = 'Map',        icon = 'map',      frontend = -1 },
    { id = 'settings',   label = 'Settings',   icon = 'settings', frontend = 6 },
    { id = 'disconnect', label = 'Disconnect', icon = 'power' },
}

Config.Server = {
    name = 'State of Mind RP',
}
