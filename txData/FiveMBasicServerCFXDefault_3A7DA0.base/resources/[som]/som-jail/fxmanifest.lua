fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-jail'
author 'Lennox'
description 'Jail and bail: booking, time served, the yard, and bail'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    -- Replaces lib.inputDialog and lib.alertDialog with som-ui's. Client
    -- only, so it cannot go in shared_scripts, and first, so every file
    -- below sees the replacement: the booking dialog and the bail confirm.
    '@som-ui/client/dialog.lua',
    '@som-ui/client/progressbar.lua',
    'client/booking.lua',
    'client/cell.lua',
    'client/service.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    -- jail.lua first: it defines Jail, which bail.lua reads through for the
    -- release-on-forfeiture path, same split som-housing uses between
    -- ownership.lua and finance.lua.
    'server/jail.lua',
    'server/bail.lua',
    'server/service.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'som-core',
    'som-court',
    'som-medical',
    'som-interact',
    'som-dispatch',
    -- The input/alert dialog shim is loaded from it at start time, so its
    -- absence must be a loud failure rather than a nil call at a booking.
    'som-ui',
}
