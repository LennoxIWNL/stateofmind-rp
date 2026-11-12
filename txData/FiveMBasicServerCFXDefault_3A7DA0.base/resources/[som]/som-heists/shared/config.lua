Config = {
    dongleItem = 'trojan_usb',
    minutes = 30,
    interactDistance = 6.0,

    -- Three tiers, from a corner store to the city vault. Clean cash is paid by
    -- the treasury and is capped per rolling hour for the whole server, so a
    -- bad week of heists cannot drain the city. Marked bills are NOT paid by the
    -- treasury: som-launder mints them against its own ledger and they only
    -- become spendable by washing them at a front.
    tiers = {
        store = {
            label = 'Store robbery', policeMin = 1, minSize = 1, maxSize = 2, slots = 1, cooldownMinutes = 45,
            hack = { kind = 'memory', level = 'easy' },
            clean = { min = 800, max = 1800 }, hourlyCleanCap = 4000,
            marked = { count = 2, worth = 300 },
        },
        bank = {
            label = 'Small bank', policeMin = 3, minSize = 2, maxSize = 4, slots = 1, cooldownMinutes = 90,
            hack = { kind = 'crack', level = 'normal' },
            clean = { min = 4000, max = 8000 }, hourlyCleanCap = 12000,
            marked = { count = 5, worth = 800 },
        },
        vault = {
            label = 'City vault', policeMin = 5, minSize = 3, maxSize = 6, slots = 1, cooldownMinutes = 240,
            hack = { kind = 'crack', level = 'hard' },
            clean = { min = 10000, max = 20000 }, hourlyCleanCap = 25000,
            marked = { count = 8, worth = 1500 },
        },
    },

    -- EVERY site ships disabled. A site is usable only when enabled is true and
    -- it has terminal coordinates and loot points. Fill these on the real map
    -- (LAUNCH-TODO.md). `doors` are ox_doorlock names opened after the hack.
    sites = {
        { id = 'store_1', tier = 'store', label = 'Corner store', enabled = false, terminal = nil, doors = {}, lootPoints = {} },
        { id = 'bank_1', tier = 'bank', label = 'Small bank', enabled = false, terminal = nil, doors = {}, lootPoints = {} },
        { id = 'vault_1', tier = 'vault', label = 'City vault', enabled = false, terminal = nil, doors = {}, lootPoints = {} },
    },
}
