fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-dmv'
author 'Lennox'
description 'Vehicle registration and vanity plates, paid to the city at a self-serve counter'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    '@som-ui/client/dialog.lua',
    '@som-ui/client/context.lua',
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
    'som-garage',
}
