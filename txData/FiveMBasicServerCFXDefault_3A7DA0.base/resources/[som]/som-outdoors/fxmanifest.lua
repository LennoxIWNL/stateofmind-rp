fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-outdoors'
author 'Lennox'
description 'Fishing, hunting and scrapping: server-checked work sold to buyers paid from a capped treasury pool'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
    'shared/config.lua',
}

client_scripts {
    '@som-ui/client/progressbar.lua',
    '@som-ui/client/dialog.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/buyer.lua',
    'server/fishing.lua',
    'server/hunting.lua',
    'server/chop.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'som-core',
    'som-interact',
    'som-ui',
}
