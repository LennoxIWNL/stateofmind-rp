fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-hud'
author 'State of Mind RP'
description 'The HUD: condition, speedometers, compass, location and the layout editor'
version '0.2.0'

-- READ ONLY, with one exception that is worth stating rather than burying.
--
-- Nothing here changes anything. It watches natives and som-core's client
-- mirror and describes what it sees, so there is no server half and nothing for
-- a client to lie to.
--
-- The exception is client/editor.lua, which accepts a LAYOUT from the page:
-- positions, scales and which panels are on. Never a value. A player editing
-- their own HUD has moved their own numbers around their own screen.
--
-- The seatbelt is the other half of an indicator: without ejection physics
-- behind it, a belt icon is decoration. See client/seatbelt.lua.

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/seatbelt.lua',
    'client/main.lua',
    'client/editor.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/assets/*.js',
    'html/assets/*.css',
}

dependencies {
    'ox_lib',
    'som-core',
}
