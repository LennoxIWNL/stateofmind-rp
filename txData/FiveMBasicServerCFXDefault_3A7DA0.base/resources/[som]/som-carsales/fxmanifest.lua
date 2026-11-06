fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-carsales'
author 'Lennox'
description 'Sell your own car to the person next to you: they agree on screen, the car changes hands and the city takes a tax'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    '@som-ui/client/dialog.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'som-core',
    'som-interact',
    'som-ui',
    'som-garage',
}
