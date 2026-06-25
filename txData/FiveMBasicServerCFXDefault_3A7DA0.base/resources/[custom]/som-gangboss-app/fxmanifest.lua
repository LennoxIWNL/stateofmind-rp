fx_version 'cerulean'
games { 'gta5' }

name 'som-gangboss-app'
author 'Lennox'
description 'Gang & Business management phone app for State of Mind RP (NPWD)'
version '1.0.0'
lua54 'yes'

shared_script 'config.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_script 'client/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
}
