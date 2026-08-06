fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-hud'
author 'State of Mind RP'
description 'The permanent HUD: condition, voice and the vehicle panel'
version '0.1.0'

shared_scripts {
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'som-assets',
    'som-core',
}
