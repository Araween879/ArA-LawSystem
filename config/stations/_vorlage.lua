--[[
    ArA-LawSystem - VORLAGE fuer eine neue Station

    Diese Datei ist AUS (enabled = false) und dient nur zum Kopieren.

    Neue Station anlegen (z.B. Van Horn):
      1. Diese Datei kopieren und umbenennen:   config/stations/vanhorn.lua
      2. In der Kopie den Schluessel aendern:   Config.Stations.vanhorn = {
         (nur Kleinbuchstaben, keine Leerzeichen, darf nur EINMAL vorkommen)
      3. enabled = true setzen, label/blip/points eintragen
         (Punkte, die du nicht brauchst: Zeile loeschen oder enabled = false)
      4. Optional: shotsZone (Schuesse-Alarm) und cells (eigene Zellen)
         eintragen und dort enabled = true setzen - beide sind in der Vorlage AUS.
         Steht die Stadt schon in config/main.lua unter ShotsFired.Zones
         (z.B. Van Horn), gilt ab jetzt das Gebiet aus dieser Datei - den
         Eintrag in config/main.lua dann loeschen.
      5. "restart ArA-LawSystem" - in der Server-Konsole steht danach
         "Stationen aktiv: ..." und ggf. Hinweise auf Tippfehler
         (Punkte mit 0.0, 0.0, 0.0 gelten als nicht ausgefuellt und sind aus)

    Koordinaten holen: im Spiel als Admin hinstellen und /lawcoords eingeben,
    die Position steht dann in der F8-Konsole (vector3 und vector4).
      vector3(x, y, z)            = Position
      vector4(x, y, z, richtung)  = Position + Blickrichtung (0 - 360)

    Wichtig: Den Schluessel (hier "vorlage") einer Station, die schon benutzt
    wurde, NICHT mehr aendern - offene Eskort-Auftraege und Haeftlinge in eigenen
    Zellen sind in der Datenbank mit diesem Schluessel gespeichert.
    Dasselbe beim Abschalten (enabled = false) einer benutzten Station oder ihres
    escort-Punkts: offene Eskort-Auftraege und abholbereite Ware dort sind dann
    nicht mehr erreichbar, bis die Station wieder an ist. Vorher abwickeln lassen.
]]

Config.Stations = Config.Stations or {}

Config.Stations.vorlage = {
    --------------------------------------------------------------------------
    -- Grunddaten
    --------------------------------------------------------------------------
    enabled = false,               -- true = Station an | false = komplett aus (Punkte, Blip, Zellen, Schuesse-Alarm)
    label   = 'Neue Station',      -- Name im Spiel (Prompt-Ueberschrift, Formulare, Liste der Eskort-Bueros)

    -- Welche Jobs duerfen die Dienst-Punkte (Dienst, Lager, Waffenkammer ...) der
    -- GANZEN Station benutzen? Die Buerger-Punkte (Schalter, Brett, Abgabe) gehen
    -- trotzdem fuer alle. Einzelne Punkte lassen sich zusaetzlich mit jobs = {...}
    -- am Punkt einschraenken (siehe points unten).
    --   nil                        = alle Behoerden
    --   { 'sheriff' }              = nur Sheriff
    --   { 'sheriff', 'marshal' }   = Sheriff und Marshals
    -- Jobs: sheriff, marshal, police, pinkerton, prisonguard, judge (config/main.lua -> Config.Departments)
    jobs = nil,

    -- Gefaengnis beim Einbuchen am Pult (jail-Punkt) und bei Kopfgeld-Abgabe:
    --   'sisika'   = Sisika-Gefaengnis (Transport per Teleport)
    --   nil        = Standard aus config/justice.lua (Config.Jail.DefaultLocation)
    -- Eigene Zellen mit Tueren werden NICHT hier gewaehlt, sondern an der Zellentuer.
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
        coords  = nil,                             -- nil = am Schalter (counter), sonst am Dienst-Punkt (duty);
                                                   -- gibt es beide nicht: hier vector3(...) eintragen, sonst kein Symbol
    },

    --------------------------------------------------------------------------
    -- Punkte
    -- Jeder Punkt braucht coords = vector3(x, y, z). Dort erscheint der Prompt.
    --   Punkt nicht gewuenscht?        -> enabled = false hineinschreiben oder Zeile loeschen
    --   Mehrere Punkte gleichen Typs?  -> Liste: duty = { { coords = ... }, { coords = ... } },
    -- Mehrere Punkte duerfen dieselbe Stelle haben (dann zeigt der Prompt alle Aktionen).
    --
    -- Nur bestimmte Jobs an EINEM Punkt:   jobs = { 'sheriff', 'marshal' }
    --   Beispiel: armory = { coords = vector3(...), jobs = { 'sheriff' } },
    --   - ohne jobs gilt: Behoerden-Punkte fuer alle Behoerden (bzw. jobs der Station),
    --     Buerger-Punkte (counter, board, dropoff, escort) fuer ALLE Spieler
    --   - mit jobs sehen NUR diese Jobs den Punkt - auch bei Buerger-Punkten!
    --   - jobs gibt keine Rechte: der Rang braucht trotzdem das Recht (z.B. 'armory')
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
                                                                         -- optional: spawn = vector4(x, y, z, richtung) = genaue Stelle, an der der Hund erscheint

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
    -- Zellen MIT Tueren (optional, realistisch - kein Teleport hinein):
    --   1. Zellentuer aufschliessen (Prompt an der Tuer, Recht 'jail')
    --   2. Haeftling geht SELBST hinein, Tuer abschliessen
    --   3. an der Tuer "Haeftling einbuchen" (Strafe, Kaution, Notiz)
    --   4. Haft vorbei -> Teleport nach draussen (release)
    -- Wer mit einem Dietrich das Schloss knackt, oeffnet die Tuer (Alarm an die
    -- Leitstelle). Verlaesst der Haeftling die Zelle, gilt das als Flucht.
    --
    -- door       = Tuer-Hash aus rdr3_discoveries (doorHashes/doorhashes.lua)
    -- doorCoords = Position der Tuer (gleiche Datei)
    -- center     = Mitte IN der Zelle (im Spiel hinstellen, /lawcoords), radius = Groesse,
    -- capacity   = wie viele Haeftlinge in die Zelle passen
    -- Als Admin zeigt /lawcells alle Tueren (gruen = zu, rot = offen) und Zellen (blau).
    -- WICHTIG: diese Tueren NICHT zusaetzlich in vorp_doorlocks eintragen.
    -- Zellen nicht loeschen/umsortieren, solange Haeftlinge sitzen (die Nummer in der Liste wird
    -- gespeichert) - zum Abschalten lieber enabled = false in die Zeile schreiben.
    -- Einstellungen fuer alle Zellen (Dietrich, Reichweite ...): config/justice.lua -> Config.Jail.Cells
    --------------------------------------------------------------------------
    cells = {
        enabled = false,
        label   = 'Zellen Neue Station',                -- Name im Dienstbuch / in der Akte
        release = vector4(0.0, 0.0, 0.0, 0.0),          -- hier kommt der Haeftling nach der Haft raus
        list = {
            -- { label = 'Zelle 1', door = 123456789, doorCoords = vector3(0.0, 0.0, 0.0), center = vector3(0.0, 0.0, 0.0), capacity = 2, radius = 1.6 },
        },
    },
    -- Weitere abschliessbare Tueren ohne Zelle (z.B. Zellentrakt):
    doors = {
        -- { label = 'Zellentrakt', door = 123456789, doorCoords = vector3(0.0, 0.0, 0.0) },
    },
    -- Gefaengnis MIT Teleport (nur fuer Orte wie Sisika, wo man nicht hinlaufen kann):
    -- prison = { label, center, radius, spawn, release, work = { ... } } - Beispiel: sisika.lua

    --------------------------------------------------------------------------
    -- Schuesse-Alarm (optional): Schuesse in diesem Gebiet meldet ein NPC-Zeuge
    -- an die Leitstelle. Zum Einschalten coords/radius eintragen und enabled = true.
    -- Gebiete OHNE Station stehen in config/main.lua (ShotsFired.Zones). Hat eine
    -- Stadt dort schon einen Eintrag (z.B. Van Horn), ersetzt dieses Gebiet ihn.
    --------------------------------------------------------------------------
    shotsZone = {
        enabled = false,
        coords  = vector3(0.0, 0.0, 0.0),   -- Mitte der Stadt
        radius  = 150.0,                    -- Meter
    },
}
