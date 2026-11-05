fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-progress'
author 'Lennox'
description 'Skill tracks that tie the jobs and crafts together: experience and levels every other resource can read'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'som-core',
    'som-phone',
}
