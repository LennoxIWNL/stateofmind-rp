fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-economy'
author 'Lennox'
description 'SOM economy: market saturation, business register, departments, fines'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/business.lua',
    'server/market.lua',
    'server/fines.lua',
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'som-core',
}
