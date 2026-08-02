Config = {}

-- The phone is a PHYSICAL ITEM. It can be lost, stolen and confiscated, which
-- is consistent with cash being stealable through som-theft, and gives police
-- something meaningful to seize.
--
-- Because of that there must always be a way back: see Config.Replacement.
Config.Item = 'phone'
Config.RequireItem = true

Config.OpenKey = 'M'

-- Cheap on purpose. Losing your phone should be an inconvenience worth
-- roleplaying, not a disaster that locks you out of banking for a week.
Config.Replacement = {
    price = 350,
    account = 'bank',
}

-- ---------------------------------------------------------------------------
-- Bank app
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- IDENTIFIER FORMATTING
--
-- Numbers players see and share, account numbers, phone numbers, anything read
-- aloud or typed into an app, are DIGITS ONLY. No branded prefix.
--
-- In game these appear on yellowpages adverts, get read out over voice and get
-- saved as contacts. A "SOM-" in front reads as a script artefact rather than a
-- number, and breaks the illusion the rest of the phone is trying to build.
--
-- Applies to every app added later: contacts, calls, yellowpages, Twitter.
-- ---------------------------------------------------------------------------

Config.Bank = {
    -- How many ledger rows the app pulls. Full history, own account only.
    historyLimit = 100,

    -- Sharing your account number broadcasts to players within this radius.
    -- Enforced server side.
    shareRadius = 8.0,

    -- Bills are REQUESTS. Money only moves when the recipient accepts, so a
    -- leaked account number can never drain anyone.
    bill = {
        minimum = 1,
        maximum = 500000,
        -- A player may not have more than this many bills outstanding against
        -- them from one sender, which stops bill spam being used as harassment.
        maxPendingPerSender = 3,
    },
}

-- ---------------------------------------------------------------------------
-- Apps
--
-- The registry is the point of the architecture: other resources add their own
-- apps rather than this resource knowing about every feature. som-jobs and
-- som-gangs will use it, and it is how the Twitter app arrives in 4b-2.
--
-- `perk` gates an app behind a supporter entitlement, checked server side.
--
-- `icon` is a name from the ICONS table in html/app.js, not a glyph. Names
-- already drawn: bank, settings, message, phone, contacts, camera, twitter,
-- dispatch, briefcase. Anything unrecognised falls back to rendering the
-- string itself, so a third-party app passing an emoji still works.
-- ---------------------------------------------------------------------------

Config.Apps = {
    {
        id = 'bank',
        label = 'Bank',
        icon = 'bank',
        colour = '#2ecc71',
        order = 10,
    },
    {
        id = 'settings',
        label = 'Settings',
        icon = 'settings',
        colour = '#8e8e93',
        order = 90,
    },
}

-- ---------------------------------------------------------------------------
-- Themes
--
-- 'default' is free. Everything else is a supporter perk, validated server side
-- against Entitlements rather than trusted from the client.
-- ---------------------------------------------------------------------------

Config.Themes = {
    default = { label = 'State of Mind', accent = '#ff1493', perk = nil },
    midnight = { label = 'Midnight',     accent = '#4a9eff', perk = 'phoneTheme' },
    ember    = { label = 'Ember',        accent = '#ff6b35', perk = 'phoneTheme' },
    mono     = { label = 'Monochrome',   accent = '#e0e0e0', perk = 'phoneTheme' },
}
