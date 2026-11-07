fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-insurance'
author 'Lennox'
description 'Vehicle insurance: weekly premiums, a claim brings a lost car back for an excess fee'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/insurance.lua',
}

dependencies {
    'ox_lib',
    'som-core',
    'som-phone',
}
