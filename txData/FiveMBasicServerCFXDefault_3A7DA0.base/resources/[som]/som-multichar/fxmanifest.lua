fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-multichar'
author 'Lennox'
description 'SOM character selection, creation and spawn'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/tuning.lua',
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
