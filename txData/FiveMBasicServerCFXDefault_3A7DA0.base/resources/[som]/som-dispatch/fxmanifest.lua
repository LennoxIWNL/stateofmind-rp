fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-dispatch'
author 'State of Mind RP'
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
    'shared/config.lua',
}

client_scripts {
    'client/detect.lua',
    'client/alerts.lua',
    -- The client half of the ps-dispatch export surface. ps-mdt calls
    -- CustomAlert from the client, where nothing answered before.
    'client/compat.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'som-core',
}
