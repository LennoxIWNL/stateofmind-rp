fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-mechanic'
author 'Lennox'
description 'Mechanic work: engine and body repair that consumes parts and bills the driver through the phone'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
    'shared/config.lua',
}

client_scripts {
    '@som-ui/client/progressbar.lua',
    'client/main.lua',
    'client/trade.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/trade.lua',
}

dependencies {
    'ox_lib',
    'ox_inventory',
    'som-core',
    'som-interact',
    'som-ui',
    'som-economy',
    'som-phone',
}
