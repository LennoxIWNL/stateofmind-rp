fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-loading'
author 'State of Mind RP'
description 'Loading screen'
version '1.0.0'

client_script 'client.lua'

loadscreen 'html/index.html'

-- The nav links and the volume slider need a pointer. Without this the page
-- renders correctly and nothing on it can be clicked.
loadscreen_cursor 'yes'

-- WE dismiss it, not the game. client.lua waits for the session to actually
-- start; without this the game tears the page down on its own schedule, which
-- is usually while the player is still looking at a black screen behind it.
loadscreen_manual_shutdown 'yes'

files {
    'config.json',
    'html/index.html',
    'html/assets/**',
}
