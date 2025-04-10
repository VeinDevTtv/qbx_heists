fx_version 'cerulean'
game 'gta5'

description 'QBX Heists - Advanced Heist System for Gangs'
version '1.0.0'
author 'Vein'

lua54 'yes'

shared_scripts {
    '@qbx_core/shared/locale.lua',
    'locales/en.lua',
    'config.lua'
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/events.lua',
    'client/target.lua',
    'client/heist_types/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/events.lua',
    'server/heist_types/*.lua'
}

ui_page 'web/build/index.html'

files {
    'web/build/index.html',
    'web/build/**/*'
}

dependencies {
    'qbx_core',
    'oxmysql',
    'qbx_laptop'
} 