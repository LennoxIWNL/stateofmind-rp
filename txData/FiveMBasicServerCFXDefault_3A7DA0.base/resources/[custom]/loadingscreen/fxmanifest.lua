fx_version "cerulean"

games { "gta5" }

description "State of Mind RP Loading Screen"

version "0.1.0"

-- Load NUI project
--loadscreen 'http://localhost:3000'
loadscreen 'nui/dist/index.html'
loadscreen_manual_shutdown "yes"
loadscreen_cursor 'yes'

files {
    "nui/dist/**/*",
}

server_scripts { "build/sv_*.js" }
client_scripts { "build/cl_*.js" }

lua54 'yes'
