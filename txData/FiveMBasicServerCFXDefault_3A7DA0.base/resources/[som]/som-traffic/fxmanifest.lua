fx_version 'cerulean'
game 'gta5'

name 'som-traffic'
author 'State of Mind RP'
description 'Puts the lore-friendly civilian cars into ambient NPC traffic'
version '0.1.0'

-- Ambient traffic composition, and nothing else.
--
-- WHY THIS IS A SEPARATE RESOURCE from som-lorefriendly, which streams the
-- models: everything under [assets-streams] is gitignored and hand-copied to
-- the server, so configuration living there would never be committed. The
-- models are content, this is a decision, and decisions belong in git. It also
-- means the models can be started without changing traffic, which is how you
-- test a spawn.
--
-- HOW IT WORKS. popgroups.ymt is the game's map of which vehicle models belong
-- to which ambient traffic group. `DLC_POP_GROUPS` OVERRIDES A GROUP WHOLESALE
-- BY NAME, so every group named in that file carries its full vanilla member
-- list plus our additions. Shipping a group with only our cars in it would
-- delete every vanilla car from that slice of traffic, which is the trap here.
--
-- The vanilla lists were lifted from karma_visuals' popgroups.ymt, the only
-- XML-form copy in the tree. That mattered: assets_vehicles and
-- qb-smallresources both ship theirs as compiled binary (PSIN/PSO), which
-- cannot be authored without OpenIV or CodeWalker, neither of which is
-- installed. FiveM accepts the uncompiled XML form, which is what makes this
-- doable at all.
--
-- WEIGHTING. popgroups has no per-model weight field. Frequency comes from how
-- many groups a model appears in, so the everyday sedans sit in both VEH_MID
-- and VEH_LARGE_CITY and turn up often, while the two upmarket SUVs sit only in
-- VEH_RICH and stay genuinely uncommon. Ten groups are touched: POOR, MID,
-- RICH, LARGE_CITY and UTILITY, each with its _MP twin, because the online
-- derived pop schedules use those and skipping them would halve the effect.
--
-- DELIBERATELY NOT SHIPPED: popcycle.dat. That file sets ped and vehicle
-- DENSITIES per zone and time of day. Nothing here wants more or fewer cars,
-- only different ones, and density is a much larger and more visible change to
-- make by accident.

files {
    'popgroups.ymt',
}

data_file 'DLC_POP_GROUPS' 'popgroups.ymt'

dependencies {
    'som-lorefriendly',
}
