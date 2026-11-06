fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-courier'
author 'Lennox'
description 'A legal group delivery run, the first provider on the job board'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
    'shared/config.lua',
}

client_scripts {
    '@som-ui/client/progressbar.lua',
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'som-core',
    'som-economy',
    'som-interact',
    'som-ui',
    'som-jobboard',
    'som-groups',
}
