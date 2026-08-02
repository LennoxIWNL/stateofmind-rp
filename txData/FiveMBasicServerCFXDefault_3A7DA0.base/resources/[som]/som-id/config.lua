Config = {}

-- ---------------------------------------------------------------------------
-- Showing a document is an interaction, not a broadcast.
--
-- You hold it out and the people around you can read it. Anyone else cannot,
-- including somebody standing directly above or below you, which is why there
-- is a separate vertical tolerance: a flat radius would push your ID through
-- the ceiling of a police lobby to the floor above.
-- ---------------------------------------------------------------------------

Config.Show = {
    -- Horizontal reach, metres. Roughly conversation distance.
    radius = 6.0,
    -- Vertical tolerance, metres. Smaller than a storey so floors separate.
    zTolerance = 2.5,

    -- How long the card stays on screen for viewers, milliseconds.
    duration = 12000,

    -- The holder sees their own card for longer, since they are reading it
    -- rather than glancing at it.
    ownDuration = 20000,
}

-- Holding the document out. This dict is the one dpemotes uses for its notepad
-- emote and ox_inventory uses for lockpicking, so it is known to exist in the
-- installed build rather than assumed from memory.
Config.Anim = {
    dict = 'missheistdockssetup1clipboard@base',
    clip = 'base',
    duration = 4000,
    -- 49 is looping and upper body only, so showing ID does not root you.
    flag = 49,
}

-- ---------------------------------------------------------------------------
-- Documents
--
-- Each maps an inventory item to a card layout. `licence` names an entry in
-- som_licenses; when set, the card shows whether it is actually held, so a
-- revoked licence is visibly revoked rather than quietly missing.
-- ---------------------------------------------------------------------------

Config.Documents = {
    id_card = {
        label = 'Identity Card',
        issuer = 'San Andreas Department of Motor Vehicles',
        accent = '#ff1493',
        fields = { 'name', 'dob', 'sex', 'nationality', 'citizenid' },
    },

    driver_license = {
        label = 'Driver Licence',
        issuer = 'San Andreas Department of Motor Vehicles',
        accent = '#4a9eff',
        licence = 'driver',
        fields = { 'name', 'dob', 'sex', 'citizenid' },
    },

    weaponlicense = {
        label = 'Firearms Permit',
        issuer = 'San Andreas State Government',
        accent = '#f0932b',
        licence = 'weapon',
        fields = { 'name', 'dob', 'citizenid' },
    },
}
