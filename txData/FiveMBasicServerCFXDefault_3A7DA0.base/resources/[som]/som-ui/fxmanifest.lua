fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-ui'
author 'State of Mind RP'
description 'SOM notifications, the single implementation behind som:client:notify'
version '0.1.0'

client_scripts {
    'client/notify.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'som-assets',
}
