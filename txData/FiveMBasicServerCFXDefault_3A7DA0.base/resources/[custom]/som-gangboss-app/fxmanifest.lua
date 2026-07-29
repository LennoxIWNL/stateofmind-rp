fx_version 'cerulean'
games { 'gta5' }

name 'som-gangboss-app'
author 'Lennox'
description 'Gang & Business management phone app for State of Mind RP (NPWD)'
version '1.0.0'
lua54 'yes'

shared_script 'config.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_script 'client/main.lua'

-- No ui_page here on purpose: this resource has no SetNuiFocus/open-close
-- logic of its own, it's meant to be embedded as an npwd app (see
-- npwd/config.json's "apps" entry, which loads html/index.html via the
-- cfx-nui-som-gangboss-app URL below). ui_page would additionally spawn an
-- independent, always-visible fullscreen browser for it at resource start.
files {
    'html/index.html',
}
