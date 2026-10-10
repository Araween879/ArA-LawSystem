--[[
    ArA-LawSystem - Station: Armadillo - Sheriff Office (New Austin)

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

-- HINWEIS: Der Lager-Punkt liegt direkt neben einer Zellentuer (-3620.99, -2600.25) - im Spiel pruefen, ob er nicht IN der Zelle steht.

Config.Stations = Config.Stations or {}

Config.Stations.armadillo = {
    enabled = true,                -- false = Station komplett aus (Punkte, Blip, Zellen, Schuesse-Alarm)
    label   = 'Armadillo',         -- Name im Spiel (Prompts, Formulare, Eskort-Bueros)
    jobs    = nil,                 -- Jobs fuer die GANZE Station: nil = alle Behoerden | z.B. { 'sheriff', 'marshal' }
    jailTo  = 'sisika',            -- Vorauswahl beim Einbuchen: Schluessel eines Knast-Orts ('sisika' oder 'armadillo' fuer eigene Zellen)

    -- Karten-Symbol
    blip = {
        enabled = true,
        name    = 'Armadillo',
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
        duty     = { coords = vector3(-3624.70, -2601.96, -13.34) },   -- Dienst an/aus
        boss     = { coords = vector3(-3624.70, -2601.96, -13.34) },   -- Chef: Personal, Kasse, Protokoll (Dienstbuch)
        counter  = { coords = vector3(-3624.70, -2601.96, -13.34) },   -- Schalter fuer ALLE Buerger (Bussgeld, Kaution, Lizenzen, Anzeige ...)
        jail     = { coords = vector3(-3624.70, -2601.96, -13.34) },   -- Einbuchen: gefesselte Person steht daneben

        -- Hinterzimmer  (ANPASSEN)
        storage  = { coords = vector3(-3622.69, -2600.00, -13.34) },   -- Dienstlager der Behoerde (alle Stationen teilen ein Lager)
        armory   = { coords = vector3(-3622.69, -2600.00, -13.34) },   -- Waffenkammer (bezahlt die Kasse der Behoerde)
        evidence = { coords = vector3(-3622.69, -2600.00, -13.34) },   -- Asservatenkammer + Labor

        -- Eingang / draussen  (ANPASSEN)
        board    = { coords = vector3(-3610.40, -2599.16, -13.88) },   -- Steckbriefbrett (Kopfgelder, Auftraege) - fuer alle
        kennel   = { coords = vector3(-3610.40, -2599.16, -13.88), heading = 0.0 },   -- Zwinger: Bluthund holen/abgeben
        dropoff  = { coords = vector3(-3610.40, -2599.16, -13.88), radius = 8.0 },    -- Abgabe-Zone fuer Gefangene (Kopfgeld/Auftraege)
        garage   = { coords = vector3(-3610.40, -2599.16, -13.88),
                     spawn  = vector4(-3604.00, -2596.00, -13.90, 270.00) },   -- Dienstwagen: hier erscheint der Wagen
        escort   = { coords = vector3(-3610.40, -2599.16, -13.88),
                     spawn  = vector4(-3604.00, -2596.00, -13.90, 270.00),      -- Panzerwagen fuer Werttransporte
                     radius = 25.0 },      -- Liefer-/Abholzone der Eskorten
    },

    -- Eigene Zellen in dieser Station (Knast-Ort mit dem Schluessel 'armadillo').
    -- Standard ist AUS: alle kommen nach Sisika. Zum Einschalten enabled = true
    -- setzen, Werte im Spiel pruefen und oben jailTo = 'armadillo' eintragen.
    -- Zellentueren laut Spieldaten (rdr3_discoveries, Tuer-Angel - Ped steht ~1 m hoeher):
    --   vector3(-3620.99, -2600.25, -14.35)
    --   vector3(-3619.15, -2604.21, -14.35)
    cells = {
        enabled = false,
        label   = 'Zelle Armadillo',
        center  = vector3(-3620.99, -2600.25, -13.35),   -- Mitte der Zelle (ANPASSEN)
        radius  = 8.0,                -- weiter weg = Flucht
        spawn   = vector4(-3620.99, -2600.25, -13.35, 0.00),   -- hier steht der Haeftling (ANPASSEN)
        release = vector4(-3610.40, -2599.16, -13.88, 270.00),   -- hier kommt er bei Entlassung raus
        work    = {},                 -- Knastarbeit-Punkte (siehe sisika.lua), leer = keine
    },

    -- Schuesse-Alarm: Schuesse in diesem Gebiet meldet ein NPC-Zeuge an die Leitstelle
    shotsZone = {
        enabled = true,
        coords  = vector3(-3660.00, -2600.00, -13.00),   -- Mitte der Stadt
        radius  = 180.0,   -- Meter
    },
}
