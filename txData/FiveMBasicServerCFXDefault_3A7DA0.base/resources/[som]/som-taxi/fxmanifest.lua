fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-taxi'
author 'Lennox'
description 'Cab driver meter: the fare is measured on the server and the passenger agrees to pay it'
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
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'som-core',
    'som-interact',
    'som-ui',
    'som-radial',
}
