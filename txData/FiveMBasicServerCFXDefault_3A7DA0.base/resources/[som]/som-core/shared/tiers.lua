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
--
-- Slots climb 2, 3, 5, 6, 7 and then stop. Seven is the purchasable ceiling
-- because nobody needs more, so the top tier sells cosmetics rather than yet
-- another slot. See patreon.md for the full perk rationale.
Tiers.supporter = {
    {
        name = 'free',
        label = 'Citizen',
        price = nil,
        ace = nil,              -- everyone
        slots = 2,
        queuePriority = 0,
        perks = {},
    },
    {
        name = 'resident',
        label = 'Resident',
        price = 5,
        ace = 'som.tier.resident',
        slots = 3,
        queuePriority = 5,      -- deliberately slight
        perks = {
            -- One extra slot and a nudge up the queue. Nothing else: the
            -- cheapest tier buys a little time, not toys.
        },
    },
    {
        name = 'insider',
        label = 'Insider',
        price = 10,
        ace = 'som.tier.insider',
        slots = 5,
        queuePriority = 15,
        perks = {
            customPhoneNumber = true,   -- the first in-game perk
        },
    },
    {
        name = 'patron',
        label = 'Patron',
        price = 20,
        ace = 'som.tier.patron',
        slots = 6,
        queuePriority = 25,
        perks = {
            customPhoneNumber = true,
            twitterHandle = true,
            twitterColour = 1,
            customPlates = 1,
        },
    },
    {
        name = 'benefactor',
        label = 'Benefactor',
        price = 30,
        ace = 'som.tier.benefactor',
        slots = 7,
        queuePriority = 35,
        perks = {
            customPhoneNumber = true,
            twitterHandle = true,
            twitterColour = 3,
            customPlates = 2,
            profileTitle = true,
        },
    },
    {
        name = 'founder',
        label = 'Founder',
        price = 40,
        ace = 'som.tier.founder',
        slots = 7,              -- the ceiling: this tier sells cosmetics
        queuePriority = 45,
        perks = {
            customPhoneNumber = true,
            twitterHandle = true,
            twitterColour = 6,
            customPlates = 3,
            profileTitle = true,
            phoneTheme = true,
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

Tiers.defaultSlots = 2

-- The most a player can ever reach by paying. Seven is plenty, and stopping
-- here is what keeps ten feeling like a staff thing rather than a purchase.
Tiers.maxPurchasableSlots = 7

-- Absolute ceiling across every source, reserved for management. Nothing may
-- exceed this whatever combination of ACEs a player accumulates, because
-- som_characters.slot is validated against it.
Tiers.maxSlots = 10
