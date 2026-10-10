--[[
    ArA-LawSystem - Station: Tumbleweed - Sheriff Office (New Austin)

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

Config.Stations.tumbleweed = {
    enabled = true,                -- false = Station komplett aus (Punkte, Blip, Zellen, Schuesse-Alarm)
    label   = 'Tumbleweed',        -- Name im Spiel (Prompts, Formulare, Eskort-Bueros)
    jobs    = nil,                 -- Jobs fuer die GANZE Station: nil = alle Behoerden | z.B. { 'sheriff', 'marshal' }
    jailTo  = 'sisika',            -- Gefaengnis beim Einbuchen am Pult (Transport, Teleport). Zellen hier: an der Zellentuer

    -- Karten-Symbol
    blip = {
        enabled = true,
        name    = 'Tumbleweed',
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
        duty     = { coords = vector3(-5529.55, -2929.25, -1.36) },   -- Dienst an/aus
        boss     = { coords = vector3(-5529.55, -2929.25, -1.36) },   -- Chef: Personal, Kasse, Protokoll (Dienstbuch)
        counter  = { coords = vector3(-5529.55, -2929.25, -1.36) },   -- Schalter fuer ALLE Buerger (Bussgeld, Kaution, Lizenzen, Anzeige ...)
        jail     = { coords = vector3(-5529.55, -2929.25, -1.36) },   -- Einbuchen: gefesselte Person steht daneben

        -- Hinterzimmer  (ANPASSEN)
        storage  = { coords = vector3(-5526.59, -2928.51, -1.36) },   -- Dienstlager der Behoerde (alle Stationen teilen ein Lager)
        armory   = { coords = vector3(-5526.59, -2928.51, -1.36) },   -- Waffenkammer (bezahlt die Kasse der Behoerde)
        evidence = { coords = vector3(-5526.59, -2928.51, -1.36) },   -- Asservatenkammer + Labor

        -- Eingang / draussen  (ANPASSEN)
        board    = { coords = vector3(-5531.39, -2935.31, -1.91) },   -- Steckbriefbrett (Kopfgelder, Auftraege) - fuer alle
        kennel   = { coords = vector3(-5531.39, -2935.31, -1.91), heading = 0.0 },   -- Zwinger: Bluthund holen/abgeben
        dropoff  = { coords = vector3(-5531.39, -2935.31, -1.91), radius = 8.0 },    -- Abgabe-Zone fuer Gefangene (Kopfgeld/Auftraege)
        garage   = { coords = vector3(-5531.39, -2935.31, -1.91),
                     spawn  = vector4(-5536.00, -2941.00, -2.00, 200.00) },   -- Dienstwagen: hier erscheint der Wagen
        escort   = { coords = vector3(-5531.39, -2935.31, -1.91),
                     spawn  = vector4(-5536.00, -2941.00, -2.00, 200.00),      -- Panzerwagen fuer Werttransporte
                     radius = 25.0 },      -- Liefer-/Abholzone der Eskorten
    },

    -- Zellen MIT Tueren (realistisch, kein Teleport hinein):
    --   1. Zellentuer aufschliessen (Prompt an der Tuer, Recht 'jail')
    --   2. Haeftling geht SELBST in die Zelle, Tuer abschliessen
    --   3. an der Tuer "Haeftling einbuchen" -> Strafe, Kaution, Notiz
    --   4. Haft vorbei -> Teleport nach draussen (release)
    -- door/doorCoords = Tuer aus den Spieldaten (rdr3_discoveries) - NICHT aendern.
    -- center = Mitte IN der Zelle (dort muss der Haeftling stehen), radius = Groesse in Metern.
    -- Welche Tuer welche ist: als Admin /lawcells (zeigt Tueren + Zellen im Spiel).
    -- Eine Tuer ist keine Zelle (z.B. Zellentrakt)? Zeile nach doors = { ... } verschieben.
    -- WICHTIG: Diese Tueren NICHT zusaetzlich in vorp_doorlocks eintragen (sonst kaempfen zwei Scripts).
    cells = {
        enabled = false,
        label   = 'Zellen Tumbleweed',
        release = vector4(-5531.39, -2935.31, -1.91, 200.00),   -- Entlassung: hier kommt der Haeftling raus (ANPASSEN)
        list = {
            { label = 'Zelle 1', door = 831345624, doorCoords = vector3(-5529.91, -2925.07, -2.36),
              center = nil, radius = 1.6 },   -- center ANPASSEN: in der Zelle /lawcoords
            { label = 'Zelle 2', door = 2677989449, doorCoords = vector3(-5531.46, -2921.75, -2.36),
              center = nil, radius = 1.6 },   -- center ANPASSEN: in der Zelle /lawcoords
            { label = 'Zelle 3', door = 2984805596, doorCoords = vector3(-5532.91, -2918.65, -2.36),
              center = nil, radius = 1.6 },   -- center ANPASSEN: in der Zelle /lawcoords
        },
    },
    doors = {},   -- weitere abschliessbare Tueren: { label = 'Zellentrakt', door = <hash>, doorCoords = vector3(...) }

    -- Schuesse-Alarm: Schuesse in diesem Gebiet meldet ein NPC-Zeuge an die Leitstelle
    shotsZone = {
        enabled = true,
        coords  = vector3(-5510.00, -2940.00, -2.00),   -- Mitte der Stadt
        radius  = 150.0,   -- Meter
    },
}
