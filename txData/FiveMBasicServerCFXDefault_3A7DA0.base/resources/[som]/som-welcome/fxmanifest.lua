fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-welcome'
author 'Lennox'
description 'A first hour for new characters: a Getting Started phone app, a job centre and a one-time settling-in payment'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
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
    'som-core',
    'som-phone',
    'som-interact',
    'som-ui',
}
