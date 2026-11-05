fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-outdoors'
author 'State of Mind RP'
description 'Fishing and hunting: server-rolled catches sold to buyers paid from a capped treasury pool'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
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
}

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'som-core',
    'som-interact',
    'som-ui',
}
