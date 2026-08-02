fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-pause'
author 'State of Mind RP'
description 'SOM pause menu: replaces the native frontend with a custom map, character and server interface'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
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
    'som-core',
    'som-assets',
}
