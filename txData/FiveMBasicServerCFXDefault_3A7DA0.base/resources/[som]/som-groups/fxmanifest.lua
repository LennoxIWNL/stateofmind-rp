fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-groups'
author 'State of Mind RP'
description 'Player groups: a leader, invited members and a ready state, shown as a phone app'
version '0.1.0'

shared_scripts {
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'oxmysql',
    'som-core',
    'som-phone',
}
