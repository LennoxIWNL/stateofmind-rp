--[[ FX Information ]] --
fx_version 'cerulean'
-- SOM: DISABLED.
--
-- Every file this resource ships is present on disk (obtaizen_ui.ytd 18KB,
-- oxdoorlock.awc 53KB, web/build), yet the server logged "could not find file
-- audio/dlc_oxdoorlock/oxdoorlock.awc" and the client never loaded the
-- obtaizen_ui texture dictionary. A reinstall would have changed nothing.
--
-- fxv2 OAL is an EXPERIMENTAL asset loader, and one loader misbehaving explains
-- both symptoms at once: file resolution for the manifest and streaming for the
-- ytd. Turning it off falls back to the stable path.
--
-- If the awc warning and the white square both disappear, this was the cause.
-- If they persist, it was not, and the next suspect is the stream folder not
-- being indexed at all.
-- use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'

--[[ Resource Information ]] --
name 'ox_doorlock'
version      '1.22.1'
license 'GPL-3.0-or-later'
author 'Overextended'
repository 'https://github.com/overextended/ox_doorlock'

--[[ Manifest ]] --
shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    -- SOM: replaces lib.skillCheck with som-ui's, so the lockpick minigame is
    -- SOM rather than stock ox_lib. FIRST, so the replacement is in place
    -- before client/utils.lua ever calls it. Degrades to ox_lib's own if
    -- som-ui is stopped. See som-ui/client/skillcheck.lua.
    '@som-ui/client/skillcheck.lua',
    -- And lib.inputDialog, which is the door passcode prompt in client/main.lua.
    '@som-ui/client/dialog.lua',
    'client/main.lua',
    'client/utils.lua',
}

server_scripts {
    -- SOM: FIRST, so ox_doorlock:setState refuses a client chosen lockpick flag on a door that is not
    -- lockpickable. Put this line back after an upgrade. See som-compat/server/guard.lua.
    '@som-compat/server/guard.lua',
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'web/build/index.html'

files {
    'web/build/index.html',
    'web/build/**/*',
    'locales/*.json',
    'audio/data/oxdoorlock_sounds.dat54.rel',
    'audio/dlc_oxdoorlock/oxdoorlock.awc',
}

data_file 'AUDIO_WAVEPACK' 'audio/dlc_oxdoorlock'
data_file 'AUDIO_SOUNDDATA' 'audio/data/oxdoorlock_sounds.dat'

dependencies {
    'oxmysql',
    'ox_lib',
}

ox_libs {
    'locale',
    'table',
}
