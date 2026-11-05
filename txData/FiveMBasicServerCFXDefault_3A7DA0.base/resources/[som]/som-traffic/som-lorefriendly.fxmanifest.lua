fx_version 'cerulean'
game 'gta5'

name 'som-lorefriendly'
author 'Lennox'
description 'Twenty lore-friendly civilian vehicles, streamed for NPC traffic'
version '0.1.0'

-- Twenty ordinary cars pulled from Aweetumn-LLC/FiveM-Lorefriendly-Vehicles
-- (the LNWK-CARS bundle), chosen for being SEDATE. The pack ships 156 vehicles
-- and most of them are drift builds, widebodies and supercars, which is wrong
-- for background traffic: the point is a street that looks lived in, not a car
-- meet. Sedans, wagons, pickups, two SUVs and a van.
--
-- 25 spawnable models across the 20 folders, because Walton, Indiana and
-- Panorama each ship several variants.
--
-- The upstream fxmanifest also loaded a client/main.lua. That is deliberately
-- NOT carried over: nothing here needs a client script, and an unread one in a
-- streaming resource is a needless surface.
--
-- som-traffic is what actually puts these into ambient traffic. This resource
-- only makes the models exist, so it can be started on its own to test a spawn
-- without touching traffic at all.

files {
    'data/**/carcols.meta',
    'data/**/carvariations.meta',
    'data/**/contentunlocks.meta',
    'data/**/handling.meta',
    'data/**/vehiclelayouts.meta',
    'data/**/vehicles.meta',
}

data_file 'CONTENT_UNLOCKING_META_FILE' 'data/**/contentunlocks.meta'
data_file 'HANDLING_FILE'               'data/**/handling.meta'
data_file 'VEHICLE_METADATA_FILE'       'data/**/vehicles.meta'
data_file 'CARCOLS_FILE'                'data/**/carcols.meta'
data_file 'VEHICLE_VARIATION_FILE'      'data/**/carvariations.meta'
data_file 'VEHICLE_LAYOUTS_FILE'        'data/**/vehiclelayouts.meta'

-- ---------------------------------------------------------------------------
-- THIS IS A COMMITTED COPY, NOT THE LIVE FILE.
--
-- The live one is at [assets-streams]/[vehicles]/som-lorefriendly/fxmanifest.lua
-- and is gitignored along with the rest of that tree, which is right for the
-- 274MB of models beside it and wrong for this, because this is authored config
-- rather than content. Losing it means the pack silently does not load.
--
-- If som-lorefriendly is missing its manifest, copy this file back, minus this
-- footer.
-- ---------------------------------------------------------------------------
