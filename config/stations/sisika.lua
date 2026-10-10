--[[
    ArA-LawSystem - Station: Sisika-Gefaengnis (Insel vor Saint Denis)

    ACHTUNG: Das hier ist auch das STANDARD-GEFAENGNIS des ganzen Servers
    (Config.Jail.DefaultLocation = 'sisika' in config/justice.lua).
    Wer diese Station ausschaltet, braucht einen anderen Knast-Ort
    (z.B. eigene Zellen einer Stadt) und muss DefaultLocation umstellen.

    So stellst du diese Station ein:
      1. Im Spiel als Admin an die gewuenschte Stelle stellen
      2. /lawcoords eingeben -> Position steht in der F8-Konsole
      3. Zahlen hier einfuegen, speichern, "restart ArA-LawSystem"

    Alles mit "ANPASSEN" sind Startwerte und sollten einmal im Spiel
    geprueft werden. Alle Felder sind in config/stations/_vorlage.lua erklaert.
]]

Config.Stations = Config.Stations or {}

Config.Stations.sisika = {
    enabled = true,                -- false = Station + Gefaengnis aus (siehe ACHTUNG oben)
    label   = 'Sisika-Gefaengnis', -- Name im Spiel
    jobs    = nil,                 -- Jobs fuer die GANZE Station: nil = alle Behoerden | z.B. { 'prisonguard' } nur Waerter
    jailTo  = 'sisika',            -- hier eingebucht -> bleibt auf Sisika

    -- Karten-Symbol
    blip = {
        enabled = true,
        name    = 'Sisika',
        sprite  = 'blip_ambient_sheriff',
        style   = 'BLIP_STYLE_FRIENDLY_ON_RADAR',
        color   = nil,
        coords  = nil,             -- nil = am Schalter (counter), sonst am Dienst-Punkt (duty)
    },

    -- Punkte der Waerter. Sisika hat bewusst keine Waffenkammer, keine
    -- Garage, kein Steckbriefbrett und kein Eskort-Buero. Wer sie haben will:
    -- Zeile aus der Vorlage (_vorlage.lua) kopieren und Koordinaten eintragen.
    points = {  -- ANPASSEN
        duty    = { coords = vector3(3339.07, -669.41, 45.83) },   -- Dienst an/aus
        storage = { coords = vector3(3339.07, -669.41, 45.83) },   -- Dienstlager
        jail    = { coords = vector3(3339.07, -669.41, 45.83) },   -- Einbuchen
        counter = { coords = vector3(3339.07, -669.41, 45.83) },   -- Schalter (z.B. Kaution, Habseligkeiten)
    },

    -- Das Gefaengnis selbst (Knast-Ort 'sisika'): Verurteilte werden hierher TRANSPORTIERT
    -- (Teleport), weil es keinen Weg auf die Insel gibt. Zellen mit Tueren: siehe Stadt-Dateien.
    prison = {
        enabled = true,
        label   = 'Sisika-Gefaengnis',
        center  = vector3(3339.23, -670.12, 45.83),          -- Mitte der Insel
        radius  = 100.0,                                     -- weiter weg = Flucht
        spawn   = vector4(3339.07, -669.41, 45.83, 194.42),  -- hier landet der Haeftling
        release = vector4(2518.42, -1308.34, 49.01, 275.49), -- Entlassung: Saint Denis (aus vorp_police)
        -- Knastarbeit: verkuerzt die Haftzeit (Einstellungen: Config.Jail.Work in config/justice.lua)
        -- scenario = Animation, die der Haeftling dabei spielt
        work = {  -- ANPASSEN: Arbeitspunkte auf der Insel
            { coords = vector3(3346.50, -680.20, 45.50), label = 'Steine klopfen',    scenario = 'WORLD_HUMAN_FARMER_HOE' },
            { coords = vector3(3330.80, -660.40, 45.80), label = 'Hof fegen',         scenario = 'WORLD_HUMAN_BROOM_WORKING' },
            { coords = vector3(3352.10, -662.90, 45.60), label = 'Unkraut jaeten',    scenario = 'WORLD_HUMAN_CROUCH_INSPECT' },
            { coords = vector3(3326.40, -676.70, 45.70), label = 'Holz aufschichten', scenario = 'WORLD_HUMAN_FARMER_RAKE' },
        },
    },

    -- Kein Schuesse-Alarm auf der Insel (Waerter sind ja vor Ort)
    shotsZone = nil,
}
