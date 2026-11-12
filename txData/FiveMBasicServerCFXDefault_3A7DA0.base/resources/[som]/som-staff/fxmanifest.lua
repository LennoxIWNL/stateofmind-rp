fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-staff'
author 'Lennox'
description 'Launch operations: the connection whitelist and the staff action tools'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
    'shared/config.lua',
    'shared/health_lists.lua',
}

client_scripts {
    '@som-ui/client/context.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@som-core/server/placements.lua',
    'server/whitelist.lua',
    'server/staff.lua',
    'server/combatlog.lua',
    'server/placements.lua',
    'server/health.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'som-core',
    'som-ui',
}
