fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-tow'
author 'Lennox'
description 'Tow drivers: an officer asks for a tow, a driver takes the ticket and delivers the car to the impound lot for a fee'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/tow.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/tow.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'som-core',
    'som-phone',
    'som-police',
}
