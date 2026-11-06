Config = {}

Config.Debug = false

Config.Characters = {
    -- No character may be a minor. Enforced server side in Characters.Create,
    -- and used by the client to default and bound the date picker.
    -- A written backstory is required at creation (AUDIT 18.6), stored in the
    -- character's metadata and shown to staff.
    backstoryMin = 100,
    backstoryMax = 1000,

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

    -- -----------------------------------------------------------------------
    -- Accounts a SHOP may be paid from, and the order they are offered in.
    --
    -- Every shop lets the player choose cash or card, so this is one list
    -- rather than a decision each shop makes for itself. crypto and dirty are
    -- absent deliberately: paying a till in laundered money would make
    -- laundering pointless, and that is the whole tension the economy is
    -- built on.
    --
    -- Enforced by Money.PayWith, so a client naming any other account is
    -- refused rather than trusted.
    -- -----------------------------------------------------------------------
    payable = { 'cash', 'bank' },

    payableLabels = {
        cash = 'Cash',
        bank = 'Card',
    },
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

-- Hunger and thirst decay.
--
-- These existed as metadata and as bounds from the first commit, and food and
-- drink moved them, but nothing ever moved them DOWNWARD, so in practice a
-- character sat at 100 and 100 for their whole life and the bars were
-- decoration. Server side, because every other write to these keys is.
--
-- At these rates a full character empties in a little over two hours of
-- connected play. Nothing happens at zero yet: the consequence is a Phase 2
-- decision and belongs with som-medical, not here.
Config.Needs = {
    intervalMinutes = 5,
    hungerPerInterval = 4,
    thirstPerInterval = 5,
}

-- What using an item does to the needs, in points on the 0 to 100 bars. Applied on the
-- server when ox_inventory reports the item used. Every item in ox_inventory's
-- data/items.lua that has `client.status` needs an entry here with the same value
-- divided by 10000 (a test checks it).
Config.ItemStatus = {
    testburger = { hunger = 20 },
    burger = { hunger = 20 },
    sandwich = { hunger = 20 },
    water = { thirst = 20 },
    cola = { thirst = 20 },
    sprunk = { thirst = 20 },
    mustard = { hunger = 2.5, thirst = 2.5 },
    panties = { thirst = -10, stress = -2.5 },
}

-- Metadata keys created on every new character. Anything not listed here is
-- rejected by SetMetadata, so a compromised client cannot invent state.
Config.DefaultMetadata = {
    backstory = '',
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

-- ---------------------------------------------------------------------------
-- World behaviour
--
-- Client side only. None of this decides anything a server would care about; it
-- decides how the WORLD behaves around a player, which is a rendering and
-- ambience question.
--
-- The NPC police suppression is the load-bearing part. GTA's own police respond
-- to crime with infinite units and a wanted star system that has nothing to do
-- with som-police, so without this every shooting summons vanilla cops who
-- shoot back and arrest nobody, and the entire player police force is
-- decoration. Every serious roleplay server turns this off.
-- ---------------------------------------------------------------------------

Config.World = {
    -- Vanilla police, their dispatch, their helicopters and their road blocks.
    suppressNpcPolice = true,

    -- The wanted star system. Separate from the above because a server that
    -- wants NPC police as ambient traffic might still want no stars.
    suppressWantedLevel = true,

    -- The police scanner chatter that plays when the player commits a crime.
    -- Pure audio, and it narrates a wanted system that no longer exists.
    suppressPoliceScanner = true,

    -- How often the suppression is re-applied, in milliseconds. These are not
    -- one-shot settings: entering a new session, respawning and some cutscenes
    -- all reset parts of them, so they are refreshed rather than set once. Slow
    -- enough that it is not a per-frame loop, which CLAUDE.md forbids.
    refreshInterval = 5000,
}

-- ACE groups, checked with IsPlayerAceAllowed. Never a client-sent flag.
Config.Permissions = {
    god = 'som.god',
    admin = 'som.admin',
    mod = 'som.mod',
    -- Ordered most privileged first, used by som:server:hasPermission.
    hierarchy = { 'som.god', 'som.admin', 'som.mod' },

    -- -----------------------------------------------------------------------
    -- OWNERS ARE ALSO MATCHED BY IDENTIFIER, AS A BELT-AND-BRACES FALLBACK.
    --
    -- ACE DOES resolve on this server now. Moving the permissions block above
    -- the ensure lines in som.cfg fixed it, and som-core confirms it at boot:
    --
    --   [som-core] permissions: cfg marker som-cfg-exec-ok | group.god=1 |
    --              owner identifier=true
    --
    -- This note used to say ACE had never resolved. That was true when it was
    -- written and stale afterwards, and it cost a debugging session: a staff
    -- command that did nothing was blamed on ACE when ACE was fine. Trust the
    -- boot line over this comment, and correct this comment if it disagrees.
    --
    -- The identifier match is kept anyway, because it costs nothing and means
    -- whoever owns the server can still administer it if ACE ever breaks again.
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
