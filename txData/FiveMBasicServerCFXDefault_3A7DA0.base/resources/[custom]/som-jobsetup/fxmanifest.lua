fx_version 'cerulean'
games { 'gta5' }

name 'som-jobsetup'
author 'State of Mind RP'
description 'Central interaction/garage point manager — relocate job interactions when swapping MLOs from one in-game menu.'
version '1.0.0'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_script 'client/main.lua'
server_scripts {
    'server/main.lua',
    'server/jobpatch.lua'
}

ui_page 'html/index.html'

files {
    'data/points.json',
    'html/index.html',
}

dependencies {
    'qb-core',
    'ox_lib',
    'qb-target'
}
