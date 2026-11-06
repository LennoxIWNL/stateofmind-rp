fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-licences'
author 'Lennox'
description 'Driver and weapon licences: the driving school, and police checks, suspensions and revocations'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
    'shared/config.lua',
}

client_scripts {
    '@som-ui/client/dialog.lua',
    '@som-ui/client/context.lua',
    'client/school.lua',
    'client/police.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/questions.lua',
    'server/licences.lua',
    'server/police.lua',
    'server/school.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'som-core',
    'som-interact',
    'som-ui',
}
