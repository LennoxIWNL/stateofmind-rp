fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-interact'
author 'State of Mind RP'
description 'SOM interaction wrapper around the preserved target system, plus the single TextUI'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/target.lua',
    'client/textui.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'ox_lib',
    'sleepless_interact',
    'som-assets',
}
