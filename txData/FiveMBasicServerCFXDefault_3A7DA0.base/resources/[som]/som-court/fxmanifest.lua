fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-court'
author 'State of Mind RP'
description 'Court: cases, hearings, rulings and warrants'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    '@som-ui/client/context.lua',
    '@som-ui/client/dialog.lua',
    'client/menus.lua',
    'client/desk.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    -- cases.lua defines Court and warrants.lua defines Warrants, which
    -- rulings.lua calls; same split som-housing uses between its files.
    'server/cases.lua',
    'server/warrants.lua',
    'server/rulings.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'som-core',
    'som-economy',
    'som-interact',
    'som-ui',
}
