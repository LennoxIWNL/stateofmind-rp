fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-medical'
author 'Lennox'
description 'The downed state: down is down, no crawling, no second death'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/call.lua',
    'server/newlife.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'ox_lib',
    'som-core',
    'som-ui',
}
