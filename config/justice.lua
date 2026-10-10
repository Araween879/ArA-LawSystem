--[[
    ArA-LawSystem - Config Justiz (Agent A)

    Festnahme, Bussgeld, Knast, Akten, Haftbefehle, Kopfgeld, NPC-Einsaetze.
    Alle Betraege und Haftzeiten werden SERVERSEITIG aus diesen Werten
    berechnet - der Client schickt nur Absichten (z.B. Delikt-IDs).

    Koordinaten mit "ANPASSEN" sind Startwerte und muessen im Spiel geprueft
    werden (/lawcoords gibt die eigene Position aus).
]]

Config = Config or {}

--------------------------------------------------------------------------
-- Festnahme
--------------------------------------------------------------------------
Config.Arrest = {
    CuffDistance         = 2.0,    -- Handschellen: naechster Spieler bis X m
    EscortDistance       = 2.5,    -- Abfuehren starten bis X m
    SearchDistance       = 2.5,    -- Durchsuchen bis X m
    IdCheckDistance      = 3.0,    -- Akte im Feld bis X m
    VehicleDistance      = 6.0,    -- Wagen muss <= X m von Officer UND Ziel sein
    SearchRequiresCuffs  = true,   -- Durchsuchen nur gefesselt (oder bewusstlos)
    AllowHuntersToCuff   = true,   -- Kopfgeldjaeger mit Lizenz duerfen Gesuchte fesseln
    CuffDelete           = true,   -- Handschellen werden beim Fesseln verbraucht, beim Loesen zurueckgegeben
    AutoUncuffMinutes    = 15,     -- niemand kuemmert sich X Minuten um den Gefesselten -> automatisch frei
    AttendRadius         = 30.0,   -- "kuemmern" = Fesselnder oder Gesetz im Dienst innerhalb X m
    CombatLogJailMinutes = 10,     -- gefesselt ausgeloggt -> beim naechsten Login X Minuten Haft
    HunterMaxMinutes     = 20,     -- Fesselung durch Kopfgeldjaeger endet spaetestens nach X Minuten
    EscortBreakDistance  = 10.0,   -- Abgefuehrter weiter als X m vom Officer -> Abfuehren endet + Alarm
    EscortCheckSeconds   = 5,
    RecordOnCuff         = true,   -- Festnahme als Akteneintrag
    Lockpick = {
        Seconds     = 8,    -- Dauer des Knackens
        Chance      = 35,   -- % Erfolg
        BreakChance = 50,   -- % Dietrich bricht bei Fehlschlag
        Cooldown    = 30,   -- Sekunden zwischen zwei Versuchen je Spieler
        Distance    = 2.0,
    },
    -- Abfuehren: Ziel haengt am Officer. Knochen 0 = Wurzel des Officer-Peds,
    -- Versatz x = rechts, y = vorne, z = oben (Meter).
    -- vorp_police nutzt (4103, 11816, 0.48 ...) - dort sind die Parameter
    -- aus einem GTA-Skript verrutscht, deshalb hier sauber getrennt.
    EscortBone   = 0,
    EscortOffset = vector3(0.30, 0.50, 0.0),
    -- Sitze im Wagen, der Reihe nach probiert (-1 = Kutscher nie benutzen). ANPASSEN je Wagenmodell
    VehicleSeats = { 1, 2, 3, 4, 5, 6, 0 },
    Anim = { dict = 'mech_inventory@crafting@fallbacks', name = 'full_craft_and_stow', ms = 2500 },
    -- Gesperrte Tasten im gefesselten Zustand (RedM Control-Hashes, Quelle: femga/rdr3_discoveries)
    DisabledControls = {
        0x07CE1E61, -- INPUT_ATTACK
        0xF84FA74F, -- INPUT_AIM
        0xB2F377E8, -- INPUT_MELEE_ATTACK
        0x2277FAE9, -- INPUT_MELEE_GRAPPLE
        0xB5EEEFB7, -- INPUT_MELEE_BLOCK
        0x018C47CF, -- INPUT_MELEE_GRAPPLE_CHOKE
        0xD9D0E1C0, -- INPUT_JUMP
        0x06052D11, -- INPUT_DIVE
        0xDE794E3E, -- INPUT_COVER
        0xE30CD707, -- INPUT_RELOAD
        0xAC4BD4F1, -- INPUT_OPEN_WHEEL_MENU (Waffenrad)
        0xD0842EDF, -- INPUT_SELECT_NEXT_WEAPON
        0xFD0F0C2C, -- INPUT_NEXT_WEAPON
        0xCC1075A7, -- INPUT_PREV_WEAPON
        0x938D4071, -- INPUT_TWIRL_PISTOL
        0xCEFD9220, -- INPUT_ENTER (Aufsteigen / Wagen betreten)
        0xE4D2CE1D, -- INPUT_HORSE_JUMP
        0x24978A28, -- INPUT_WHISTLE (Pferd rufen)
        0xE7EB9185, -- INPUT_WHISTLE_HORSEBACK
        0xF3830D8E, -- INPUT_OPEN_JOURNAL (Wagen rufen)
        0x4CC0E2FE, -- INPUT_OPEN_SATCHEL_MENU
        0xC1989F95, -- INPUT_QUICK_USE_ITEM (vorp_inventory: Taste I)
        0xE2B557A3, -- INPUT_OPEN_EMOTE_WHEEL
        0x41AC83D1, -- INPUT_LOOT
        0xD9C50532, -- INPUT_HOGTIE
        0xEB2AC491, -- INPUT_PICKUP_CARRIABLE
        0xF8982F00, -- INPUT_INTERACT_LOCKON
        0x8FFC75D6, -- INPUT_SPRINT
    },
}

--------------------------------------------------------------------------
-- Strafkatalog
-- id: fester Schluessel (nie aendern, steht in der DB), fine: Dollar,
-- jail: Haftminuten. Kategorien nur zur Gruppierung in der NUI.
--------------------------------------------------------------------------
Config.PenalCode = {
    -- Eigentum
    { id = 'theft',              label = 'Diebstahl',                           category = 'Eigentum',              fine = 25,  jail = 5 },
    { id = 'horse_theft',        label = 'Pferdediebstahl',                     category = 'Eigentum',              fine = 75,  jail = 15 },
    { id = 'cattle_rustling',    label = 'Viehdiebstahl',                       category = 'Eigentum',              fine = 60,  jail = 12 },
    { id = 'burglary',           label = 'Einbruch',                            category = 'Eigentum',              fine = 80,  jail = 15 },
    { id = 'store_robbery',      label = 'Ladenueberfall',                      category = 'Eigentum',              fine = 150, jail = 25 },
    { id = 'grave_robbing',      label = 'Grabschaendung',                      category = 'Eigentum',              fine = 60,  jail = 10 },
    { id = 'trespassing',        label = 'Hausfriedensbruch',                   category = 'Eigentum',              fine = 20,  jail = 0 },
    { id = 'vandalism',          label = 'Sachbeschaedigung',                   category = 'Eigentum',              fine = 30,  jail = 0 },
    { id = 'poaching',           label = 'Wilderei',                            category = 'Eigentum',              fine = 30,  jail = 5 },
    -- Gewalt
    { id = 'assault',            label = 'Koerperverletzung',                   category = 'Gewalt',                fine = 50,  jail = 10 },
    { id = 'assault_officer',    label = 'Angriff auf einen Gesetzeshueter',    category = 'Gewalt',                fine = 120, jail = 25 },
    { id = 'manslaughter',       label = 'Totschlag',                           category = 'Gewalt',                fine = 200, jail = 40 },
    { id = 'kidnapping',         label = 'Entfuehrung',                         category = 'Gewalt',                fine = 250, jail = 40 },
    -- Schwere Verbrechen
    { id = 'murder',             label = 'Mord',                                category = 'Schwere Verbrechen',    fine = 400, jail = 60 },
    { id = 'bank_robbery',       label = 'Bankraub',                            category = 'Schwere Verbrechen',    fine = 500, jail = 60 },
    { id = 'stagecoach_robbery', label = 'Postkutschenueberfall',               category = 'Schwere Verbrechen',    fine = 250, jail = 40 },
    { id = 'train_robbery',      label = 'Zugueberfall',                        category = 'Schwere Verbrechen',    fine = 400, jail = 50 },
    { id = 'arson',              label = 'Brandstiftung',                       category = 'Schwere Verbrechen',    fine = 150, jail = 30 },
    -- Waffen
    { id = 'illegal_weapon',     label = 'Unerlaubter Waffenbesitz',            category = 'Waffen',                fine = 40,  jail = 5 },
    { id = 'filed_serial',       label = 'Abgefeilte Seriennummer',             category = 'Waffen',                fine = 80,  jail = 10 },
    { id = 'weapon_in_town',     label = 'Waffengebrauch in der Stadt',         category = 'Waffen',                fine = 50,  jail = 5 },
    { id = 'brandishing',        label = 'Bedrohung mit einer Waffe',           category = 'Waffen',                fine = 40,  jail = 5 },
    -- Justiz
    { id = 'resisting',          label = 'Widerstand gegen die Staatsgewalt',   category = 'Justiz',                fine = 60,  jail = 10 },
    { id = 'fleeing',            label = 'Flucht vor dem Gesetz',               category = 'Justiz',                fine = 40,  jail = 5 },
    { id = 'escape',             label = 'Flucht aus der Haft',                 category = 'Justiz',                fine = 100, jail = 30 },
    { id = 'obstruction',        label = 'Behinderung der Justiz',              category = 'Justiz',                fine = 50,  jail = 10 },
    { id = 'bribery',            label = 'Bestechung',                          category = 'Justiz',                fine = 80,  jail = 10 },
    { id = 'false_statement',    label = 'Falschaussage',                       category = 'Justiz',                fine = 40,  jail = 5 },
    { id = 'unpaid_fine',        label = 'Nicht bezahltes Bussgeld',            category = 'Justiz',                fine = 0,   jail = 10 },
    -- Oeffentliche Ordnung
    { id = 'insulting_officer',  label = 'Beamtenbeleidigung',                  category = 'Oeffentliche Ordnung',  fine = 20,  jail = 0 },
    { id = 'drunkenness',        label = 'Oeffentliche Trunkenheit',            category = 'Oeffentliche Ordnung',  fine = 10,  jail = 0 },
    { id = 'disturbance',        label = 'Ruhestoerung',                        category = 'Oeffentliche Ordnung',  fine = 15,  jail = 0 },
    -- Schmuggel
    { id = 'smuggling',          label = 'Schmuggel',                           category = 'Schmuggel',             fine = 120, jail = 20 },
    { id = 'moonshine',          label = 'Illegale Schnapsbrennerei',           category = 'Schmuggel',             fine = 100, jail = 15 },
}

--------------------------------------------------------------------------
-- Bussgeld
--------------------------------------------------------------------------
Config.Fines = {
    DueHours             = 72,     -- Zahlungsfrist
    MaxAmount            = 5000,   -- Deckel je Bescheid
    MaxCount             = 5,      -- hoechstens X offene/ueberfaellige Bescheide je Person
    MaxCodes             = 10,     -- verschiedene Delikte je Bescheid
    MaxCodeCount         = 5,      -- Anzahl je Delikt
    OfficerCommission    = 0.10,   -- Anteil fuer den ausstellenden Officer (Rest -> Kasse)
    AutoWarrantOnOverdue = true,   -- ueberfaellig -> automatischer Haftbefehl
    OverdueJailMinutes   = 10,
    FieldDistance        = 5.0,    -- Ausstellen/Kassieren vor Ort bis X m
    CheckMinutes         = 10,     -- Faelligkeitspruefung alle X Minuten
    FallbackDepartment   = 'sheriff',
}

--------------------------------------------------------------------------
-- Knast
--------------------------------------------------------------------------
Config.Jail = {
    DefaultLocation    = 'sisika',
    MaxMinutes         = 240,
    MaxExtraMinutes    = 30,     -- Zusatzminuten im Formular
    SentenceDistance   = 5.0,    -- Ziel muss <= X m vom Officer am Einbuchungspunkt stehen
    CountOffline       = false,  -- true: Haftzeit laeuft auch offline weiter
    TickSeconds        = 60,
    EscapeCheckSeconds = 10,
    EscapeGraceSeconds = 30,     -- nach Teleport X Sekunden keine Fluchtpruefung (Laden der Welt)
    EscapeExtraMinutes = 30,
    EscapeBounty       = 150,    -- 0 = kein Kopfgeld bei Flucht
    DiedRecentlySeconds = 90,    -- kuerzlich tot -> zurueck statt Fluchtalarm
    MaxDeathReturns    = 3,      -- hoechstens X Mal hintereinander "tot -> zurueck", danach gilt es als Flucht
    -- Knast-Orte: Sisika und die eigenen Zellen der Staedte stehen jetzt in
    -- config/stations/<stadt>.lua (Feld "cells"), die Vorauswahl je Station im
    -- Feld "jailTo". Hier nur zusaetzliche Knast-Orte OHNE eigene Station eintragen:
    --   meinknast = { label = '...', enabled = true, center = vector3(...), radius = 50.0,
    --                 spawn = vector4(...), release = vector4(...), work = {} },
    Locations = {},
    StationLocation = {},  -- wird aus config/stations/*.lua (jailTo) gefuellt

    -- Zellen in den Stationen (config/stations/<stadt>.lua -> cells):
    -- Zellentuer aufschliessen -> Haeftling geht SELBST hinein -> abschliessen ->
    -- an der Tuer "Haeftling einbuchen". KEIN Teleport hinein. Nach Ablauf der
    -- Haft wird er nach draussen teleportiert (cells.release der Station).
    Cells = {
        Radius        = 1.6,    -- Groesse einer Zelle in Metern (wenn bei der Zelle kein radius steht)
        DoorReach     = 2.0,    -- so nah muss man an der Zellentuer stehen (Prompt)
        LockedOnStart = true,   -- nach Server-Neustart sind alle Zellentueren abgeschlossen
        -- Ausbruch: Schloss einer Zellentuer mit einem Dietrich knacken (alle ausser Gesetz im Dienst)
        Lockpick = {
            Enabled     = true,
            Item        = 'lockpick',  -- gleiches Item wie bei vorp_doorlocks
            Seconds     = 20,          -- Dauer des Knackens
            Chance      = 20,          -- % Erfolg
            BreakChance = 50,          -- % Dietrich bricht bei Fehlschlag
            Cooldown    = 60,          -- Sekunden zwischen zwei Versuchen je Spieler
            Alarm       = true,        -- Leitstelle bekommt einen Alarm, wenn eine Zellentuer aufgebrochen wird
        },
    },
    Work = {
        Seconds          = 10,   -- Dauer einer Arbeit
        ReduceSeconds    = 30,   -- Haftzeit-Verkuerzung je Arbeit
        Cooldown         = 45,   -- Sekunden zwischen zwei Arbeiten
        MaxReducePercent = 50,   -- hoechstens X % der Strafe abarbeiten
        Distance         = 2.5,
    },
    Confiscate = {
        Weapons     = true,
        KeepWeapons = { 'WEAPON_LASSO', 'WEAPON_MELEE_LANTERN', 'WEAPON_KIT_CAMERA' },  -- bleiben beim Haeftling
        Items       = { 'lockpick', 'dynamite', 'law_gunfile', 'law_strongbox_tool', 'handcuffs', 'handcuffkey', 'moonshine', 'molotov' },
        Limit       = 200,       -- Plaetze im Habseligkeiten-Fach
    },
    Bail = {
        MaxAmount = 2000,
    },
    DisabledControls = {
        0x24978A28, -- INPUT_WHISTLE (Pferd rufen)
        0xE7EB9185, -- INPUT_WHISTLE_HORSEBACK
        0xF3830D8E, -- INPUT_OPEN_JOURNAL (Wagen rufen)
    },
}

--------------------------------------------------------------------------
-- Haftbefehle
--------------------------------------------------------------------------
Config.Warrants = {
    ExpireDays      = 7,
    RequireApproval = true,     -- ohne Recht warrant_approve -> "pending"
    SystemDept      = 'sheriff', -- Behoerde fuer automatische Haftbefehle
    CheckMinutes    = 10,
}

--------------------------------------------------------------------------
-- Kopfgeld
--------------------------------------------------------------------------
Config.Bounty = {
    License = {
        Price      = 150,
        Days       = 14,
        Department = 'sheriff',   -- Kasse, die den Lizenzpreis bekommt
        CacheSeconds = 60,
    },
    Private = {
        Min             = 50,
        Max             = 5000,
        FeePercent      = 0.10,   -- Gebuehr (wird bei Storno NICHT erstattet)
        FeeDepartment   = 'sheriff',
        RequireApproval = true,
        ExpireDays      = 7,
        MinAgeMinutes   = 10,     -- Kopfgeld muss X Minuten alt sein, bevor es eingeloest werden kann (gilt fuer ALLE Kopfgelder)
        MaxPerPlacer    = 5,      -- offene private Kopfgelder je Auftraggeber
    },
    Official = {
        FundedBy   = 'society',   -- 'society' = Kasse zahlt sofort (treuhaenderisch) | 'state' = Geld entsteht bei Auszahlung
        Max        = 2000,
        ExpireDays = 7,
        SystemDept = 'sheriff',   -- Kasse fuer automatische Kopfgelder (z.B. Flucht)
    },
    Claim = {
        HunterRadius       = 10.0,
        PairCooldownHours  = 24,    -- gleicher Jaeger + gleiches Ziel hoechstens 1x je X Stunden
        DeadGoesToJail     = true,  -- tot abgeliefert -> wiederbeleben + Knast
        DefaultJailMinutes = 15,
        -- Gesetz im Dienst: offizielle Kopfgelder gehen zurueck in die Kasse
        -- (kein Privatgewinn). Private Kopfgelder nur, wenn true.
        LawGetsPrivate     = false,
    },
    BoardDistance = 5.0,
}

--------------------------------------------------------------------------
-- NPC-Einsaetze (wichtig auf einem 5-Slot-Server)
--------------------------------------------------------------------------
local BANDIT_WEAPONS = { 'WEAPON_REVOLVER_CATTLEMAN', 'WEAPON_REPEATER_CARBINE', 'WEAPON_SHOTGUN_DOUBLEBARREL', 'WEAPON_RIFLE_VARMINT', 'WEAPON_PISTOL_VOLCANIC' }

Config.Npc = {
    Bounties = {
        Enabled          = true,
        AllowLaw         = true,   -- Gesetz im Dienst darf NPC-Kopfgelder auch ohne Lizenz annehmen
        PerHunterPerHour = 3,
        Cooldown         = 600,    -- Sekunden nach Abschluss/Abbruch bis zum naechsten Auftrag
        MinSeconds       = 180,    -- Abliefern fruehestens X Sekunden nach Annahme
        MaxActive        = 1,      -- gleichzeitige Auftraege je Jaeger
        MaxMinutes       = 45,     -- danach verfaellt der Auftrag
        OfferMinutes     = 60,     -- Angebote am Brett wechseln alle X Minuten
        SpawnDistance    = 250.0,  -- Ziel + Bande erscheinen erst naeher als X m
        SpawnCheckRadius = 400.0,  -- gemeldete NPCs muessen <= X m vom Zielgebiet stehen
        SampleSeconds    = 5,      -- Takt der Positionsproben des Ziels
        MaxSpeed         = 40.0,   -- m/s zwischen zwei Positionsproben; schneller = Teleport -> Auftrag ungueltig (kein Lohn)
        MinSamples       = 6,      -- so viele Positionsproben muss es vor dem Abliefern geben (6 x 5 s = 30 s Beobachtung)
        AreaRadius       = 120.0,  -- Suchkreis auf der Karte
        Weapons          = BANDIT_WEAPONS,
        Blip = { sprite = 'blip_ambient_bounty_target', color = 'BLIP_MODIFIER_MP_COLOR_2' },
        -- Zielgebiete aus erprobten Kopfgeld-Orten (ricx_bounty_quests) - trotzdem im Spiel pruefen
        Targets = {
            {
                id = 'dutch_varley', name = 'Dutch Varley', description = 'Pferdedieb, soll sich mit seiner Bande in den Huegeln westlich von Valentine verstecken.',
                model = 'g_m_m_unicriminals_01', gang = { 'g_m_m_unicriminals_01', 'a_m_m_valcriminals_01' }, count = 2,
                areas = { vector3(-594.20, 511.84, 95.54), vector3(-345.23, -114.62, 46.43) }, areaLabel = 'Umgebung Valentine',
                reward = { 60, 90 }, aliveBonus = 30, difficulty = 1,
            },
            {
                id = 'ezra_cole', name = 'Ezra "Rattlesnake" Cole', description = 'Postkutschenraeuber, zuletzt bei den Oelfeldern gesehen.',
                model = 'g_m_m_unibanditos_01', gang = { 'g_m_m_unibanditos_01' }, count = 3,
                areas = { vector3(610.22, 585.86, 109.93), vector3(277.62, 147.17, 101.07) }, areaLabel = 'Heartlands',
                reward = { 80, 120 }, aliveBonus = 40, difficulty = 2,
            },
            {
                id = 'silas_brody', name = 'Silas Brody', description = 'Moerder, versteckt sich mit Komplizen im Grizzly-Gebirge.',
                model = 'g_m_m_unimountainmen_01', gang = { 'g_m_m_unimountainmen_01' }, count = 3,
                areas = { vector3(276.85, 2053.87, 228.73), vector3(779.98, 1847.71, 243.22) }, areaLabel = 'Grizzlies',
                reward = { 110, 150 }, aliveBonus = 50, difficulty = 3,
            },
            {
                id = 'jeb_tanner', name = 'Jeb Tanner', description = 'Deserteur und Viehdieb, haust mit Ex-Konfoederierten in einem alten Fort.',
                model = 'g_m_y_uniexconfeds_01', gang = { 'g_m_y_uniexconfeds_01', 'g_m_o_uniexconfeds_01' }, count = 4,
                areas = { vector3(383.40, 1463.89, 177.87) }, areaLabel = 'Fort noerdlich von Valentine',
                reward = { 120, 170 }, aliveBonus = 60, difficulty = 3,
            },
            {
                id = 'hector_morales', name = 'Hector Morales', description = 'Bandit aus Mexiko, lagert am Fluss bei Blackwater.',
                model = 'g_m_m_unibanditos_01', gang = { 'g_m_m_unibanditos_01' }, count = 2,
                areas = { vector3(-929.08, -896.18, 40.87), vector3(-755.04, -361.49, 40.84) }, areaLabel = 'Umgebung Blackwater',
                reward = { 70, 100 }, aliveBonus = 30, difficulty = 1,
            },
            {
                id = 'amos_greer', name = 'Amos Greer', description = 'Schwarzbrenner und Schmuggler im Sumpf bei Lagras.',
                model = 'g_m_m_uniswamp_01', gang = { 'g_m_m_uniswamp_01' }, count = 3,
                areas = { vector3(2205.94, -547.59, 40.22), vector3(1852.46, -1226.62, 42.43) }, areaLabel = 'Bayou Nwa',
                reward = { 90, 130 }, aliveBonus = 40, difficulty = 2,
            },
            {
                id = 'lemuel_pike', name = 'Lemuel Pike', description = 'Brandstifter, zuletzt im verlassenen Dorf mit der abgebrannten Kirche.',
                model = 'g_m_m_uniinbred_01', gang = { 'g_m_m_uniinbred_01' }, count = 3,
                areas = { vector3(1700.41, -405.29, 49.01), vector3(2496.86, 733.85, 74.03) }, areaLabel = 'Scarlett Meadows / Roanoke',
                reward = { 90, 130 }, aliveBonus = 45, difficulty = 2,
            },
            {
                id = 'virgil_hayes', name = 'Virgil Hayes', description = 'Bankraeuber mit bewaffneter Bande, verschanzt im Fort bei Van Horn.',
                model = 'g_m_m_unigrays_01', gang = { 'g_m_m_unigrays_01', 'g_m_m_unibrontegoons_01' }, count = 5,
                areas = { vector3(2460.86, 309.43, 71.50) }, areaLabel = 'Fort bei Van Horn',
                reward = { 160, 220 }, aliveBonus = 80, difficulty = 4,
            },
            {
                id = 'cyrus_webb', name = 'Cyrus Webb', description = 'Grabraeuber, versteckt sich in den Hoehlen oestlich der Big Valley.',
                model = 'g_m_m_unicriminals_01', gang = { 'g_m_m_unicriminals_01' }, count = 2,
                areas = { vector3(-2365.78, 122.59, 215.78), vector3(-1385.30, 1156.93, 224.07) }, areaLabel = 'Big Valley / Mount Hagen',
                reward = { 80, 120 }, aliveBonus = 35, difficulty = 2,
            },
            {
                id = 'otis_crane', name = 'Otis Crane', description = 'Entflohener Haeftling, zuletzt suedlich von Strawberry gesehen.',
                model = 'a_m_m_valcriminals_01', gang = {}, count = 0,
                areas = { vector3(-1470.56, -770.06, 103.68), vector3(-1529.31, -926.86, 85.74) }, areaLabel = 'Suedlich von Strawberry',
                reward = { 50, 80 }, aliveBonus = 40, difficulty = 1,
            },
        },
    },
    Calls = {
        Enabled        = true,
        IntervalMin    = { 20, 40 },  -- naechster Einsatz nach X bis Y Minuten
        MinOnDuty      = 1,           -- mindestens X Beamte mit Recht npc_calls im Dienst
        Reward         = 40,          -- je beteiligtem Beamten am Ort
        MinSeconds     = 120,         -- Abschluss fruehestens X Sekunden nach Annahme
        CompleteRadius = 100.0,       -- Beamte muessen <= X m am Einsatzort sein
        SpawnDistance  = 200.0,       -- NPCs erscheinen erst naeher als X m
        Expires        = 1800,        -- Sekunden, bis der Einsatz verfaellt
        CheckSeconds   = 5,
        Types = {
            bandits = {
                weight = 60,
                models = { 'g_m_m_unibanditos_01', 'g_m_m_unicriminals_01', 'g_m_y_uniexconfeds_01', 'g_m_m_unigrays_01' },
                count  = { 3, 5 },
                weapons = BANDIT_WEAPONS,
            },
            fugitive = {
                weight = 40,
                models = { 'a_m_m_valcriminals_01', 'g_m_m_unicriminals_01' },
                count  = { 1, 1 },
                weapons = { 'WEAPON_REVOLVER_CATTLEMAN', 'WEAPON_MELEE_KNIFE' },
            },
        },
        -- Einsatzorte (erprobte Kopfgeld-Orte, trotzdem im Spiel pruefen). ANPASSEN
        Locations = {
            { label = 'Huegel westlich von Valentine',     coords = vector3(-594.20, 511.84, 95.54) },
            { label = 'Abgebrannte Siedlung bei Valentine', coords = vector3(-345.23, -114.62, 46.43) },
            { label = 'Oelfelder',                          coords = vector3(610.22, 585.86, 109.93) },
            { label = 'Moonstone Pond',                     coords = vector3(1233.80, 1197.33, 149.11) },
            { label = 'Insel westlich von Braithwaite',     coords = vector3(386.69, -1162.66, 41.59) },
            { label = 'Suedlich von Rhodes',                coords = vector3(702.87, -1185.53, 46.86) },
            { label = 'Caliga Hall',                        coords = vector3(1852.46, -1226.62, 42.43) },
            { label = 'Sumpf bei Lagras',                   coords = vector3(2205.94, -547.59, 40.22) },
            { label = 'Lager bei Roanoke Ridge',            coords = vector3(2496.86, 733.85, 74.03) },
            { label = 'Fluss bei Blackwater',               coords = vector3(-929.08, -896.18, 40.87) },
            { label = 'Suedlich von Strawberry',            coords = vector3(-1470.56, -770.06, 103.68) },
            { label = 'Heartlands',                         coords = vector3(277.62, 147.17, 101.07) },
        },
    },
}
