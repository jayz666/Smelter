fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Smelter Script'
description 'Minimal standalone smelter script'
version '1.0.0'

dependencies {
    'ox_lib',
    'ox_inventory',
    'ox_target'
}

shared_script 'config.lua'

client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
