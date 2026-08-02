fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-chat'
author 'State of Mind RP'
description 'SOM chat: proximity messages, command input, and the stock chat:addMessage compatibility'
version '0.1.0'

-- Replaces the stock cfx `chat`, which is absent from this server. Declared so
-- anything depending on chat by name resolves.
provide 'chat'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'ox_lib',
    'som-core',
    'som-assets',
}
