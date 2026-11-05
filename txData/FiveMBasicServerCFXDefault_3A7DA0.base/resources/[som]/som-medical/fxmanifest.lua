fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-medical'
author 'State of Mind RP'
description 'The downed state: down is down, no crawling, no second death'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
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
