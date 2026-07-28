fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'APEX FiveM'
description 'APEX NPC MECHANIC'

shared_scripts {
    'config.lua',
    'locales/*.lua'
}

client_script 'client/main.lua'
server_script 'server/main.lua'

dependency '/onesync'
