fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-phone'
author 'State of Mind RP'
description 'SOM phone: the action pipeline, the app host, banking over the transaction ledger, settings'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/anim.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bank.lua',
    'server/core.lua',
    'server/device.lua',
    'server/apps.lua',
    'server/comms.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

-- Built from ui/apps/som-phone. Do not edit html/ by hand, it is generated.
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
    'som-assets',
}
