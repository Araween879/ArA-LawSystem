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
    Lifetime            = { casing = 2700, blood = 3600, cloth = 7200 },  -- wie lange eine Spur in der Welt liegt
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
    BleedRateMs         = 5000,    -- hoechstens eine Blutspur je Spieler in diesem Abstand
    ClothRateMs         = 60000,   -- hoechstens ein Kleidungsfetzen je Spieler in diesem Abstand
    -- Verletzungen: Wer getroffen wird, hinterlaesst Spuren an SEINER Position.
    -- Blood / Cloth = Chance in % je Treffer (0 = nie, 100 = immer)
    Wounds = {
        Fist   = { Blood = 35 },              -- Schlaegerei (Faeuste, Laterne, Fackel ...): Blut KANN fallen
        Shot   = { Blood = 100 },             -- angeschossen (Revolver, Gewehr, Schrot, Bogen)
        Sharp  = { Blood = 100, Cloth = 100 },-- Messer, Axt, Machete ... (Liste SharpWeapons): Blut + Kleidungsfetzen
        Animal = { Blood = 100 },             -- Tierbiss (Wolf, Baer ...)
        Other  = { Blood = 0 },               -- Sturz, Feuer, Explosion, Ertrinken ...
    },
    -- Waffen, die Kleidung zerschneiden (Messer, Aexte & Co)
    SharpWeapons = {
        'WEAPON_MELEE_KNIFE', 'WEAPON_MELEE_KNIFE_JAWBONE', 'WEAPON_MELEE_KNIFE_TRADER', 'WEAPON_MELEE_KNIFE_HORROR',
        'WEAPON_MELEE_KNIFE_RUSTIC', 'WEAPON_MELEE_KNIFE_MINER', 'WEAPON_MELEE_KNIFE_VAMPIRE', 'WEAPON_MELEE_KNIFE_CIVIL_WAR',
        'WEAPON_MELEE_KNIFE_BEAR',
        'WEAPON_MELEE_MACHETE', 'WEAPON_MELEE_MACHETE_HORROR', 'WEAPON_MELEE_MACHETE_COLLECTOR',
        'WEAPON_MELEE_CLEAVER', 'WEAPON_MELEE_BROKEN_SWORD',
        'WEAPON_MELEE_HATCHET', 'WEAPON_MELEE_HATCHET_HUNTER', 'WEAPON_MELEE_HATCHET_DOUBLE_BIT', 'WEAPON_MELEE_HATCHET_HEWING',
        'WEAPON_MELEE_HATCHET_VIKING', 'WEAPON_MELEE_ANCIENT_HATCHET', 'WEAPON_MELEE_HATCHET_HUNTER_RUSTED',
        'WEAPON_MELEE_HATCHET_DOUBLE_BIT_RUSTED',
        'WEAPON_THROWN_THROWING_KNIVES', 'WEAPON_THROWN_TOMAHAWK', 'WEAPON_THROWN_TOMAHAWK_ANCIENT',
    },
    -- Womit wird eine Spur gesichert? (Item wird verbraucht)
    CollectWith = {
        casing = 'law_evidence_bag',
        blood  = 'law_sterilecloth',   -- Blut nimmt man mit einem sterilen Tuch auf
        cloth  = 'law_evidence_bag',
    },
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
    MaxAge         = 3600,     -- Punkte aelter als das verfliegen (60 Min.)
    SniffRadius    = 200.0,    -- Hund findet den neuesten Punkt in diesem Umkreis
    Chunk          = 15,       -- Punkte je Teilstueck
    Tolerance      = 15.0,     -- Hund muss so nah am letzten Punkt sein, bevor es weitergeht
    FoundDistance  = 5.0,      -- "Gefunden", wenn der Hund so nah an der Person steht
    Cooldown       = 60,       -- Sekunden zwischen zwei Witterungen je Hundefuehrer
    UsesPerItem    = 3,        -- so oft taugt ein Geruchstraeger
    Uses           = {         -- abweichend je Item (0 = unbegrenzt)
        law_clothscrap = 0,    -- Kleidung: der Hund findet den Traeger damit immer wieder
    },
    -- Wie lange nach der Tat taugt ein Geruchstraeger fuer den Hund? (Minuten, 0/fehlt = immer)
    -- Blut: 60 Min. ab dem Moment, in dem es auf den Boden gefallen ist.
    ItemMinutes    = {
        law_bloodsample = 60,
    },
    -- Nach einer Haftstrafe ist der Geruch weg: alles, was VOR dem Einbuchen
    -- gesichert wurde (Kleidung, Blut, Huelsen, Geruchsproben), taugt nicht mehr fuer den Hund.
    ResetOnJail    = true,
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
