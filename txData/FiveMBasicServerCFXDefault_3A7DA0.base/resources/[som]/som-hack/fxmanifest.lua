fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-hack'
author 'Lennox'
description 'Hacking challenges whose answer the server holds and checks'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/play.lua',
}

server_scripts {
    'server/hack.lua',
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
