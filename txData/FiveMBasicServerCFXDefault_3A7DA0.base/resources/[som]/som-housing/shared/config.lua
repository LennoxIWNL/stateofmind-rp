--- som-housing configuration.
---
--- The rule som-garage states and this follows: CONFIG DECIDES WHAT IS OFFERED,
--- NEVER WHAT IS ALLOWED. Every price, tier and door below is re-read server
--- side at the moment of purchase. A client sends a property slug and nothing
--- else, never a price and never whether something is for sale.

Config = {}

-- ---------------------------------------------------------------------------
-- Instancing
-- ---------------------------------------------------------------------------

--- Routing buckets, and why this number is what it is.
---
--- A property's bucket is `bucketBase + propertyId`, so one shell model serves
--- every property that uses it and two people in identical apartments never see
--- each other.
---
--- IT MUST STAY BELOW som-multichar's 100000. That resource's onResourceStart
--- handler puts everyone in a bucket >= 100000 back to bucket 0, to rescue
--- players stranded in character select after a restart. It cannot tell a
--- stranded selection bucket from an occupied living room, so a housing bucket
--- up there would empty every house on the server the moment som-multichar
--- restarted, and leave those players standing in the void at the shell
--- coordinates rather than anywhere real.
---
--- 20000 leaves room for 80,000 properties before the two ranges could ever
--- meet, which is far more than this server will have.
Config.BucketBase = 20000

--- Where shells are spawned.
---
--- Far under the map, and spaced far enough apart that two shells in different
--- buckets cannot overlap even though buckets already make them invisible to
--- each other. The spacing is belt and braces: physics and sound occasionally
--- cross buckets in ways rendering does not.
Config.Void = {
    origin  = vec3(1000.0, 1000.0, -500.0),
    spacing = 150.0,
}

-- ---------------------------------------------------------------------------
-- Tiers
-- ---------------------------------------------------------------------------

--- What a tier means, rather than what it costs. Price lives on the property.
---
--- `realtorOnly` is the owner's decision made concrete: the expensive tier
--- cannot be bought outright at all, so a real estate agent is a job somebody
--- has to do rather than a convenience somebody can skip.
Config.Tiers = {
    starter  = { label = 'Starter',  stashSlots = 30,  stashWeight = 60000,  realtorOnly = false },
    standard = { label = 'Standard', stashSlots = 50,  stashWeight = 100000, realtorOnly = false },
    premium  = { label = 'Premium',  stashSlots = 80,  stashWeight = 180000, realtorOnly = false },
    luxury   = { label = 'Luxury',   stashSlots = 120, stashWeight = 300000, realtorOnly = true },
}

--- Warehouse sizes.
---
--- Property and storage only. Growing is a separate system that will ask
--- housing what a player owns and where its interior is, which is why the only
--- thing that varies here is capacity.
---
--- `coke_business_empty` and `warehouse_small` from jordqn_free_shells are the
--- obvious models for the two ends of this and are deliberately NOT used yet:
--- neither has a measured exit offset, and shells.lua refuses a shell it cannot
--- place you inside. Measure them and the two largest tiers can move over.
Config.Warehouses = {
    tiny   = { label = 'Lock-Up',           shell = 'container_shell',  stashSlots = 40,  stashWeight = 150000 },
    small  = { label = 'Small Warehouse',   shell = 'shell_warehouse1', stashSlots = 80,  stashWeight = 400000 },
    medium = { label = 'Warehouse',         shell = 'shell_warehouse1', stashSlots = 150, stashWeight = 800000 },
    large  = { label = 'Large Warehouse',   shell = 'shell_warehouse1', stashSlots = 250, stashWeight = 1600000 },
}

-- ---------------------------------------------------------------------------
-- Finance
-- ---------------------------------------------------------------------------

--- Mortgages.
---
--- A mortgage REQUIRES AN ONLINE REALTOR. Buying outright requires nobody. That
--- is the whole shape of the owner's decision: the fast path is always open, and
--- the cheaper path costs a conversation with another player.
---
--- Instalments are real som_phone_bills rows with auto_collect set, so the
--- phone's existing sweep collects them and som-housing only owns the contract.
Config.Finance = {
    job = 'realtor',

    -- Of the price, paid up front before any contract is written.
    depositRate = 0.15,
    -- Added to the financed remainder, once, at signing. Not compound interest:
    -- a per-cycle rate on a debt the player cannot see accruing is a bad thing
    -- to discover, and this is a game.
    interestRate = 0.12,
    -- What the realtor takes, from the deposit rather than from the bank.
    commission = 0.05,

    intervalDays = 7,
    minCycles = 4,
    maxCycles = 26,

    -- Missed payments do not vanish. som-phone's collector resolves debtors
    -- from memory and silently skips anyone offline, so the sweep records a
    -- missed cycle instead and housing settles the arrears on next login,
    -- oldest first. Logging out is not a way to keep a house for free.
    -- How often the arrears sweep runs. Longer than som-phone's own 15 minute
    -- collector because this only moves clocks and counts misses; the money is
    -- moved by that collector, not by this one.
    sweepMinutes = 20,

    repossessAfterMissed = 4,
    -- Of what has been paid so far, returned on repossession. Not zero: losing
    -- the house is the punishment, and taking the money as well is what makes
    -- players stop engaging with a system entirely.
    repossessRefundRate = 0.35,
}

-- ---------------------------------------------------------------------------
-- Raids
-- ---------------------------------------------------------------------------

--- A warrant is authority, not a key.
---
--- Nothing here unlocks anything. A warrant records that an entry was lawful,
--- and entry itself is always physical: a ram is loud and fast, a lockpick is
--- quiet and slow and can fail. Breaching without a warrant works exactly as
--- well and is recorded as unlawful, which is the consequence rather than a
--- refusal.
Config.Raid = {
    job = 'police',
    -- The grade that may approve a warrant, not request one.
    approveGrade = 3,
    warrantMinutes = 45,

    ram = { item = 'breach_ram', duration = 8000, alertsOwner = true },
    lockpick = { item = 'lockpick', duration = 20000, failChance = 0.35, alertsOwner = false },

    -- Kept unlocked for a while after a breach so a raid is a scene rather than
    -- a door that shuts behind the first officer through it.
    breachOpenMinutes = 15,
}


-- ---------------------------------------------------------------------------
-- Entering and buying
-- ---------------------------------------------------------------------------

Config.Interior = {
    -- How close the SERVER insists you are to a door before it will let you in.
    -- Looser than the target range because client coordinates lag the server.
    enterDistance = 6.0,
}

Config.Keys = {
    -- Both people present. A key handed over from across the map is a key
    -- handed to an id somebody typed, and typing an id is not knowing a person.
    distance = 3.0,
}

Config.Purchase = {
    -- Same reasoning, applied to money rather than to doors.
    distance = 8.0,
    -- Keys held on other people's properties do not count towards this. Being
    -- given a spare key to six houses must not stop somebody buying their first.
    maxOwned = 3,
}

-- ---------------------------------------------------------------------------
-- Furniture
-- ---------------------------------------------------------------------------

--- What can be placed, and nothing else.
---
--- A WHITELIST, not a suggestion. The client sends a model NAME and the server
--- refuses anything not in this table, because a client that could name its own
--- model could place a locked door, a wall, or an ATM inside a room only it can
--- reach. som-props takes the same position for the same reason.
---
--- Vanilla models only for now. ex-maps carries a Gabz furniture set but costs
--- 868MB as one resource, which is a decision worth making on its own rather
--- than as a side effect of this.
Config.Furniture = {
    -- How far from the shell origin anything may sit. Generous enough for the
    -- largest shell and small enough that nothing can be pushed out of the room
    -- and into somebody else's bucket.
    maxOffset = 30.0,
    maxPerProperty = 60,

    catalogue = {
        { model = 'v_res_tre_sofa',        label = 'Sofa',          category = 'seating' },
        { model = 'v_res_tt_bed',          label = 'Bed',           category = 'bedroom' },
        { model = 'v_res_mbcabinet',       label = 'Cabinet',       category = 'storage' },
        { model = 'prop_table_04',         label = 'Dining Table',  category = 'tables' },
        { model = 'prop_table_04_chr',     label = 'Dining Chair',  category = 'seating' },
        { model = 'v_res_tre_tvstand',     label = 'TV Stand',      category = 'living' },
        { model = 'prop_tv_flat_01',       label = 'Television',    category = 'living' },
        { model = 'v_res_fridge_2',        label = 'Fridge',        category = 'kitchen' },
        { model = 'prop_micro_01',         label = 'Microwave',     category = 'kitchen' },
        { model = 'v_res_d_rug',           label = 'Rug',           category = 'decor' },
        { model = 'prop_plant_01a',        label = 'Plant',         category = 'decor' },
        { model = 'prop_shelves_02',       label = 'Shelving',      category = 'storage' },
        { model = 'v_res_lastbin',         label = 'Bin',           category = 'decor' },
        { model = 'prop_off_chair_01',     label = 'Office Chair',  category = 'seating' },
        { model = 'prop_desk_01',          label = 'Desk',          category = 'tables' },
    },
}

-- ---------------------------------------------------------------------------
-- Properties
-- ---------------------------------------------------------------------------

--- The seed list.
---
--- Rows are reconciled from this at boot the way som-garage reconciles its
--- fleet: a slug that disappears from here has its row retired, and a new slug
--- gets a row. `slug` is the identity and must never be reused for a different
--- building.
---
--- COORDINATES ARE UNVERIFIED, exactly as som-garage's pdm shop coordinates are
--- and for the same reason: they were chosen from map knowledge rather than by
--- standing on them. Every one needs walking to before this ships. A door in
--- the wrong place is the failure mode, and it is obvious the moment anyone
--- tries it.
Config.Properties = {
    {
        slug = 'mirror_park_1', label = 'Mirror Park Residence', type = 'house',
        tier = 'standard', shell = 'shell_v16mid',
        door = vec4(1310.85, -1650.42, 52.28, 137.0), price = 185000,
    },
    {
        slug = 'grove_1', label = 'Grove Street House', type = 'house',
        tier = 'starter', shell = 'shell_frankaunt',
        door = vec4(126.44, -1943.28, 21.32, 46.0), price = 95000,
    },
    {
        slug = 'vespucci_apt_1', label = 'Vespucci Apartment', type = 'apartment',
        tier = 'starter', shell = 'shell_v16low',
        door = vec4(-1150.20, -1520.86, 10.63, 125.0), price = 72000,
    },
    {
        slug = 'del_perro_apt_1', label = 'Del Perro Heights', type = 'apartment',
        tier = 'standard', shell = 'furnitured_midapart',
        door = vec4(-1447.06, -538.32, 34.74, 34.0), price = 210000,
    },
    {
        slug = 'vinewood_hills_1', label = 'Vinewood Hills Estate', type = 'house',
        tier = 'luxury', shell = 'shell_michael',
        door = vec4(-813.62, 178.66, 72.55, 27.0), price = 1450000,
    },
    {
        slug = 'sandy_trailer_1', label = 'Sandy Shores Trailer', type = 'house',
        tier = 'starter', shell = 'shell_trailer',
        door = vec4(1975.34, 3815.42, 33.43, 121.0), price = 48000,
    },
    {
        slug = 'cypress_lockup_1', label = 'Cypress Flats Lock-Up', type = 'warehouse',
        tier = 'starter', shell = 'container_shell', warehouse = 'tiny',
        door = vec4(812.44, -2168.30, 29.62, 88.0), price = 120000,
    },
    {
        slug = 'la_mesa_wh_1', label = 'La Mesa Warehouse', type = 'warehouse',
        tier = 'standard', shell = 'shell_warehouse1', warehouse = 'medium',
        door = vec4(846.12, -1544.88, 30.30, 268.0), price = 460000,
    },
}

-- ---------------------------------------------------------------------------
-- Boot-time validation
-- ---------------------------------------------------------------------------

--- Refuses to offer a property whose shell nobody can be placed inside.
---
--- Runs at load rather than at purchase, because the alternative is a player
--- paying for a house and then falling through the world. shells.lua returns
--- nil for an unmeasured shell and this is what turns that nil into something
--- somebody reads.
CreateThread(function()
    local usable = {}

    for _, property in ipairs(Config.Properties) do
        if Shells.IsUsable(property.shell) then
            usable[#usable + 1] = property
        else
            print(('[som-housing] %s is configured on shell "%s", which has no measured exit offset. Not offered. See shared/shells.lua.')
                :format(property.slug, tostring(property.shell)))
        end
    end

    Config.Properties = usable
end)
