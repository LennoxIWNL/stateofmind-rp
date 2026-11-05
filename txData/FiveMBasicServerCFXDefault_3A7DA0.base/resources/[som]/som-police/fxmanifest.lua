fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-police'
author 'Lennox'
description 'LSPD: duty, armoury, custody, fines, impounds and certifications'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    -- Replaces lib.progressBar, lib.registerContext and lib.inputDialog with
    -- som-ui's. Client only, so none can go in shared_scripts, and first, so
    -- every file below sees the replacement. Between them these cover the plate
    -- lookup, the impound reason list, the fleet, the ID check, the fine
    -- presets, and the three forms those open into: the custom fine amount, the
    -- impound release payment and the plate flag reason.
    '@som-ui/client/progressbar.lua',
    '@som-ui/client/context.lua',
    '@som-ui/client/dialog.lua',
    -- duty first: stations, custody and keybinds all read Duty.IsOnDuty().
    'client/duty.lua',
    'client/armoury.lua',
    'client/stations.lua',
    'client/custody.lua',
    'client/vehicles.lua',
    'client/keybinds.lua',
    'client/vehiclecontrols.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    -- main first: it defines Police, which every other server file calls for
    -- its authority checks.
    'server/main.lua',
    'server/custody.lua',
    'server/vehicles.lua',
    'server/fines.lua',
    'server/impound.lua',
    'server/incidents.lua',
}

-- Built from ui/apps/som-police. Do not edit html/ by hand, it is generated.
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/assets/*.js',
    'html/assets/*.css',
    'html/assets/*.map',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'som-core',
    'som-interact',
    'som-economy',
    'som-assets',
    -- The progress bar is loaded from it at start time, so its absence must be
    -- a loud failure rather than a nil call later.
    'som-ui',
}
