-- Supporter tiers and staff entitlements.
--
-- NOTHING HERE MAY BE PAY TO WIN. No money, no vehicles, no items, no stats,
-- no gameplay advantage. Entitlements are limited to convenience (queue
-- priority, character slots) and cosmetics (names, colours, plates). If a perk
-- would make a paying player stronger in an interaction with a non-paying one,
-- it does not belong in this file.
--
-- HOW A TIER IS RESOLVED
--
-- Tiers are granted through ACE, not read from Patreon directly. That keeps
-- the mechanism independent of where the entitlement comes from, so it works
-- today by hand and later from an automated source without touching the code
-- that consumes it. Any of these can grant the ACE:
--
--   * manually in server.cfg, which is how it works right now
--   * a Discord bot mapping roles to principals
--   * a future Patreon webhook
--
-- The txAdmin Discord bot is currently DISABLED on this server, so the Discord
-- route is not available yet. Grant by hand until it is:
--
--   add_principal identifier.license:<license> group.supporter
--   add_ace group.supporter som.tier.supporter allow
--
-- Patreon does not exist yet either. Prices below are placeholders for
-- planning, not a live storefront.

Tiers = {}

-- Ordered lowest to highest. A player gets the best tier they hold.
Tiers.supporter = {
    {
        name = 'free',
        label = 'Citizen',
        price = nil,
        ace = nil,              -- everyone
        slots = 3,
        queuePriority = 0,
        perks = {},
    },
    {
        name = 'supporter',
        label = 'Supporter',
        price = 5,
        ace = 'som.tier.supporter',
        slots = 5,
        queuePriority = 10,
        perks = {
            -- Deliberately queue only. The cheapest tier buys time, not toys.
        },
    },
    {
        name = 'resident',
        label = 'Resident',
        price = 10,
        ace = 'som.tier.resident',
        slots = 7,
        queuePriority = 20,
        perks = {
            twitterHandle = true,    -- choose a custom handle
            twitterColour = 1,       -- how many colourways unlocked
            customPlates = 1,        -- custom plate on this many owned vehicles
        },
    },
    {
        name = 'insider',
        label = 'Insider',
        price = 20,
        ace = 'som.tier.insider',
        slots = 10,
        queuePriority = 30,
        perks = {
            twitterHandle = true,
            twitterColour = 3,
            customPlates = 3,
            customPhoneNumber = true,
        },
    },
}

-- Staff entitlements. NOT purchasable, and resolved independently: a player
-- receives the better of their staff and supporter entitlement, so buying a
-- tier never removes something staff already had, and staff rank is never a
-- substitute for supporting.
--
-- Management sits at the top deliberately. Keeping the highest slot count
-- purchasable is the incentive the owner asked for, so staff below management
-- get 7 rather than 10.
Tiers.staff = {
    { ace = 'som.mod',   slots = 3,  queuePriority = 25 },
    { ace = 'som.admin', slots = 7,  queuePriority = 40 },
    { ace = 'som.god',   slots = 10, queuePriority = 50 },
}

Tiers.defaultSlots = 3

-- Hard ceiling. Nothing may exceed this, whatever combination of ACEs a player
-- somehow accumulates, because som_characters.slot is validated against it.
Tiers.maxSlots = 10
