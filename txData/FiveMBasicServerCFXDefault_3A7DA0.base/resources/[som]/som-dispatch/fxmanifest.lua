fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-dispatch'
author 'Lennox'
description 'Crime alerts and the call store, answering to the ps-dispatch surface ps-mdt expects'
version '0.1.0'

-- ps-mdt calls exports['ps-dispatch']:GetDispatchCalls(). This satisfies its
-- dependency check; the exports themselves are published under that name by the
-- __cfx_export_ps-dispatch_<name> handlers in server/main.lua, because `provide`
-- does not forward exports on its own.
--
-- Never enable this alongside a real ps-dispatch: both claim the same name.
provide 'ps-dispatch'

shared_scripts {
    '@ox_lib/init.lua',
    '@som-core/shared/trace.lua',
    'shared/config.lua',
}

client_scripts {
    '@som-ui/client/context.lua',
    '@som-ui/client/dialog.lua',
    'client/panel.lua',
    'client/detect.lua',
    'client/alerts.lua',
    -- The client half of the ps-dispatch export surface. ps-mdt calls
    -- CustomAlert from the client, where nothing answered before.
    'client/compat.lua',
    -- Draws the feed. Purely additive: it forwards the same call record
    -- alerts.lua already receives, so ps-mdt's dispatch tab keeps working
    -- unchanged alongside it.
    'client/nui.lua',
}

server_scripts {
    'server/main.lua',
}

-- Built from ui/apps/som-dispatch. Do not edit html/ by hand, it is generated.
--
-- The asset names are stable rather than hashed, which is what lets this glob
-- work: vite's default hashed filenames would need this block edited on every
-- build, and a manifest that silently stops matching serves a blank page.
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/assets/*.js',
    'html/assets/*.css',
    'html/assets/*.map',
}

dependencies {
    'ox_lib',
    'som-core',
    'som-ui',
}
