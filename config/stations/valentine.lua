--[[
    ArA-LawSystem - Station: Valentine - Sheriff Office (New Hanover)

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

Config.Stations.valentine = {
    enabled = true,                -- false = Station komplett aus (Punkte, Blip, Zellen, Schuesse-Alarm)
    label   = 'Valentine',         -- Name im Spiel (Prompts, Formulare, Eskort-Bueros)
    depts   = nil,                 -- nil = alle Behoerden duerfen hier arbeiten | z.B. { 'sheriff', 'marshal' }
    jailTo  = 'sisika',            -- Vorauswahl beim Einbuchen: Schluessel eines Knast-Orts ('sisika' oder 'valentine' fuer eigene Zellen)

    -- Karten-Symbol
    blip = {
        enabled = true,
        name    = 'Valentine',
        sprite  = 'blip_ambient_sheriff',
        style   = 'BLIP_STYLE_FRIENDLY_ON_RADAR',
        color   = nil,             -- z.B. 'BLIP_MODIFIER_MP_COLOR_32' | nil = Standardfarbe
        coords  = nil,             -- nil = am Schalter (counter), sonst am Dienst-Punkt (duty) | sonst vector3(...)
    },

    -- Alle Punkte der Station. Jeder Punkt: coords = vector3(x, y, z)
    -- Mehrere Punkte vom selben Typ:  duty = { { coords = ... }, { coords = ... } },
    points = {
        -- Pult / Tresen  (ANPASSEN)
        duty     = { coords = vector3(-277.73, 804.84, 119.38) },   -- Dienst an/aus
        boss     = { coords = vector3(-277.73, 804.84, 119.38) },   -- Chef: Personal, Kasse, Protokoll (Dienstbuch)
        counter  = { coords = vector3(-277.73, 804.84, 119.38) },   -- Schalter fuer ALLE Buerger (Bussgeld, Kaution, Lizenzen, Anzeige ...)
        jail     = { coords = vector3(-277.73, 804.84, 119.38) },   -- Einbuchen: gefesselte Person steht daneben

        -- Hinterzimmer  (ANPASSEN)
        storage  = { coords = vector3(-276.97, 810.83, 119.38) },   -- Dienstlager der Behoerde (alle Stationen teilen ein Lager)
        armory   = { coords = vector3(-276.97, 810.83, 119.38) },   -- Waffenkammer (bezahlt die Kasse der Behoerde)
        evidence = { coords = vector3(-276.97, 810.83, 119.38) },   -- Asservatenkammer + Labor

        -- Eingang / draussen  (ANPASSEN)
        board    = { coords = vector3(-278.17, 814.88, 119.28) },   -- Steckbriefbrett (Kopfgelder, Auftraege) - fuer alle
        kennel   = { coords = vector3(-278.17, 814.88, 119.28), heading = 0.0 },   -- Zwinger: Bluthund holen/abgeben
        dropoff  = { coords = vector3(-278.17, 814.88, 119.28), radius = 8.0 },    -- Abgabe-Zone fuer Gefangene (Kopfgeld/Auftraege)
        garage   = { coords = vector3(-278.17, 814.88, 119.28),
                     spawn  = vector4(-283.50, 823.50, 119.30, 190.00) },   -- Dienstwagen: hier erscheint der Wagen
        escort   = { coords = vector3(-278.17, 814.88, 119.28),
                     spawn  = vector4(-283.50, 823.50, 119.30, 190.00),      -- Panzerwagen fuer Werttransporte
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
