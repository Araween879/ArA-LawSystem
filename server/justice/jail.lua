--[[
    ArA-LawSystem - Knast (Server, Agent A)

    Vertrag 4.1:  Law.Jail.IsJailed(charId) -> bool
                  Law.Jail.Sentence(targetSrc, minutes, reason, officerCtx?, opts?) -> bool, errCode
                  opts = { location?, bail?, warrantIds?, codes?, noConfiscate?, dept? (Zusatz) }
    Einbuchen:    jail:sentence(targetSrc, codes, extraMinutes, bail, note, location?)
    Dienstbuch:   jail:list() · jail:release(charId) · jail:adjust(charId, minutesDelta) · jail:setBail(charId, amount)
    Schalter:     jail:bailList() · jail:payBail(charId) · jail:propertyStatus() · jail:claimProperty()
    Haeftling:    jail:workStart(index) · jail:workFinish() · jail:myStatus()   (Zusatz)

    Wahrheit ist die Tabelle ara_law_jail (+ Spiegel im Speicher fuer Online-
    Haeftlinge). Die Zeit laeuft serverseitig (Tick), Flucht wird
    serverseitig ueber die Position erkannt.

    has_property: 0 = nichts beschlagnahmt, 1 = Fach belegt,
                  2 = offline verurteilt, Beschlagnahme beim naechsten Login.
]]

Law.Justice = Law.Justice or {}
Law.Jail    = Law.Jail or {}

local inmates = {}  -- [src] = { charId, name, location, department, sentence, served, reduced, graceUntil, work, lastWorkAt }

--------------------------------------------------------------------------
-- Helfer
--------------------------------------------------------------------------
local function locationCfg(key)
    local l = key and Config.Jail.Locations[key]
    if l and l.enabled ~= false then return l end
    return nil
end

local function isPrison(l) return l ~= nil and l.mode ~= 'cells' end

--- Standard-Haftort (Gefaengnis mit Teleport). Zellen mit Tueren nie: dort
--- wird nur an der Zellentuer eingebucht (jail:sentenceCell).
local function defaultLocationKey()
    if isPrison(locationCfg(Config.Jail.DefaultLocation)) then return Config.Jail.DefaultLocation end
    for k, l in pairs(Config.Jail.Locations) do
        if l.enabled ~= false and isPrison(l) then return k end
    end
    return nil
end

local function locationLabel(key)
    local l = key and Config.Jail.Locations[key]
    return l and l.label or tostring(key)
end

local function v4(v)
    return { x = v.x, y = v.y, z = v.z, w = v.w or 0.0 }
end

--- Zelle eines Haeftlings (nur Zellen-Modus) -> cell | nil
local function cellOf(i)
    local loc = i and locationCfg(i.location)
    return loc and loc.mode == 'cells' and i.cell and (loc.cells or {})[i.cell] or nil
end

--- Bereich, in dem der Haeftling bleiben muss -> center, radius, spawn (vector4), maxDz|nil
local function zoneOf(i)
    local cell = cellOf(i)
    if cell then
        return cell.center, cell.radius, vector4(cell.center.x, cell.center.y, cell.center.z, cell.heading or 0.0), 3.0
    end
    local loc = locationCfg(i and i.location)
    if not loc then return nil end
    return loc.center, loc.radius, loc.spawn, nil
end

local function dist2D(a, b)
    a, b = Law.Vec(a), Law.Vec(b)
    if not a or not b then return math.huge end
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function remaining(i)
    return math.max(0, i.sentence - i.served - i.reduced)
end

local function workCap(i)
    return math.floor(i.sentence * (Config.Jail.Work.MaxReducePercent or 50) / 100)
end

local function hudData(i)
    local per = math.max(1, Config.Jail.Work.ReduceSeconds or 30)
    return {
        remaining = remaining(i), total = i.sentence, reduced = i.reduced,
        work = { done = math.floor(i.reduced / per), max = math.floor(workCap(i) / per) },
    }
end

--- Nur wirklich verbundene Haeftlinge zaehlen (M7). Veraltete Eintraege
--- (Spieler weg, Hook noch nicht gelaufen) werden dabei entfernt.
local function inmateSrc(charId)
    charId = tonumber(charId)
    for src, i in pairs(inmates) do
        if i.charId == charId then
            if GetPlayerPing(src) > 0 then return src end
            inmates[src] = nil
        end
    end
    return nil
end

local function enterPayload(i, teleport)
    local loc = locationCfg(i.location)
    if not loc then return nil end
    local work = {}
    for idx, w in ipairs(loc.work or {}) do
        work[#work + 1] = { index = idx, coords = Law.VecToTable(w.coords), label = w.label, scenario = w.scenario }
    end
    local center, radius, spawn = zoneOf(i)
    local cell = cellOf(i)
    return {
        location = i.location, label = cell and (cell.label .. ' - ' .. loc.label) or loc.label,
        center = Law.VecToTable(center), radius = radius,
        spawn = v4(spawn), work = work, workSeconds = Config.Jail.Work.Seconds, workDistance = Config.Jail.Work.Distance,
        hud = hudData(i), teleport = teleport == true,
    }
end

local function graceSeconds()
    return Config.Jail.EscapeGraceSeconds or 30
end

--- Online-Haeftling im Speicher anlegen. silent = Client-Event spaeter selbst schicken.
--- Nur fuer verbundene Spieler (M7) -> sonst nil.
local function setupInmate(src, row, teleport, silent)
    if not src or GetPlayerPing(src) <= 0 then return nil end
    local key = locationCfg(row.location) and row.location or defaultLocationKey()
    local loc = locationCfg(key)
    local cell = tonumber(row.cell)
    if not (loc and loc.mode == 'cells' and cell and (loc.cells or {})[cell]) then
        cell = nil
        -- Zellen-Ort ohne gueltige Zelle (Config geaendert) -> Standard-Gefaengnis
        if loc and loc.mode == 'cells' then key = defaultLocationKey() end
    end
    local i = {
        cell       = cell,
        charId     = tonumber(row.charid),
        name       = row.name,
        location   = key,
        department = row.department,
        sentence   = tonumber(row.sentence_seconds) or 0,
        served     = tonumber(row.served_seconds) or 0,
        reduced    = tonumber(row.reduced_seconds) or 0,
        graceUntil = Law.Now() + graceSeconds(),
        lastWorkAt = 0,
        deathReturns = 0,  -- "tot -> zurueck" in Folge (H1)
    }
    inmates[src] = i
    Law.State.jailed[src] = i.charId
    Player(src).state:set('law_jailed', true, true)
    if not silent then
        local payload = enterPayload(i, teleport)
        if payload then TriggerClientEvent('ara_law:cl:jail:enter', src, payload) end
    end
    return i
end

--- Online-Zustand eines Charakters loesen (DB wurde schon geaendert)
local function clearOnline(charId, sendRelease, escaped)
    local src = inmateSrc(charId)
    if not src then return nil end
    local i = inmates[src]
    inmates[src] = nil
    Law.State.jailed[src] = nil
    if GetPlayerPing(src) > 0 then
        Player(src).state:set('law_jailed', nil, true)
        local loc = locationCfg(i and i.location) or locationCfg(defaultLocationKey())
        TriggerClientEvent('ara_law:cl:jail:leave', src, {
            release = (sendRelease and loc) and v4(loc.release) or nil,
            escaped = escaped == true,
        })
    end
    return src
end

local function finishRelease(charId, reason, actorCtx)
    local src = clearOnline(charId, true, false)
    if src and GetPlayerPing(src) > 0 then Law.Notify(src, L('jail_released_you'), 'success', 8000) end
    Law.Records.Add(charId, 'release', L('record_release_' .. reason), nil, actorCtx)
    Law.Audit(actorCtx, 'jail.release', charId, { reason = reason })
end

--- Freilassen (Strafe verbuesst, Freigabe, Zeit geaendert). -> bool
local function releaseInmate(charId, reason, actorCtx)
    local okD, affected = Law.DB.Try(MySQL.update.await, 'DELETE FROM ara_law_jail WHERE charid = ?', { charId })
    if not okD then return false end  -- DB-Fehler: Zustand unveraendert lassen
    if affected ~= 1 then
        clearOnline(charId, true, false)  -- Speicher war veraltet
        return false
    end
    finishRelease(charId, reason, actorCtx)
    return true
end

--------------------------------------------------------------------------
-- Habseligkeiten (vorp-Custom-Inventar je Charakter)
--------------------------------------------------------------------------
local registeredProperty = {}  -- [invId] = true

local function propertyId(charId)
    return 'ara_law_property_' .. tostring(charId)
end

local function ensureProperty(charId)
    local id = propertyId(charId)
    if not Law.Inv:isCustomInventoryRegistered(id) then
        Law.Inv:registerInventory({
            id = id,
            name = L('jail_property_inv_name'),
            limit = Config.Jail.Confiscate.Limit or 200,
            acceptWeapons = true,
            shared = true,             -- Inventar gehoert ohnehin nur einem Charakter
            ignoreItemStackLimit = true,
            whitelistItems = false,
            UsePermissions = true,
            UseBlackList = false,
            whitelistWeapons = false,
        })
        -- Nur der Besitzer darf entnehmen (Vertrag A4).
        Law.Inv:AddCharIdPermissionTakeFromCustom(id, charId, true)
        -- In dieser vorp_inventory-Version ist der Export oben wirkungslos
        -- (invertierte canContinue-Pruefung) -> Rechte zusaetzlich direkt
        -- setzen. MoveTo auf einen nicht existierenden Job = niemand legt
        -- etwas hinein (sonst waere das Fach ein Gratis-Lager).
        Law.Inv:updateCustomInventoryData(id, {
            CharIdPermissionTakeFrom = { [tonumber(charId)] = true },
            PermissionMoveTo = { ara_law_nobody = 99 },
        })
    end
    registeredProperty[id] = true
    return id
end

local function hasProperty(charId)
    local id = propertyId(charId)
    local ok, n = pcall(function()
        return MySQL.scalar.await(
            'SELECT (SELECT COUNT(*) FROM character_inventories WHERE inventory_type = ?) + (SELECT COUNT(*) FROM loadout WHERE curr_inv = ?)',
            { id, id })
    end)
    return ok and (tonumber(n) or 0) > 0
end

--- Waffen und verbotene Items ins Fach. Waffen behalten ihre Seriennummer:
--- addWeaponsToCustomInventory liest `serial_number` (im vorp-Code geprueft,
--- types.lua nennt faelschlich custom_serial) -> neue loadout-Zeile mit
--- gleicher Nummer.
--- Reihenfolge (Dupe-Schutz, H2): ERST beim Spieler entfernen (nur bei
--- Erfolg weiter), DANN einlagern; scheitert das Einlagern, bekommt der
--- Spieler die Waffe mit gleicher Seriennummer zurueck (createWeapon).
--- Items genauso: erst abziehen, dann einlagern, bei Fehler zurueckgeben.
local function confiscate(src, charId)
    local cfg = Config.Jail.Confiscate
    local inv = ensureProperty(charId)
    local moved = 0

    if cfg.Weapons then
        local keep = {}
        for _, n in ipairs(cfg.KeepWeapons or {}) do keep[n:upper()] = true end
        local weapons = Law.Inv:getUserInventoryWeapons(src) or {}
        for _, w in ipairs(weapons) do
            local name = w.name and tostring(w.name):upper()
            if name and not keep[name] then
                local comps
                pcall(function() comps = Law.Inv:getWeaponComponents(src, w.id) end)
                comps = type(comps) == 'table' and comps or nil
                if Law.Inv:deleteWeapon(src, w.id) == true then
                    local okAdd, added = pcall(function()
                        return Law.Inv:addWeaponsToCustomInventory(inv, { {
                            name = w.name,
                            serial_number = w.serial_number,
                            custom_serial = w.serial_number,
                            custom_label = w.custom_label,
                            custom_desc = w.custom_desc,
                            components = comps,
                        } }, charId)
                    end)
                    if okAdd and added then
                        moved = moved + 1
                    else
                        -- zurueck an den Spieler, gleiche Seriennummer
                        pcall(function()
                            Law.Inv:createWeapon(src, w.name, nil, nil, comps or {}, nil, nil, w.serial_number, w.custom_label, w.custom_desc)
                        end)
                        Law.Warn('Beschlagnahme: Waffe %s (%s) nicht eingelagert - zurueckgegeben', tostring(w.name), tostring(w.serial_number))
                    end
                else
                    Law.Warn('Beschlagnahme: Waffe %s (%s) konnte nicht entfernt werden', tostring(w.name), tostring(w.serial_number))
                end
            end
        end
    end

    local wanted = {}
    for _, n in ipairs(cfg.Items or {}) do wanted[n] = true end
    local items = Law.Inv:getUserInventoryItems(src) or {}
    for _, it in ipairs(items) do
        local count = tonumber(it.count) or 0
        if wanted[it.name] and count > 0 then
            if Law.Items.TakeById(src, it.id, count) then
                local meta = type(it.metadata) == 'table' and it.metadata or {}
                local okAdd, ok = pcall(function()
                    return Law.Inv:addItemsToCustomInventory(inv, { { name = it.name, amount = count, metadata = meta } }, charId)
                end)
                if okAdd and ok then
                    moved = moved + 1
                else
                    Law.Items.Give(src, it.name, count, meta)
                    Law.Warn('Beschlagnahme: %s x%d konnte nicht eingelagert werden', tostring(it.name), count)
                end
            end
        end
    end
    return moved > 0
end

--------------------------------------------------------------------------
-- Datenform (Vertrag 10.6 Inmate)
--------------------------------------------------------------------------
local function inmatePublic(row, i)
    local sentence = i and i.sentence or tonumber(row.sentence_seconds) or 0
    local served   = i and i.served or tonumber(row.served_seconds) or 0
    local reduced  = i and i.reduced or tonumber(row.reduced_seconds) or 0
    return {
        charId        = tonumber(row.charid),
        name          = row.name,
        location      = row.location,
        locationLabel = locationLabel(row.location),
        sentence      = sentence,
        served        = served,
        reduced       = reduced,
        remaining     = math.max(0, sentence - served - reduced),
        reason        = row.reason,
        officerName   = row.officer_name,
        bail          = tonumber(row.bail),
        deptLabel     = Law.Justice.DeptLabel(row.department),
        online        = i ~= nil,
        jailedAt      = tonumber(row.jailed_at),
        hasProperty   = tonumber(row.has_property) == 1,
    }
end

--- Namen der Haeftlinge, die (online) in dieser Zelle sitzen
function Law.Justice.InmatesInCell(locationKey, cellIdx)
    local out = {}
    for src, i in pairs(inmates) do
        if i.location == locationKey and i.cell == cellIdx and GetPlayerPing(src) > 0 then out[#out + 1] = i.name or '?' end
    end
    return out
end

function Law.Justice.InmateByCharId(charId)
    local row = MySQL.single.await('SELECT * FROM ara_law_jail WHERE charid = ?', { charId })
    if not row then return nil end
    local src = inmateSrc(charId)
    return inmatePublic(row, src and inmates[src] or nil)
end

--------------------------------------------------------------------------
-- Vertrag 4.1
--------------------------------------------------------------------------
function Law.Jail.IsJailed(charId)
    charId = tonumber(charId)
    if not charId then return false end
    if inmateSrc(charId) then return true end
    return MySQL.scalar.await('SELECT 1 FROM ara_law_jail WHERE charid = ? LIMIT 1', { charId }) ~= nil
end

local sentencing = {}  -- [charId] = true, solange Law.Jail.Sentence laeuft

--- Laeuft gerade eine Einbuchung? (arrest.lua: kein Combat-Log zusaetzlich)
function Law.Justice.IsSentencing(charId)
    return sentencing[tonumber(charId)] == true
end

--- Eigentliche Einbuchung. Reihenfolge (M7): DB-Zeile mit has_property = 2
--- zuerst -> ab da ist die Haft gesichert. Faellt der Spieler waehrend eines
--- DB-Wartens weg, endet die Funktion mit true und der naechste Login holt
--- Beschlagnahme, Probe, Haftbefehle und Kopfgelder nach (handleLogin).
local function doSentence(targetSrc, tctx, minutes, reason, officerCtx, opts)
    local function gone() return GetPlayerPing(targetSrc) <= 0 end

    local key = (opts.location and locationCfg(opts.location)) and opts.location or defaultLocationKey()
    local loc = locationCfg(key)
    -- Zellen mit Tueren nur mit einer gueltigen Zelle (Einbuchen an der Zellentuer).
    -- Sonst (z.B. Kopfgeld-Abgabe an dieser Station) -> Standard-Gefaengnis.
    local cell = nil
    if loc and loc.mode == 'cells' then
        cell = tonumber(opts.cell)
        if not (cell and (loc.cells or {})[cell]) then
            cell = nil
            key = defaultLocationKey()
            loc = locationCfg(key)
        end
    end
    if not loc then return false, 'no_location' end
    local oc = type(officerCtx) == 'table' and officerCtx or nil
    local dept = (oc and oc.dept) or ((opts.dept and Law.GetDept(opts.dept)) and opts.dept or nil)
    local bail = opts.bail ~= nil and Law.ToMoney(opts.bail, 0, Config.Jail.Bail.MaxAmount) or nil
    if bail and bail <= 0 then bail = nil end
    reason = Law.ToStr(reason, 255) or L('jail_reason_default')
    local now = Law.Now()
    local seconds = minutes * 60

    -- 1. DB-Zeile zuerst (has_property = 2 = Nacharbeiten ausstehend)
    local okI, affected = Law.DB.Try(MySQL.update.await,
        'INSERT INTO ara_law_jail (charid, name, location, cell, sentence_seconds, served_seconds, reduced_seconds, reason, officer_charid, officer_name, bail, department, has_property, jailed_at, updated_at) VALUES (?, ?, ?, ?, ?, 0, 0, ?, ?, ?, ?, ?, 2, ?, ?)',
        { tctx.charId, tctx.name, key, cell, seconds, reason, oc and oc.charId or nil, oc and oc.name or nil, bail, dept, now, now })
    if not okI or (affected or 0) < 1 then return false, 'failed' end
    if gone() then return true end

    -- 2. Beschlagnahme - Handschellen bleiben dabei noch dran (H2).
    --    Fehler in vorp-Exports duerfen die schon gebuchte Haft nicht abbrechen.
    local property = false
    if not opts.noConfiscate then
        local okC, res = pcall(confiscate, targetSrc, tctx.charId)
        if not okC then Law.Warn('Beschlagnahme fehlgeschlagen fuer #%s: %s', tostring(tctx.charId), tostring(res)) end
        property = okC and res == true
    end

    -- 3. Jetzt erst Fesseln/Abfuehren loesen, Dienst beenden
    Law.Justice.ReleaseCuffs(targetSrc, 'jail', nil)
    if Law.Duty.active[targetSrc] then Law.Duty.Set(targetSrc, false, 'jailed') end
    if gone() then return true end

    -- 4. Probe in die Akte, Haftbefehle erledigt, Kopfgelder geschlossen (mit Erstattung)
    Law.Citizens.SetSample(tctx.charId, true)
    if gone() then return true end
    local served = Law.Justice.ServeWarrants(tctx.charId)
    if gone() then return true end
    local closed = Law.Justice.CloseBountiesForTarget(tctx.charId, 'cancelled', oc)
    if gone() then return true end

    -- 5. Nacharbeiten erledigt -> endgueltiger Fach-Status, Akte + Protokoll
    Law.DB.Try(MySQL.update.await, 'UPDATE ara_law_jail SET has_property = ? WHERE charid = ?',
        { (property or hasProperty(tctx.charId)) and 1 or 0, tctx.charId })
    local details = reason
    if bail then details = details .. '\n' .. L('record_jail_bail', bail) end
    local placeLabel = cell and (loc.cells[cell].label .. ' - ' .. loc.label) or loc.label
    Law.Records.Add(tctx.charId, 'jail', L('record_jail', minutes, placeLabel), details, oc)
    Law.Audit(oc, 'jail.sentence', tctx.charId, {
        minutes = minutes, location = key, cell = cell, bail = bail, warrants = #served, bounties = closed, property = property,
    })
    if gone() then return true end

    -- 6. Zustand (online). Zelle: KEIN Teleport - der Haeftling steht schon drin.
    setupInmate(targetSrc, {
        charid = tctx.charId, name = tctx.name, location = key, cell = cell, department = dept,
        sentence_seconds = seconds, served_seconds = 0, reduced_seconds = 0,
    }, cell == nil or opts.teleportIn == true, false)
    Law.Notify(targetSrc, L('jail_sentenced_you', minutes, placeLabel), 'objective', 10000)
    if property then Law.Notify(targetSrc, L('jail_property_taken'), 'info', 8000) end
    return true
end

--- Kopfgeld-Abgabe durch einen Kopfgeldjaeger: freie Zelle der Station waehlen,
--- Tuer abschliessen und den Gefangenen HINEIN teleportieren (Gesetz sperrt
--- dagegen selbst an der Zellentuer ein). Nur Zellen mit gemessener Mitte und
--- freiem Platz (capacity), die leerste zuerst.
--- -> ok, err   (false, 'no_cell' = keine passende Zelle -> Aufrufer nimmt das Gefaengnis)
function Law.Jail.SentenceToCell(targetSrc, stationKey, minutes, reason, officerCtx, opts)
    local loc = locationCfg(stationKey)
    if not loc or loc.mode ~= 'cells' then return false, 'no_location' end
    local best, bestN
    for idx, c in ipairs(loc.cells or {}) do
        if not c.fallback then
            local n = #Law.Justice.InmatesInCell(stationKey, idx)
            if n < (c.capacity or 1) and (not bestN or n < bestN) then best, bestN = idx, n end
        end
    end
    if not best then return false, 'no_cell' end
    local o = Law.Copy(type(opts) == 'table' and opts or {})
    o.location, o.cell, o.teleportIn = stationKey, best, true
    Law.Doors.SetLocked(loc.cells[best].door, true, officerCtx, 'bounty')
    return Law.Jail.Sentence(targetSrc, minutes, reason, officerCtx, o)
end

function Law.Jail.Sentence(targetSrc, minutes, reason, officerCtx, opts)
    opts = type(opts) == 'table' and opts or {}
    targetSrc = tonumber(targetSrc)
    local tctx = targetSrc and Law.Ctx(targetSrc)
    if not tctx then return false, 'no_target' end
    minutes = Law.ToInt(minutes, 1)
    if not minutes then return false, 'invalid' end
    minutes = math.min(minutes, Config.Jail.MaxMinutes or 240)
    if inmates[targetSrc] or Law.State.jailed[targetSrc] or sentencing[tctx.charId] then return false, 'already_jailed' end
    sentencing[tctx.charId] = true

    local okQ, exists = Law.DB.Try(MySQL.scalar.await, 'SELECT 1 FROM ara_law_jail WHERE charid = ? LIMIT 1', { tctx.charId })
    if not okQ then sentencing[tctx.charId] = nil return false, 'failed' end
    if exists then sentencing[tctx.charId] = nil return false, 'already_jailed' end
    if GetPlayerPing(targetSrc) <= 0 then sentencing[tctx.charId] = nil return false, 'no_target' end

    local ok, res, err = pcall(doSentence, targetSrc, tctx, minutes, reason, officerCtx, opts)
    sentencing[tctx.charId] = nil
    if not ok then
        Law.Warn('Law.Jail.Sentence #%s: %s', tostring(tctx.charId), tostring(res))
        return false, 'failed'
    end
    return res, err
end

--- Offline-Haft (Combat-Log). Beschlagnahme folgt beim naechsten Login.
--- Gibt es schon eine Haftzeile (z.B. Einbuchung lief gerade), kommt KEINE
--- Zusatzstrafe dazu (M7).
function Law.Justice.SentenceOffline(charId, minutes, reason, officerCtx, name)
    charId = tonumber(charId)
    local key = defaultLocationKey()
    if not charId or not key then return false end
    if sentencing[charId] then return false end
    minutes = math.min(Law.ToInt(minutes, 1) or 1, Config.Jail.MaxMinutes or 240)
    local oc = type(officerCtx) == 'table' and officerCtx or nil
    local now, seconds = Law.Now(), minutes * 60
    reason = Law.ToStr(reason, 255) or L('jail_reason_default')
    local okI, affected = Law.DB.Try(MySQL.update.await,
        'INSERT INTO ara_law_jail (charid, name, location, sentence_seconds, served_seconds, reduced_seconds, reason, officer_charid, officer_name, bail, department, has_property, jailed_at, updated_at) VALUES (?, ?, ?, ?, 0, 0, ?, ?, ?, NULL, ?, 2, ?, ?) ON DUPLICATE KEY UPDATE charid = charid',
        { charId, name or Law.GetCharName(charId), key, seconds, reason, oc and oc.charId or nil, oc and oc.name or nil,
          oc and oc.dept or nil, now, now })
    if not okI or affected ~= 1 then return false end
    Law.Records.Add(charId, 'jail', L('record_jail_offline', minutes), reason, oc)
    Law.Audit(oc, 'jail.offline', charId, { minutes = minutes, reason = reason })
    return true
end

--------------------------------------------------------------------------
-- Einbuchen am jail-Punkt
--------------------------------------------------------------------------
--- Formular auswerten (Pult und Zellentuer gleich) -> minutes, bail, reason, calc | nil, err
local function parseSentence(codes, extraMinutes, bail, note)
    local calc = Law.Justice.ComputeCodes(codes)
    if not calc then return nil, 'invalid_codes' end
    local extra = 0
    if extraMinutes ~= nil and extraMinutes ~= '' then
        extra = Law.ToInt(extraMinutes, 0, Config.Jail.MaxExtraMinutes)
        if not extra then return nil, 'invalid_minutes' end
    end
    local minutes = math.min(calc.jail + extra, Config.Jail.MaxMinutes)
    if minutes < 1 then return nil, 'minutes_zero' end
    local bailAmount
    if bail ~= nil and bail ~= '' then
        bailAmount = Law.ToMoney(bail, 0, Config.Jail.Bail.MaxAmount)
        if not bailAmount then return nil, 'invalid_amount' end
    end
    note = Law.ToStr(note, 120, true) or ''
    local reason = note ~= '' and (calc.text .. ' - ' .. note) or calc.text
    return { minutes = minutes, bail = bailAmount, reason = reason, calc = calc }
end

Law.Cb.Register('jail:sentence', { perm = 'jail', rate = 2000, notCuffed = true, alive = true }, function(src, ctx, targetSrc, codes, extraMinutes, bail, note, location)
    local stationKey = Law.Stations.NearPoint(src, 'jail', 3.0)
    if not stationKey or not Law.Stations.AllowsDept(stationKey, ctx.dept) then return Law.Result(false, 'not_at_point') end
    targetSrc = Law.ToInt(targetSrc, 1)
    if not targetSrc or targetSrc == src then return Law.Result(false, 'invalid') end
    local tctx = Law.Ctx(targetSrc)
    if not tctx then return Law.Result(false, 'no_target') end
    if not Law.State.cuffed[targetSrc] then return Law.Result(false, 'target_not_cuffed') end
    if not Law.IsNear(src, targetSrc, Config.Jail.SentenceDistance or 5.0) then return Law.Result(false, 'too_far') end

    local f, ferr = parseSentence(codes, extraMinutes, bail, note)
    if not f then return Law.Result(false, ferr) end

    -- Am Pult nur Gefaengnisse mit Transport (Zellen werden an der Zellentuer eingebucht)
    local loc = Law.ToStr(location, 32, true)
    if not loc or not isPrison(locationCfg(loc)) then
        loc = Config.Jail.StationLocation[stationKey] or Config.Jail.DefaultLocation
    end

    local ok, err = Law.Jail.Sentence(targetSrc, f.minutes, f.reason, ctx, { location = loc, bail = f.bail, codes = f.calc.list })
    if not ok then return Law.Result(false, err or 'failed') end
    return Law.Result(true, { minutes = f.minutes, location = loc }, L('jail_sentenced', tctx.name, f.minutes))
end)

--------------------------------------------------------------------------
-- Einbuchen an der Zellentuer (Zellen-Modus, kein Teleport hinein)
-- Bedingungen: Tuer abgeschlossen, Person steht IN der Zelle, Officer an der Tuer.
--------------------------------------------------------------------------
Law.Cb.Register('jail:sentenceCell', { perm = 'jail', rate = 2000, notCuffed = true, notJailed = true, alive = true }, function(src, ctx, doorHash, targetSrc, codes, extraMinutes, bail, note)
    local door = Law.Doors.Get(Law.ToInt(doorHash, 0) or 0)
    if not door or not door.cell then return Law.Result(false, 'door_unknown') end
    if not Law.Stations.AllowsDept(door.station, ctx.dept) then return Law.Result(false, 'no_permission') end
    local loc = locationCfg(door.station)
    local cell = loc and loc.mode == 'cells' and (loc.cells or {})[door.cell]
    if not cell then return Law.Result(false, 'no_location') end

    local me = Law.GetCoords(src)
    local reach = ((Config.Jail.Cells and Config.Jail.Cells.DoorReach) or 2.0) + 1.5
    if not me or dist2D(me, door.coords) > reach or math.abs(me.z - door.coords.z) > 3.0 then return Law.Result(false, 'too_far') end
    if not Law.Doors.IsLocked(door.hash) then return Law.Result(false, 'cell_door_open') end
    if #Law.Justice.InmatesInCell(door.station, door.cell) >= (cell.capacity or 1) then
        return Law.Result(false, 'cell_full')
    end

    targetSrc = Law.ToInt(targetSrc, 1)
    if not targetSrc or targetSrc == src then return Law.Result(false, 'invalid') end
    local tctx = Law.Ctx(targetSrc)
    if not tctx then return Law.Result(false, 'no_target') end
    local tc = Law.GetCoords(targetSrc)
    if not tc or dist2D(tc, cell.center) > cell.radius + 0.3 or math.abs(tc.z - cell.center.z) > 3.0 then
        return Law.Result(false, 'cell_target_outside')
    end

    local f, ferr = parseSentence(codes, extraMinutes, bail, note)
    if not f then return Law.Result(false, ferr) end

    local ok, err = Law.Jail.Sentence(targetSrc, f.minutes, f.reason, ctx,
        { location = door.station, cell = door.cell, bail = f.bail, codes = f.calc.list })
    if not ok then return Law.Result(false, err or 'failed') end
    return Law.Result(true, { minutes = f.minutes, location = door.station, cell = door.cell },
        L('jail_sentenced_cell', tctx.name, f.minutes, cell.label))
end)

--------------------------------------------------------------------------
-- Dienstbuch
--------------------------------------------------------------------------
Law.Cb.Register('jail:list', { perm = 'records_view', duty = false, rate = 800 }, function(src, ctx)
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM ara_law_jail ORDER BY jailed_at DESC LIMIT 100') or {}) do
        local s = inmateSrc(r.charid)
        out[#out + 1] = inmatePublic(r, s and inmates[s] or nil)
    end
    return Law.Result(true, out)
end)

Law.Cb.Register('jail:release', { perm = 'jail_release', rate = 1000 }, function(src, ctx, charId)
    charId = Law.ToInt(charId, 1)
    if not charId then return Law.Result(false, 'invalid') end
    -- sich selbst / den Zweitchar freilassen: nein (M2)
    if Law.IsSelfOrAlt(ctx, charId) then return Law.Result(false, 'self_target') end
    if not releaseInmate(charId, 'manual', ctx) then return Law.Result(false, 'not_jailed') end
    return Law.Result(true, { charId = charId }, L('jail_release_ok'))
end)

Law.Cb.Register('jail:adjust', { perm = 'jail_release', rate = 1000 }, function(src, ctx, charId, minutesDelta)
    charId = Law.ToInt(charId, 1)
    local maxMin = Config.Jail.MaxMinutes or 240
    local delta = Law.ToInt(minutesDelta, -maxMin, maxMin)
    if not charId or not delta or delta == 0 then return Law.Result(false, 'invalid') end
    if Law.IsSelfOrAlt(ctx, charId) then return Law.Result(false, 'self_target') end
    local row = MySQL.single.await('SELECT * FROM ara_law_jail WHERE charid = ?', { charId })
    if not row then return Law.Result(false, 'not_jailed') end
    local s = inmateSrc(charId)
    local i = s and inmates[s] or nil
    local sentence = (i and i.sentence or tonumber(row.sentence_seconds) or 0) + delta * 60
    sentence = math.min(sentence, maxMin * 60)
    local done = (i and i.served or tonumber(row.served_seconds) or 0) + (i and i.reduced or tonumber(row.reduced_seconds) or 0)

    Law.Audit(ctx, 'jail.adjust', charId, { delta = delta })
    if sentence <= done then
        releaseInmate(charId, 'adjusted', ctx)
        return Law.Result(true, { charId = charId, released = true }, L('jail_adjust_released'))
    end
    local affected = MySQL.update.await('UPDATE ara_law_jail SET sentence_seconds = ?, updated_at = ? WHERE charid = ?', { sentence, Law.Now(), charId })
    if affected ~= 1 then return Law.Result(false, 'not_jailed') end
    if i then
        i.sentence = sentence
        TriggerClientEvent('ara_law:cl:jail:hud', s, hudData(i))
        Law.Notify(s, L('jail_adjusted_you', delta), 'info')
    end
    Law.Records.Add(charId, 'jail', L('record_jail_adjust', delta), nil, ctx)
    return Law.Result(true, { charId = charId, sentence = sentence }, L('jail_adjust_ok', delta))
end)

Law.Cb.Register('jail:setBail', { perm = 'jail_release', rate = 1000 }, function(src, ctx, charId, amount)
    charId = Law.ToInt(charId, 1)
    amount = Law.ToMoney(amount, 0, Config.Jail.Bail.MaxAmount)
    if not charId or not amount then return Law.Result(false, 'invalid') end
    if Law.IsSelfOrAlt(ctx, charId) then return Law.Result(false, 'self_target') end
    local affected
    if amount <= 0 then
        affected = MySQL.update.await('UPDATE ara_law_jail SET bail = NULL WHERE charid = ?', { charId })
    else
        -- Kasse fuer die Kaution: Behoerde der Einbuchung, sonst die des Setzenden
        affected = MySQL.update.await('UPDATE ara_law_jail SET bail = ?, department = COALESCE(department, ?) WHERE charid = ?', { amount, ctx.dept, charId })
    end
    if affected ~= 1 then return Law.Result(false, 'not_jailed') end
    Law.Records.Add(charId, 'jail', amount > 0 and L('record_jail_bail', amount) or L('record_jail_bail_removed'), nil, ctx)
    Law.Audit(ctx, 'jail.bail', charId, { amount = amount })
    local s = inmateSrc(charId)
    if s and amount > 0 then Law.Notify(s, L('jail_bail_set_you', amount), 'info', 8000) end
    return Law.Result(true, { charId = charId, bail = amount > 0 and amount or nil }, amount > 0 and L('jail_bail_set', amount) or L('jail_bail_removed'))
end)

--------------------------------------------------------------------------
-- Schalter: Kaution, Habseligkeiten
--------------------------------------------------------------------------
Law.Cb.Register('jail:bailList', { rate = 800 }, function(src, ctx)
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT charid, name, bail FROM ara_law_jail WHERE bail IS NOT NULL AND bail > 0 ORDER BY name ASC LIMIT 50') or {}) do
        out[#out + 1] = { charId = tonumber(r.charid), name = r.name, bail = tonumber(r.bail) }
    end
    return Law.Result(true, out)
end)

Law.Cb.Register('jail:payBail', { rate = 2500, notCuffed = true, notJailed = true, alive = true }, function(src, ctx, charId)
    charId = Law.ToInt(charId, 1)
    if not charId then return Law.Result(false, 'invalid') end
    -- Haeftling selbst oder sein Zweitchar zahlen nicht (gleiches Konto)
    if Law.IsSelfOrAlt(ctx, charId) then return Law.Result(false, 'own_bail') end
    if not Law.Stations.NearPoint(src, 'counter') then return Law.Result(false, 'not_at_point') end
    local row = MySQL.single.await('SELECT charid, name, bail, department FROM ara_law_jail WHERE charid = ?', { charId })
    if not row then return Law.Result(false, 'not_jailed') end
    local bail = tonumber(row.bail) or 0
    if bail <= 0 then return Law.Result(false, 'no_bail') end

    -- 1. Geld, 2. atomar loeschen (nur wenn die Kaution noch gleich ist), 3. Kasse
    if not Law.Money.Take(src, bail, 0) then return Law.Result(false, 'no_money') end
    local okD, affected = Law.DB.Try(MySQL.update.await, 'DELETE FROM ara_law_jail WHERE charid = ? AND bail = ?', { charId, row.bail })
    if not okD or affected ~= 1 then
        Law.Justice.GiveBack(src, ctx.charId, bail, 'bail_refund')
        return Law.Result(false, okD and 'already_done' or 'failed')
    end
    local dept = Law.GetDept(row.department) and row.department or (Config.Fines.FallbackDepartment or 'sheriff')
    if not Law.Justice.SocietyAdd(dept, bail, 'bail', ctx) then
        Law.Warn('Kaution fuer #%s konnte nicht in Kasse %s gebucht werden', tostring(charId), tostring(dept))
    end
    finishRelease(charId, 'bail', ctx)
    Law.Audit(ctx, 'jail.bail_paid', charId, { amount = bail, dept = dept })
    return Law.Result(true, { charId = charId, amount = bail }, L('jail_bail_paid', row.name, bail))
end)

Law.Cb.Register('jail:propertyStatus', { rate = 800 }, function(src, ctx)
    return Law.Result(true, { hasProperty = hasProperty(ctx.charId) })
end)

Law.Cb.Register('jail:claimProperty', { rate = 2000, notCuffed = true, notJailed = true, alive = true }, function(src, ctx)
    if not Law.Stations.NearPoint(src, 'counter') then return Law.Result(false, 'not_at_point') end
    if Law.Jail.IsJailed(ctx.charId) then return Law.Result(false, 'jailed') end
    if not hasProperty(ctx.charId) then return Law.Result(false, 'no_property') end
    local inv = ensureProperty(ctx.charId)
    -- Schalter-NUI schliessen, sonst liegt das vorp-Inventar darunter
    TriggerClientEvent('ara_law:cl:jail:closeUi', src)
    SetTimeout(400, function()
        if GetPlayerPing(src) > 0 then Law.Inv:openInventory(src, inv) end
    end)
    Law.Audit(ctx, 'jail.property', ctx.charId, {})
    return Law.Result(true, nil, L('jail_property_opened'))
end)

--------------------------------------------------------------------------
-- Haeftling: Status, Knastarbeit
--------------------------------------------------------------------------
Law.Cb.Register('jail:myStatus', { rate = 1000 }, function(src, ctx)
    local i = inmates[src]
    if not i then return Law.Result(true, nil) end
    return Law.Result(true, enterPayload(i, false))
end)

Law.Cb.Register('jail:workStart', { rate = 1000, notCuffed = true, alive = true }, function(src, ctx, index)
    local i = inmates[src]
    if not i then return Law.Result(false, 'not_jailed') end
    local loc = locationCfg(i.location)
    index = Law.ToInt(index, 1)
    local point = loc and index and (loc.work or {})[index]
    if not point then return Law.Result(false, 'invalid') end
    local c = Law.GetCoords(src)
    local wcfg = Config.Jail.Work
    if not c or dist2D(c, point.coords) > (wcfg.Distance or 2.5) or math.abs(c.z - point.coords.z) > 5.0 then
        return Law.Result(false, 'too_far')
    end
    local now = Law.Now()
    if i.work and GetGameTimer() - i.work.startedAt < (wcfg.Seconds or 10) * 3000 then return Law.Result(false, 'work_busy') end
    if now - (i.lastWorkAt or 0) < (wcfg.Cooldown or 45) then return Law.Result(false, 'cooldown') end
    if i.reduced >= workCap(i) then return Law.Result(false, 'work_cap') end
    i.work = { index = index, startedAt = GetGameTimer() }
    return Law.Result(true, { seconds = wcfg.Seconds or 10, scenario = point.scenario })
end)

Law.Cb.Register('jail:workFinish', { rate = 1000, notCuffed = true, alive = true }, function(src, ctx)
    local i = inmates[src]
    if not i then return Law.Result(false, 'not_jailed') end
    local w = i.work
    if not w then return Law.Result(false, 'invalid') end
    local wcfg = Config.Jail.Work
    if GetGameTimer() - w.startedAt < (wcfg.Seconds or 10) * 1000 - 500 then return Law.Result(false, 'too_early') end
    i.work = nil
    local loc = locationCfg(i.location)
    local point = loc and (loc.work or {})[w.index]
    local c = Law.GetCoords(src)
    if not point or not c or dist2D(c, point.coords) > (wcfg.Distance or 2.5) + 1.0 then return Law.Result(false, 'too_far') end

    local add = math.max(0, math.min(wcfg.ReduceSeconds or 30, workCap(i) - i.reduced))
    if add <= 0 then return Law.Result(false, 'work_cap') end
    i.reduced = i.reduced + add
    i.lastWorkAt = Law.Now()
    MySQL.update.await('UPDATE ara_law_jail SET reduced_seconds = ?, updated_at = ? WHERE charid = ?', { i.reduced, Law.Now(), i.charId })
    Law.Audit(ctx, 'jail.work', i.charId, { reduced = add })
    if remaining(i) <= 0 then
        releaseInmate(i.charId, 'served', nil)
        return Law.Result(true, { reduced = add, released = true }, L('jail_work_done', add))
    end
    TriggerClientEvent('ara_law:cl:jail:hud', src, hudData(i))
    return Law.Result(true, { reduced = add }, L('jail_work_done', add))
end)

--------------------------------------------------------------------------
-- Zeit und Flucht
--------------------------------------------------------------------------
local function snapshot()
    local list = {}
    for src, i in pairs(inmates) do list[#list + 1] = { src = src, i = i } end
    return list
end

local function tick()
    local step = Config.Jail.TickSeconds or 60
    for _, e in ipairs(snapshot()) do
        local src, i = e.src, e.i
        if inmates[src] == i and GetPlayerPing(src) > 0 then
            i.served = i.served + step
            if remaining(i) <= 0 then
                releaseInmate(i.charId, 'served', nil)
            else
                MySQL.update('UPDATE ara_law_jail SET served_seconds = ?, updated_at = ? WHERE charid = ?', { i.served, Law.Now(), i.charId })
                TriggerClientEvent('ara_law:cl:jail:hud', src, hudData(i))
            end
        end
    end
end

local function escape(src, i, coords)
    local okD, affected = Law.DB.Try(MySQL.update.await, 'DELETE FROM ara_law_jail WHERE charid = ?', { i.charId })
    if not okD then return end  -- DB weg: Haeftling bleibt drin, naechste Pruefung versucht es erneut
    clearOnline(i.charId, false, true)
    if affected ~= 1 then return end
    local cfg = Config.Jail
    local restMin = math.ceil(remaining(i) / 60)
    local label = locationLabel(i.location)

    Law.Records.Add(i.charId, 'escape', L('record_escape', label), L('record_escape_rest', restMin), nil)
    Law.Warrants.CreateAuto(i.charId, L('jail_escape_reason', label), {
        jailMinutes = math.min(restMin + (cfg.EscapeExtraMinutes or 30), cfg.MaxMinutes or 240),
        bounty = (cfg.EscapeBounty or 0) > 0 and cfg.EscapeBounty or nil,
        codes = { { id = 'escape', count = 1 } },
        dept = i.department,
    })
    Law.Dispatch.Create({
        kind = 'escape', coords = coords, priority = 3, fuzz = 40,
        title = L('dispatch_title_jail_escape'), text = L('jail_escape_dispatch', i.name or '?', label),
    })
    -- Spur fuer den Bluthund
    Law.Evidence.CreateTrace('cloth', coords, { ownerCharId = i.charId })
    Law.Audit(nil, 'jail.escape', i.charId, { location = i.location, rest = restMin })
    Law.Notify(src, L('jail_escaped_you'), 'objective', 10000)
end

--- Zurueck in die Zelle: serverseitig (OneSync) UND per Client-Event
--- (Fade/Kollision). Der Server-Teleport greift auch, wenn der Client das
--- Event ignoriert.
local function teleportBack(src, i)
    local _, _, s = zoneOf(i)
    if not s then return end
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        SetEntityCoords(ped, s.x + 0.0, s.y + 0.0, s.z + 0.0, false, false, false, false)
    end
    TriggerClientEvent('ara_law:cl:jail:teleport', src, v4(s))
end

local function checkEscapes()
    local now = Law.Now()
    local maxReturns = Config.Jail.MaxDeathReturns or 3
    for _, e in ipairs(snapshot()) do
        local src, i = e.src, e.i
        if inmates[src] == i and GetPlayerPing(src) > 0 and now >= (i.graceUntil or 0) then
            local center, radius, _, maxDz = zoneOf(i)
            local c = Law.GetCoords(src)
            local recentlyDead = Law.DiedRecently(src, Config.Jail.DiedRecentlySeconds or 90)
            local outside = center and c and (dist2D(c, center) > radius or (maxDz and math.abs(c.z - center.z) > maxDz))
            if outside then
                local ctx = Law.Ctx(src)
                -- Tod/Respawn ist keine Flucht -> zurueck. Aber hoechstens
                -- MaxDeathReturns Mal in Folge (H1), sonst waere "kuerzlich tot"
                -- ein Freifahrtschein zum Weglaufen.
                local cell = cellOf(i)
                if (recentlyDead or (ctx and ctx.isDead)) and (i.deathReturns or 0) < maxReturns then
                    i.deathReturns = (i.deathReturns or 0) + 1
                    i.graceUntil = now + graceSeconds()
                    teleportBack(src, i)
                elseif cell and Law.Doors.IsLocked(cell.door) and dist2D(c, center) <= radius + 6.0 then
                    -- Zellentuer ist zu: durch Gitter laeuft keiner -> Glitch (oder radius
                    -- zu klein). Keine Flucht, zurueck in die Zelle.
                    i.graceUntil = now + graceSeconds()
                    teleportBack(src, i)
                else
                    escape(src, i, c)
                end
            elseif center and c and not recentlyDead then
                -- sicher in der Zone und nicht frisch gestorben -> Zaehler zuruecksetzen
                i.deathReturns = 0
            end
        end
    end
end

--------------------------------------------------------------------------
-- Lebenszyklus
--------------------------------------------------------------------------
local function handleLogin(src, ctx)
    local row = MySQL.single.await('SELECT * FROM ara_law_jail WHERE charid = ?', { ctx.charId })
    if not row then
        if inmates[src] then clearOnline(inmates[src].charId, false, false) end
        -- Waehrend der Abwesenheit freigelassen, aber noch im Gefaengnis ausgeloggt?
        SetTimeout(6000, function()
            if GetPlayerPing(src) <= 0 or inmates[src] then return end
            local c = Law.GetCoords(src)
            local now = Law.Ctx(src)
            if not c or not now or now.dept then return end  -- Waerter/Gesetz nie wegteleportieren
            for _, loc in pairs(Config.Jail.Locations) do
                if loc.enabled ~= false and dist2D(c, loc.center) <= loc.radius then
                    local recent = MySQL.scalar.await("SELECT COUNT(*) FROM ara_law_records WHERE charid = ? AND type = 'release' AND created_at >= ?",
                        { ctx.charId, Law.Now() - 7 * 86400 })
                    if (tonumber(recent) or 0) > 0 then
                        TriggerClientEvent('ara_law:cl:jail:leave', src, { release = v4(loc.release) })
                    end
                    return
                end
            end
        end)
        return
    end

    if Config.Jail.CountOffline then
        local away = math.max(0, Law.Now() - (tonumber(row.updated_at) or Law.Now()))
        row.served_seconds = (tonumber(row.served_seconds) or 0) + away
    end
    local i = setupInmate(src, row, false, true)
    if not i then return end  -- schon wieder weg
    i.graceUntil = Law.Now() + math.max(60, graceSeconds())
    -- has_property = 2: Offline-Haft oder abgebrochene Einbuchung -> Nacharbeiten
    local pendingConfiscation = tonumber(row.has_property) == 2

    -- vorp setzt nach der Charakterwahl noch Position und Inventar -> kurz warten
    SetTimeout(5000, function()
        if inmates[src] ~= i or GetPlayerPing(src) <= 0 then return end
        if remaining(i) <= 0 then
            releaseInmate(i.charId, 'served', nil)
            return
        end
        if pendingConfiscation then
            local okC, res = pcall(confiscate, src, i.charId)
            if not okC then Law.Warn('Beschlagnahme (Login) fehlgeschlagen fuer #%s: %s', tostring(i.charId), tostring(res)) end
            local has = (okC and res == true) or hasProperty(i.charId)
            Law.Citizens.SetSample(i.charId, true)
            Law.Justice.ServeWarrants(i.charId)
            Law.Justice.CloseBountiesForTarget(i.charId, 'cancelled', nil)
            -- erst ganz am Ende: Nacharbeiten erledigt
            Law.DB.Try(MySQL.update.await, 'UPDATE ara_law_jail SET has_property = ? WHERE charid = ?', { has and 1 or 0, i.charId })
            if inmates[src] ~= i or GetPlayerPing(src) <= 0 then return end
            Law.Notify(src, L('jail_offline_you', math.ceil(remaining(i) / 60)), 'objective', 10000)
        end
        local center, radius = zoneOf(i)
        local c = Law.GetCoords(src)
        local inside = center and c and dist2D(c, center) <= radius
        i.graceUntil = Law.Now() + graceSeconds()
        local payload = enterPayload(i, not inside)
        if payload then TriggerClientEvent('ara_law:cl:jail:enter', src, payload) end
    end)
end

Law.Modules.Register('jail', {
    init = function()
        Law.Every((Config.Jail.TickSeconds or 60) * 1000, tick)
        Law.Every((Config.Jail.EscapeCheckSeconds or 10) * 1000, checkEscapes)
    end,
    playerLoaded = function(src, ctx)
        handleLogin(src, ctx)
    end,
    playerRespawned = function(src)
        local i = inmates[src]
        if not i then return end
        i.graceUntil = Law.Now() + graceSeconds()
        if not zoneOf(i) then return end
        -- vorp teleportiert beim Respawn selbst -> danach zurueck in die Zelle
        SetTimeout(3000, function()
            if inmates[src] == i and GetPlayerPing(src) > 0 then
                teleportBack(src, i)
            end
        end)
    end,
    playerDropped = function(src, cache)
        local i = inmates[src]
        if not i then return end
        inmates[src] = nil
        MySQL.update('UPDATE ara_law_jail SET served_seconds = ?, reduced_seconds = ?, updated_at = ? WHERE charid = ?',
            { i.served, i.reduced, Law.Now(), i.charId })
    end,
    stop = function()
        -- keine awaits im stop-Hook (Vertrag 11.14)
        for _, i in pairs(inmates) do
            MySQL.update('UPDATE ara_law_jail SET served_seconds = ?, reduced_seconds = ?, updated_at = ? WHERE charid = ?',
                { i.served, i.reduced, Law.Now(), i.charId })
        end
        for id in pairs(registeredProperty) do
            pcall(function() Law.Inv:removeInventory(id) end)
        end
        inmates = {}
    end,
})
