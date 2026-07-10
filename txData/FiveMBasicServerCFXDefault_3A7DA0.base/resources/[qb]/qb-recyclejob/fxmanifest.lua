fx_version 'cerulean'
game 'gta5'

description 'QB-RecycleJob'
version '2.2.0'

shared_scripts {
  '@qbx_core/shared/locale.lua',
  'locales/en.lua',
  'locales/*.lua',
  'config.lua'
}

client_script {
  'client/main.lua',
  '@PolyZone/client.lua',
  '@PolyZone/BoxZone.lua',
  '@PolyZone/CircleZone.lua'
}

server_script 'server/main.lua'

lua54 'yes'
server_scripts { '@oxmysql/lib/MySQL.lua' }