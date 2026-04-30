fx_version 'cerulean'
game 'gta5'

author 'Ari / ESX-Framework'
description 'ari_garage - Advanced Vehicle Garage & Impound System'

version '1.15.0-ari'
legacyversion '1.15.0-ari'

lua54 'yes'

shared_script '@es_extended/imports.lua'

server_scripts {
    '@es_extended/locale.lua',
    'locales/*.lua',
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server/main.lua'
}

client_scripts {
    '@es_extended/locale.lua',
    'locales/*.lua',
    'config.lua',
    'client/main.lua'
}

ui_page 'nui/ui.html'

files {
    'nui/ui.html',
    'nui/js/*.js',
    'nui/css/*.css'
}
