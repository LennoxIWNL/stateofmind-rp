fx_version 'cerulean'
game 'gta5'

description 'QB-Vineyard'
version '1.2.0'

shared_scripts {
    '@qbx_core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    'config.lua'
}

server_script 'server.lua'

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    'client.lua'
}

dependencies {
    'qb-core',
    'PolyZone'
}

lua54 'yes'
server_scripts { '@oxmysql/lib/MySQL.lua' }server_scripts { '@oxmysql/lib/MySQL.lua' }