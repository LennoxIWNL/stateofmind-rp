fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-theft'
author 'State of Mind RP'
description 'Server-validated cash robbery, so cash is stealable without being an inventory item'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'som-core',
    'som-interact',
}
