--[[
    ArA-LawSystem - Station: Blackwater - Police Office (West Elizabeth)

    So stellst du diese Station ein:
      1. Im Spiel als Admin an die gewuenschte Stelle stellen
      2. /lawcoords eingeben -> Position steht in der F8-Konsole
      3. Zahlen hier einfuegen, speichern, "restart ArA-LawSystem"

    Alles mit "ANPASSEN" sind Startwerte (aus vorp_police bzw. geschaetzt)
    und sollten einmal im Spiel geprueft werden.
    Einen Punkt nicht haben wollen?  ->  enabled = false  in den Punkt schreiben
    Die ganze Station nicht haben?   ->  enabled = false  ganz oben
    Alle Felder sind in config/stations/_vorlage.lua genau erklaert.
]]

Config.Stations = Config.Stations or {}

Config.Stations.blackwater = {
    enabled = true,                -- false = Station komplett aus (Punkte, Blip, Zellen, Schuesse-Alarm)
    label   = 'Blackwater',        -- Name im Spiel (Prompts, Formulare, Eskort-Bueros)
    jobs    = nil,                 -- Jobs fuer die GANZE Station: nil = alle Behoerden | z.B. { 'sheriff', 'marshal' }
    jailTo  = 'sisika',            -- Vorauswahl beim Einbuchen: Schluessel eines Knast-Orts ('sisika' oder 'blackwater' fuer eigene Zellen)

    -- Karten-Symbol
    blip = {
        enabled = true,
        name    = 'Blackwater',
        sprite  = 'blip_ambient_sheriff',
        style   = 'BLIP_STYLE_FRIENDLY_ON_RADAR',
        color   = nil,             -- z.B. 'BLIP_MODIFIER_MP_COLOR_32' | nil = Standardfarbe
        coords  = nil,             -- nil = am Schalter (counter), sonst am Dienst-Punkt (duty) | sonst vector3(...)
    },

    -- Alle Punkte der Station. Jeder Punkt: coords = vector3(x, y, z)
    -- Nur bestimmte Jobs an einem Punkt:  armory = { coords = ..., jobs = { 'sheriff' } },
    -- Mehrere Punkte vom selben Typ:  duty = { { coords = ... }, { coords = ... } },
    points = {
        -- Pult / Tresen  (ANPASSEN)
        duty     = { coords = vector3(-761.95, -1272.62, 44.05) },   -- Dienst an/aus
        boss     = { coords = vector3(-761.95, -1272.62, 44.05) },   -- Chef: Personal, Kasse, Protokoll (Dienstbuch)
        counter  = { coords = vector3(-761.95, -1272.62, 44.05) },   -- Schalter fuer ALLE Buerger (Bussgeld, Kaution, Lizenzen, Anzeige ...)
        jail     = { coords = vector3(-761.95, -1272.62, 44.05) },   -- Einbuchen: gefesselte Person steht daneben

        -- Hinterzimmer  (ANPASSEN)
        storage  = { coords = vector3(-765.12, -1272.37, 44.04) },   -- Dienstlager der Behoerde (alle Stationen teilen ein Lager)
        armory   = { coords = vector3(-765.12, -1272.37, 44.04) },   -- Waffenkammer (bezahlt die Kasse der Behoerde)
        evidence = { coords = vector3(-765.12, -1272.37, 44.04) },   -- Asservatenkammer + Labor

        -- Eingang / draussen  (ANPASSEN)
        board    = { coords = vector3(-752.53, -1266.10, 43.43) },   -- Steckbriefbrett (Kopfgelder, Auftraege) - fuer alle
        kennel   = { coords = vector3(-752.53, -1266.10, 43.43), heading = 0.0 },   -- Zwinger: Bluthund holen/abgeben
        dropoff  = { coords = vector3(-752.53, -1266.10, 43.43), radius = 8.0 },    -- Abgabe-Zone fuer Gefangene (Kopfgeld/Auftraege)
        garage   = { coords = vector3(-752.53, -1266.10, 43.43),
                     spawn  = vector4(-747.00, -1262.00, 43.40, 90.00) },   -- Dienstwagen: hier erscheint der Wagen
        escort   = { coords = vector3(-752.53, -1266.10, 43.43),
                     spawn  = vector4(-747.00, -1262.00, 43.40, 90.00),      -- Panzerwagen fuer Werttransporte
                     radius = 25.0 },      -- Liefer-/Abholzone der Eskorten
    },

    -- Eigene Zellen in dieser Station (Knast-Ort mit dem Schluessel 'blackwater').
    -- Standard ist AUS: alle kommen nach Sisika. Zum Einschalten enabled = true
    -- setzen, Werte im Spiel pruefen und oben jailTo = 'blackwater' eintragen.
    -- Zellentueren laut Spieldaten (rdr3_discoveries, Tuer-Angel - Ped steht ~1 m hoeher):
    --   vector3(-763.53, -1262.46, 43.02)
    --   vector3(-765.86, -1264.70, 43.02)
    cells = {
        enabled = false,
        label   = 'Zelle Blackwater',
        center  = vector3(-763.53, -1262.46, 44.02),   -- Mitte der Zelle (ANPASSEN)
        radius  = 8.0,                -- weiter weg = Flucht
        spawn   = vector4(-763.53, -1262.46, 44.02, 0.00),   -- hier steht der Haeftling (ANPASSEN)
        release = vector4(-752.53, -1266.10, 43.43, 90.00),   -- hier kommt er bei Entlassung raus
        work    = {},                 -- Knastarbeit-Punkte (siehe sisika.lua), leer = keine
    },

    -- Schuesse-Alarm: Schuesse in diesem Gebiet meldet ein NPC-Zeuge an die Leitstelle
    shotsZone = {
        enabled = true,
        coords  = vector3(-800.00, -1290.00, 43.00),   -- Mitte der Stadt
        radius  = 250.0,   -- Meter
    },
}
