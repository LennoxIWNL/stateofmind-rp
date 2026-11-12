fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-news'
author 'Lennox'
description 'Weazel News: on duty reporters publish stories and breaking alerts through a phone app, everyone reads the feed'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
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
