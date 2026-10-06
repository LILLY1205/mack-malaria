fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'mack-malaria'
author 'mack-phil'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}


server_scripts {
    'server/*.lua'
}

client_scripts {
    'client/*.lua'
}

files {
    'locales/*.json'
}

-- NOTE: rNotify / bln_notify are intentionally NOT listed here.
-- The script chooses one at runtime via Config.NotifySystem, and
-- hard-requiring both would force admins to install the one they
-- don't use.
dependencies {
    'rsg-core',
    'ox_lib',
}

escrow_ignore {
    'config.lua',
    'installation/*.png',
    'installation/*.lua',
    'locales/*.json'
}

lua54 'yes'