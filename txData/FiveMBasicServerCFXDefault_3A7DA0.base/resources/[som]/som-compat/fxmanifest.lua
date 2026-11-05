fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-compat'
author 'Lennox'
description 'Legacy qb-core export surface backed by som-core, so preserved resources run untouched'
version '0.1.0'

-- Answers exports['qb-core']:GetCoreObject() the same way qbx_core does today.
-- Never enable this alongside qbx_core: both claim the same name.
provide 'qb-core'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
    -- NOT loaded into som-compat itself, only EXPOSED so ps-hud's manifest can
    -- @-reference it. Listed in files{} below rather than here, because loading
    -- it into every script that includes som-compat would define a global
    -- Locale nothing here uses.
    'shared/lazy.lua',
    'shared/items.lua',
    'shared/vehicles.lua',
}

client_scripts {
    -- Replaces lib.progressBar with som-ui's, so QBCore.Functions.Progressbar
    -- draws the SOM bar for every preserved resource that calls it, r14-evidence
    -- included. Client only, so it cannot go in shared_scripts.
    '@som-ui/client/progressbar.lua',
    'client/qbcore.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/qbcore.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'som-core',
    'som-ui',
}

-- ps-hud @-references shared/locale.lua. See that file for why it exists.
files {
    'shared/locale.lua',
}
