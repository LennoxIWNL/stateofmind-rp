fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-id'
author 'State of Mind RP'
description 'SOM identity documents: ID card, licences, shown to players nearby'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'som-core',
    'som-assets',
}
