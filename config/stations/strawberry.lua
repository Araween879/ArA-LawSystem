--[[
    ArA-LawSystem - Station: Strawberry - Sheriff Office (West Elizabeth)

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

-- HINWEIS: Die Zellentueren liegen laut Spieldaten ca. 4 m TIEFER (z = 160.4) als die Punkte oben (z = 164.6). Hoehe im Spiel pruefen!

Config.Stations = Config.Stations or {}

Config.Stations.strawberry = {
    enabled = true,                -- false = Station komplett aus (Punkte, Blip, Zellen, Schuesse-Alarm)
    label   = 'Strawberry',        -- Name im Spiel (Prompts, Formulare, Eskort-Bueros)
    jobs    = nil,                 -- Jobs fuer die GANZE Station: nil = alle Behoerden | z.B. { 'sheriff', 'marshal' }
    jailTo  = 'sisika',            -- Gefaengnis beim Einbuchen am Pult (Transport, Teleport). Zellen hier: an der Zellentuer

    -- Karten-Symbol
    blip = {
        enabled = true,
        name    = 'Strawberry',
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
        duty     = { coords = vector3(-1807.03, -348.47, 164.65) },   -- Dienst an/aus
        boss     = { coords = vector3(-1807.03, -348.47, 164.65) },   -- Chef: Personal, Kasse, Protokoll (Dienstbuch)
        counter  = { coords = vector3(-1807.03, -348.47, 164.65) },   -- Schalter fuer ALLE Buerger (Bussgeld, Kaution, Lizenzen, Anzeige ...)
        jail     = { coords = vector3(-1807.03, -348.47, 164.65) },   -- Einbuchen: gefesselte Person steht daneben

        -- Hinterzimmer  (ANPASSEN)
        storage  = { coords = vector3(-1814.17, -354.75, 164.65) },   -- Dienstlager der Behoerde (alle Stationen teilen ein Lager)
        armory   = { coords = vector3(-1814.17, -354.75, 164.65) },   -- Waffenkammer (bezahlt die Kasse der Behoerde)
        evidence = { coords = vector3(-1814.17, -354.75, 164.65) },   -- Asservatenkammer + Labor

        -- Eingang / draussen  (ANPASSEN)
        board    = { coords = vector3(-1805.13, -355.05, 164.14) },   -- Steckbriefbrett (Kopfgelder, Auftraege) - fuer alle
        kennel   = { coords = vector3(-1805.13, -355.05, 164.14), heading = 0.0 },   -- Zwinger: Bluthund holen/abgeben
        dropoff  = { coords = vector3(-1805.13, -355.05, 164.14), radius = 8.0 },    -- Abgabe-Zone fuer Gefangene (Kopfgeld/Auftraege)
        garage   = { coords = vector3(-1805.13, -355.05, 164.14),
                     spawn  = vector4(-1800.50, -360.50, 163.90, 150.00) },   -- Dienstwagen: hier erscheint der Wagen
        escort   = { coords = vector3(-1805.13, -355.05, 164.14),
                     spawn  = vector4(-1800.50, -360.50, 163.90, 150.00),      -- Panzerwagen fuer Werttransporte
                     radius = 25.0 },      -- Liefer-/Abholzone der Eskorten
    },

    -- Zellen MIT Tueren (realistisch, kein Teleport hinein):
    --   1. Zellentuer aufschliessen (Prompt an der Tuer, Recht 'jail')
    --   2. Haeftling geht SELBST in die Zelle, Tuer abschliessen
    --   3. an der Tuer "Haeftling einbuchen" -> Strafe, Kaution, Notiz
    --   4. Haft vorbei -> Teleport nach draussen (release)
    -- door/doorCoords = Tuer aus den Spieldaten (rdr3_discoveries) - NICHT aendern.
    -- center = Mitte IN der Zelle (dort muss der Haeftling stehen), radius = Groesse in Metern,
    -- capacity = wie viele Haeftlinge in die Zelle passen.
    -- Welche Tuer welche ist: als Admin /lawcells (zeigt Tueren + Zellen im Spiel).
    -- Eine Tuer ist keine Zelle (z.B. Zellentrakt)? Zeile nach doors = { ... } verschieben.
    -- WICHTIG: Diese Tueren NICHT zusaetzlich in vorp_doorlocks eintragen (sonst kaempfen zwei Scripts).
    -- Zellen nicht loeschen/umsortieren, solange Haeftlinge sitzen (die Nummer in der Liste wird
    -- gespeichert) - zum Abschalten lieber enabled = false in die Zeile schreiben.
    cells = {
        enabled = false,
        label   = 'Zellen Strawberry',
        release = vector4(-1805.13, -355.05, 164.14, 150.00),   -- Entlassung: hier kommt der Haeftling raus (ANPASSEN)
        list = {
            { label = 'Zelle 1', door = 902070893, doorCoords = vector3(-1814.40, -353.15, 160.44),
              center = nil, capacity = 2, radius = 1.6 },   -- center ANPASSEN: in der Zelle /lawcoords
            { label = 'Zelle 2', door = 1207903970, doorCoords = vector3(-1812.01, -351.92, 160.47),
              center = nil, capacity = 2, radius = 1.6 },   -- center ANPASSEN: in der Zelle /lawcoords
        },
    },
    doors = {},   -- weitere abschliessbare Tueren: { label = 'Zellentrakt', door = <hash>, doorCoords = vector3(...) }

    -- Schuesse-Alarm: Schuesse in diesem Gebiet meldet ein NPC-Zeuge an die Leitstelle
    shotsZone = {
        enabled = true,
        coords  = vector3(-1780.00, -420.00, 156.00),   -- Mitte der Stadt
        radius  = 150.0,   -- Meter
    },
}
