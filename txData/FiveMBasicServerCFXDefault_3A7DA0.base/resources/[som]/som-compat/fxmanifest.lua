fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-compat'
author 'State of Mind RP'
description 'Legacy qb-core export surface backed by som-core, so preserved resources run untouched'
version '0.1.0'

-- Answers exports['qb-core']:GetCoreObject() the same way qbx_core does today.
-- Never enable this alongside qbx_core: both claim the same name.
provide 'qb-core'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/qbcore.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/qbcore.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'som-core',
}
