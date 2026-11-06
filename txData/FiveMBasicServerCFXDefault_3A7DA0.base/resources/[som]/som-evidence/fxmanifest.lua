fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-evidence'
author 'Lennox'
description 'Evidence: scene traces, collection, custody, the lab and case links'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
    'shared/config.lua',
}

client_scripts {
    '@som-ui/client/context.lua',
    '@som-ui/client/dialog.lua',
    '@som-ui/client/progressbar.lua',
    'client/scan.lua',
    'client/stations.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    -- evidence.lua defines Evidence, which locker.lua calls.
    'server/evidence.lua',
    'server/locker.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'som-core',
    'som-court',
    'som-interact',
    'som-ui',
}
