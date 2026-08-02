Config = {}

Config.Debug = false

Config.Characters = {
    maxSlots = 5,
    startingCash = 500,
    startingBank = 5000,
    -- Where a brand new character spawns before housing exists.
    defaultSpawn = vec4(-1035.71, -2731.87, 12.86, 328.0),
}

Config.Money = {
    accounts = { 'cash', 'bank', 'crypto', 'dirty' },
    -- Accounts a player may never move money into or out of directly.
    -- 'dirty' only changes through laundering in Phase 4.
    protected = { dirty = true },
    -- Paycheck cadence in minutes. Payroll always debits a business account,
    -- it never mints money. See som-core/server/money.lua.
    paycheckInterval = 10,
    payOffDutyByDefault = false,
}

Config.Save = {
    -- Periodic character flush in minutes. Also runs on drop and on shutdown.
    intervalMinutes = 5,
}

-- Metadata keys created on every new character. Anything not listed here is
-- rejected by SetMetadata, so a compromised client cannot invent state.
Config.DefaultMetadata = {
    hunger = 100,
    thirst = 100,
    stress = 0,
    armor = 0,
    isdead = false,
    inlaststand = false,
    injuries = {},
    bleeding = 0,
    fingerprint = nil,
    callsign = nil,
    jailtime = 0,
    licenses = {},
}

-- Numeric metadata bounds, enforced server side in SetMetadata.
Config.MetadataBounds = {
    hunger = { 0, 100 },
    thirst = { 0, 100 },
    stress = { 0, 100 },
    armor = { 0, 100 },
    bleeding = { 0, 4 },
    jailtime = { 0, 10000 },
}

-- ACE groups, checked with IsPlayerAceAllowed. Never a client-sent flag.
Config.Permissions = {
    god = 'som.god',
    admin = 'som.admin',
    mod = 'som.mod',
    -- Ordered most privileged first, used by som:server:hasPermission.
    hierarchy = { 'som.god', 'som.admin', 'som.mod' },
}
