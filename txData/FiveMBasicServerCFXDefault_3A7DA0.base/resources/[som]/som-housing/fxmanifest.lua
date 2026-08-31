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

client_scripts {
    -- Replaces lib.inputDialog with som-ui's, which is how the account picker
    -- at a door stops being stock ox_lib. Client only, so it cannot go in
    -- shared_scripts, and first, so every file below sees the replacement.
    '@som-ui/client/dialog.lua',
    -- interior.lua first: property.lua calls Interior.Build into it.
    'client/interior.lua',
    'client/property.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    -- properties.lua defines the Properties authority the other two read
    -- through, the same split som-garage uses with vehicles.lua.
    'server/properties.lua',
    'server/ownership.lua',
    -- Last: entering needs both a property and a key, so it uses the other two.
    'server/interior.lua',
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
    -- The input dialog shim is loaded from it at start time, so its absence
    -- must be a loud failure rather than a nil call at a door.
    'som-ui',
    -- The shells themselves. Without it every property points at a model that
    -- does not exist, which fails as an invisible interior rather than as an
    -- error, so its absence must be loud.
    'qb-interior',
}
