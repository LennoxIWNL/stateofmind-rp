Config = {}

-- ---------------------------------------------------------------------------
-- The pink wash over the pause menu.
--
-- 0-255 per channel. `a` is the one worth tuning: the native menu already
-- applies its own beige wash and we cannot remove it, so this sits on top of
-- that rather than replacing it. Too high and the two combine into mud.
--
-- Start low. It is meant to read as a tint on the world, not as a filter.
-- ---------------------------------------------------------------------------

Config.Tint = {
    r = 255,
    g = 20,
    b = 147,
    a = 38,
}
