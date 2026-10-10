--[[
    ArA-LawSystem - VORLAGE fuer eine neue Station

    Diese Datei ist AUS (enabled = false) und dient nur zum Kopieren.

    Neue Station anlegen (z.B. Van Horn):
      1. Diese Datei kopieren und umbenennen:   config/stations/vanhorn.lua
      2. In der Kopie den Schluessel aendern:   Config.Stations.vanhorn = {
         (nur Kleinbuchstaben, keine Leerzeichen, darf nur EINMAL vorkommen)
      3. enabled = true setzen, label/blip/points eintragen
      4. "restart ArA-LawSystem" - in der Server-Konsole steht danach
         "Stationen aktiv: ..." und ggf. Hinweise auf Tippfehler

    Koordinaten holen: im Spiel als Admin hinstellen und /lawcoords eingeben,
    die Position steht dann in der F8-Konsole (vector3 und vector4).
      vector3(x, y, z)            = Position
      vector4(x, y, z, richtung)  = Position + Blickrichtung (0 - 360)

    Wichtig: Den Schluessel (hier "vorlage") einer Station, die schon benutzt
    wurde, NICHT mehr aendern - offene Eskort-Auftraege und Haeftlinge in eigenen
    Zellen sind in der Datenbank mit diesem Schluessel gespeichert.
]]

Config.Stations = Config.Stations or {}

Config.Stations.vorlage = {
    --------------------------------------------------------------------------
    -- Grunddaten
    --------------------------------------------------------------------------
    enabled = false,               -- true = Station an | false = komplett aus (Punkte, Blip, Zellen, Schuesse-Alarm)
    label   = 'Neue Station',      -- Name im Spiel (Prompt-Ueberschrift, Formulare, Liste der Eskort-Bueros)

    -- Welche Behoerden duerfen die Dienst-Punkte (Dienst, Lager, Waffenkammer ...)
    -- hier benutzen? Die Buerger-Punkte (Schalter, Brett, Abgabe) gehen immer fuer alle.
    --   nil                        = alle Behoerden
    --   { 'sheriff' }              = nur Sheriff
    --   { 'sheriff', 'marshal' }   = Sheriff und Marshals
    -- Behoerden-Schluessel: sheriff, marshal, police, pinkerton, prisonguard, judge (config/main.lua)
    depts = nil,

    -- Wohin wird hier eingebucht? (Vorauswahl im Haft-Formular, Ziel bei Kopfgeld-Abgabe)
    --   'sisika'   = Sisika-Gefaengnis
    --   'vorlage'  = eigene Zellen dieser Station (siehe cells unten, Schluessel = Stationsname)
    --   nil        = Standard aus config/justice.lua (Config.Jail.DefaultLocation)
    jailTo = 'sisika',

    --------------------------------------------------------------------------
    -- Karten-Symbol (Blip)
    --------------------------------------------------------------------------
    blip = {
        enabled = true,                            -- false = kein Symbol auf der Karte
        name    = 'Neue Station',                  -- Text auf der Karte
        sprite  = 'blip_ambient_sheriff',          -- Symbol
        style   = 'BLIP_STYLE_FRIENDLY_ON_RADAR',
        color   = nil,                             -- z.B. 'BLIP_MODIFIER_MP_COLOR_32' | nil = Standard
        coords  = nil,                             -- nil = am Schalter (counter), sonst vector3(...)
    },

    --------------------------------------------------------------------------
    -- Punkte
    -- Jeder Punkt braucht coords = vector3(x, y, z). Dort erscheint der Prompt.
    --   Punkt nicht gewuenscht?        -> enabled = false hineinschreiben oder Zeile loeschen
    --   Mehrere Punkte gleichen Typs?  -> Liste: duty = { { coords = ... }, { coords = ... } },
    -- Mehrere Punkte duerfen dieselbe Stelle haben (dann zeigt der Prompt alle Aktionen).
    --------------------------------------------------------------------------
    points = {
        -- Fuer Behoerden (Rechte je Rang: config/main.lua -> Config.Departments)
        duty     = { coords = vector3(0.0, 0.0, 0.0) },  -- Dienst an/aus (Stempeluhr)
        boss     = { coords = vector3(0.0, 0.0, 0.0) },  -- Chef-Menue: einstellen, befoerdern, Kasse, Protokoll
        jail     = { coords = vector3(0.0, 0.0, 0.0) },  -- Einbuchen: gefesselte Person muss daneben stehen
        storage  = { coords = vector3(0.0, 0.0, 0.0) },  -- Dienstlager (ein Lager je Behoerde, an allen Stationen gleich)
        armory   = { coords = vector3(0.0, 0.0, 0.0) },  -- Waffenkammer (Ausruestung zahlt die Kasse)
        evidence = { coords = vector3(0.0, 0.0, 0.0) },  -- Asservatenkammer + Labor (Spuren auswerten)
        kennel   = { coords = vector3(0.0, 0.0, 0.0), heading = 0.0 },  -- Zwinger: Bluthund holen/abgeben, heading = Blickrichtung des Hundes

        -- Fuer ALLE Spieler
        counter  = { coords = vector3(0.0, 0.0, 0.0) },  -- Schalter: Bussgeld, Kaution, Lizenzen, Kopfgeld, Waffen, Eskorte, Habseligkeiten, Anzeige
        board    = { coords = vector3(0.0, 0.0, 0.0) },  -- Steckbriefbrett: Kopfgelder + NPC-Auftraege
        dropoff  = { coords = vector3(0.0, 0.0, 0.0), radius = 8.0 },   -- Abgabe-Zone fuer Gefangene (Kopfgeldjaeger), radius = Groesse in Metern

        -- Mit Fahrzeug
        garage   = { coords = vector3(0.0, 0.0, 0.0),                   -- Dienstwagen ausparken/einparken
                     spawn  = vector4(0.0, 0.0, 0.0, 0.0) },             -- hier erscheint der Wagen (mit Richtung!)
        escort   = { coords = vector3(0.0, 0.0, 0.0),                   -- Eskort-Buero (Personenschutz, Transporte)
                     spawn  = vector4(0.0, 0.0, 0.0, 0.0),               -- hier erscheint der Panzerwagen
                     radius = 25.0 },                                    -- Liefer-/Abholzone in Metern
    },

    --------------------------------------------------------------------------
    -- Eigene Zellen (optional). Schluessel des Knast-Orts = Schluessel der Station.
    -- Ganz weglassen oder enabled = false, wenn alle nach Sisika sollen.
    --------------------------------------------------------------------------
    cells = {
        enabled = false,
        label   = 'Zelle Neue Station',             -- Name im Haft-Formular
        center  = vector3(0.0, 0.0, 0.0),            -- Mitte der Zelle(n)
        radius  = 8.0,                               -- wer weiter weg ist, gilt als geflohen
        spawn   = vector4(0.0, 0.0, 0.0, 0.0),       -- hier steht der Haeftling
        release = vector4(0.0, 0.0, 0.0, 0.0),       -- hier kommt er bei Entlassung raus
        work    = {                                  -- Knastarbeit (verkuerzt die Strafe), leer {} = keine
            -- { coords = vector3(0.0, 0.0, 0.0), label = 'Hof fegen', scenario = 'WORLD_HUMAN_BROOM_WORKING' },
        },
    },

    --------------------------------------------------------------------------
    -- Schuesse-Alarm (optional): Schuesse in diesem Gebiet meldet ein NPC-Zeuge
    -- an die Leitstelle. Weglassen oder enabled = false = kein Alarm.
    -- Gebiete ohne Station (z.B. Van Horn) stehen in config/main.lua.
    --------------------------------------------------------------------------
    shotsZone = {
        enabled = true,
        coords  = vector3(0.0, 0.0, 0.0),   -- Mitte der Stadt
        radius  = 150.0,                    -- Meter
    },
}
