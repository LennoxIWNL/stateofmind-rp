fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-garage'
author 'State of Mind RP'
description 'Vehicle ownership and garages: personal, business fleets and the police pool, with a live preview'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    -- What the dealerships sell. Shared, because the server sells from it and
    -- the client's zones read Config.Shops beside it.
    'shared/catalogue.lua',
}

client_scripts {
    -- Replaces lib.registerContext with som-ui's, which is what takes the mod
    -- bay's four menus off ox_lib's stock UI. Client only, so it cannot go in
    -- shared_scripts, and first, so every file below sees the replacement.
    '@som-ui/client/context.lua',
    -- And lib.inputDialog, which is how a buyer picks cash or card when a
    -- dealer offers them a car.
    '@som-ui/client/dialog.lua',
    -- preview first: garage.lua calls into it.
    'client/preview.lua',
    'client/garage.lua',
    -- After garage.lua, which declares the Panel table the dealership shows
    -- through, and whose `buy` callback delegates here in shop mode.
    'client/dealership.lua',
    'client/modshop.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    -- vehicles.lua defines the Vehicles authority that the other two use.
    'server/vehicles.lua',
    'server/garage.lua',
    'server/fleet.lua',
    'server/dealership.lua',
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
    'som-interact',
    'som-assets',
    -- The context menu shim is loaded from it at start time, so its absence
    -- must be a loud failure rather than a nil call later.
    'som-ui',
}
