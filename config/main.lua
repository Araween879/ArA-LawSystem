--[[
    ArA-LawSystem - Haupt-Config (Kern)

    Welche Datei fuer was?
      config/main.lua           (DIESE: Allgemein, Tasten, Befehle, Items, Behoerden + Raenge,
                                 Waffenkammer, Dienstwagen, Lohn, Kassen, Leitstelle)
      config/stations/*.lua     (EINE Datei pro Stadt: alle Punkte der Station, Blip, Zellen)
      config/justice.lua        (Festnahme, Bussgeld, Knast, Akten, Haftbefehle, Kopfgeld, NPC)
      config/investigation.lua  (Spuren, Waffenregister, Geruch, Bluthund)
      config/escort.lua         (Personenschutz, Transporte, Werttransporte)
      config/server_only.lua    (Webhooks - wird NIE an Clients geschickt)

    Alle Koordinaten mit "ANPASSEN" sind sinnvolle Startwerte aus vorp_police,
    muessen aber im Spiel geprueft werden. Hilfe: /lawcoords (Admin) gibt die
    eigene Position als vector3/vector4 in der F8-Konsole aus.
]]

Config = Config or {}

--------------------------------------------------------------------------
-- Allgemein
--------------------------------------------------------------------------
Config.General = {
    Locale       = 'de',        -- 'de' oder 'en'
    Debug        = false,       -- ausfuehrliche Konsolenausgaben
    RequireDuty  = true,        -- Rechte gelten nur im Dienst (Ausnahme: Rechte ohne Dienstpflicht im Code)
    Currency     = '$',
    AdminGroups  = { 'admin', 'superadmin' },  -- vorp-Gruppen mit Admin-Befehlen
    AskTimeout   = 15000,       -- ms, wie lange der Server auf eine Client-Antwort wartet
    ShowDutyHud  = true,        -- kleines Abzeichen im HUD, solange man im Dienst ist
    -- Tod zusaetzlich serverseitig an der Ped-Gesundheit pruefen (Schutz gegen
    -- gefaelschtes vorp:ImDead). Nur auf false stellen, wenn Tote im Spiel
    -- nachweislich nicht als tot erkannt werden (z.B. Kopfgeld "tot" geht nicht).
    ValidateDeath = true,
}

--------------------------------------------------------------------------
-- Tasten (RedM Control-Hashes)
--------------------------------------------------------------------------
Config.Keys = {
    Prompt   = 0xCEFD9220,  -- E   (INPUT_CONTEXT_Y) - Prompts an Stationen
    Interact = 0x3C0A40F2,  -- F6  - Interaktionsmenue (Spieler in der Naehe / eigene Aktionen)
}

Config.Interact = {
    TargetDistance = 3.0,   -- Reichweite fuer Aktionen am naechsten Spieler (F6)
}

-- Stations-Punkte: Abstand wird waagerecht gemessen. Der Punkt darf so viele
-- Meter ueber/unter dem Spieler liegen (z.B. auf Tisch-, Schrank- oder
-- Schildhoehe eingetragen). Nicht hoeher als ~3 stellen, sonst greifen Punkte
-- durch Decken/Boeden in mehrstoeckigen Gebaeuden.
Config.Points = {
    HeightTolerance = 2.5,
}

--------------------------------------------------------------------------
-- Befehle
--------------------------------------------------------------------------
Config.Commands = {
    Ledger    = 'dienstbuch',  -- Dienstbuch oeffnen (nur Behoerde)
    Interact  = 'lawmenu',     -- Interaktionsmenue (auch per Taste)
    Badge     = 'marke',       -- Marke zeigen (Alternative zum Item)
    CallLaw   = 'sheriff',     -- /sheriff <Text>  Buerger-Notruf
    Panic     = 'panik',       -- Panikknopf (Behoerde im Dienst)
    Accept    = 'einsatz',     -- /einsatz <Nr>  Einsatz annehmen
    Coords    = 'lawcoords',   -- Admin: eigene Position ausgeben
}

--------------------------------------------------------------------------
-- Items (Namen muessen in der Tabelle `items` stehen -> sql/items.sql)
--------------------------------------------------------------------------
Config.Items = {
    Cuffs          = 'handcuffs',        -- vorhanden
    CuffKey        = 'handcuffkey',      -- vorhanden
    Lockpick       = 'lockpick',         -- vorhanden, gehoert vorp_doorlocks -> NICHT als benutzbar registrieren
    BountyLicense  = 'bountylicns',      -- vorhanden
    Badge          = 'law_badge',
    FineTicket     = 'law_fineticket',
    EvidenceBag    = 'law_evidence_bag',
    Casing         = 'law_casing',
    BloodSample    = 'law_bloodsample',
    ClothScrap     = 'law_clothscrap',
    ScentCloth     = 'law_scentcloth',
    Whistle        = 'law_whistle',
    GunFile        = 'law_gunfile',
    WeaponPermit   = 'law_weaponpermit',
    StrongboxTool  = 'law_strongbox_tool',
}

--------------------------------------------------------------------------
-- Rechte je Rang (Schluessel siehe docs/01_CONTRACT.md Abschnitt 6)
-- Ein Rang erbt NICHT automatisch vom Rang darunter - die Listen unten
-- werden beim Start zusammengefuehrt, wenn `inherit = true` gesetzt ist.
--------------------------------------------------------------------------
local BASE_LAW = { 'duty', 'badge', 'dispatch', 'storage', 'garage', 'cuff', 'escort', 'search', 'idcheck', 'records_view' }

Config.Departments = {
    sheriff = {
        label = 'County Sheriff', short = 'Sheriff', badgePrefix = 'SO', color = '#8b5a2b',
        seal = 'sheriff', inherit = true,
        grades = {
            [0] = { label = 'Anwaerter',     salary = 8,  perms = BASE_LAW },
            [1] = { label = 'Deputy',        salary = 12, perms = { 'fine', 'jail', 'records_edit', 'warrant_create', 'evidence', 'weapons_registry', 'escort_contracts', 'npc_calls', 'scent_sample', 'armory' } },
            [2] = { label = 'Senior Deputy', salary = 15, perms = { 'k9', 'evidence_analyze', 'fine_cancel', 'escort_lead' } },
            [3] = { label = 'Undersheriff',  salary = 18, perms = { 'warrant_approve', 'jail_release', 'bounty_manage', 'license_manage', 'boss_hire', 'boss_logs' } },
            [4] = { label = 'Sheriff',       salary = 22, perms = { 'all' } },
        },
        armory = 'lawman', garage = 'county',
    },
    marshal = {
        label = 'US Marshals', short = 'Marshal', badgePrefix = 'USM', color = '#6b6b6b',
        seal = 'marshal', inherit = true,
        grades = {
            [0] = { label = 'Anwaerter',      salary = 8,  perms = { 'duty', 'badge', 'dispatch', 'storage', 'garage', 'cuff', 'escort', 'search', 'idcheck', 'records_view', 'escort_contracts' } },
            [1] = { label = 'Deputy Marshal', salary = 13, perms = { 'fine', 'jail', 'records_edit', 'warrant_create', 'evidence', 'weapons_registry', 'armory', 'npc_calls', 'k9', 'scent_sample', 'escort_lead' } },
            [2] = { label = 'Marshal',        salary = 17, perms = { 'warrant_approve', 'bounty_manage', 'jail_release', 'evidence_analyze', 'license_manage', 'fine_cancel', 'boss_logs' } },
            [3] = { label = 'Chief Marshal',  salary = 22, perms = { 'all' } },
        },
        armory = 'lawman', garage = 'federal',
    },
    police = {
        label = 'Saint Denis Police', short = 'Police', badgePrefix = 'SDPD', color = '#2b3f5c',
        seal = 'police', inherit = true,
        grades = {
            [0] = { label = 'Kadett',   salary = 8,  perms = BASE_LAW },
            [1] = { label = 'Officer',  salary = 12, perms = { 'fine', 'jail', 'records_edit', 'warrant_create', 'evidence', 'weapons_registry', 'armory', 'npc_calls' } },
            [2] = { label = 'Sergeant', salary = 16, perms = { 'k9', 'scent_sample', 'evidence_analyze', 'fine_cancel', 'escort_contracts', 'boss_logs' } },
            [3] = { label = 'Captain',  salary = 21, perms = { 'all' } },
        },
        armory = 'lawman', garage = 'city',
    },
    pinkerton = {
        label = 'Pinkerton-Detektei', short = 'Pinkerton', badgePrefix = 'PNK', color = '#3a2e22',
        seal = 'pinkerton', inherit = true,
        grades = {
            [0] = { label = 'Anwaerter',    salary = 8,  perms = { 'duty', 'badge', 'dispatch', 'storage', 'garage', 'idcheck', 'records_view', 'evidence', 'escort_contracts' } },
            [1] = { label = 'Agent',        salary = 13, perms = { 'cuff', 'escort', 'search', 'evidence_analyze', 'weapons_registry', 'k9', 'scent_sample', 'escort_lead', 'armory', 'records_edit' } },
            [2] = { label = 'Senior Agent', salary = 17, perms = { 'warrant_create', 'jail', 'fine', 'boss_logs' } },
            [3] = { label = 'Direktor',     salary = 22, perms = { 'all' } },
        },
        armory = 'detective', garage = 'federal',
    },
    prisonguard = {
        label = 'Sisika-Gefaengnis', short = 'Waerter', badgePrefix = 'SIS', color = '#4a4a3a',
        seal = 'prison', inherit = true,
        grades = {
            [0] = { label = 'Waerter',    salary = 8,  perms = { 'duty', 'badge', 'dispatch', 'storage', 'cuff', 'escort', 'search', 'idcheck', 'records_view', 'jail' } },
            [1] = { label = 'Oberwaerter', salary = 12, perms = { 'jail_release', 'records_edit', 'armory', 'garage', 'k9', 'scent_sample', 'boss_logs' } },
            [2] = { label = 'Direktor',   salary = 18, perms = { 'all' } },
        },
        armory = 'lawman', garage = 'county',
    },
    judge = {
        label = 'Gericht', short = 'Richter', badgePrefix = 'CRT', color = '#5c1f1f',
        seal = 'court', inherit = true,
        grades = {
            [0] = { label = 'Richter',     salary = 15, perms = { 'duty', 'badge', 'records_view', 'records_edit', 'warrant_create', 'warrant_approve', 'jail_release', 'fine_cancel', 'bounty_manage', 'license_manage' } },
            [1] = { label = 'Oberrichter', salary = 20, perms = { 'all' } },
        },
        armory = nil, garage = nil,
    },
}

--------------------------------------------------------------------------
-- Waffenkammer: Ausruestung, die die Kasse der Behoerde bezahlt
--------------------------------------------------------------------------
Config.Armory = {
    Cooldown = 20,  -- Sekunden zwischen zwei Entnahmen je Officer
    Sets = {
        lawman = {
            { kind = 'weapon', name = 'WEAPON_REVOLVER_CATTLEMAN', label = 'Cattleman-Revolver',   price = 25, minGrade = 0 },
            { kind = 'weapon', name = 'WEAPON_REPEATER_CARBINE',   label = 'Karabiner-Repetierer', price = 45, minGrade = 1 },
            { kind = 'weapon', name = 'WEAPON_SHOTGUN_PUMP',       label = 'Pump-Schrotflinte',    price = 55, minGrade = 2 },
            { kind = 'weapon', name = 'WEAPON_RIFLE_SPRINGFIELD',  label = 'Springfield-Gewehr',   price = 60, minGrade = 2 },
            { kind = 'weapon', name = 'WEAPON_LASSO',              label = 'Lasso',                price = 5,  minGrade = 0 },
            { kind = 'item',   name = 'ammorevolvernormal',        label = 'Revolvermunition',     price = 3,  minGrade = 0, amount = 1 },
            { kind = 'item',   name = 'ammorepeaternormal',        label = 'Repetiermunition',     price = 4,  minGrade = 1, amount = 1 },
            { kind = 'item',   name = 'ammoshotgunnormal',         label = 'Schrotmunition',       price = 4,  minGrade = 2, amount = 1 },
            { kind = 'item',   name = 'ammoriflenormal',           label = 'Gewehrmunition',       price = 5,  minGrade = 2, amount = 1 },
            { kind = 'item',   name = 'handcuffs',                 label = 'Handschellen',         price = 5,  minGrade = 0, amount = 1 },
            { kind = 'item',   name = 'handcuffkey',               label = 'Handschellenschluessel', price = 2, minGrade = 0, amount = 1 },
            { kind = 'item',   name = 'law_evidence_bag',          label = 'Beweismittelbeutel',   price = 1,  minGrade = 1, amount = 5 },
            { kind = 'item',   name = 'law_whistle',               label = 'Hundepfeife',          price = 10, minGrade = 2, amount = 1, perm = 'k9' },
            { kind = 'item',   name = 'law_badge',                 label = 'Dienstmarke',          price = 0,  minGrade = 0, amount = 1 },
            { kind = 'item',   name = 'bandage',                   label = 'Verband',              price = 2,  minGrade = 0, amount = 1 },
        },
        detective = {
            { kind = 'weapon', name = 'WEAPON_PISTOL_VOLCANIC',    label = 'Volcanic-Pistole',     price = 35, minGrade = 0 },
            { kind = 'weapon', name = 'WEAPON_REPEATER_WINCHESTER',label = 'Lancaster-Repetierer', price = 55, minGrade = 1 },
            { kind = 'item',   name = 'ammopistolnormal',          label = 'Pistolenmunition',     price = 3,  minGrade = 0, amount = 1 },
            { kind = 'item',   name = 'ammorepeaternormal',        label = 'Repetiermunition',     price = 4,  minGrade = 1, amount = 1 },
            { kind = 'item',   name = 'handcuffs',                 label = 'Handschellen',         price = 5,  minGrade = 1, amount = 1 },
            { kind = 'item',   name = 'handcuffkey',               label = 'Handschellenschluessel', price = 2, minGrade = 1, amount = 1 },
            { kind = 'item',   name = 'law_evidence_bag',          label = 'Beweismittelbeutel',   price = 1,  minGrade = 0, amount = 5 },
            { kind = 'item',   name = 'law_whistle',               label = 'Hundepfeife',          price = 10, minGrade = 1, amount = 1, perm = 'k9' },
            { kind = 'item',   name = 'law_badge',                 label = 'Dienstmarke',          price = 0,  minGrade = 0, amount = 1 },
        },
    },
}

--------------------------------------------------------------------------
-- Dienstwagen (Gefangenentransport)
--------------------------------------------------------------------------
Config.Garage = {
    MaxPerOfficer    = 1,
    Cooldown         = 60,     -- Sekunden zwischen zwei Ausparkvorgaengen
    DespawnOnDutyOff = true,
    Sets = {
        county  = { { model = 'wagonprison01x', label = 'Gefangenenwagen', minGrade = 0 } },
        city    = { { model = 'policewagon01x', label = 'Polizeiwagen', minGrade = 0 }, { model = 'wagonprison01x', label = 'Gefangenenwagen', minGrade = 1 } },
        federal = { { model = 'wagonprison01x', label = 'Gefangenenwagen', minGrade = 0 } },
    },
}

--------------------------------------------------------------------------
-- Dienst, Lohn, Kassen, Chef
--------------------------------------------------------------------------
Config.Duty = {
    OnlyAtPoint = true,   -- Dienst nur am "duty"-Punkt einer Station umschalten
    PointRadius = 2.0,
}

Config.Payroll = {
    Enabled      = false,  -- AUS lassen, wenn vorp_paycheck schon nach Job bezahlt (sonst doppelt)
    IntervalMin  = 30,     -- Lohn je X Minuten Dienst
    FromSociety  = true,   -- Lohn kommt aus der Kasse (reicht sie nicht, gibt es keinen Lohn)
}

Config.Society = {
    StartBalance = 1000,   -- Startguthaben je Behoerde (nur beim allerersten Start)
    MaxWithdraw  = 5000,   -- max. Entnahme je Vorgang
}

Config.Counter = {
    -- Reihenfolge = Reihenfolge der Reiter am Schalter. 'escort' erscheint nur
    -- an Stationen mit escort-Punkt.
    Tabs = { 'fines', 'bail', 'license', 'bounty', 'weapons', 'escort', 'property', 'report' },
}

Config.Storage = {
    Limit = 1000,          -- Plaetze im Dienstlager je Behoerde (alle Stationen teilen sich ein Lager)
}

Config.Boss = {
    HireDistance = 5.0,    -- Einstellen nur, wenn der Spieler in der Naehe steht
}

Config.Badge = {
    ShowDistance = 5.0,
    DurationMs   = 6000,
    Cooldown     = 5,
}

--------------------------------------------------------------------------
-- Leitstelle
--------------------------------------------------------------------------
Config.Dispatch = {
    CallCooldown   = 120,   -- Sekunden zwischen zwei Buerger-Notrufen
    PanicCooldown  = 60,
    AlertLifetime  = 900,   -- Sekunden, bis ein Einsatz automatisch verfaellt
    MaxOpenAlerts  = 30,
    -- Werte wie in vorp_police (dort erprobt). color = BLIP_MODIFIER_MP_COLOR_2 ist rot.
    Blip = { style = 'BLIP_STYLE_CHALLENGE_OBJECTIVE', sprite = 'blip_mp_bounty_hunter_introduction', color = 'BLIP_MODIFIER_MP_COLOR_2', seconds = 180 },
    AllowCallWhenDead = true,
    ShotsFired = {
        Enabled         = true,
        IgnoreLawOnDuty = true,   -- Schuesse von Gesetzeshuetern im Dienst loesen keinen Alarm aus
        ZoneCooldown    = 60,     -- je Stadt hoechstens ein Alarm pro X Sekunden
        Delay           = { 5, 15 },  -- Sekunden bis der NPC-Zeuge meldet
        Fuzz            = 60,     -- Meter Ungenauigkeit der Meldung
        -- Die Gebiete der Staedte stehen in config/stations/<stadt>.lua (shotsZone).
        -- Hier nur Orte OHNE eigene Station:
        Zones = {  -- ANPASSEN nach Bedarf
            { label = 'Van Horn',      coords = vector3(2960.0, 530.0, 45.0),    radius = 120.0 },
            { label = 'Emerald Ranch', coords = vector3(1420.0, 290.0, 88.0),    radius = 100.0 },
        },
    },
}

--------------------------------------------------------------------------
-- Stationen
-- Jede Stadt hat ihre EIGENE Datei:  config/stations/<stadt>.lua
-- Dort stehen alle Punkte, Blip, erlaubte Behoerden, eigene Zellen und das
-- Schuesse-Alarm-Gebiet. Neue Station: config/stations/_vorlage.lua kopieren.
--------------------------------------------------------------------------
Config.Stations = Config.Stations or {}
