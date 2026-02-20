fx_version 'cerulean'
game 'gta5'

author 'Jayz'
description 'Standalone FiveM Industrial Smelting System'
version '1.0.0'

lua54 'yes'

-- Dependencies
dependencies {
    'ox_lib',
    'ox_inventory',
    'ox_target',
    'oxmysql'
}

-- Shared scripts
shared_script '@ox_lib/init.lua'

-- Server scripts
server_script 'database.lua'
server_script 'config.lua'
server_script 'server.lua'

-- Client scripts
client_script 'config.lua'
client_script 'client.lua'

-- NUI files
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
