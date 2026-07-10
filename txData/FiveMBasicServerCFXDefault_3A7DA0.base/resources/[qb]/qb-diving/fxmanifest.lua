fx_version 'cerulean'
game 'gta5'

description 'QB-Diving'
version '1.2.1'

shared_script {
    '@qbx_core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    'config.lua'
}

server_script 'server/main.lua'

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    'client/main.lua'
}

lua54 'yes'
server_scripts { '@oxmysql/lib/MySQL.lua' }