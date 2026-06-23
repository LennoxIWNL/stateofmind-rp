fx_version "cerulean"
game 'gta5'
lua54 'yes'
description "Karma Developments 4.0 - Report System"
author "ANTUNES & UnknownJohn"
version '1.0.0'

ui_page 'web/build/index.html'

files {
  'web/build/index.html',
  'web/build/**/*'
}

client_scripts { 
  "client/**/*",
}

server_scripts { 
  "server/**/*",
}

escrow_ignore {
  'client/cl_registercommand.lua',
  'server/sv_main.lua',
}