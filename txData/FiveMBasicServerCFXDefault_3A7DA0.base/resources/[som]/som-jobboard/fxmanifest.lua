fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-jobboard'
author 'State of Mind RP'
description 'The job board: groups wait on a job type and a weighted lottery decides who gets the next one'
version '0.1.0'

shared_scripts {
    'shared/config.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'som-core',
    'som-phone',
    'som-groups',
}
