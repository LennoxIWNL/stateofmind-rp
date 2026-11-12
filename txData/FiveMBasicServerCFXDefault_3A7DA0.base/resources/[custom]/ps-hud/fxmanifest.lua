fx_version 'cerulean'
game 'gta5'

description 'ps-hud'
version '2.1.2'

shared_scripts {
	-- SOM: repointed from @qb-core. There is no qb-core resource on this
	-- server; som-compat answers the qb-core EXPORTS but a manifest
	-- @-reference is a file path and resolves by real directory name, so
	-- this failed to start before any of ps-hud's code ran.
	'@som-compat/shared/locale.lua',
	'locales/en.lua',
	'locales/*.lua',
	'config.lua',
	'uiconfig.lua'
}

client_script 'client.lua'
-- SOM: FIRST, so the stress events are bounded. Put this line back after an upgrade. See som-compat/server/guard.lua.
server_script '@som-compat/server/guard.lua'
server_script 'server.lua'
lua54 'yes'
use_fxv2_oal 'yes'

ui_page 'html/index.html'

files {
	'html/*',
}
