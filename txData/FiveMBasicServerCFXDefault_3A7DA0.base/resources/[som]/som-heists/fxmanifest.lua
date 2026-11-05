fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-heists'
author 'Lennox'
description 'Heist framework: store, small bank and vault tiers as job board providers, started by a ledger backed dongle'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    '@som-ui/client/progressbar.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@som-core/server/placements.lua',
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'som-core',
    'som-interact',
    'som-ui',
    'som-jobboard',
    'som-groups',
    'som-hack',
    'som-launder',
    'som-dispatch',
}
