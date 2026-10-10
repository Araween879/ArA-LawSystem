--[[
    ArA-LawSystem - Ermittlung: Spuren, Waffenregister, Geruch, Bluthund

    Besitzer: Agent B. Diese Datei definiert NUR ihre eigenen Unterschluessel
    (Vertrag Abschnitt 2). Zeiten in Sekunden, Distanzen in Metern.
]]

Config = Config or {}

--------------------------------------------------------------------------
-- Spuren (Huelsen, Blut, Stoff) und Labor
--------------------------------------------------------------------------
Config.Evidence = {
    Enabled             = true,
    Lifetime            = { casing = 2700, blood = 1800, cloth = 2700 },  -- wie lange eine Spur in der Welt liegt
    ScanRadius          = 30.0,    -- Spurensuche: Spuren in diesem Umkreis um den Officer
    ScanCooldown        = 3,       -- Sekunden zwischen zwei Suchen
    DrawDistance        = 30.0,    -- ab hier zeichnet der Client die Marker
    CollectDistance     = 2.0,     -- Server: max. Abstand beim Sichern
    PromptDistance      = 1.5,     -- Client: ab hier erscheint "Spur sichern"
    MaxWorld            = 600,     -- Obergrenze Spuren im Speicher (aelteste fliegen)
    MaxPerOwner         = 40,      -- je Verursacher; darueber fliegt zuerst SEINE aelteste Spur (Dauerfeuer verdraengt keine fremden Tatort-Spuren)
    ShotRateMs          = 1500,    -- hoechstens eine Schussmeldung je Spieler in diesem Abstand
    CasingMerge         = 3.0,     -- gleiche Waffe im Umkreis -> eine Spur mit Zaehler
    CasingScatter       = 1.2,     -- zufaelliger Versatz der Huelse
    BleedRateMs         = 10000,   -- hoechstens eine Blutspur je Spieler in diesem Abstand
    BleedMinDamage      = 10,      -- so viel Lebenspunkte muessen auf einmal fehlen
    MeleeClothChance    = 20,      -- % Stofffetzen bei Verletzung im Nahkampf
    AnalysisSeconds     = 60,      -- Laborzeit
    RevealCurrentHolder = true,    -- Labor/Register zeigen den aktuellen Besitzer laut vorp-Inventar
    Gsr                 = { Minutes = 15, Distance = 2.5 },  -- Schmauchspurentest
    CasingHasScent      = true,    -- Huelsen taugen als Geruchstraeger fuer den Bluthund
    LockerLimit         = 500,     -- Plaetze in der Asservatenkammer je Behoerde
    -- Markerfarben (r, g, b) im Spurensuche-Modus
    Colors = {
        casing = { 212, 175, 55 },
        blood  = { 150, 12, 12 },
        cloth  = { 90, 110, 170 },
    },
}

--------------------------------------------------------------------------
-- Waffenregister
--------------------------------------------------------------------------
Config.Weapons = {
    RegisterFee          = 10,           -- Gebuehr am Schalter
    FeeDepartment        = 'sheriff',    -- Kasse, die die Gebuehr bekommt
    PermitItem           = true,         -- Waffenschein als Item ausgeben
    FiledSerial          = 'ABGEFEILT',  -- Seriennummer nach dem Abfeilen
    File                 = { Seconds = 10, Chance = 80, BreakChance = 30 },
    InspectRequiresCuffs = true,         -- Feldkontrolle nur bei gefesselter/bewusstloser Person
    InspectDistance      = 3.0,
    -- Anzeigenamen (Schluessel = vorp-Waffenname). Fehlende Waffen zeigen den Rohnamen.
    Labels = {
        WEAPON_REVOLVER_CATTLEMAN            = 'Cattleman-Revolver',
        WEAPON_REVOLVER_CATTLEMAN_MEXICAN    = 'Cattleman-Revolver (mexikanisch)',
        WEAPON_REVOLVER_DOUBLEACTION         = 'Double-Action-Revolver',
        WEAPON_REVOLVER_DOUBLEACTION_GAMBLER = 'Double-Action-Revolver (Spieler)',
        WEAPON_REVOLVER_SCHOFIELD            = 'Schofield-Revolver',
        WEAPON_REVOLVER_LEMAT                = 'LeMat-Revolver',
        WEAPON_REVOLVER_NAVY                 = 'Navy-Revolver',
        WEAPON_REVOLVER_NAVY_CROSSOVER       = 'Navy-Revolver (Crossover)',
        WEAPON_PISTOL_VOLCANIC               = 'Volcanic-Pistole',
        WEAPON_PISTOL_MAUSER                 = 'Mauser-Pistole',
        WEAPON_PISTOL_SEMIAUTO               = 'Halbautomatische Pistole',
        WEAPON_PISTOL_M1899                  = 'M1899-Pistole',
        WEAPON_REPEATER_CARBINE              = 'Karabiner-Repetierer',
        WEAPON_REPEATER_WINCHESTER           = 'Lancaster-Repetierer',
        WEAPON_REPEATER_HENRY                = 'Litchfield-Repetierer',
        WEAPON_REPEATER_EVANS                = 'Evans-Repetierer',
        WEAPON_RIFLE_VARMINT                 = 'Varmint-Gewehr',
        WEAPON_RIFLE_SPRINGFIELD             = 'Springfield-Gewehr',
        WEAPON_RIFLE_BOLTACTION              = 'Repetierbuechse',
        WEAPON_RIFLE_ELEPHANT                = 'Elefantenbuechse',
        WEAPON_SNIPERRIFLE_ROLLINGBLOCK      = 'Rolling-Block-Gewehr',
        WEAPON_SNIPERRIFLE_CARCANO           = 'Carcano-Gewehr',
        WEAPON_SHOTGUN_DOUBLEBARREL          = 'Doppellaeufige Schrotflinte',
        WEAPON_SHOTGUN_DOUBLEBARREL_EXOTIC   = 'Doppellaeufige Schrotflinte (verziert)',
        WEAPON_SHOTGUN_SAWEDOFF              = 'Abgesaegte Schrotflinte',
        WEAPON_SHOTGUN_PUMP                  = 'Pump-Schrotflinte',
        WEAPON_SHOTGUN_REPEATING             = 'Repetier-Schrotflinte',
        WEAPON_SHOTGUN_SEMIAUTO              = 'Halbautomatische Schrotflinte',
    },
}

--------------------------------------------------------------------------
-- Geruchsspur (Server zeichnet von JEDEM Spieler auf, nur im Speicher)
--------------------------------------------------------------------------
Config.Scent = {
    RecordInterval = 5,        -- Sekunden zwischen zwei Aufzeichnungen
    MinStep        = 3.0,      -- neuer Punkt erst ab dieser Bewegung
    JumpReset      = 150.0,    -- Sprung groesser als das in einem Intervall (Teleport, Knast) -> neue Spur
    MaxAge         = 1800,     -- Punkte aelter als das verfliegen (30 Min.)
    SniffRadius    = 200.0,    -- Hund findet den neuesten Punkt in diesem Umkreis
    Chunk          = 15,       -- Punkte je Teilstueck
    Tolerance      = 15.0,     -- Hund muss so nah am letzten Punkt sein, bevor es weitergeht
    FoundDistance  = 5.0,      -- "Gefunden", wenn der Hund so nah an der Person steht
    Cooldown       = 60,       -- Sekunden zwischen zwei Witterungen je Hundefuehrer
    UsesPerItem    = 3,        -- so oft taugt ein Geruchstraeger
    MaxDogSpeed    = 10.0,     -- m/s - schneller kann kein Hund sein (Schutz gegen Teleport)
    SampleDistance = 3.0,      -- Geruchsprobe nehmen
    SampleCooldown = 30,
    SourceItems = {            -- welche Items als Geruchstraeger taugen
        law_casing      = true,
        law_bloodsample = true,
        law_clothscrap  = true,
        law_scentcloth  = true,
    },
    Strength       = { fresh = 300, medium = 900 },  -- Alter in Sekunden fuer frisch / mittel (sonst schwach)
    FollowLive     = true,     -- Person online: Spur verlaengert sich bis zur Person
    SessionTimeout = 600,      -- Verfolgung endet spaetestens nach so vielen Sekunden
}

--------------------------------------------------------------------------
-- Bluthund
--------------------------------------------------------------------------
Config.K9 = {
    Model              = 'A_C_DogBluetickCoonhound_01',
    HandlerMaxDistance = 60.0,   -- weiter weg -> Hund wartet
    SummonDistance     = 10.0,   -- Witterung nur, wenn der Hund so nah am Hundefuehrer ist
    FromKennel         = true,   -- Hund am Zwinger (Stationspunkt "kennel") holen
    FromWhistle        = true,   -- Hund mit der Hundepfeife rufen
    DeathCooldown      = 300,    -- Sekunden nach dem Tod des Hundes
    Search             = { Radius = 25.0, Cooldown = 60 },
    AllowAttack        = false,  -- Angriff auf Personen (Griefing-Gefahr) - Standard: nur "Stellen"
    Invincible         = false,
    Blip               = true,
    PointReach         = 3.0,    -- Client: Punkt gilt als erreicht
    Speed              = { walk = 1.0, run = 2.0 },
}
