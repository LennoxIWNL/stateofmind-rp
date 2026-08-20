fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-ui'
author 'State of Mind RP'
description 'SOM notifications and progress, the single implementation behind som:client:notify'
version '0.2.0'

shared_scripts {
    'shared/config.lua',
}

client_scripts {
    'client/notify.lua',
    'client/progress.lua',
    'client/contextui.lua',
    'client/skillcheckui.lua',
    'client/dialogui.lua',
    'client/feedback.lua',
}

-- client/progressbar.lua, client/context.lua, client/skillcheck.lua and
-- client/dialog.lua are deliberately NOT in client_scripts. They are loaded by consumers with
-- '@som-ui/client/<file>.lua' so that they run inside the calling resource,
-- where their `lib` table is the caller's own and where the callbacks they hold
-- actually live. See the header of each file.
--
-- They MUST still appear in files{} below, or the client never receives them
-- and every consumer fails to start on a missing include. ox_lib lists its own
-- init.lua for exactly this reason.

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    -- Fetched by consumers as '@som-ui/client/progressbar.lua'.
    'client/progressbar.lua',
    -- Fetched by consumers as '@som-ui/client/context.lua'.
    'client/context.lua',
    -- Fetched by consumers as '@som-ui/client/skillcheck.lua'.
    'client/skillcheck.lua',
    -- Fetched by consumers as '@som-ui/client/dialog.lua'.
    'client/dialog.lua',
}

dependencies {
    'som-assets',
}
