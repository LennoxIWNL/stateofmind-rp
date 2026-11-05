fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-props'
author 'Lennox'
description 'Placeable scene props: cones, barriers and worklights, placed and picked up under server authority'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    -- Replaces lib.progressBar with som-ui's. Client only, so it cannot go in
    -- shared_scripts, and first, so main.lua sees the replacement.
    '@som-ui/client/progressbar.lua',
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'ox_inventory',
    'som-interact',
    'som-ui',
}
