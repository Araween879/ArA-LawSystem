fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

author 'Araween'
description 'ArA-LawSystem - Sheriff, Marshals, Police, Pinkerton, Knast, Kopfgeld, Bussgeld, Spuren, Waffenregister, Bluthund, Eskorten'
version '1.0.0'

-- Reihenfolge ist Vertrag (docs/01_CONTRACT.md, Abschnitt 2):
-- erst alle Config-Dateien, dann die Helfer, dann die Texte.
shared_scripts {
    'config/main.lua',
    'config/justice.lua',
    'config/investigation.lua',
    'config/escort.lua',
    'shared/*.lua',
    'locales/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/server_only.lua',   -- Webhooks: NUR Server, nie an Clients
    'server/core/*.lua',        -- nummeriert, Kern zuerst
    'server/justice/*.lua',
    'server/investigation/*.lua',
    'server/escort/*.lua',
    'server/zz_boot.lua',       -- startet alles, wenn alle Module geladen sind
}

client_scripts {
    'client/core/*.lua',
    'client/justice/*.lua',
    'client/investigation/*.lua',
    'client/escort/*.lua',
    'client/zz_boot.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/**/*',
}

dependencies {
    'oxmysql',
    'vorp_core',
    'vorp_inventory',
    -- vorp_progressbar wird benutzt, wenn vorhanden (sonst Wartezeit ohne Balken)
    -- vorp_police DARF NICHT laufen (gleiche Items/Befehle) - siehe docs/INSTALL.md
}
