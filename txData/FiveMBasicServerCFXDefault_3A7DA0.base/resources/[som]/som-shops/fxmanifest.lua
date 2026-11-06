fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-shops'
author 'Lennox'
description 'Player-run shops: buy one from the city, stock and price it, hire staff, and see it on the phone'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
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
    'server/shops.lua',
    'server/stock.lua',
    'server/staff.lua',
    'server/app.lua',
}

dependencies {
    'ox_lib',
    'ox_inventory',
    'som-core',
    'som-interact',
    'som-ui',
    'som-phone',
}
