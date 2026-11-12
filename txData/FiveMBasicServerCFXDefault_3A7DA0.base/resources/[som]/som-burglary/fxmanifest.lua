fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-burglary'
author 'Lennox'
description 'House burglary as job board providers: pick a lock at night, search a house, sell the stolen goods to a fence'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
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
    'som-dispatch',
    'som-housing',
}
