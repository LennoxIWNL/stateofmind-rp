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
    'client/feedback.lua',
}

-- client/progressbar.lua is deliberately NOT in client_scripts. It is loaded by
-- consumers with '@som-ui/client/progressbar.lua' so that it runs inside the
-- calling resource, where it can yield and where its `lib` table is the
-- caller's own. See the header of that file.
--
-- It MUST still appear in files{} below, or the client never receives it and
-- every consumer fails to start on a missing include. ox_lib lists its own
-- init.lua for exactly this reason.

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    -- Fetched by consumers as '@som-ui/client/progressbar.lua'.
    'client/progressbar.lua',
}

dependencies {
    'som-assets',
}
