fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-radial'
author 'Lennox'
description 'SOM radial menu: contextual actions on F1, contributed by other resources'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
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
