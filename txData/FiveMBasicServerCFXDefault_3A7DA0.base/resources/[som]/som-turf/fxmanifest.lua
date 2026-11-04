fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-turf'
author 'State of Mind RP'
description 'Gang turf and the street drug market as one system: owning a zone is what lets a gang sell in it'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    '@som-ui/client/progressbar.lua',
    '@som-ui/client/dialog.lua',
    'client/main.lua',
    'client/grow.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/gang.lua',
    'server/payroll.lua',
    'server/app.lua',
    'server/grow.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'som-core',
    'som-interact',
    'som-ui',
    'som-launder',
    'som-dispatch',
    'som-phone',
}
