fx_version "cerulean"

game "gta5"
lua54 "yes"
client_scripts {
	'config.lua',
	'core/cl.lua'
}

server_scripts {
	'config.lua',
	'core/sv.lua'
}

file {
	'web/**'
}

ui_page 'web/index.html'