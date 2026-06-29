fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'Lennox-DoorCreator'
author 'Lennox'
description 'Premium door creation & management tool for ox_doorlock'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/*.lua',
}

client_scripts {
    'client/utils.lua',
    'client/preview.lua',
    'client/creator.lua',
    'client/bulk.lua',
    'client/building.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/framework/*.lua',
    'server/logging.lua',
    'server/backup.lua',
    'server/import.lua',
    'server/export.lua',
    'server/commands.lua',
    'server/main.lua',
}

ui_page 'web/build/index.html'

files {
    'web/build/index.html',
    'web/build/**/*',
}

dependencies {
    'oxmysql',
    'ox_lib',
    'ox_doorlock',
}
