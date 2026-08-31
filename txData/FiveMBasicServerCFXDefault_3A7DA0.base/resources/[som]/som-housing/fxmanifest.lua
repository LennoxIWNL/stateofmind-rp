fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-housing'
author 'State of Mind RP'
description 'Property: houses, apartments and warehouses in shell interiors, with keys, storage, mortgages and police raids'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    -- shells.lua first: config.lua validates its own property list against the
    -- offsets in it at load, so a property pointing at a shell nobody has
    -- measured is caught at boot rather than when somebody tries to walk in.
    'shared/shells.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    -- properties.lua defines the Properties authority the rest read through,
    -- the same split som-garage uses with vehicles.lua. Client scripts and the
    -- ownership half arrive with the next stage; this manifest lists only what
    -- exists, because a manifest naming a missing file fails the whole resource.
    'server/properties.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'som-core',
    'som-interact',
    'som-assets',
    -- Storage is ox_inventory's, registered through RegisterStash. AUDIT 8.7
    -- pre-commits that decision: no bespoke storage table.
    'ox_inventory',
    -- The shells themselves. Without it every property points at a model that
    -- does not exist, which fails as an invisible interior rather than as an
    -- error, so its absence must be loud.
    'qb-interior',
}
