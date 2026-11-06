fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-anpr'
author 'Lennox'
description 'Plate reader hits: a police cruiser flags stolen, BOLO and police flagged plates to the officer and to dispatch'
version '0.1.0'

shared_scripts {
    '@som-core/shared/trace.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'som-core',
    'som-dispatch',
    'wk_wars2x',
}
