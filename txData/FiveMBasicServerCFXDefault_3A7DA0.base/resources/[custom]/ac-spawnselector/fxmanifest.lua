fx_version 'cerulean'
game 'gta5'
lua54 'yes'
escrow_ignore {
	'config.lua',
	'c.lua',
	's.lua',
	'example-qb-apartments-config.lua'
}
shared_scripts {
	'config.lua',
	'@qb-apartments/config.lua'
} 
escrow_ignore 'config.lua'
client_script 'c.lua'
server_script 's.lua'
ui_page 'html/index.html'
files {
	'html/index.html',
	'html/style.css',
	'html/index.js',
    'html/files/*.png',
    'html/files/*.jpg',
	'html/fonts/*.otf',
	'html/fonts/*.ttf'
}
dependency '/assetpacks'
dependency '/assetpacks'