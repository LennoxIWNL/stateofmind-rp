fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-ems'
author 'Lennox'
description 'Paramedic work: revive a downed player with a first aid kit and bill the patient for the service'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
    'shared/config.lua',
}

client_scripts {
    '@som-ui/client/progressbar.lua',
    'client/main.lua',
    'client/hospital.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@som-core/server/placements.lua',
    'server/main.lua',
    'server/hospital.lua',
}

dependencies {
    'ox_lib',
    'ox_inventory',
    'som-core',
    'som-interact',
    'som-ui',
    'som-economy',
    'som-medical',
    'som-phone',
}
