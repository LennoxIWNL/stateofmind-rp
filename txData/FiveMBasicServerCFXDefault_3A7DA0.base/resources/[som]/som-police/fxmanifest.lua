fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-police'
author 'State of Mind RP'
description 'LSPD: duty, armoury, custody, fines, impounds and certifications'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    -- duty first: stations, custody and keybinds all read Duty.IsOnDuty().
    'client/duty.lua',
    'client/armoury.lua',
    'client/stations.lua',
    'client/custody.lua',
    'client/vehicles.lua',
    'client/keybinds.lua',
    'client/vehiclecontrols.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    -- main first: it defines Police, which every other server file calls for
    -- its authority checks.
    'server/main.lua',
    'server/custody.lua',
    'server/vehicles.lua',
    'server/fines.lua',
    'server/impound.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'som-core',
    'som-interact',
    'som-economy',
    'som-assets',
}
