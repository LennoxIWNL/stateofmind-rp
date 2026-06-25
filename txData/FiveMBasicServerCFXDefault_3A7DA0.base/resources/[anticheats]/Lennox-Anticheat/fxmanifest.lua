fx_version 'cerulean'
games { 'gta5' }

name 'Lennox-Anticheat'
author 'Lennox'
description 'Server-authoritative anti-cheat — weapon/explosion/entity filtering, heartbeat tamper detection, teleport/speed monitoring, honeypot traps, ban evasion blocking.'
version '1.0.0'
lua54 'yes'

shared_script 'config.lua'

server_scripts {
    'server/main.lua',
    'server/detections.lua',
    'server/connect.lua',
    'server/commands.lua',
}

client_script 'client/main.lua'

files {
    'data/bans.json',
}
