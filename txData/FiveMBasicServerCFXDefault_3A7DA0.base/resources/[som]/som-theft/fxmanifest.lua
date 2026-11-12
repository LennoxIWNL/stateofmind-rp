fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-theft'
author 'Lennox'
description 'Server-validated cash robbery, so cash is stealable without being an inventory item'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
    'config.lua',
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
    'som-core',
    'som-interact',
    'som-ui',
}
