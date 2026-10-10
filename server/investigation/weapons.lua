--[[
    ArA-LawSystem - Waffenregister (Server)

    Seriennummern kommen aus vorp_inventory (Tabelle loadout.serial_number).
    Register = ara_law_weapons. Schalter: eigene Waffen registrieren, als
    gestohlen melden. Dienstbuch: Abfrage, Status setzen. Feldkontrolle am
    gefesselten Ziel. Waffenfeile (jeder) und Waffenschein (Dokument).

    Wichtig (vorp-Quelltext geprueft): setWeaponSerialNumber und getUserWeapon
    pruefen den Besitzer NICHT - deshalb wird jede Waffen-ID vorher gegen
    getUserInventoryWeapons(src) des Aufrufers abgeglichen.
]]

local WCfg = Config.Weapons

Law.Weapons = Law.Weapons or {}

local SETTABLE = { registered = true, stolen = true, confiscated = true, destroyed = true }

local function isFirearm(name) return Law.Evidence.IsFirearm(name) end
local function label(name) return Law.Evidence.WeaponLabel(name) end
local function statusLabel(s) return L('weapons_status_' .. tostring(s or 'unregistered')) end

local function validSerial(serial)
    return type(serial) == 'string' and serial ~= '' and serial ~= WCfg.FiledSerial
end

--- Waffe aus dem EIGENEN Inventar (nie getUserWeapon - das prueft den Besitzer nicht)
local function ownWeapon(src, weaponId)
    weaponId = tonumber(weaponId)
    if not weaponId then return nil end
    for _, w in ipairs(Law.Inv:getUserInventoryWeapons(src) or {}) do
        if tonumber(w.id) == weaponId then return w end
    end
    return nil
end

local function placeholders(n)
    return ('?,'):rep(n):sub(1, -2)
end

--------------------------------------------------------------------------
-- Querverweise (Vertrag 4.1) + Hilfen fuer evidence.lua
--------------------------------------------------------------------------
--- Aktueller Besitzer laut vorp (loadout). nil = unbekannt.
function Law.Weapons.CurrentHolder(serial)
    if not validSerial(serial) then return nil end
    local r = MySQL.single.await('SELECT charidentifier, curr_inv FROM loadout WHERE serial_number = ? LIMIT 1', { serial })
    if not r then return nil end
    if r.curr_inv and r.curr_inv ~= '' and r.curr_inv ~= 'default' then
        return { name = L('weapons_holder_stored') }
    end
    local cid = tonumber(r.charidentifier)
    if not cid or cid <= 0 then return nil end
    return { charId = cid, name = Law.GetCharName(cid) }
end

--- Vertrag 4.1: WeaponInfo | nil
function Law.Weapons.Lookup(serial)
    serial = Law.ToStr(serial, 50)
    -- "ABGEFEILT" ist keine Nummer - sonst liesse sich jeder Besitzer einer abgefeilten Waffe finden
    if not validSerial(serial) then return nil end
    local row = MySQL.single.await('SELECT * FROM ara_law_weapons WHERE serial = ?', { serial })
    local weaponName = row and row.weapon or nil
    if not row then
        local l = MySQL.single.await('SELECT name FROM loadout WHERE serial_number = ? LIMIT 1', { serial })
        if not l then return nil end
        weaponName = l.name
    end
    local holder = Config.Evidence.RevealCurrentHolder and Law.Weapons.CurrentHolder(serial) or nil
    local evidence = {}
    -- Nur ausgewertete Beweise - die Seriennummer einer Huelse liefert erst das Labor
    for _, e in ipairs(MySQL.query.await("SELECT id, type, zone, created_at FROM ara_law_evidence WHERE serial = ? AND status = 'analyzed' ORDER BY id DESC LIMIT 20", { serial }) or {}) do
        evidence[#evidence + 1] = {
            id = tonumber(e.id), type = e.type, typeLabel = Law.Evidence.TypeLabel(e.type),
            zone = e.zone, createdAt = tonumber(e.created_at),
        }
    end
    local status = row and row.status or 'unregistered'
    return {
        serial        = serial,
        weapon        = weaponName,
        weaponLabel   = label(weaponName),
        status        = status,
        statusLabel   = statusLabel(status),
        ownerName     = row and row.owner_name or nil,
        ownerCharId   = row and tonumber(row.owner_charid) or nil,
        registeredAt  = row and tonumber(row.registered_at) or nil,
        notes         = row and row.notes or nil,
        department    = row and row.department or nil,
        currentHolder = holder and { name = holder.name } or nil,
        evidence      = evidence,
    }
end

--- Vertrag 4.1: Liste { serial, weapon, weaponLabel, status }
function Law.Weapons.GetByOwner(charId)
    charId = tonumber(charId)
    if not charId then return {} end
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT serial, weapon, status FROM ara_law_weapons WHERE owner_charid = ? ORDER BY registered_at DESC LIMIT 50', { charId }) or {}) do
        out[#out + 1] = { serial = r.serial, weapon = r.weapon, weaponLabel = label(r.weapon), status = r.status, statusLabel = statusLabel(r.status) }
    end
    return out
end

--- Vertrag 4.1: Dienstwaffe aus der Waffenkammer ins Register
function Law.Weapons.RegisterIssued(serial, weaponName, charId, dept)
    serial = Law.ToStr(serial, 50)
    if not validSerial(serial) then return false end
    charId = tonumber(charId)
    local name = charId and Law.GetCharName(charId) or nil
    local now = Law.Now()
    local affected = MySQL.update.await([[INSERT INTO ara_law_weapons
        (serial, weapon, owner_charid, owner_name, status, department, registered_at, registered_by, notes, updated_at)
        VALUES (?, ?, ?, ?, 'issued', ?, ?, ?, NULL, ?)
        ON DUPLICATE KEY UPDATE weapon = VALUES(weapon), owner_charid = VALUES(owner_charid), owner_name = VALUES(owner_name),
            status = 'issued', department = VALUES(department), updated_at = VALUES(updated_at)]],
        { serial, tostring(weaponName or ''), charId, name, dept, now, charId, now })
    return (tonumber(affected) or 0) > 0
end

--------------------------------------------------------------------------
-- Schalter (Tab "weapons")
--------------------------------------------------------------------------
Law.Cb.Register('weapons:mine', { rate = 1000 }, function(src, ctx)
    local out, serials = {}, {}
    for _, w in ipairs(Law.Inv:getUserInventoryWeapons(src) or {}) do
        if isFirearm(w.name) then
            local serial = (type(w.serial_number) == 'string' and w.serial_number ~= '') and w.serial_number or nil
            local e = {
                id          = tonumber(w.id),
                serial      = serial,
                weapon      = w.name,
                weaponLabel = (type(w.custom_label) == 'string' and w.custom_label ~= '') and w.custom_label or label(w.name),
                filed       = serial == WCfg.FiledSerial,
                registered  = false,
                status      = nil,
                statusLabel = statusLabel('unregistered'),
            }
            out[#out + 1] = e
            if validSerial(serial) then serials[#serials + 1] = serial end
        end
    end
    if #serials > 0 then
        local map = {}
        local rows = MySQL.query.await(('SELECT serial, owner_charid, status FROM ara_law_weapons WHERE serial IN (%s)'):format(placeholders(#serials)), serials) or {}
        for _, r in ipairs(rows) do map[r.serial] = r end
        for _, e in ipairs(out) do
            local r = e.serial and map[e.serial]
            if r then
                local mine = tonumber(r.owner_charid) == ctx.charId
                e.status = r.status
                e.statusLabel = statusLabel(r.status)
                e.registered = mine and (r.status == 'registered' or r.status == 'issued')
                e.foreign = not mine  -- im Register auf jemand anderen eingetragen
            end
        end
    end
    -- Auf mich registrierte Waffen, die ich NICHT mehr habe (gestohlen melden moeglich)
    local have = {}
    for _, e in ipairs(out) do
        e.inInventory = true
        if e.serial then have[e.serial] = true end
    end
    for _, r in ipairs(MySQL.query.await("SELECT serial, weapon, status FROM ara_law_weapons WHERE owner_charid = ? AND status IN ('registered','stolen') ORDER BY registered_at DESC LIMIT 30",
        { ctx.charId }) or {}) do
        if not have[r.serial] then
            out[#out + 1] = {
                id = nil, serial = r.serial, weapon = r.weapon, weaponLabel = label(r.weapon), filed = false,
                registered = r.status == 'registered', status = r.status, statusLabel = statusLabel(r.status),
                inInventory = false, missing = true,
            }
        end
    end
    return Law.Result(true, out)
end)

Law.Cb.Register('weapons:register', { rate = 2000, notCuffed = true, notJailed = true }, function(src, ctx, weaponId)
    weaponId = Law.ToInt(weaponId, 1)
    if not weaponId then return Law.Result(false, 'invalid') end
    local station = Law.Stations.NearPoint(src, 'counter')
    if not station then return Law.Result(false, 'not_at_point') end

    local w = ownWeapon(src, weaponId)
    if not w or not isFirearm(w.name) then return Law.Result(false, 'weapons_not_found') end
    local serial = w.serial_number
    if type(serial) ~= 'string' or serial == '' then return Law.Result(false, 'weapons_no_serial') end
    if serial == WCfg.FiledSerial then return Law.Result(false, 'weapons_filed') end

    local row = MySQL.single.await('SELECT owner_charid, status FROM ara_law_weapons WHERE serial = ?', { serial })
    if row then
        local owner = tonumber(row.owner_charid)
        if owner and owner ~= ctx.charId and (row.status == 'registered' or row.status == 'stolen') then
            -- Waffe eines ANDEREN eingetragenen Besitzers am Schalter: kein Umschreiben.
            -- Akteneintrag beim Besitzer + Hinweis an das Gesetz (wer hat sie jetzt?)
            local stationLabel = (Config.Stations[station] or {}).label or station
            local stolen = row.status == 'stolen'
            Law.Records.Add(owner, 'weapon', L('weapons_record_presented', serial, stationLabel),
                L('weapons_record_presented_by', ctx.name), nil, nil)
            Law.NotifyLaw(L(stolen and 'weapons_stolen_presented' or 'weapons_foreign_presented', serial, stationLabel), 'weapons_registry')
            Law.Audit(ctx, stolen and 'weapons.stolen_presented' or 'weapons.foreign_presented', owner, { serial = serial, station = station })
            return Law.Result(false, stolen and 'weapons_stolen' or 'weapons_foreign')
        end
        if row.status == 'issued' then return Law.Result(false, 'weapons_issued') end
        if row.status == 'confiscated' or row.status == 'destroyed' then return Law.Result(false, 'weapons_blocked') end
        if row.status == 'registered' and owner == ctx.charId then return Law.Result(false, 'weapons_already') end
        -- uebrig: eigene, als gestohlen gemeldete Waffe wiedergefunden
    end

    local fee = Law.ToMoney(WCfg.RegisterFee or 0, 0) or 0
    if fee > 0 and not Law.Money.Take(src, fee, 0) then return Law.Result(false, 'no_money') end

    -- oxmysql-.await wirft bei SQL-Fehlern -> Law.DB.Try, sonst waere die Gebuehr weg
    local now = Law.Now()
    local okDb, affected
    if row then
        -- Wiedergefundene eigene Waffe: nur, wenn sich der Eintrag inzwischen nicht geaendert hat
        okDb, affected = Law.DB.Try(MySQL.update.await, [[UPDATE ara_law_weapons SET weapon = ?, owner_charid = ?, owner_name = ?, status = 'registered',
            registered_at = ?, registered_by = NULL, updated_at = ? WHERE serial = ? AND status = ? AND COALESCE(owner_charid, 0) = ?]],
            { w.name, ctx.charId, ctx.name, now, now, serial, row.status, tonumber(row.owner_charid) or 0 })
    else
        okDb, affected = Law.DB.Try(MySQL.update.await, [[INSERT IGNORE INTO ara_law_weapons
            (serial, weapon, owner_charid, owner_name, status, department, registered_at, registered_by, notes, updated_at)
            VALUES (?, ?, ?, ?, 'registered', NULL, ?, NULL, NULL, ?)]],
            { serial, w.name, ctx.charId, ctx.name, now, now })
    end
    if not okDb or affected ~= 1 then
        if fee > 0 then Law.Money.Give(src, fee, 0) end
        return Law.Result(false, okDb and 'already_done' or 'failed')
    end
    if fee > 0 then Law.Society.Add(WCfg.FeeDepartment or 'sheriff', fee, 'weapon_register', ctx) end

    local wl = label(w.name)
    if WCfg.PermitItem then
        local meta = {
            serial = serial, weapon = wl, owner = ctx.name, owner_charid = ctx.charId,
            description = L('weapons_permit_desc', wl, serial, ctx.name),
        }
        if not Law.Items.Give(src, Config.Items.WeaponPermit, 1, meta) then
            Law.Notify(src, L('weapons_permit_no_space'), 'error')
        end
    end
    Law.Records.Add(ctx.charId, 'weapon', L('weapons_record_registered', wl, serial), nil, nil, nil)
    Law.Audit(ctx, 'weapons.register', nil, { serial = serial, weapon = w.name, fee = fee, station = station })
    return Law.Result(true, { serial = serial }, L('weapons_registered', wl, serial))
end)

-- Nur der eingetragene Besitzer - er muss die Waffe NICHT mehr bei sich haben (sie wurde ja gestohlen)
Law.Cb.Register('weapons:reportStolen', { rate = 2000, notCuffed = true, notJailed = true }, function(src, ctx, serial)
    serial = Law.ToStr(serial, 50)
    if not validSerial(serial) then return Law.Result(false, 'invalid') end
    if not Law.Stations.NearPoint(src, 'counter') then return Law.Result(false, 'not_at_point') end
    local affected = MySQL.update.await("UPDATE ara_law_weapons SET status = 'stolen', updated_at = ? WHERE serial = ? AND owner_charid = ? AND status = 'registered'",
        { Law.Now(), serial, ctx.charId })
    if affected ~= 1 then return Law.Result(false, 'weapons_not_registered') end
    Law.Records.Add(ctx.charId, 'weapon', L('weapons_record_stolen', serial), nil, nil, nil)
    Law.NotifyLaw(L('weapons_stolen_reported', serial), 'weapons_registry')
    Law.Audit(ctx, 'weapons.stolen', nil, { serial = serial })
    return Law.Result(true, nil, L('weapons_stolen_ok', serial))
end)

--------------------------------------------------------------------------
-- Waffe verkaufen / umschreiben (Schalter): der einzige legale Besitzerwechsel
-- einer registrierten Waffe. Ablauf: pruefen -> Kaeufer fragen -> ALLES erneut
-- pruefen -> Register atomar umschreiben -> Waffe uebergeben (sonst zurueck).
--
-- vorp (Quelltext geprueft, inventoryApiService GIVE_WEAPON): giveWeapon(source,
-- weaponId, target) gibt die Waffe AN `source` (Kapazitaetspruefung, "erhalten")
-- und nimmt sie VON `target`. Deshalb: giveWeapon(kaeufer, weaponId, verkaeufer).
--------------------------------------------------------------------------
local transferring = {}  -- [weaponId] = true (keine zwei Umschreibungen derselben Waffe)
local TRANSFER_DISTANCE = 3.0

--- Alle Bedingungen; wird VOR und NACH der Rueckfrage aufgerufen -> data | nil, errCode
local function transferCheck(src, ctx, weaponId, targetSrc, serial)
    if not Law.Stations.NearPoint(src, 'counter') then return nil, 'not_at_point' end
    if Law.IsCuffed(src) or Law.IsJailed(src) then return nil, 'invalid' end
    local w = ownWeapon(src, weaponId)
    if not w or not isFirearm(w.name) then return nil, 'weapons_not_found' end
    if w.serial_number == WCfg.FiledSerial then return nil, 'weapons_filed' end
    if not validSerial(w.serial_number) then return nil, 'weapons_no_serial' end
    if serial and w.serial_number ~= serial then return nil, 'weapons_not_found' end
    local row = MySQL.single.await('SELECT owner_charid, status, notes FROM ara_law_weapons WHERE serial = ?', { w.serial_number })
    if not row or row.status ~= 'registered' or tonumber(row.owner_charid) ~= ctx.charId then return nil, 'weapons_not_registered' end

    local target = Law.Ctx(targetSrc)
    if not target then return nil, 'no_target' end
    if not Law.IsNear(src, targetSrc, TRANSFER_DISTANCE) then return nil, 'too_far' end
    if Law.IsCuffed(targetSrc) or Law.IsJailed(targetSrc) or target.isDead then return nil, 'weapons_buyer_unable' end
    if Law.IsSelfOrAlt(ctx, target.charId) then return nil, 'weapons_self' end
    if not Law.Inv:canCarryWeapons(targetSrc, 1, nil, w.name) then return nil, 'weapons_buyer_full' end
    return { w = w, row = row, target = target }
end

Law.Cb.Register('weapons:transfer', { rate = 3000, notCuffed = true, notJailed = true }, function(src, ctx, weaponId, targetSrc)
    weaponId = Law.ToInt(weaponId, 1)
    targetSrc = Law.ToInt(targetSrc, 1)
    if not weaponId or not targetSrc or targetSrc == src then return Law.Result(false, 'invalid') end
    if transferring[weaponId] then return Law.Result(false, 'weapons_transfer_busy') end
    -- Kein Rueckfrage-Spam an denselben Kaeufer (jede Rueckfrage oeffnet dort ein Menue)
    if not Law.RateLimit(targetSrc, 'weapons:askedTransfer', 30000) then return Law.Result(false, 'cooldown') end
    transferring[weaponId] = true

    local ok, res = xpcall(function()
        -- 1) + 2) Verkaeufer, Waffe, Register, Kaeufer
        local d, err = transferCheck(src, ctx, weaponId, targetSrc, nil)
        if not d then return Law.Result(false, err) end
        local serial = d.w.serial_number
        local wl = label(d.w.name)

        -- 3) Kaeufer fragen
        local answer = Law.Ask(targetSrc, 'weapons:confirmTransfer', { weaponLabel = wl, serial = serial, sellerName = ctx.name }, 12000)
        if answer ~= true then return Law.Result(false, 'declined') end

        -- 4) Nach der Rueckfrage ALLES erneut pruefen (Waffe weg? Kaeufer weggegangen?)
        d, err = transferCheck(src, ctx, weaponId, targetSrc, serial)
        if not d then return Law.Result(false, err) end
        local buyer = d.target
        local oldNotes = d.row.notes

        -- 5) Register atomar umschreiben
        local now = Law.Now()
        local okDb, affected = Law.DB.Try(MySQL.update.await,
            "UPDATE ara_law_weapons SET owner_charid = ?, owner_name = ?, updated_at = ?, notes = ? WHERE serial = ? AND owner_charid = ? AND status = 'registered'",
            { buyer.charId, buyer.name, now, L('weapons_note_transfer', ctx.name), serial, ctx.charId })
        if not okDb or affected ~= 1 then return Law.Result(false, okDb and 'already_done' or 'failed') end

        -- 6) Waffe uebergeben: AN den Kaeufer, VON dem Verkaeufer (vorp-Reihenfolge, siehe oben).
        -- vorp prueft NICHT, wem die Waffe gerade gehoert - und zwischen Pruefung und
        -- hier lag ein DB-await. Deshalb unmittelbar davor (ohne yield) erneut pruefen.
        local stillOwned = ownWeapon(src, weaponId)
        local okGive, given = false, false
        if stillOwned and stillOwned.serial_number == serial then
            okGive, given = pcall(function() return Law.Inv:giveWeapon(targetSrc, weaponId, src) end)
        end
        if not okGive or given ~= true then
            Law.DB.Try(MySQL.update.await,
                "UPDATE ara_law_weapons SET owner_charid = ?, owner_name = ?, updated_at = ?, notes = ? WHERE serial = ? AND owner_charid = ? AND status = 'registered'",
                { ctx.charId, ctx.name, Law.Now(), oldNotes, serial, buyer.charId })
            return Law.Result(false, 'failed')
        end

        -- 7) Waffenschein fuer den Kaeufer, Akten, Protokoll, Benachrichtigung
        if WCfg.PermitItem then
            local meta = {
                serial = serial, weapon = wl, owner = buyer.name, owner_charid = buyer.charId,
                description = L('weapons_permit_desc', wl, serial, buyer.name),
            }
            if not Law.Items.Give(targetSrc, Config.Items.WeaponPermit, 1, meta) then
                Law.Notify(targetSrc, L('weapons_permit_no_space'), 'error')
            end
        end
        Law.Records.Add(ctx.charId, 'weapon', L('weapons_record_sold', wl, serial, buyer.name), nil, nil, nil)
        Law.Records.Add(buyer.charId, 'weapon', L('weapons_record_bought', wl, serial, ctx.name), nil, nil, nil)
        Law.Audit(ctx, 'weapons.transfer', buyer.charId, { serial = serial, weapon = d.w.name })
        Law.Notify(targetSrc, L('weapons_transfer_received', wl, serial, ctx.name), 'success')
        return Law.Result(true, { serial = serial }, L('weapons_transfer_done', wl, buyer.name))
    end, debug.traceback)

    transferring[weaponId] = nil
    if not ok then
        Law.Warn('weapons:transfer: %s', tostring(res))
        return Law.Result(false, 'internal')
    end
    return res
end)

--------------------------------------------------------------------------
-- Dienstbuch (Tab "weapons")
--------------------------------------------------------------------------
Law.Cb.Register('weapons:lookup', { perm = 'weapons_registry', rate = 800 }, function(src, ctx, serial)
    serial = Law.ToStr(serial, 50)
    if not serial then return Law.Result(false, 'invalid') end
    local info = Law.Weapons.Lookup(serial)
    if not info then return Law.Result(false, 'not_found') end
    Law.Audit(ctx, 'weapons.lookup', info.ownerCharId, { serial = serial })
    return Law.Result(true, info)
end)

Law.Cb.Register('weapons:setStatus', { perm = 'weapons_registry', rate = 1500 }, function(src, ctx, serial, status, note)
    serial = Law.ToStr(serial, 50)
    status = Law.ToStr(status, 12)
    note = Law.ToStr(note, 255, true) or ''
    if not validSerial(serial) or not status or not SETTABLE[status] then return Law.Result(false, 'weapons_bad_status') end
    local row = MySQL.single.await('SELECT owner_charid, status FROM ara_law_weapons WHERE serial = ?', { serial })
    if not row then return Law.Result(false, 'not_found') end
    local affected = MySQL.update.await('UPDATE ara_law_weapons SET status = ?, notes = ?, department = ?, updated_at = ? WHERE serial = ? AND status = ?',
        { status, note ~= '' and note or nil, ctx.dept, Law.Now(), serial, row.status })
    if affected ~= 1 then return Law.Result(false, 'already_done') end
    local owner = tonumber(row.owner_charid)
    if owner then
        Law.Records.Add(owner, 'weapon', L('weapons_record_status', serial, statusLabel(status)), note ~= '' and note or nil, ctx, nil)
    end
    Law.Audit(ctx, 'weapons.status', owner, { serial = serial, from = row.status, to = status, note = note })
    return Law.Result(true, Law.Weapons.Lookup(serial), L('weapons_status_set', serial, statusLabel(status)))
end)

--------------------------------------------------------------------------
-- Feldkontrolle (Recht weapons_registry ODER search)
--------------------------------------------------------------------------
Law.Cb.Register('weapons:inspect', { law = true, duty = true, rate = 2000, notCuffed = true, alive = true }, function(src, ctx, targetSrc)
    if not (Law.HasPerm(ctx, 'weapons_registry') or Law.HasPerm(ctx, 'search')) then
        return Law.Result(false, 'no_permission')
    end
    targetSrc = Law.ToInt(targetSrc, 1)
    if not targetSrc or targetSrc == src then return Law.Result(false, 'invalid') end
    local target = Law.Ctx(targetSrc)
    if not target then return Law.Result(false, 'no_target') end
    if not Law.IsNear(src, targetSrc, WCfg.InspectDistance or 3.0) then return Law.Result(false, 'too_far') end
    if WCfg.InspectRequiresCuffs and not (Law.IsCuffed(targetSrc) or target.isDead) then
        return Law.Result(false, 'weapons_target_not_cuffed')
    end

    local list, serials = {}, {}
    for _, w in ipairs(Law.Inv:getUserInventoryWeapons(targetSrc) or {}) do
        if isFirearm(w.name) then
            local serial = (type(w.serial_number) == 'string' and w.serial_number ~= '') and w.serial_number or nil
            list[#list + 1] = {
                serial = serial, weapon = w.name, weaponLabel = label(w.name),
                filed = serial == WCfg.FiledSerial, status = 'unregistered', statusLabel = statusLabel('unregistered'),
            }
            if validSerial(serial) then serials[#serials + 1] = serial end
        end
    end
    if #serials > 0 then
        local map = {}
        for _, r in ipairs(MySQL.query.await(('SELECT serial, owner_charid, owner_name, status FROM ara_law_weapons WHERE serial IN (%s)'):format(placeholders(#serials)), serials) or {}) do
            map[r.serial] = r
        end
        for _, e in ipairs(list) do
            local r = e.serial and map[e.serial]
            if r then
                e.status = r.status
                e.statusLabel = statusLabel(r.status)
                e.ownerName = r.owner_name
                e.foreign = tonumber(r.owner_charid) ~= target.charId
            end
        end
    end
    Law.Audit(ctx, 'weapons.inspect', target.charId, { count = #list })
    return Law.Result(true, { name = target.name, weapons = list })
end)

--------------------------------------------------------------------------
-- Waffenfeile (jeder): Start/Ende-Muster, Zeit wird serverseitig gemessen
--------------------------------------------------------------------------
local filing = {}  -- [src] = { weaponId, serial, startedAt }

Law.Items.RegisterUsable(Config.Items.GunFile, function(src)
    -- Law.Ask blockiert - nie im vorp-Rueckruf selbst warten
    CreateThread(function()
        if filing[src] then return end
        local choices = {}
        for _, w in ipairs(Law.Inv:getUserInventoryWeapons(src) or {}) do
            if isFirearm(w.name) and validSerial(w.serial_number) then
                choices[#choices + 1] = { id = tonumber(w.id), label = label(w.name), serial = w.serial_number }
            end
        end
        if #choices == 0 then return Law.Notify(src, L('weapons_file_none'), 'error') end

        local choice = Law.ToInt(Law.Ask(src, 'weapons:chooseFile', { weapons = choices }, 30000), 1)
        if not choice then return end
        local w = ownWeapon(src, choice)
        if not w or not validSerial(w.serial_number) then return Law.Notify(src, L('err_weapons_not_found'), 'error') end
        if Law.Items.Count(src, Config.Items.GunFile) < 1 then return end
        if Law.IsCuffed(src) then return end

        filing[src] = { weaponId = tonumber(w.id), serial = w.serial_number, startedAt = GetGameTimer() }
        TriggerClientEvent('ara_law:cl:weapons:fileStart', src, (WCfg.File and WCfg.File.Seconds) or 10)
    end)
end, { notCuffed = true, notJailed = true, alive = true })

Law.Net.On('weapons:fileFinish', { rate = 1000 }, function(src, ctx, cancelled)
    local f = filing[src]
    filing[src] = nil
    if not f then return end
    if Law.ToBool(cancelled) then return Law.Notify(src, L('weapons_file_cancelled'), 'info') end
    local seconds = (WCfg.File and WCfg.File.Seconds) or 10
    if GetGameTimer() - f.startedAt < seconds * 1000 - 500 then return end  -- zu schnell = manipuliert
    if Law.IsCuffed(src) or ctx.isDead then return end

    local w = ownWeapon(src, f.weaponId)
    if not w or w.serial_number ~= f.serial then return Law.Notify(src, L('err_weapons_not_found'), 'error') end
    if Law.Items.Count(src, Config.Items.GunFile) < 1 then return Law.Notify(src, L('weapons_file_no_item'), 'error') end

    if math.random(1, 100) <= ((WCfg.File and WCfg.File.Chance) or 80) then
        Law.Inv:setWeaponSerialNumber(src, f.weaponId, WCfg.FiledSerial)
        Law.Notify(src, L('weapons_file_success'), 'success')
        -- Registereintrag bleibt unveraendert (Status wie vorher)
        Law.Audit(ctx, 'weapons.filed', nil, { serial = f.serial, weapon = w.name })
    elseif math.random(1, 100) <= ((WCfg.File and WCfg.File.BreakChance) or 30) then
        Law.Items.Take(src, Config.Items.GunFile, 1)
        Law.Notify(src, L('weapons_file_broke'), 'error')
    else
        Law.Notify(src, L('weapons_file_failed'), 'error')
    end
end)

--------------------------------------------------------------------------
-- Waffenschein (Dokument aus der DB, Metadaten sind nur Verweis)
--------------------------------------------------------------------------
Law.Items.RegisterUsable(Config.Items.WeaponPermit, function(src, ctx, item)
    local meta = type(item.metadata) == 'table' and item.metadata or {}
    CreateThread(function()
        local serial = Law.ToStr(meta.serial, 50)
        if not validSerial(serial) then return Law.Notify(src, L('weapons_permit_invalid'), 'error') end
        local row = MySQL.single.await('SELECT * FROM ara_law_weapons WHERE serial = ?', { serial })
        local holderOk = row and tostring(row.owner_charid or '') == tostring(meta.owner_charid or row.owner_charid or '')
        local valid = row ~= nil and row.status == 'registered' and holderOk
        local deptKey = WCfg.FeeDepartment or 'sheriff'
        TriggerClientEvent('ara_law:cl:weapons:document', src, {
            kind     = 'permit',
            title    = L('weapons_permit_title'),
            subtitle = valid and L('weapons_permit_valid') or L('weapons_permit_void'),
            fields   = {
                { label = L('weapons_permit_serial'), value = serial },
                { label = L('weapons_permit_weapon'), value = row and label(row.weapon) or tostring(meta.weapon or '-') },
                { label = L('weapons_permit_owner'),  value = row and row.owner_name or tostring(meta.owner or '-') },
                { label = L('weapons_permit_date'),   value = row and Law.Evidence.FormatTime(row.registered_at) or '-' },
                { label = L('weapons_permit_status'), value = statusLabel(row and row.status or 'unregistered') },
            },
            footer   = L('weapons_permit_footer', (Config.Departments[deptKey] or {}).label or deptKey),
            seal     = Law.Evidence.SealOf(deptKey),
        })
    end)
end, {})

Law.Modules.Register('weapons', {
    playerDropped = function(src)
        filing[src] = nil
    end,
    stop = function()
        filing = {}
    end,
})
