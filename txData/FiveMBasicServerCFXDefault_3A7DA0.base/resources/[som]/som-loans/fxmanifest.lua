fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-loans'
author 'Lennox'
description 'Phone loans: borrow a fixed amount from the city treasury, repay weekly, default into collection'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/loans.lua',
}

dependencies {
    'ox_lib',
    'som-core',
    'som-phone',
}
