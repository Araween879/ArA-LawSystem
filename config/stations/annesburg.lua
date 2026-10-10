--[[
    ArA-LawSystem - Station: Annesburg - Sheriff Office (New Hanover)

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

Config.Stations.annesburg = {
    enabled = true,                -- false = Station komplett aus (Punkte, Blip, Zellen, Schuesse-Alarm)
    label   = 'Annesburg',         -- Name im Spiel (Prompts, Formulare, Eskort-Bueros)
    depts   = nil,                 -- nil = alle Behoerden duerfen hier arbeiten | z.B. { 'sheriff', 'marshal' }
    jailTo  = 'sisika',            -- Vorauswahl beim Einbuchen: Schluessel eines Knast-Orts ('sisika' oder 'annesburg' fuer eigene Zellen)

    -- Karten-Symbol
    blip = {
        enabled = true,
        name    = 'Annesburg',
        sprite  = 'blip_ambient_sheriff',
        style   = 'BLIP_STYLE_FRIENDLY_ON_RADAR',
        color   = nil,             -- z.B. 'BLIP_MODIFIER_MP_COLOR_32' | nil = Standardfarbe
        coords  = nil,             -- nil = am Schalter (counter) | sonst vector3(...)
    },

    -- Alle Punkte der Station. Jeder Punkt: coords = vector3(x, y, z)
    -- Mehrere Punkte vom selben Typ:  duty = { { coords = ... }, { coords = ... } },
    points = {
        -- Pult / Tresen  (ANPASSEN)
        duty     = { coords = vector3(2907.11, 1313.93, 44.94) },   -- Dienst an/aus
        boss     = { coords = vector3(2907.11, 1313.93, 44.94) },   -- Chef: Personal, Kasse, Protokoll (Dienstbuch)
        counter  = { coords = vector3(2907.11, 1313.93, 44.94) },   -- Schalter fuer ALLE Buerger (Bussgeld, Kaution, Lizenzen, Anzeige ...)
        jail     = { coords = vector3(2907.11, 1313.93, 44.94) },   -- Einbuchen: gefesselte Person steht daneben

        -- Hinterzimmer  (ANPASSEN)
        storage  = { coords = vector3(2904.03, 1309.86, 44.94) },   -- Dienstlager der Behoerde (alle Stationen teilen ein Lager)
        armory   = { coords = vector3(2904.03, 1309.86, 44.94) },   -- Waffenkammer (bezahlt die Kasse der Behoerde)
        evidence = { coords = vector3(2904.03, 1309.86, 44.94) },   -- Asservatenkammer + Labor

        -- Eingang / draussen  (ANPASSEN)
        board    = { coords = vector3(2916.59, 1317.09, 44.35) },   -- Steckbriefbrett (Kopfgelder, Auftraege) - fuer alle
        kennel   = { coords = vector3(2916.59, 1317.09, 44.35), heading = 0.0 },   -- Zwinger: Bluthund holen/abgeben
        dropoff  = { coords = vector3(2916.59, 1317.09, 44.35), radius = 8.0 },    -- Abgabe-Zone fuer Gefangene (Kopfgeld/Auftraege)
        garage   = { coords = vector3(2916.59, 1317.09, 44.35),
                     spawn  = vector4(2922.00, 1321.00, 44.20, 60.00) },   -- Dienstwagen: hier erscheint der Wagen
        escort   = { coords = vector3(2916.59, 1317.09, 44.35),
                     spawn  = vector4(2922.00, 1321.00, 44.20, 60.00),      -- Panzerwagen fuer Werttransporte
                     radius = 25.0 },      -- Liefer-/Abholzone der Eskorten
    },

    -- Eigene Zellen in dieser Station (Knast-Ort mit dem Schluessel 'annesburg').
    -- Standard ist AUS: alle kommen nach Sisika. Zum Einschalten enabled = true
    -- setzen, Werte im Spiel pruefen und oben jailTo = 'annesburg' eintragen.
    -- Zellentueren laut Spieldaten (rdr3_discoveries, Tuer-Angel - Ped steht ~1 m hoeher):
    --   vector3(2904.27, 1314.34, 43.94)
    --   vector3(2902.96, 1310.87, 43.94)
    cells = {
        enabled = false,
        label   = 'Zelle Annesburg',
        center  = vector3(2904.27, 1314.34, 44.94),   -- Mitte der Zelle (ANPASSEN)
        radius  = 8.0,                -- weiter weg = Flucht
        spawn   = vector4(2904.27, 1314.34, 44.94, 0.00),   -- hier steht der Haeftling (ANPASSEN)
        release = vector4(2916.59, 1317.09, 44.35, 60.00),   -- hier kommt er bei Entlassung raus
        work    = {},                 -- Knastarbeit-Punkte (siehe sisika.lua), leer = keine
    },

    -- Schuesse-Alarm: Schuesse in diesem Gebiet meldet ein NPC-Zeuge an die Leitstelle
    shotsZone = {
        enabled = true,
        coords  = vector3(2930.00, 1330.00, 44.00),   -- Mitte der Stadt
        radius  = 170.0,   -- Meter
    },
}
