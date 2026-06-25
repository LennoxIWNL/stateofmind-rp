fx_version 'bodacious'
game 'common'

server_scripts {
    'server/sv_queue_config.lua',
    'server/sv_discord.lua',
    'connectqueue.lua',
    'shared/sh_queue.lua',
}

client_script 'shared/sh_queue.lua'