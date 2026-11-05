fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-launder'
author 'Lennox'
description 'Marked bills: the ledger that mints them, and the front that washes them'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    '@som-ui/client/context.lua',
    '@som-ui/client/dialog.lua',
    'client/front.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@som-core/server/placements.lua',
    -- ledger.lua defines Ledger, which wash.lua reads through.
    'server/ledger.lua',
    'server/wash.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'som-core',
    'som-interact',
    'som-ui',
}
