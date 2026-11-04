--- som-evidence configuration. Data only: every value is re-checked server
--- side, so editing this changes what is offered, never what is allowed.

Config = {}

Config.Job = 'police'

Config.Items = {
    emptyBag = 'empty_evidence_bag',
    filledBag = 'filled_evidence_bag',
    dnaKit = 'dnatestkit',
    printReader = 'fingerprintreader',
    gsrKit = 'gsrtestkit',
}

-- fade is minutes before an uncollected trace is gone.
Config.Kinds = {
    casing      = { label = 'Bullet casing',       fade = 60,  lab = 10 },
    blood       = { label = 'Blood',               fade = 45,  lab = 15 },
    fingerprint = { label = 'Fingerprint',         fade = 120, lab = 10 },
    dna_sample  = { label = 'DNA sample',          reference = true, matches = 'blood' },
    print_sample = { label = 'Fingerprint sample', reference = true, matches = 'fingerprint' },
}

Config.Create = {
    casingGap = 3,        -- seconds between two casings from one shooter
    areaRadius = 6.0,
    areaCap = 6,          -- casings one shooter may have on the ground in that radius
}

Config.Collect = { range = 2.5, gap = 2 }
Config.Sample = { range = 3.0, needsCuffed = true }
Config.Scan = { range = 20.0, gap = 1, show = 45000 }
Config.Gsr = { windowMinutes = 45, consumeKit = true }

-- UNVERIFIED. Walk the station and correct these; /pdcoords prints a position
-- already formatted for a config file.
Config.Stations = {
    mrpd = {
        label = 'Mission Row',
        locker = vec3(474.7, -996.4, 26.3),
        lab = vec3(486.9, -987.6, 30.7),
        range = 3.0,
    },
}
