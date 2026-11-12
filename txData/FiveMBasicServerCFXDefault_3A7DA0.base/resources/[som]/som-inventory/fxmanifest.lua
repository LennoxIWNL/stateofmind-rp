fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'som-inventory'
author 'Lennox'
description 'The inventory actions ox_inventory has no stock path for: throwing, and giving to a named nearby player'
version '0.1.0'

-- NO client script and NO ui_page, which looks like an omission and is not.
--
-- The inventory PAGE is served by ox_inventory, because fetchNui posts to
-- whichever resource served it and a RegisterNUICallback only answers for the
-- resource owning the frame. The page therefore cannot reach a callback
-- registered here, however it is written.
--
-- The bridge that closes that gap is a file added to ox_inventory,
-- `som_bridge.lua`, which registers the extra NUI callbacks and relays them to
-- the validated server events below. That file is on the AUDIT 16.2 re-apply
-- list. The renderer's source lives at ui/apps/som-inventory.
--
-- What lives here is only the half that decides: the server.

server_scripts {
    'server/main.lua',
}

dependencies {
    'ox_inventory',
    'som-core',
}
