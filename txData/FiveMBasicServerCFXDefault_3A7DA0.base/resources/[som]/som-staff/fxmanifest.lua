fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-staff'
author 'State of Mind RP'
description 'Launch operations: the connection whitelist and the staff action tools'
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
    'server/whitelist.lua',
    'server/staff.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'som-core',
    'som-ui',
}
