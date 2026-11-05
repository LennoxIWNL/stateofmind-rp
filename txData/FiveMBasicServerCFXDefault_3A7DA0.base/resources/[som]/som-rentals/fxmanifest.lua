fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-rentals'
author 'Lennox'
description 'SOM vehicle rental: counter ped, deposit, and rental papers carrying the plate'
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

-- Built from ui/apps/som-rentals. Do not edit html/ by hand, it is generated.
files {
    'html/index.html',
    'html/assets/*.js',
    'html/assets/*.css',
    'html/assets/*.map',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'som-core',
    'som-interact',
    'som-assets',
}
