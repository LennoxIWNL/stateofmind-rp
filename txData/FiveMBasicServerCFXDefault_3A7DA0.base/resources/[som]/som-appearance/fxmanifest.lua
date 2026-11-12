fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-appearance'
author 'Lennox'
description 'SOM appearance: character creator, barber and clothing, over the standard ped appearance shape'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
    'shared/config.lua',
}

client_scripts {
    'client/appearance.lua',
    'client/main.lua',
    -- After main, because it calls Appearance.Apply which appearance.lua
    -- defines and main.lua is the one that already proves is reachable.
    'client/wardrobe.lua',
    -- The barber and clothing store zones. Last, because they only call the
    -- openEditor export, which main.lua registers.
    'client/zones.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    -- Taking clothes off, asked for by the inventory. Lives here rather than in
    -- som-inventory so there is still exactly one writer of appearance.
    'server/wardrobe.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'som-core',
    'som-assets',
    'som-interact',
}
