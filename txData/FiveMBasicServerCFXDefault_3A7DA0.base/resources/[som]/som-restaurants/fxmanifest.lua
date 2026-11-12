fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-restaurants'
author 'Lennox'
description 'Player-run restaurants: buy one, hire staff, buy ingredients, cook in steps, sell at the counter, self-serve when nobody is on duty'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
    'shared/config.lua',
}

client_scripts {
    '@som-ui/client/dialog.lua',
    '@som-ui/client/context.lua',
    '@som-ui/client/progressbar.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@som-core/server/placements.lua',
    'server/restaurants.lua',
    'server/kitchen.lua',
    'server/orders.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'som-core',
    'som-interact',
    'som-ui',
}
