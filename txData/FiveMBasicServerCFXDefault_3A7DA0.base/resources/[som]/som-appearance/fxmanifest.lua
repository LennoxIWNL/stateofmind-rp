fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-appearance'
author 'State of Mind RP'
description 'SOM appearance: character creator, barber and clothing, over the standard ped appearance shape'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/appearance.lua',
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
