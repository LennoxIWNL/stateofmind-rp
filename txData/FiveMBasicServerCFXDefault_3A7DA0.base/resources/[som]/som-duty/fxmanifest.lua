fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-duty'
author 'Lennox'
description 'Clock in and out of the job you hold, from the radial menu'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
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
    'som-radial',
}
