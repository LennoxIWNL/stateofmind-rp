Config = {}

-- The phone is a PHYSICAL ITEM. It can be lost, stolen and confiscated, which
-- is consistent with cash being stealable through som-theft, and gives police
-- something meaningful to seize.
--
-- Because of that there must always be a way back: see Config.Replacement.
Config.Item = 'phone'
Config.RequireItem = true

Config.OpenKey = 'M'

-- ---------------------------------------------------------------------------
-- Animation
--
-- The phone is visible in the world: the character takes it out to use it and
-- puts it away when the UI closes, so other players can see who is on their
-- phone. That readability is the point, not the polish.
--
-- Clip names are the two verified against the installed game build (pa-radio
-- and dpemotes both use them). The cellphone@ dict also has in/out clips, but
-- they are not used here because they could not be confirmed locally: the
-- blend in and out already reads as taking it out and putting it away.
-- ---------------------------------------------------------------------------

Config.Animation = {
    enabled = true,

    dict = 'cellphone@',
    hold = 'cellphone_text_read_base',
    -- Held to the ear. Used by som-phone's call API in 4b-2.
    call = 'cellphone_call_listen_base',

    prop = 'prop_npc_phone_02',
    -- PH_R_Hand. The clips are authored around the phone being in the right
    -- hand, so this is not a preference.
    bone = 28422,
    offset = vec3(0.0, 0.0, 0.0),
    rotation = vec3(0.0, 0.0, 0.0),

    blendIn = 3.0,
    blendOut = 2.0,
}

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

        -- Billing needs the target's account to have been shared with you, and
        -- recently. Transfers deliberately do NOT: you can send money to any
        -- number, but you cannot demand it from a stranger whose number you
        -- happened to overhear a week ago.
        requireShared = true,
        sharedWindowHours = 24,

        -- Billing yourself. Off in a normal economy, on here so a single player
        -- can exercise the whole flow without a second character online.
        allowSelf = true,

        -- Bills raised with auto collection settle themselves if ignored. This
        -- exists for police fines: refusing to open your phone should not be a
        -- way to dodge one. Nothing sets it yet, som-police will.
        autoCollectDays = 7,
        -- How often the collector sweeps, in minutes.
        autoCollectInterval = 15,
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

-- ---------------------------------------------------------------------------
-- Notification sounds
--
-- The game's OWN phone sound set, not an audio file lifted from another script.
-- Two reasons: it is guaranteed present on every client with no streaming and
-- no licence question, and it is the sound players already associate with a
-- phone in this game, so it reads as a notification without being taught.
--
-- `set` and `name` map to PlaySoundFrontend(-1, name, set, true).
-- ---------------------------------------------------------------------------

Config.Sounds = {
    enabled = true,

    -- A message or a bill landing.
    notification = { set = 'Phone_SoundSet_Default', name = 'Text_Arrive_Tone' },

    -- Reserved. Messages and calls will want their own, and naming them here
    -- rather than at the call site is what stops them drifting apart.
    message = { set = 'Phone_SoundSet_Default', name = 'Text_Arrive_Tone' },
    call     = { set = 'Phone_SoundSet_Michael', name = 'Remote_Ring' },
}
