--[[
    ArA-LawSystem - Akten (Server, Agent A)

    Law.Records.Add (Vertrag 4.1) + Dienstbuch-Tab "Personen":
      records:search(query)          -> [PersonHit]
      records:getFile(charId)        -> File
      records:addNote(charId, title, text)
      records:setDangerous(charId, bool)
      records:brief(charId)          -> { charId, name }   (Zusatz: Name fuer Formulare)

    Ausserdem gemeinsame Helfer der Justiz-Dateien in Law.Justice
    (Strafkatalog, Charakter-Zeile, Datenformen). Sie werden nur zur
    LAUFZEIT von anderen Dateien benutzt - die Ladereihenfolge ist egal.
]]

Law.Justice = Law.Justice or {}
Law.Records = Law.Records or {}

local RECORD_TYPES = {
    note = true, arrest = true, fine = true, jail = true, release = true, escape = true,
    warrant = true, bounty = true, evidence = true, weapon = true, escort = true,
}

--------------------------------------------------------------------------
-- Strafkatalog
--------------------------------------------------------------------------
local penalById = {}
for _, p in ipairs(Config.PenalCode or {}) do penalById[p.id] = p end
Law.Justice.PenalById = penalById

--- Delikt-Auswahl vom Client pruefen und serverseitig ausrechnen.
--- codes = { { id = 'theft', count = 2 }, ... }
--- -> { list = { {id,label,count} }, fine, jail (Minuten), text } | nil
function Law.Justice.ComputeCodes(codes)
    if type(codes) ~= 'table' then return nil end
    local maxCodes = Config.Fines.MaxCodes or 10
    local maxCount = Config.Fines.MaxCodeCount or 5
    -- Riesige Listen gar nicht erst durchlaufen (Spam-Schutz)
    if #codes > maxCodes * maxCount then return nil end
    local merged, order = {}, {}
    for _, c in ipairs(codes) do
        if type(c) == 'table' then
            local id = Law.ToStr(c.id, 32)
            local count = Law.ToInt(c.count or 1, 1, maxCount)
            if id and count and penalById[id] then
                if not merged[id] then
                    if #order >= maxCodes then return nil end
                    order[#order + 1] = id
                    merged[id] = 0
                end
                merged[id] = math.min(merged[id] + count, maxCount)
            end
        end
    end
    if #order == 0 then return nil end

    local list, fine, jail, labels = {}, 0, 0, {}
    for _, id in ipairs(order) do
        local p, cnt = penalById[id], merged[id]
        list[#list + 1] = { id = id, label = p.label, count = cnt }
        fine = fine + (tonumber(p.fine) or 0) * cnt
        jail = jail + (tonumber(p.jail) or 0) * cnt
        labels[#labels + 1] = cnt > 1 and ('%s x%d'):format(p.label, cnt) or p.label
    end
    return { list = list, fine = Law.Round(fine, 2), jail = math.floor(jail), text = table.concat(labels, ', ') }
end

--- Gespeicherte Delikte (JSON) in NUI-Form. Automatische Haftbefehle zu
--- Bussgeldern speichern { fine_id = X } statt einer Liste.
--- -> list {id,label,count}, fineId|nil
function Law.Justice.CodesPublic(raw)
    local decoded = type(raw) == 'table' and raw or Law.DB.Decode(raw, nil)
    local list, fineId = {}, nil
    if type(decoded) == 'table' then
        if decoded[1] ~= nil then
            for _, c in ipairs(decoded) do
                if type(c) == 'table' and c.id then
                    local p = penalById[c.id]
                    list[#list + 1] = { id = c.id, label = p and p.label or tostring(c.label or c.id), count = tonumber(c.count) or 1 }
                end
            end
        else
            fineId = tonumber(decoded.fine_id)
        end
    end
    return list, fineId
end

--------------------------------------------------------------------------
-- Allgemeine Helfer
--------------------------------------------------------------------------
function Law.Justice.DeptLabel(dept)
    local d = Law.GetDept(dept)
    return d and d.label or nil
end

function Law.Justice.DeptSeal(dept)
    local d = Law.GetDept(dept)
    return d and (d.seal or dept) or nil
end

--- Charakter aus der vorp-Tabelle (auch offline) oder nil
function Law.Justice.CharRow(charId)
    charId = tonumber(charId)
    if not charId or charId <= 0 then return nil end
    return MySQL.single.await('SELECT charidentifier, identifier, firstname, lastname, age, gender FROM characters WHERE charidentifier = ? LIMIT 1', { charId })
end

function Law.Justice.RowName(row)
    if not row then return '?' end
    return (((row.firstname or '') .. ' ' .. (row.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''))
end

--------------------------------------------------------------------------
-- Geld sicher buchen. oxmysql-.await WIRFT bei SQL-Fehlern -> alles, was
-- nach einem Geldabzug/Statuswechsel noch in die DB schreibt, laeuft ueber
-- Law.DB.Try und meldet Erfolg als bool (Aufrufer bucht dann zurueck).
--------------------------------------------------------------------------
function Law.Justice.PayCharId(charId, amount, reason)
    local ok, res = Law.DB.Try(Law.Money.GiveCharId, charId, amount, 0, reason)
    return ok and res == true
end

--- Geld an einen (vermutlich online stehenden) Spieler zurueck; offline -> Nachzahlung
function Law.Justice.GiveBack(src, charId, amount, reason)
    if amount <= 0 then return true end
    if src and GetPlayerPing(src) > 0 and Law.Money.Give(src, amount, 0) then return true end
    local ok = Law.Justice.PayCharId(charId, amount, reason)
    if not ok then Law.Warn('Rueckbuchung fehlgeschlagen: #%s $%s (%s)', tostring(charId), tostring(amount), tostring(reason)) end
    return ok
end

function Law.Justice.SocietyAdd(dept, amount, reason, actorCtx)
    local ok, res = Law.DB.Try(Law.Society.Add, dept, amount, reason, actorCtx)
    return ok and res == true
end

function Law.Justice.SocietyRemove(dept, amount, reason, actorCtx)
    local ok, res = Law.DB.Try(Law.Society.Remove, dept, amount, reason, actorCtx)
    return ok and res == true
end

--- "?, ?, ?" fuer IN-Listen (nur Platzhalter, nie Werte)
function Law.Justice.Placeholders(n)
    local t = {}
    for i = 1, n do t[i] = '?' end
    return table.concat(t, ', ')
end

function Law.Justice.FormatDate(unix)
    unix = tonumber(unix)
    if not unix or unix <= 0 then return '-' end
    return os.date('%d.%m.%Y %H:%M', unix)
end

function Law.Justice.RecordPublic(r)
    return {
        id          = r.id,
        type        = r.type,
        typeLabel   = L('record_type_' .. tostring(r.type)),
        title       = r.title,
        details     = r.details,
        officerName = r.officer_name,
        deptLabel   = Law.Justice.DeptLabel(r.department),
        createdAt   = tonumber(r.created_at),
    }
end

--------------------------------------------------------------------------
-- Vertrag 4.1: Law.Records.Add(charId, type, title, details?, officerCtx?, refId?) -> id
--------------------------------------------------------------------------
function Law.Records.Add(charId, rtype, title, details, officerCtx, refId)
    charId = tonumber(charId)
    if not charId or charId <= 0 then return nil end
    if not RECORD_TYPES[rtype] then rtype = 'note' end
    title = Law.ToStr(title, 128, true) or ''
    if details ~= nil then details = Law.ToStr(tostring(details), 4000, true, true) end
    local oc = type(officerCtx) == 'table' and officerCtx or nil
    return MySQL.insert.await(
        'INSERT INTO ara_law_records (charid, type, title, details, ref_id, officer_charid, officer_name, department, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { charId, rtype, title, details, tonumber(refId), oc and oc.charId or nil, oc and oc.name or nil, oc and oc.dept or nil, Law.Now() })
end

--------------------------------------------------------------------------
-- Markierungen je Person (gesucht, Kopfgeld, in Haft, gefaehrlich)
--------------------------------------------------------------------------
local function flagsFor(ids)
    local out = {}
    for _, id in ipairs(ids) do out[id] = { warrant = false, bounty = false, jailed = false, dangerous = false } end
    if #ids == 0 then return out end
    local ph = Law.Justice.Placeholders(#ids)

    local function params(first)
        local p = {}
        if first then p[1] = first end
        for _, id in ipairs(ids) do p[#p + 1] = id end
        return p
    end

    for _, r in ipairs(MySQL.query.await(('SELECT DISTINCT charid FROM ara_law_warrants WHERE status = ? AND charid IN (%s)'):format(ph), params('active')) or {}) do
        local f = out[tonumber(r.charid)]; if f then f.warrant = true end
    end
    for _, r in ipairs(MySQL.query.await(('SELECT DISTINCT charid FROM ara_law_bounties WHERE status = ? AND charid IN (%s)'):format(ph), params('active')) or {}) do
        local f = out[tonumber(r.charid)]; if f then f.bounty = true end
    end
    for _, r in ipairs(MySQL.query.await(('SELECT charid FROM ara_law_jail WHERE charid IN (%s)'):format(ph), params()) or {}) do
        local f = out[tonumber(r.charid)]; if f then f.jailed = true end
    end
    for _, r in ipairs(MySQL.query.await(('SELECT charid FROM ara_law_citizens WHERE dangerous = 1 AND charid IN (%s)'):format(ph), params()) or {}) do
        local f = out[tonumber(r.charid)]; if f then f.dangerous = true end
    end
    return out
end
Law.Justice.FlagsFor = flagsFor

--------------------------------------------------------------------------
-- Dienstbuch: Suche
--------------------------------------------------------------------------
Law.Cb.Register('records:search', { perm = 'records_view', duty = false, rate = 800 }, function(src, ctx, query)
    query = Law.ToStr(query, 60)
    if not query or utf8.len(query) < 2 then return Law.Result(false, 'query_short') end
    local like = '%' .. Law.DB.Like(query) .. '%'
    local rows = MySQL.query.await(
        "SELECT charidentifier, firstname, lastname, age, gender FROM characters WHERE CONCAT(firstname, ' ', lastname) LIKE ? ORDER BY lastname ASC LIMIT 20",
        { like }) or {}
    local ids = {}
    for _, r in ipairs(rows) do ids[#ids + 1] = tonumber(r.charidentifier) end
    local flags = flagsFor(ids)
    local hits = {}
    for _, r in ipairs(rows) do
        local id = tonumber(r.charidentifier)
        hits[#hits + 1] = {
            charId = id, name = Law.Justice.RowName(r), age = tonumber(r.age), gender = r.gender,
            flags = flags[id] or { warrant = false, bounty = false, jailed = false, dangerous = false },
        }
    end
    return Law.Result(true, hits)
end)

Law.Cb.Register('records:brief', { law = true, duty = false, rate = 300 }, function(src, ctx, charId)
    charId = Law.ToInt(charId, 1)
    local row = charId and Law.Justice.CharRow(charId)
    if not row then return Law.Result(false, 'not_found') end
    return Law.Result(true, { charId = charId, name = Law.Justice.RowName(row) })
end)

--------------------------------------------------------------------------
-- Dienstbuch: Akte
--------------------------------------------------------------------------
Law.Cb.Register('records:getFile', { perm = 'records_view', duty = false, rate = 800 }, function(src, ctx, charId)
    charId = Law.ToInt(charId, 1)
    local row = charId and Law.Justice.CharRow(charId)
    if not row then return Law.Result(false, 'not_found') end

    local citizen = Law.Citizens.Get(charId) or {}
    local flags = flagsFor({ charId })[charId]

    local records = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM ara_law_records WHERE charid = ? ORDER BY id DESC LIMIT 50', { charId }) or {}) do
        records[#records + 1] = Law.Justice.RecordPublic(r)
    end

    local fines = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM ara_law_fines WHERE charid = ? ORDER BY id DESC LIMIT 30', { charId }) or {}) do
        fines[#fines + 1] = Law.Justice.FinePublic(r)
    end

    local warrantRows = MySQL.query.await('SELECT * FROM ara_law_warrants WHERE charid = ? ORDER BY id DESC LIMIT 30', { charId }) or {}
    local warrants = Law.Justice.WarrantsPublic(warrantRows)

    local bounties = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM ara_law_bounties WHERE charid = ? ORDER BY id DESC LIMIT 30', { charId }) or {}) do
        bounties[#bounties + 1] = Law.Justice.BountyPublic(r, true)
    end

    local licenses = {}
    for _, r in ipairs(MySQL.query.await('SELECT type, status, expires_at FROM ara_law_licenses WHERE charid = ? ORDER BY id DESC LIMIT 20', { charId }) or {}) do
        licenses[#licenses + 1] = { type = r.type, status = r.status, expiresAt = tonumber(r.expires_at) }
    end

    local weapons = {}
    for _, w in ipairs(Law.Weapons.GetByOwner(charId) or {}) do
        weapons[#weapons + 1] = { serial = w.serial, weapon = w.weapon, weaponLabel = w.weaponLabel, status = w.status }
    end

    return Law.Result(true, {
        charId    = charId,
        name      = Law.Justice.RowName(row),
        age       = tonumber(row.age),
        gender    = row.gender,
        -- Blutgruppe nur, wenn eine Probe in der Akte liegt (Vertrag A5)
        bloodType = citizen.hasSample and citizen.bloodType or nil,
        dangerous = citizen.dangerous == true,
        notes     = citizen.notes,
        flags     = flags,
        records   = records,
        fines     = fines,
        warrants  = warrants,
        bounties  = bounties,
        jail      = Law.Justice.InmateByCharId(charId),
        weapons   = weapons,
        licenses  = licenses,
    })
end)

--------------------------------------------------------------------------
-- Dienstbuch: Notiz, gefaehrlich
--------------------------------------------------------------------------
Law.Cb.Register('records:addNote', { perm = 'records_edit', rate = 1500 }, function(src, ctx, charId, title, text)
    charId = Law.ToInt(charId, 1)
    title = Law.ToStr(title, 128)
    text = Law.ToStr(text, 2000, true, true)
    if not charId or not title then return Law.Result(false, 'invalid') end
    if not Law.Justice.CharRow(charId) then return Law.Result(false, 'not_found') end
    -- keine Eintraege in die eigene Akte / die eines Zweitcharakters
    if Law.IsSelfOrAlt(ctx, charId) then return Law.Result(false, 'self_target') end
    local id = Law.Records.Add(charId, 'note', title, text ~= '' and text or nil, ctx)
    if not id then return Law.Result(false, 'failed') end
    Law.Audit(ctx, 'records.note', charId, { id = id, title = title })
    return Law.Result(true, { id = id }, L('records_note_added'))
end)

Law.Cb.Register('records:setDangerous', { perm = 'records_edit', rate = 1000 }, function(src, ctx, charId, flag)
    charId = Law.ToInt(charId, 1)
    if not charId then return Law.Result(false, 'invalid') end
    if not Law.Justice.CharRow(charId) then return Law.Result(false, 'not_found') end
    if Law.IsSelfOrAlt(ctx, charId) then return Law.Result(false, 'self_target') end
    flag = Law.ToBool(flag)
    Law.Citizens.SetDangerous(charId, flag)
    Law.Records.Add(charId, 'note', flag and L('record_dangerous_on') or L('record_dangerous_off'), nil, ctx)
    Law.Audit(ctx, 'records.dangerous', charId, { dangerous = flag })
    return Law.Result(true, { dangerous = flag }, flag and L('records_dangerous_on') or L('records_dangerous_off'))
end)
