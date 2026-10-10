--[[
    ArA-LawSystem - Eskorten: Personenschutz, Personentransport, Werttransport

    Besitzer: Agent B. Eskort-Bueros = alle Config.Stations mit points.escort
    (Kern-Config). Entfernung = Luftlinie zwischen den escort-Punkten in km.
    Preise werden NUR serverseitig berechnet.
]]

Config = Config or {}

Config.Escort = {
    Enabled       = true,
    Department    = 'marshal',   -- Kasse fuer Anteil, Praemien und Versicherungsleistungen
    AllowedDepts  = { 'marshal', 'sheriff', 'pinkerton', 'police' },  -- wer Auftraege annehmen darf
    DepartmentCut = 0.25,        -- Anteil des Preises fuer die Kasse (Rest an die Begleiter)

    Types = {
        bodyguard = { Base = 50, PerMinute = 1.5, Durations = { 30, 60, 90, 120 }, MinEscorts = 1, MaxEscorts = 4, VipRadius = 75.0, DeathRefund = 0.5 },
        transport = { Base = 30, PerKm = 8,  MinutesPerKm = 6, MinMinutes = 15, MinEscorts = 1, MaxEscorts = 3, VipRadius = 75.0 },
        cargo     = { Base = 60, PerKm = 10, ValuePercent = 0.05, MinutesPerKm = 6, MinMinutes = 20, MinEscorts = 1, MaxEscorts = 4 },
    },
    PerExtraEscort = 20,         -- Aufpreis je weiterem Begleiter

    -- Erlaubte Ware im Panzerwagen (Name = Item in der DB) und Wert je Stueck in $.
    -- Items, die es in der DB nicht gibt, werden beim Start mit Warnung ausgeblendet.
    CargoItems = {
        goldbar    = { value = 500 },
        gold_nugget = { value = 15 },  -- in der DB als "gold_nugget" vorhanden
        diamond    = { value = 100 },
    },
    GoldValue       = 20,        -- Wert von 1 Gold (Waehrung) in $ fuer Preis und Versicherung
    MaxCargoEntries = 10,
    MaxCargoValue   = 50000,
    MaxMoney        = 20000,
    MaxGold         = 100,
    -- Versichert ist NUR der Warenwert (Bargeld und Gold nie). Ein Ueberfall
    -- erzeugt einen Versicherungsfall ("pending"), den die Behoerde
    -- `Department` (Recht boss_funds) im Dienstbuch prueft und freigibt.
    Insurance       = {
        PremiumPercent   = 0.08,
        Coverage         = 0.8,
        MaxClaimsPerWeek = 1,     -- je Kunde (Steam-ID): Faelle pending/paid in 7 Tagen
        ExpireDays       = 14,    -- unbearbeitete Faelle verfallen
        -- false (Head Designer): der Taeter soll ermittelt werden (Spuren, Labor,
        -- Bluthund), nicht im Versicherungsformular stehen. Komplizen-Betrug
        -- faengt das System ohnehin automatisch ab (gleicher Spieler / kein Begleiter).
        RevealRobber     = false,
    },

    WagonModel          = 'wagonarmoured01x',
    TickSeconds         = 10,
    ParticipationRadius = 75.0,  -- Begleiter zaehlt nur so nah am Wagen
    StartDistance       = 20.0,  -- Personenschutz/-transport: Leiter so nah an der Person
    DeliverMargin       = 10.0,  -- Wagen darf so weit ausserhalb der Zielzone stehen
    WagonLostGrace      = 120,
    LeaderLostGrace     = 300,
    RefundOnFail        = 0.5,   -- Anteil des Preises zurueck bei Scheitern
    OpenExpireHours     = 24,    -- offene/nie gestartete Auftraege verfallen (volle Erstattung)
    ClaimExpireDays     = 14,    -- danach darf auch der Auftraggeber die Lieferung abholen

    Robbery = {
        Item             = Config.Items and Config.Items.StrongboxTool or 'law_strongbox_tool',
        Seconds          = 60,
        Distance         = 3.0,
        Cooldown         = 300,
        WagonDeleteAfter = 600,  -- ueberfallener Wagen bleibt so lange stehen
    },

    Ambush = {
        Enabled    = true,
        Chance     = 0.35,
        Count      = { 3, 6 },
        Models     = { 'g_m_m_unibanditos_01', 'g_m_m_uniduster_01', 'g_m_y_uniexconfeds_01' },
        Weapons    = { 'WEAPON_REPEATER_CARBINE', 'WEAPON_REVOLVER_CATTLEMAN', 'WEAPON_SHOTGUN_DOUBLEBARREL' },
        Progress   = { 0.3, 0.7 },  -- Hinterhalt zwischen 30 % und 70 % der Strecke
        SpawnAhead = 120.0,
        Spread     = 15.0,
        DespawnAfter = 900,
    },
}
