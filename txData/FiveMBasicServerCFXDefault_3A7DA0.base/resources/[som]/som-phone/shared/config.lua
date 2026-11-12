Config = {}

-- The phone is a PHYSICAL ITEM. It can be lost, stolen and confiscated, which
-- is consistent with cash being stealable through som-theft, and gives police
-- something meaningful to seize.
--
-- Because of that there must always be a way back: see Config.Replacement.
Config.Item = 'phone'
Config.RequireItem = true

Config.OpenKey = 'M'

-- The action pipeline: every request the phone makes goes through one server
-- function that checks these before an app sees it.
Config.Pipeline = {
    maxPayload = 4096,        -- characters of strings and keys in one request, nesting included
    maxDepth = 5,
    readsPerMinute = 90,      -- per player per action
    writesPerMinute = 20,
}

Config.Messages = { maxLength = 280, threadLimit = 40, historyLimit = 60 }

Config.Contacts = { max = 100, nameLength = 32 }

-- The public feed ("Chirp") and Pages. Everything here is re-checked on the server.
Config.Social = {
    postLength = 280,
    postGapSeconds = 20,       -- between two posts by one character
    postsPerDay = 40,
    feedSize = 30,
    replySize = 40,
    handleChangeHours = 24,

    -- Images are shown by URL, so a viewer's client fetches them from that
    -- host. Only hosts listed here are accepted; empty means no images. Set
    -- this to the image host the server chose (see LAUNCH-TODO.md).
    imageHosts = {},

    -- A custom handle cannot be one of these or start with one, so nobody can
    -- pose as a department or the staff.
    reserved = { 'police', 'lspd', 'bcso', 'sasp', 'sheriff', 'ems', 'doj', 'court', 'judge', 'gov', 'mayor',
        'admin', 'staff', 'mod', 'moderator', 'support', 'official', 'som', 'news', 'dispatch', 'system' },

    -- A supporter with the twitterColour perk may pick from the first N of these
    -- (N is the perk's value). Purely a text colour.
    colours = { '#ff6b9d', '#4a9eff', '#2ecc71', '#f0932b', '#e566e8', '#f1c40f' },
}

Config.Pages = {
    categories = { 'for_sale', 'wanted', 'services', 'business', 'property', 'vehicles', 'other' },
    expireHours = 48,
    maxActive = 3,
    titleLength = 48,
    bodyLength = 280,
    priceLength = 24,
    searchMin = 3,
    searchLimit = 10,
    feedSize = 40,
}

-- Garage, Services and Notes.
Config.City = {
    -- Counts are only shown where knowing them gives no one an edge. Police and
    -- ambulance staffing is the thing a heist crew would love to read.
    services = {
        { job = 'mechanic', label = 'Mechanic', showCount = true },
        { job = 'taxi', label = 'Taxi', showCount = true },
        { job = 'realtor', label = 'Real estate', showCount = true },
        { job = 'cardealer', label = 'Car dealer', showCount = true },
    },
    emergencyGapSeconds = 30,
    emergencyLength = 140,

    notes = { max = 30, titleLength = 40, bodyLength = 2000 },
    vehicleLimit = 60,
}

-- A call is a server record. The server picks the voice channel, and the
-- number is large and random so a channel cannot be guessed: pma-voice
-- registers its own net event that lets any client join any channel number,
-- which this resource cannot change.
Config.Calls = { ringSeconds = 30, historyLimit = 30, channelMin = 100000, channelMax = 2000000000 }

-- A passcode is four digits, stored as a salted hash. The pepper is a convar
-- (som_phone_pepper) so it never sits in a file clients download.
Config.Lock = {
    failsBeforeLock = 5,
    lockSeconds = 30,
}

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

-- ---------------------------------------------------------------------------
-- Card alerts
--
-- A banner when money moves on an account the player carries as a card. Cash is
-- deliberately excluded: cash changing hands is physical and visible, and a
-- phone alert for it would be noise.
--
-- `window` is the aggregation window. Buying three things at the armoury inside
-- it produces ONE banner reading "Purchase  -$1,450  (3)", not three banners.
-- Without this, a shop with a fast list is a phone that buzzes continuously.
-- ---------------------------------------------------------------------------

Config.CardAlerts = {
    enabled = true,

    -- Accounts that produce an alert, and how each is tagged on the line.
    -- Keys are som-core account names.
    --
    -- CASH IS HERE NOW, and this is the fix for "no notification when I buy
    -- from the armoury". Bank only was defensible as fiction, since a card
    -- alert is a card's business, and it was wrong in practice: som-core's
    -- payable order is { 'cash', 'bank' } and every shop defaults to the first
    -- account holding anything, so the ordinary case, paying with money in your
    -- pocket, produced no notification at all. The alert is really "your money
    -- moved", and cash moving is money moving.
    --
    -- A cash line is tagged so the two are still distinguishable. A bank line
    -- is not, because it is the default and tagging it would put a word on
    -- every alert to no purpose.
    accounts = {
        bank = { tag = nil },
        cash = { tag = 'Cash' },
    },

    -- Milliseconds.
    --
    -- Was 4000, which was far too long: the alert arrived so late it read as
    -- unrelated to what caused it. The window only has to cover a burst of
    -- clicks in one shop, not a whole shopping trip, and a person clicking
    -- through a list does it in well under a second per item.
    --
    -- Short enough to feel like a response, long enough that three quick
    -- purchases still arrive as one banner rather than three.
    window = 1200,

    -- Movements smaller than this are ignored entirely. Stops rounding and
    -- one dollar adjustments buzzing a phone.
    minAmount = 1,

    -- Prints the reason an alert was dropped.
    --
    -- Every gate below this line is silent by design, and the phone item check
    -- in particular looks exactly like a broken notification: no phone in the
    -- bag means no banner, correctly, and nothing anywhere says so. Turn this on
    -- when an alert that should have arrived did not.
    debug = false,
}

Config.Sounds = {
    enabled = true,

    -- A message or a bill landing.
    notification = { set = 'Phone_SoundSet_Default', name = 'Text_Arrive_Tone' },

    -- Reserved. Messages and calls will want their own, and naming them here
    -- rather than at the call site is what stops them drifting apart.
    message = { set = 'Phone_SoundSet_Default', name = 'Text_Arrive_Tone' },
    call     = { set = 'Phone_SoundSet_Michael', name = 'Remote_Ring' },
}
