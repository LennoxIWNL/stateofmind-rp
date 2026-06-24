fx_version 'cerulean'
game 'gta5'

description 'Compatibility bridge: maps old qb-phone events/exports to npwd'
version '1.0.0'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

client_script 'client.lua'

lua54 'yes'

provide 'qb-phone'
