--[[
    ArA-LawSystem - Datenbank-Schema (Server)

    ALLE Tabellen des Projekts stehen hier (Vertrag Abschnitt 7). Module legen
    keine eigenen Tabellen an. Neue Spalte? -> hier in SCHEMA eintragen, mit
    DEFAULT, dann legt der naechste Start sie automatisch an.

    Ablauf bei jedem Start (gefahrlos wiederholbar):
      1. CREATE TABLE IF NOT EXISTS aus der Spaltenliste
      2. fehlende Spalten per ALTER TABLE ADD COLUMN
      3. fehlende Indizes anlegen
      4. Kassen-Zeilen fuer jede Behoerde anlegen (INSERT IGNORE)

    Tabellen-/Spaltennamen koennen in DDL nicht als Parameter gebunden werden.
    Alle Namen hier kommen ausschliesslich aus der SCHEMA-Konstante, nie aus
    einer Eingabe.

    Zeiten: INT UNSIGNED Unix-Sekunden (keine Zeitzonen-Fehler zwischen DB und Lua).
]]

Law.DB = Law.DB or {}

local ready = false
local readyWaiters = {}

local T  = 'INT UNSIGNED NOT NULL DEFAULT 0'   -- Zeitstempel
local TN = 'INT UNSIGNED NULL DEFAULT NULL'    -- optionaler Zeitstempel
local NAME = "VARCHAR(100) NOT NULL DEFAULT ''"
local NAMEN = 'VARCHAR(100) NULL DEFAULT NULL'
local INTN = 'INT NULL DEFAULT NULL'

local SCHEMA = {
    {
        name = 'ara_law_society', pk = { 'department' },
        columns = {
            { 'department', 'VARCHAR(32) NOT NULL' },
            { 'balance',    'DECIMAL(14,2) NOT NULL DEFAULT 0' },
            { 'updated_at', T },
        },
    },
    {
        name = 'ara_law_society_log', pk = { 'id' },
        columns = {
            { 'id',            'INT UNSIGNED NOT NULL AUTO_INCREMENT' },
            { 'department',    "VARCHAR(32) NOT NULL DEFAULT ''" },
            { 'amount',        'DECIMAL(14,2) NOT NULL DEFAULT 0' },
            { 'balance_after', 'DECIMAL(14,2) NOT NULL DEFAULT 0' },
            { 'reason',        "VARCHAR(64) NOT NULL DEFAULT ''" },
            { 'actor_charid',  INTN },
            { 'actor_name',    NAME },
            { 'created_at',    T },
        },
        indexes = { { 'idx_ara_law_soclog_dept', { 'department', 'created_at' } } },
    },
    {
        name = 'ara_law_duty_log', pk = { 'id' },
        columns = {
            { 'id',         'INT UNSIGNED NOT NULL AUTO_INCREMENT' },
            { 'charid',     'INT NOT NULL DEFAULT 0' },
            { 'name',       NAME },
            { 'department', "VARCHAR(32) NOT NULL DEFAULT ''" },
            { 'grade',      'INT NOT NULL DEFAULT 0' },
            { 'started_at', T },
            { 'ended_at',   TN },
            { 'seconds',    'INT NOT NULL DEFAULT 0' },
        },
        indexes = {
            { 'idx_ara_law_duty_char', { 'charid', 'started_at' } },
            { 'idx_ara_law_duty_dept', { 'department', 'started_at' } },
        },
    },
    {
        name = 'ara_law_audit', pk = { 'id' },
        columns = {
            { 'id',            'BIGINT UNSIGNED NOT NULL AUTO_INCREMENT' },
            { 'actor_charid',  INTN },
            { 'actor_name',    NAME },
            { 'action',        "VARCHAR(48) NOT NULL DEFAULT ''" },
            { 'target_charid', INTN },
            { 'data',          'LONGTEXT NULL' },
            { 'created_at',    T },
        },
        indexes = {
            { 'idx_ara_law_audit_action', { 'action', 'created_at' } },
            { 'idx_ara_law_audit_target', { 'target_charid' } },
        },
    },
    {
        name = 'ara_law_citizens', pk = { 'charid' },
        columns = {
            { 'charid',     'INT NOT NULL' },
            { 'blood_type', "VARCHAR(3) NOT NULL DEFAULT ''" },
            { 'has_sample', 'TINYINT NOT NULL DEFAULT 0' },
            { 'dangerous',  'TINYINT NOT NULL DEFAULT 0' },
            { 'notes',      'TEXT NULL' },
            { 'scent_reset_at', TN },   -- letzte Haft: aeltere Geruchstraeger taugen nicht mehr
            { 'updated_at', T },
        },
    },
    {
        name = 'ara_law_records', pk = { 'id' },
        columns = {
            { 'id',             'INT UNSIGNED NOT NULL AUTO_INCREMENT' },
            { 'charid',         'INT NOT NULL DEFAULT 0' },
            { 'type',           "VARCHAR(16) NOT NULL DEFAULT 'note'" },
            { 'title',          "VARCHAR(128) NOT NULL DEFAULT ''" },
            { 'details',        'TEXT NULL' },
            { 'ref_id',         INTN },
            { 'officer_charid', INTN },
            { 'officer_name',   NAMEN },
            { 'department',     'VARCHAR(32) NULL DEFAULT NULL' },
            { 'created_at',     T },
        },
        indexes = { { 'idx_ara_law_records_char', { 'charid', 'created_at' } } },
    },
    {
        name = 'ara_law_fines', pk = { 'id' },
        columns = {
            { 'id',             'INT UNSIGNED NOT NULL AUTO_INCREMENT' },
            { 'charid',         'INT NOT NULL DEFAULT 0' },
            { 'target_name',    NAME },
            { 'officer_charid', INTN },
            { 'officer_name',   NAME },
            { 'department',     "VARCHAR(32) NOT NULL DEFAULT ''" },
            { 'reason',         "VARCHAR(255) NOT NULL DEFAULT ''" },
            { 'codes',          'LONGTEXT NULL' },
            { 'amount',         'DECIMAL(10,2) NOT NULL DEFAULT 0' },
            { 'status',         "VARCHAR(12) NOT NULL DEFAULT 'open'" },
            { 'created_at',     T },
            { 'due_at',         T },
            { 'paid_at',        TN },
            { 'paid_by_charid', INTN },
        },
        indexes = {
            { 'idx_ara_law_fines_char',   { 'charid', 'status' } },
            { 'idx_ara_law_fines_status', { 'status', 'due_at' } },
        },
    },
    {
        name = 'ara_law_warrants', pk = { 'id' },
        columns = {
            { 'id',               'INT UNSIGNED NOT NULL AUTO_INCREMENT' },
            { 'charid',           'INT NOT NULL DEFAULT 0' },
            { 'target_name',      NAME },
            { 'reason',           "VARCHAR(255) NOT NULL DEFAULT ''" },
            { 'codes',            'LONGTEXT NULL' },
            { 'jail_minutes',     'INT NOT NULL DEFAULT 0' },
            { 'dead_or_alive',    'TINYINT NOT NULL DEFAULT 0' },
            { 'department',       "VARCHAR(32) NOT NULL DEFAULT ''" },
            { 'created_by',       INTN },
            { 'created_by_name',  NAME },
            { 'approved_by',      INTN },
            { 'approved_by_name', NAMEN },
            { 'status',           "VARCHAR(12) NOT NULL DEFAULT 'pending'" },
            { 'created_at',       T },
            { 'expires_at',       TN },
            { 'closed_at',        TN },
        },
        indexes = {
            { 'idx_ara_law_warrants_char',   { 'charid', 'status' } },
            { 'idx_ara_law_warrants_status', { 'status' } },
        },
    },
    {
        name = 'ara_law_bounties', pk = { 'id' },
        columns = {
            { 'id',                   'INT UNSIGNED NOT NULL AUTO_INCREMENT' },
            { 'charid',               'INT NOT NULL DEFAULT 0' },
            { 'target_name',          NAME },
            { 'kind',                 "VARCHAR(10) NOT NULL DEFAULT 'official'" },
            { 'warrant_id',           INTN },
            { 'amount',               'DECIMAL(10,2) NOT NULL DEFAULT 0' },
            { 'placed_by',            INTN },
            { 'placed_by_name',       NAMEN },
            { 'placed_by_identifier', 'VARCHAR(64) NULL DEFAULT NULL' },
            { 'department',           'VARCHAR(32) NULL DEFAULT NULL' },
            { 'reason',               "VARCHAR(255) NOT NULL DEFAULT ''" },
            { 'dead_or_alive',        'TINYINT NOT NULL DEFAULT 0' },
            { 'status',               "VARCHAR(12) NOT NULL DEFAULT 'pending'" },
            { 'claimed_by',           INTN },
            { 'claimed_by_name',      NAMEN },
            { 'claimed_at',           TN },
            { 'created_at',           T },
            { 'expires_at',           TN },
        },
        indexes = {
            { 'idx_ara_law_bounties_char',   { 'charid', 'status' } },
            { 'idx_ara_law_bounties_status', { 'status' } },
        },
    },
    {
        name = 'ara_law_licenses', pk = { 'id' },
        columns = {
            { 'id',         'INT UNSIGNED NOT NULL AUTO_INCREMENT' },
            { 'charid',     'INT NOT NULL DEFAULT 0' },
            { 'type',       "VARCHAR(16) NOT NULL DEFAULT 'bounty'" },
            { 'status',     "VARCHAR(12) NOT NULL DEFAULT 'active'" },
            { 'issued_at',  T },
            { 'expires_at', TN },
            { 'issued_by',  INTN },
        },
        indexes = { { 'idx_ara_law_licenses_char', { 'charid', 'type', 'status' } } },
    },
    {
        name = 'ara_law_jail', pk = { 'charid' },
        columns = {
            { 'charid',           'INT NOT NULL' },
            { 'name',             NAME },
            { 'location',         "VARCHAR(32) NOT NULL DEFAULT ''" },
            { 'cell',             'TINYINT NULL DEFAULT NULL' },  -- Zelle (Zellen mit Tueren), sonst NULL
            { 'sentence_seconds', 'INT NOT NULL DEFAULT 0' },
            { 'served_seconds',   'INT NOT NULL DEFAULT 0' },
            { 'reduced_seconds',  'INT NOT NULL DEFAULT 0' },
            { 'reason',           "VARCHAR(255) NOT NULL DEFAULT ''" },
            { 'officer_charid',   INTN },
            { 'officer_name',     NAMEN },
            { 'bail',             'DECIMAL(10,2) NULL DEFAULT NULL' },
            { 'department',       'VARCHAR(32) NULL DEFAULT NULL' },  -- Behoerde des Officers (Kaution geht in deren Kasse)
            { 'has_property',     'TINYINT NOT NULL DEFAULT 0' },
            { 'jailed_at',        T },
            { 'updated_at',       T },
        },
    },
    {
        name = 'ara_law_evidence', pk = { 'id' },
        columns = {
            { 'id',                'INT UNSIGNED NOT NULL AUTO_INCREMENT' },
            { 'type',              "VARCHAR(12) NOT NULL DEFAULT 'casing'" },
            { 'weapon',            'VARCHAR(64) NULL DEFAULT NULL' },
            { 'serial',            'VARCHAR(50) NULL DEFAULT NULL' },
            { 'owner_charid',      INTN },
            { 'blood_type',        'VARCHAR(3) NULL DEFAULT NULL' },
            { 'x',                 'FLOAT NOT NULL DEFAULT 0' },
            { 'y',                 'FLOAT NOT NULL DEFAULT 0' },
            { 'z',                 'FLOAT NOT NULL DEFAULT 0' },
            { 'zone',              'VARCHAR(64) NULL DEFAULT NULL' },
            { 'created_at',        T },
            { 'collected_by',      INTN },
            { 'collected_by_name', NAMEN },
            { 'collected_at',      T },
            { 'department',        'VARCHAR(32) NULL DEFAULT NULL' },
            { 'status',            "VARCHAR(12) NOT NULL DEFAULT 'collected'" },
            { 'analysis',          'LONGTEXT NULL' },
            { 'analyzed_by_name',  NAMEN },
            { 'analyzed_at',       TN },
        },
        indexes = {
            { 'idx_ara_law_evidence_serial', { 'serial' } },
            { 'idx_ara_law_evidence_owner',  { 'owner_charid' } },
            { 'idx_ara_law_evidence_status', { 'status', 'collected_at' } },
        },
    },
    {
        name = 'ara_law_weapons', pk = { 'serial' },
        columns = {
            { 'serial',        'VARCHAR(50) NOT NULL' },
            { 'weapon',        "VARCHAR(64) NOT NULL DEFAULT ''" },
            { 'owner_charid',  INTN },
            { 'owner_name',    NAMEN },
            { 'status',        "VARCHAR(12) NOT NULL DEFAULT 'registered'" },
            { 'department',    'VARCHAR(32) NULL DEFAULT NULL' },
            { 'registered_at', T },
            { 'registered_by', INTN },
            { 'notes',         'VARCHAR(255) NULL DEFAULT NULL' },
            { 'updated_at',    T },
        },
        indexes = { { 'idx_ara_law_weapons_owner', { 'owner_charid' } } },
    },
    {
        -- Auszahlungen an Charaktere, die gerade offline sind. Werden beim
        -- naechsten Login ausgezahlt (server/core/04_money_items.lua).
        -- Direkt in `characters` zu schreiben waere unsicher: vorp haelt
        -- Geld im Speicher und wuerde den Wert beim Speichern ueberschreiben.
        name = 'ara_law_payouts', pk = { 'id' },
        columns = {
            { 'id',         'INT UNSIGNED NOT NULL AUTO_INCREMENT' },
            { 'charid',     'INT NOT NULL DEFAULT 0' },
            { 'amount',     'DECIMAL(12,2) NOT NULL DEFAULT 0' },
            { 'currency',   'TINYINT NOT NULL DEFAULT 0' },
            { 'reason',     "VARCHAR(64) NOT NULL DEFAULT ''" },
            { 'created_at', T },
        },
        indexes = { { 'idx_ara_law_payouts_char', { 'charid' } } },
    },
    {
        name = 'ara_law_escorts', pk = { 'id' },
        columns = {
            { 'id',                'INT UNSIGNED NOT NULL AUTO_INCREMENT' },
            { 'type',              "VARCHAR(16) NOT NULL DEFAULT 'cargo'" },
            { 'client_charid',     'INT NOT NULL DEFAULT 0' },
            { 'client_name',       NAME },
            { 'client_identifier', "VARCHAR(64) NOT NULL DEFAULT ''" },
            { 'recipient_charid',  INTN },
            { 'recipient_name',    NAMEN },
            { 'pickup',            "VARCHAR(32) NOT NULL DEFAULT ''" },
            { 'destination',       'VARCHAR(32) NULL DEFAULT NULL' },
            { 'duration_min',      INTN },
            { 'escorts_required',  'INT NOT NULL DEFAULT 1' },
            { 'price',             'DECIMAL(10,2) NOT NULL DEFAULT 0' },
            { 'insurance',         'TINYINT NOT NULL DEFAULT 0' },
            { 'premium',           'DECIMAL(10,2) NOT NULL DEFAULT 0' },
            { 'insured_value',     'DECIMAL(12,2) NOT NULL DEFAULT 0' },
            { 'cargo',             'LONGTEXT NULL' },
            { 'cargo_money',       'DECIMAL(12,2) NOT NULL DEFAULT 0' },
            { 'cargo_gold',        'DECIMAL(12,2) NOT NULL DEFAULT 0' },
            { 'department',        "VARCHAR(32) NOT NULL DEFAULT ''" },
            { 'leader_charid',     INTN },
            { 'leader_name',       NAMEN },
            { 'escorts',           'LONGTEXT NULL' },
            { 'status',            "VARCHAR(12) NOT NULL DEFAULT 'open'" },
            { 'status_reason',     'VARCHAR(64) NULL DEFAULT NULL' },
            { 'claim_office',      'VARCHAR(32) NULL DEFAULT NULL' },
            -- Versicherungsfall nach Ueberfall: wird NICHT automatisch gezahlt,
            -- sondern von der Behoerde geprueft (Schutz gegen Komplizen-Raub)
            { 'insurance_state',   "VARCHAR(12) NOT NULL DEFAULT 'none'" },  -- none|pending|paid|denied|expired
            { 'insurance_amount',  'DECIMAL(12,2) NOT NULL DEFAULT 0' },
            { 'insurance_by',      NAMEN },
            { 'insurance_at',      TN },
            { 'robbed_by',         INTN },
            { 'robbed_by_identifier', 'VARCHAR(64) NULL DEFAULT NULL' },
            { 'created_at',        T },
            { 'accepted_at',       TN },
            { 'started_at',        TN },
            { 'finished_at',       TN },
            { 'deadline_at',       TN },
            { 'claimed_at',        TN },
        },
        indexes = {
            { 'idx_ara_law_escorts_status',    { 'status' } },
            { 'idx_ara_law_escorts_client',    { 'client_charid' } },
            { 'idx_ara_law_escorts_recipient', { 'recipient_charid' } },
        },
    },
}

local function createSql(tbl)
    local parts = {}
    for _, col in ipairs(tbl.columns) do
        parts[#parts + 1] = ('`%s` %s'):format(col[1], col[2])
    end
    local pk = {}
    for _, c in ipairs(tbl.pk) do pk[#pk + 1] = ('`%s`'):format(c) end
    parts[#parts + 1] = ('PRIMARY KEY (%s)'):format(table.concat(pk, ', '))
    return ('CREATE TABLE IF NOT EXISTS `%s` (\n  %s\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'):format(tbl.name, table.concat(parts, ',\n  '))
end

local function existingColumns(tableName)
    local rows = MySQL.query.await(
        'SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?',
        { tableName }) or {}
    local set = {}
    for _, r in ipairs(rows) do set[r.COLUMN_NAME] = true end
    return set
end

local function existingIndexes(tableName)
    local rows = MySQL.query.await(
        'SELECT DISTINCT INDEX_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?',
        { tableName }) or {}
    local set = {}
    for _, r in ipairs(rows) do set[r.INDEX_NAME] = true end
    return set
end

--- Wird von server/zz_boot.lua genau einmal aufgerufen (im Thread).
function Law.DB.Init()
    for _, tbl in ipairs(SCHEMA) do
        MySQL.query.await(createSql(tbl))

        local have = existingColumns(tbl.name)
        for _, col in ipairs(tbl.columns) do
            if not have[col[1]] then
                -- AUTO_INCREMENT-Spalten sind immer Teil des CREATE, nie nachtraeglich
                local def = col[2]:gsub(' AUTO_INCREMENT', '')
                MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(tbl.name, col[1], def))
                Law.Warn('DB: Spalte %s.%s ergaenzt', tbl.name, col[1])
            end
        end

        if tbl.indexes then
            local idx = existingIndexes(tbl.name)
            for _, ix in ipairs(tbl.indexes) do
                if not idx[ix[1]] then
                    local cols = {}
                    for _, c in ipairs(ix[2]) do cols[#cols + 1] = ('`%s`'):format(c) end
                    MySQL.query.await(('CREATE INDEX `%s` ON `%s` (%s)'):format(ix[1], tbl.name, table.concat(cols, ', ')))
                end
            end
        end
    end

    -- Kassen je Behoerde (nur beim ersten Mal mit Startguthaben)
    for dept in pairs(Config.Departments) do
        MySQL.insert.await('INSERT IGNORE INTO ara_law_society (department, balance, updated_at) VALUES (?, ?, ?)',
            { dept, Config.Society.StartBalance or 0, Law.Now() })
    end

    ready = true
    for _, fn in ipairs(readyWaiters) do
        local ok, err = xpcall(fn, debug.traceback)
        if not ok then Law.Warn('DB.OnReady: %s', tostring(err)) end
    end
    readyWaiters = {}
    Law.Log('Datenbank bereit')
end

function Law.DB.Ready()
    return ready
end

function Law.DB.OnReady(fn)
    if ready then
        CreateThread(fn)
    else
        readyWaiters[#readyWaiters + 1] = fn
    end
end

--- DB-Aufruf, der bei SQL-Fehler NICHT wirft (oxmysql-.await wirft sonst
--- und eine Rueckbuchung danach wuerde nie erreicht).
--- local ok, affected = Law.DB.Try(MySQL.update.await, sql, params)
function Law.DB.Try(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then
        Law.Warn('DB-Fehler: %s', tostring(res))
        return false, nil
    end
    return true, res
end

--- JSON sicher dekodieren
function Law.DB.Decode(text, fallback)
    if type(text) ~= 'string' or text == '' then return fallback end
    local ok, out = pcall(json.decode, text)
    if ok and out ~= nil then return out end
    return fallback
end

--- LIKE-Suchtext escapen (% und _ und \)
function Law.DB.Like(text)
    return (text:gsub('\\', '\\\\'):gsub('%%', '\\%%'):gsub('_', '\\_'))
end
