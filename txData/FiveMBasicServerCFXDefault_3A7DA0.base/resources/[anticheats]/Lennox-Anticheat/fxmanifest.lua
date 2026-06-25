fx_version 'cerulean'
games { 'gta5' }

name 'Lennox-Anticheat'
author 'Lennox'
description 'Lennox Anti-Cheat v1.0 Full Release — 50+ detection modules, hardware fingerprinting, behavioral analysis, economy protection, framework auto-detection.'
version '1.0.0'
lua54 'yes'

shared_script 'config.lua'

server_scripts {
    'server/main.lua',
    'server/detections.lua',
    'server/protection.lua',
    'server/hwid.lua',
    'server/behavioral.lua',
    'server/damage_model.lua',
    'server/economy.lua',
    'server/validation.lua',
    'server/connect.lua',
    'server/commands.lua',
}

client_script 'client/main.lua'

files {
    'data/bans.json',
}
