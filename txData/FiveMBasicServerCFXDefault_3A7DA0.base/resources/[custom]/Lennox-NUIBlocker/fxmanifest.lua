fx_version 'cerulean'
games { 'gta5' }

name 'Lennox-NUIBlocker'
author 'Lennox'
description 'Universal NUI exploit protection — tracks open NUI states server-side, rate-limits actions, blocks inventory/shop/crafting abuse when no NUI is open.'
version '1.0.0'
lua54 'yes'

shared_script 'config.lua'
client_script 'client/main.lua'
server_script 'server/main.lua'

provides { 'nui-blocker' }
