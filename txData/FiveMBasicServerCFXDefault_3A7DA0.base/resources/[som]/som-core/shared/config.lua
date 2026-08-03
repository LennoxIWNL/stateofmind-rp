Config = {}

Config.Debug = false

Config.Characters = {
    -- No character may be a minor. Enforced server side in Characters.Create,
    -- and used by the client to default and bound the date picker.
    minimumAge = 18,
    maximumAge = 90,

    maxSlots = 5,
    startingCash = 500,
    startingBank = 5000,
    -- Given once, on character creation only. Enough to not be stranded:
    -- a phone, ID, and basic food and water.
    --
    -- Deliberately the cheap consumables, not restaurant food. Player-run
    -- restaurants need to be worth visiting, so the starter items should keep
    -- someone alive without competing with them.
    -- `sandwich` rather than bread: ox_inventory has no bread item, and
    -- sandwich is the plain consumable. The burgershot_* items belong to the
    -- player-run restaurant and should stay worth buying.
    welcomeGift = {
        { item = 'phone',    count = 1 },
        { item = 'id_card',  count = 1 },
        { item = 'water',    count = 10 },
        { item = 'sandwich', count = 10 },
    },

    -- Where a brand new character spawns before housing exists.
    -- LSIA upper deck. Mirrored in som-multichar Config.DefaultSpawn: the two
    -- must be changed together. The z is an estimate, see the note there.
    defaultSpawn = vec4(-1035.71, -2731.87, 20.17, 328.0),
}

Config.Money = {
    accounts = { 'cash', 'bank', 'crypto', 'dirty' },
    -- Accounts a player may never move money into or out of directly.
    -- 'dirty' only changes through laundering in Phase 4.
    protected = { dirty = true },
    -- Paychecks are HOURLY. Job `payment` values are therefore per hour, not
    -- per tick, which makes them directly comparable to prices.
    paycheckInterval = 60,

    -- Absolute ceiling on paycheck income, enforced in payroll regardless of
    -- what any job config claims. Nobody earns more than this per hour from
    -- wages, ever. Commission and business profit sit outside it, but a salary
    -- alone can never exceed this.
    maxHourlyPaycheck = 5000,

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
    -- Set once the welcome gift has been handed over, so it cannot be farmed
    -- by relogging. Metadata keys not listed here are rejected by setMetadata.
    welcomed = false,
    -- Restraint state. som-theft gates cash robbery on these, so they are
    -- framework state rather than something a job script keeps to itself.
    cuffed = false,
    handsup = false,
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

    -- -----------------------------------------------------------------------
    -- OWNERS ARE MATCHED BY IDENTIFIER, NOT BY ACE.
    --
    -- ACE has never resolved on this server. The cfg provably executes, the
    -- grants are present and correctly ordered, and IsPlayerAceAllowed still
    -- returns false for an identifier that is listed. Re-applying them from Lua
    -- was refused outright: granting an ACE itself requires one.
    --
    -- Rather than keep guessing, ownership is settled here by a direct
    -- identifier match that cannot fail. ACE is still declared in som.cfg and
    -- still governs everyone else; this only guarantees that whoever owns the
    -- server can always administer it.
    -- -----------------------------------------------------------------------

    -- Who gets what, by identifier. `license:` is the reliable one: it works
    -- without Steam and is what the server sees whatever the player launched
    -- from.
    --
    -- NOTE: these are committed to the repository. A Rockstar license
    -- identifier is not a secret, it identifies rather than authenticates, but
    -- if this repo ever goes public, move this list to a convar.
    owners = {
        ['license:1edd18060d34914e203e0036ff7ea5ae0a06ae7e'] = 'group.god',
    },
}
