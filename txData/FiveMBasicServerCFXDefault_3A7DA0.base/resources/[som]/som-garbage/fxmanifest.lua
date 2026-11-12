fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-garbage'
author 'Lennox'
description 'A municipal garbage and recycling round on the job board'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
    'shared/config.lua',
}

client_scripts {
    '@som-ui/client/progressbar.lua',
    '@som-ui/client/dialog.lua',
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
    'som-economy',
    'som-interact',
    'som-ui',
    'som-jobboard',
    'som-groups',
}
