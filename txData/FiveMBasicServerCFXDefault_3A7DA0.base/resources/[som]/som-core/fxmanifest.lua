fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-core'
author 'Lennox'
description 'SOM framework core: players, characters, money bus, permissions, state bridge'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/trace.lua',
    'shared/config.lua',
    'shared/clock.lua',
    'shared/tiers.lua',
    'shared/jobs.lua',
    'shared/gangs.lua',
}

client_scripts {
    'client/main.lua',
    'client/clock.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/permissions.lua',
    'server/entitlements.lua',
    'server/player.lua',
    'server/money.lua',
    'server/characters.lua',
    'server/main.lua',
    'server/clock.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
}
