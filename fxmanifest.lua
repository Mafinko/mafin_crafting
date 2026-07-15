fx_version 'cerulean'
game 'gta5'

author 'Mafin'
description 'A refined monochrome crafting experience by Mafin, built for smooth progression, responsive recipes, and effortless server performance.'
version '2.0.0'

shared_scripts {
    'config.lua',
    'locales/en.lua',
    'locales/cs.lua',
    '@ox_lib/init.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'data/mafin_crafting_xp.json',
}

dependencies {
    'es_extended',
    'ox_inventory',
    'ox_target',
    'ox_lib',
}
