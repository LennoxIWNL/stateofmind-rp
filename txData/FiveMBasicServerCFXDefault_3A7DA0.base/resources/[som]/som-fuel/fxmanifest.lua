fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-fuel'
author 'Lennox'
description 'Fuel: cars burn it, gas stations sell it for a station business account, jerry cans carry it'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
    'shared/config.lua',
}

client_scripts {
    '@som-ui/client/progressbar.lua',
    'client/drive.lua',
    'client/pump.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@som-core/server/placements.lua',
    'server/main.lua',
    'server/can.lua',
}

dependencies {
    'ox_lib',
    'ox_inventory',
    'som-core',
    'som-interact',
    'som-ui',
}
