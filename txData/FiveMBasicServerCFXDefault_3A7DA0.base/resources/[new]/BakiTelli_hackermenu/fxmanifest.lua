fx_version 'cerulean'

game 'gta5'

ui_page 'html/index.html'

client_scripts {
	'shared/config.lua',
	'client.lua',
	'shared/client.lua',
}

server_scripts {
	'@mysql-async/lib/MySQL.lua',
	'shared/config.lua',
	'server.lua',
	'shared/server.lua',
}

files {
	'html/index.html',
	'html/css/*.css',
	'html/fonts/*.css',
	'html/js/*.js',
	'html/imgs/*.png',
	'html/imgs/*.jpg',
	'html/imgs/*.svg',
	'html/fonts/*.ttf',
	'html/fonts/*.woff',
}
lua54 'yes'

escrow_ignore {
	'shared/*.lua'
}
