Config = {}

-- ---------------------------------------------------------------------------
-- Feedback sounds
--
-- The game's OWN frontend sound sets, not audio files lifted from another
-- script. Three reasons: they are guaranteed present on every client with no
-- streaming and no licence question, they cost nothing to download, and they
-- are sounds players already associate with these actions in this game, so they
-- read correctly without being taught.
--
-- Named here rather than at each call site, which is what stops a purchase in
-- the armoury and a purchase in a future dealership drifting into two different
-- sounds. Same reasoning, and the same `set`/`name` shape, as som-phone's
-- Config.Sounds.
--
-- `set` and `name` map to PlaySoundFrontend(-1, name, set, true).
--
-- CONFIDENCE. These are the widely used frontend sets and every one is believed
-- correct, but none has been heard on this server yet. If one is silent it is a
-- wrong string rather than broken code, and it is a one line fix here. That is
-- the whole reason they are config and not literals.
-- ---------------------------------------------------------------------------

Config.Sounds = {
    enabled = true,

    -- A purchase completing. The liquor store set is the one GTA itself uses
    -- for buying something over a counter.
    purchase = { set = 'HUD_LIQUOR_STORE_SOUNDSET', name = 'PURCHASE' },

    -- Something worked, but no money moved: an item drawn from department
    -- issue, a vehicle stored, a door unlocked.
    success = { set = 'HUD_MINI_GAME_SOUNDSET', name = 'CHECKPOINT_PERFECT' },

    -- A refusal. Deliberately the same sound the pause menu uses when you
    -- cannot do something, because players already read it as "no".
    error = { set = 'HUD_FRONTEND_DEFAULT_SOUNDSET', name = 'ERROR' },

    -- Picking something in a list.
    select = { set = 'HUD_FRONTEND_DEFAULT_SOUNDSET', name = 'SELECT' },

    -- Moving through a list without committing.
    nav = { set = 'HUD_FRONTEND_DEFAULT_SOUNDSET', name = 'NAV_UP_DOWN' },

    -- Leaving a menu.
    back = { set = 'HUD_FRONTEND_DEFAULT_SOUNDSET', name = 'BACK' },
}
