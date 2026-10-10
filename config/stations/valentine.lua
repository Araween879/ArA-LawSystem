--[[
    ArA-LawSystem - Station: Valentine - Sheriff Office (New Hanover)

    So stellst du diese Station ein:
      1. Im Spiel als Admin an die gewuenschte Stelle stellen
      2. /lawcoords eingeben -> Position steht in der F8-Konsole
      3. Zahlen hier einfuegen, speichern, "restart ArA-LawSystem"

    Punkte eingetragen am 10.10.2026 (im Spiel gemessen). Offen: jail (Startwert).
    Alles mit "ANPASSEN" sind Startwerte und sollten einmal im Spiel geprueft werden.
    Einen Punkt nicht haben wollen?  ->  enabled = false  in den Punkt schreiben
    Die ganze Station nicht haben?   ->  enabled = false  ganz oben
    Alle Felder sind in config/stations/_vorlage.lua genau erklaert.
]]

Config.Stations = Config.Stations or {}

Config.Stations.valentine = {
    enabled = true,                -- false = Station komplett aus (Punkte, Blip, Zellen, Schuesse-Alarm)
    label   = 'Valentine',         -- Name im Spiel (Prompts, Formulare, Eskort-Bueros)
    jobs    = nil,                 -- Jobs fuer die GANZE Station: nil = alle Behoerden | z.B. { 'sheriff', 'marshal' }
    jailTo  = 'sisika',            -- Gefaengnis beim Einbuchen am Pult (Transport, Teleport). Zellen hier: an der Zellentuer

    -- Karten-Symbol
    blip = {
        enabled = true,
        name    = 'Valentine',
        sprite  = 'blip_ambient_sheriff',
        style   = 'BLIP_STYLE_FRIENDLY_ON_RADAR',
        color   = nil,             -- z.B. 'BLIP_MODIFIER_MP_COLOR_32' | nil = Standardfarbe
        coords  = vector3(-277.47, 806.09, 119.38),   -- nil = am Schalter (counter), sonst am Dienst-Punkt (duty)
    },

    -- Alle Punkte der Station. Jeder Punkt: coords = vector3(x, y, z)
    -- Nur bestimmte Jobs an einem Punkt:  armory = { coords = ..., jobs = { 'sheriff' } },
    -- Mehrere Punkte vom selben Typ:  duty = { { coords = ... }, { coords = ... } },
    -- Punkte duerfen auf Tisch-/Schrankhoehe liegen (bis 2,5 m, Config.Points in config/main.lua).
    points = {
        -- Pult / Tresen
        duty     = { coords = vector3(-278.25, 802.64, 119.38) },   -- Dienst an/aus
        boss     = { coords = vector3(-276.95, 807.33, 118.17) },   -- Chef: Behoerde verwalten (Personal, Kasse, Protokoll)
        jail     = { coords = vector3(-277.73, 804.84, 119.38) },   -- Einbuchen: gefesselte Person steht daneben  (ANPASSEN: noch Startwert)

        -- Hinterzimmer
        storage  = { coords = vector3(-277.57, 810.97, 120.11) },   -- Dienstlager der Behoerde (alle Stationen teilen ein Lager)
        armory   = { coords = vector3(-279.01, 805.08, 120.56) },   -- Waffenkammer (bezahlt die Kasse der Behoerde)
        evidence = { coords = vector3(-279.84, 809.31, 120.01) },   -- Asservatenkammer + Labor

        -- Fuer Buerger
        counter  = { coords = vector3(-274.28, 802.21, 120.38) },   -- Schalter fuer ALLE Buerger (Bussgeld, Kaution, Lizenzen, Anzeige ...)
        board    = { coords = vector3(-269.56, 807.15, 120.74) },   -- Steckbriefbrett (Kopfgelder, Auftraege) - fuer alle
        dropoff  = { coords = vector3(-270.10, 809.65, 119.25), radius = 8.0 },   -- Abgabe-Zone fuer Gefangene (Kopfgeld/Auftraege)

        -- Draussen
        kennel   = { coords = vector3(-281.75, 811.92, 119.95),                     -- Zwinger: Bluthund holen/abgeben (Prompt)
                     spawn  = vector4(-281.52, 810.94, 119.36, 8.06) },             -- hier erscheint der Hund (mit Blickrichtung)
        garage   = { coords = vector3(-272.59, 814.42, 121.26),
                     spawn  = vector4(-268.55, 821.92, 119.02, 201.61) },   -- Dienstwagen: hier erscheint der Wagen
        escort   = { coords = vector3(-272.59, 814.42, 121.26),
                     spawn  = vector4(-268.55, 821.92, 119.02, 201.61),     -- Panzerwagen fuer Werttransporte
                     radius = 25.0 },      -- Liefer-/Abholzone der Eskorten
    },

    -- Zellen MIT Tueren (realistisch, kein Teleport hinein):
    --   1. Zellentuer aufschliessen (Prompt an der Tuer, Recht 'jail')
    --   2. Haeftling geht SELBST in die Zelle, Tuer abschliessen
    --   3. an der Tuer "Haeftling einbuchen" -> Strafe, Kaution, Notiz
    --   4. Haft vorbei -> Teleport nach draussen (release)
    -- Kopfgeldjaeger gibt jemanden an der Abgabestelle ab -> Gefangener kommt per
    -- Teleport in eine freie Zelle (Tuer wird abgeschlossen). Gesetz sperrt selbst ein.
    -- door/doorCoords = Tuer aus den Spieldaten (rdr3_discoveries) - NICHT aendern.
    -- center = Mitte IN der Zelle (dort muss der Haeftling stehen), radius = Groesse in Metern,
    -- capacity = wie viele Haeftlinge in die Zelle passen.
    -- Welche Tuer welche ist: als Admin /lawcells (zeigt Tueren + Zellen im Spiel).
    -- Eine Tuer ist keine Zelle (z.B. Zellentrakt)? Zeile nach doors = { ... } verschieben.
    -- WICHTIG: Diese Tueren NICHT zusaetzlich in vorp_doorlocks eintragen (sonst kaempfen zwei Scripts).
    cells = {
        enabled = true,
        label   = 'Zellen Valentine',
        release = vector4(-269.78, 809.68, 119.24, 276.62),   -- Entlassung: hier kommt der Haeftling raus
        list = {
            -- center = Mitte der Zelle (/lawcoords), capacity = Plaetze, radius = Groesse in Metern
            { label = 'Zelle 1', door = 295355979, doorCoords = vector3(-273.46, 809.97, 118.37),
              center = vector3(-273.13, 811.37, 119.37), heading = 12.58, capacity = 3, radius = 2.0 },
            { label = 'Zelle 2', door = 193903155, doorCoords = vector3(-272.05, 808.26, 118.37),
              center = vector3(-272.19, 807.28, 119.37), heading = 260.25, capacity = 3, radius = 2.0 },
        },
    },
    -- weitere abschliessbare Gittertueren (Start: offen). Gesetz im Dienst schliesst sie per Prompt ab.
    doors = {
        { label = 'Gittertuer Zellengang', door = 1508776842, doorCoords = vector3(-270.77, 810.03, 118.40), locked = false },
        { label = 'Gittertuer hinten',     door = 535323366,  doorCoords = vector3(-275.02, 809.27, 118.37), locked = false },
    },

    -- Schuesse-Alarm: Schuesse in diesem Gebiet meldet ein NPC-Zeuge an die Leitstelle
    shotsZone = {
        enabled = true,
        coords  = vector3(-281.00, 790.00, 119.00),   -- Mitte der Stadt
        radius  = 180.0,   -- Meter
    },
}
