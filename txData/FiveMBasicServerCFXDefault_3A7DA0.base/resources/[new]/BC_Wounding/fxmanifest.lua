fx_version 'cerulean'
game 'gta5'

name 'BC_Wounding'
description 'Detailed Player Damage System Which Works With Our OX_Inventory Re Design'
author 'Bro Code'
version '1.0.0'

lua54 'yes'
use_fxv2_oal 'yes'
dependency 'ox_lib'

escrow_ignore {
    'config.lua',
    'client_open.lua',
    'readme.md',
    'damage.json'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client_open.lua',
    'client.lua'
}

server_script 'server.lua'

dependency '/assetpacks'