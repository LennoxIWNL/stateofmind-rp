fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-boosting'
author 'Lennox'
description 'Vehicle contracts as job board providers: steal a listed car, deliver it, get paid in marked bills'
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
    'som-core',
    'som-interact',
    'som-ui',
    'som-jobboard',
    'som-launder',
    'som-dispatch',
}
