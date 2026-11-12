fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-racing'
author 'Lennox'
description 'Underground street racing from the phone: record tracks, host races with escrowed buy-ins, server judged checkpoints'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
    'shared/config.lua',
}

client_scripts {
    '@som-ui/client/dialog.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/race.lua',
    'server/app.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'som-core',
    'som-interact',
    'som-ui',
    'som-phone',
    'som-dispatch',
}
