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
    jailTo  = 'sisika',            -- Vorauswahl beim Einbuchen: Schluessel eines Knast-Orts ('sisika' oder 'valentine' fuer eigene Zellen)

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
        boss     = { coords = vector3(-277.19, 804.38, 119.38) },   -- Chef: Personal, Kasse, Protokoll (Dienstbuch)
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

    -- Eigene Zellen in dieser Station (Knast-Ort mit dem Schluessel 'valentine').
    -- Standard ist AUS: alle kommen nach Sisika. Zum Einschalten enabled = true
    -- setzen, Werte im Spiel pruefen und oben jailTo = 'valentine' eintragen.
    -- Zellentueren laut Spieldaten (rdr3_discoveries, Tuer-Angel - Ped steht ~1 m hoeher):
    --   vector3(-272.05, 808.26, 118.37)
    --   vector3(-273.46, 809.97, 118.37)
    --   vector3(-275.02, 809.27, 118.37)
    --   vector3(-270.77, 810.03, 118.40)
    cells = {
        enabled = false,
        label   = 'Zelle Valentine',
        center  = vector3(-273.20, 810.90, 119.38),   -- Mitte der Zelle (ANPASSEN)
        radius  = 8.0,                -- weiter weg = Flucht
        spawn   = vector4(-273.20, 810.90, 119.38, 90.00),   -- hier steht der Haeftling (ANPASSEN)
        release = vector4(-278.17, 814.88, 119.28, 180.00),   -- hier kommt er bei Entlassung raus
        work    = {},                 -- Knastarbeit-Punkte (siehe sisika.lua), leer = keine
    },

    -- Schuesse-Alarm: Schuesse in diesem Gebiet meldet ein NPC-Zeuge an die Leitstelle
    shotsZone = {
        enabled = true,
        coords  = vector3(-281.00, 790.00, 119.00),   -- Mitte der Stadt
        radius  = 180.0,   -- Meter
    },
}
