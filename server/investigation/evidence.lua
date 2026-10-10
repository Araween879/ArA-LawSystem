--[[
    ArA-LawSystem - Spuren, Labor, Asservatenkammer, Schmauchtest (Server)

    Welt-Spuren leben NUR im Server-Speicher. Erst beim Sichern entsteht eine
    DB-Zeile (ara_law_evidence) und ein Item, das nur auf diese Zeile zeigt -
    Kopieren oder Umbenennen des Items bringt also nichts.

    Spuren gehen nur an Gesetz im Dienst mit Recht `evidence`, nur auf
    Anfrage und nur im Umkreis (sonst waeren sie ein "Wallhack").

    Client-Meldungen (Schuss, Verletzung) belasten NUR den Meldenden:
    Position = Server-Position, Seriennummer = aus SEINEM vorp-Inventar.
]]

local Cfg = Config.Evidence

Law.Evidence = Law.Evidence or {}

local TYPES      = { casing = true, blood = true, cloth = true, scent = true }
local STATUS     = { collected = true, analyzing = true, analyzed = true, destroyed = true }
local ANALYZABLE = { casing = true, blood = true, cloth = true }

local ITEM_BY_TYPE = {
    casing = Config.Items.Casing,
    blood  = Config.Items.BloodSample,
    cloth  = Config.Items.ClothScrap,
    scent  = Config.Items.ScentCloth,
}
local TYPE_BY_ITEM = {}
for kind, name in pairs(ITEM_BY_TYPE) do TYPE_BY_ITEM[name] = kind end

local world       = {}   -- [traceId] = { id, kind, coords, createdAt, count, ownerCharId?, weapon?, serial?, bloodType?, zone? }
local worldCount  = 0
local nextTraceId = 0
local lastShotAt  = {}   -- [charId] = unix
local analyzing   = {}   -- [evidenceId] = src

--------------------------------------------------------------------------
-- Hilfen (auch von weapons.lua, scent.lua und k9.lua benutzt)
--------------------------------------------------------------------------
-- Waffen-Hashes kommen als vorzeichenbehaftete 32-Bit-Zahl vom Client,
-- joaat() kann je nach Seite anders aussehen -> immer vorzeichenlos vergleichen.
local function u32(h)
    h = math.tointeger(tonumber(h) or 0) or 0
    if h < 0 then h = h + 4294967296 end
    return h
end

local FIREARM_PREFIX = { 'WEAPON_REVOLVER_', 'WEAPON_PISTOL_', 'WEAPON_REPEATER_', 'WEAPON_RIFLE_', 'WEAPON_SNIPERRIFLE_', 'WEAPON_SHOTGUN_' }

--- Nur Feuerwaffen hinterlassen Huelsen und stehen im Register
local function isFirearm(name)
    if type(name) ~= 'string' then return false end
    name = name:upper()
    for _, p in ipairs(FIREARM_PREFIX) do
        if name:sub(1, #p) == p then return true end
    end
    return false
end

-- Hash -> Waffenname, falls die Waffe nicht im Inventar steht (z.B. nicht ausgeruestet)
local NAME_BY_HASH = {}
for name in pairs(Config.Weapons.Labels or {}) do NAME_BY_HASH[u32(joaat(name))] = name end

local function weaponLabel(name)
    if type(name) ~= 'string' or name == '' then return L('evidence_weapon_unknown') end
    local labels = Config.Weapons.Labels or {}
    return labels[name] or labels[name:upper()] or name
end

local function typeLabel(kind) return L('evidence_type_' .. tostring(kind)) end
local function statusLabel(s) return L('evidence_status_' .. tostring(s)) end
local function isOn(v) return v == true or v == 1 end

local function zoneOf(coords)
    coords = Law.Vec(coords)
    if not coords then return nil end
    local zones = Config.Dispatch and Config.Dispatch.ShotsFired and Config.Dispatch.ShotsFired.Zones or {}
    local best, bestDist
    for _, z in ipairs(zones) do
        local d = #(coords - z.coords)
        if d <= z.radius and (not bestDist or d < bestDist) then best, bestDist = z, d end
    end
    return best and best.label or nil
end

local function fmtTime(t)
    t = tonumber(t)
    if not t or t <= 0 then return '-' end
    return os.date('%d.%m.%Y %H:%M', t)
end

local function sealOf(dept)
    local d = dept and Config.Departments[dept]
    return d and (d.seal or dept) or 'sheriff'
end

Law.Evidence.U32         = u32
Law.Evidence.IsFirearm   = isFirearm
Law.Evidence.WeaponLabel = weaponLabel
Law.Evidence.TypeLabel   = typeLabel
Law.Evidence.ZoneOf      = zoneOf
Law.Evidence.FormatTime  = fmtTime
Law.Evidence.SealOf      = sealOf
Law.Evidence.ItemByType  = ITEM_BY_TYPE
Law.Evidence.TypeByItem  = TYPE_BY_ITEM

--------------------------------------------------------------------------
-- Welt-Spuren (nur Speicher)
--------------------------------------------------------------------------
local function ageClass(t)
    local life = Cfg.Lifetime[t.kind] or 1800
    local age = Law.Now() - t.createdAt
    if age < life / 3 then return 'fresh' end
    if age < life * 2 / 3 then return 'medium' end
    return 'old'
end

local function putTrace(t)
    if not world[t.id] then
        world[t.id] = t
        worldCount = worldCount + 1
    end
end

local function removeTrace(id)
    if world[id] then
        world[id] = nil
        worldCount = worldCount - 1
    end
end

--- aelter = frueher entstanden; gleiche Sekunde -> kleinere Nummer (sonst koennte eine
--- gerade angelegte Spur eine andere aus derselben Sekunde verdraengen)
local function older(t, id, oldestAt, oldestId)
    return not oldestAt or t.createdAt < oldestAt or (t.createdAt == oldestAt and id < oldestId)
end

local function dropOldest()
    local oldestId, oldestAt
    for id, t in pairs(world) do
        if older(t, id, oldestAt, oldestId) then oldestId, oldestAt = id, t.createdAt end
    end
    if not oldestId then return false end
    removeTrace(oldestId)
    return true
end

--- Obergrenze je Verursacher: bei Dauerfeuer fliegt zuerst SEINE aelteste Spur,
--- damit ein Spieler keine fremden Tatort-Spuren aus dem Speicher draengen kann.
--- noEvict (Verletzungs-Meldungen vom Client): voll -> die NEUE Spur entfaellt,
--- es fliegt nichts Aelteres raus (sonst koennte man Tatort-Spuren wegspammen).
--- -> false, wenn die neue Spur nicht angelegt werden darf
local function capOwner(ownerCharId, noEvict)
    if not ownerCharId then return true end
    local limit = Cfg.MaxPerOwner or 40
    local count, oldestId, oldestAt = 0, nil, nil
    for id, t in pairs(world) do
        if t.ownerCharId == ownerCharId then
            count = count + 1
            if older(t, id, oldestAt, oldestId) then oldestId, oldestAt = id, t.createdAt end
        end
    end
    if count < limit then return true end
    if noEvict then return false end
    if oldestId then removeTrace(oldestId) end
    return true
end

local function addTrace(kind, coords, data)
    if not Cfg.Enabled or not Cfg.Lifetime[kind] then return nil end
    coords = Law.Vec(coords)
    if not coords then return nil end
    data = data or {}
    if not capOwner(tonumber(data.ownerCharId), data.noEvict) then return nil end
    while worldCount >= (Cfg.MaxWorld or 600) do
        if not dropOldest() then worldCount = 0 break end
    end
    nextTraceId = nextTraceId + 1
    local t = {
        id          = nextTraceId,
        kind        = kind,
        coords      = coords,
        createdAt   = Law.Now(),
        count       = 1,
        ownerCharId = tonumber(data.ownerCharId),
        weapon      = data.weapon,
        serial      = data.serial,
        bloodType   = data.bloodType,
        zone        = zoneOf(coords),
    }
    putTrace(t)
    return t
end

local function findNear(kind, ownerCharId, coords, radius, match)
    for _, t in pairs(world) do
        if t.kind == kind and t.ownerCharId == ownerCharId and #(t.coords - coords) <= radius
            and (not match or match(t)) then
            return t
        end
    end
    return nil
end

--- Vertrag 4.1: kind = casing|blood|cloth, data = { ownerCharId?, weapon?, serial?, bloodType? }
function Law.Evidence.CreateTrace(kind, coords, data)
    local t = addTrace(kind, coords, data)
    if not t then return nil end
    -- Blutgruppe nachladen, falls der Aufrufer sie nicht kennt (DB-Zugriff im eigenen Thread)
    if kind == 'blood' and not t.bloodType and t.ownerCharId then
        CreateThread(function()
            local c = Law.Citizens.Get(t.ownerCharId)
            if c and world[t.id] == t then t.bloodType = c.bloodType end
        end)
    end
    return t.id
end

--- Vertrag 4.1: letzter gemeldeter Schuss des Charakters (fuer Schmauchtest)
function Law.Evidence.LastShotAt(charId)
    return lastShotAt[tonumber(charId)]
end

--------------------------------------------------------------------------
-- Schuesse und Verletzungen (Client meldet nur "ich")
--------------------------------------------------------------------------
--- Waffe mit passendem Hash aus dem EIGENEN Inventar. Seriennummer nur,
--- wenn diese Waffe gerade ausgeruestet ist (used/used2).
local function weaponForShot(src, hash)
    local anyMatch
    for _, w in ipairs(Law.Inv:getUserInventoryWeapons(src) or {}) do
        if w.name and u32(joaat(w.name)) == hash then
            if isOn(w.used) or isOn(w.used2) then return w, true end
            anyMatch = anyMatch or w
        end
    end
    return anyMatch, false
end

Law.Net.On('evidence:shot', { rate = Cfg.ShotRateMs or 1500 }, function(src, ctx, weaponHash)
    if not Cfg.Enabled then return end
    local hash = Law.ToInt(weaponHash)
    if not hash then return end
    hash = u32(hash)
    local coords = Law.GetCoords(src)
    if not coords then return end

    local weapon, equipped = weaponForShot(src, hash)
    local name = weapon and weapon.name or NAME_BY_HASH[hash]
    -- Boegen, Wurfwaffen, Lasso, Unbekanntes: keine Huelse
    if not isFirearm(name) then return end
    local serial = nil
    if equipped and type(weapon.serial_number) == 'string' and weapon.serial_number ~= '' then
        serial = weapon.serial_number
    end

    lastShotAt[ctx.charId] = Law.Now()

    local merged = findNear('casing', ctx.charId, coords, Cfg.CasingMerge or 3.0, function(t)
        return t.serial == serial and t.weapon == name
    end)
    if merged then
        merged.count = merged.count + 1
        merged.createdAt = Law.Now()
    else
        local ang = math.random() * math.pi * 2
        local r = math.random() * (Cfg.CasingScatter or 1.2)
        addTrace('casing', vector3(coords.x + math.cos(ang) * r, coords.y + math.sin(ang) * r, coords.z),
            { ownerCharId = ctx.charId, weapon = name, serial = serial })
    end

    Law.Dispatch.ShotsFired(src, coords, weaponLabel(name))
end)

--- Verletzung (Client meldet nur die Art des Treffers an SICH selbst):
---   fist = Schlaegerei, shot = angeschossen, sharp = Messer/Axt, animal = Tierbiss, other
--- Blut/Kleidung wuerfelt der Server (Config.Evidence.Wounds), Position = Server-Position.
local WOUND_KEY = { fist = 'Fist', shot = 'Shot', sharp = 'Sharp', animal = 'Animal', other = 'Other' }
local lastBleedAt, lastClothAt = {}, {}  -- [charId] = GetGameTimer()

local function roll(chance)
    chance = tonumber(chance) or 0
    return chance > 0 and math.random(1, 100) <= chance
end

-- rate klein: der Client meldet hoechstens alle 400 ms, Netz-Schwankungen sollen
-- keinen Messerstich verschlucken (Spuren drosseln BleedRateMs/ClothRateMs)
Law.Net.On('evidence:wound', { rate = 100 }, function(src, ctx, kind)
    if not Cfg.Enabled then return end
    local w = (Cfg.Wounds or {})[WOUND_KEY[kind] or '']
    if not w then return end
    local coords = Law.GetCoords(src)
    if not coords then return end
    local now = GetGameTimer()

    if roll(w.Blood) and now - (lastBleedAt[ctx.charId] or -1e9) >= (Cfg.BleedRateMs or 5000) then
        lastBleedAt[ctx.charId] = now
        local near = findNear('blood', ctx.charId, coords, 2.0)
        if near then
            near.count = near.count + 1
            near.createdAt = Law.Now()
        else
            local citizen = Law.Citizens.Get(ctx.charId)
            addTrace('blood', coords, { ownerCharId = ctx.charId, bloodType = citizen and citizen.bloodType or nil, noEvict = true })
        end
    end

    if roll(w.Cloth) and now - (lastClothAt[ctx.charId] or -1e9) >= (Cfg.ClothRateMs or 60000) then
        lastClothAt[ctx.charId] = now
        local ang = math.random() * math.pi * 2
        local r = 0.3 + math.random() * 0.7
        addTrace('cloth', vector3(coords.x + math.cos(ang) * r, coords.y + math.sin(ang) * r, coords.z),
            { ownerCharId = ctx.charId, noEvict = true })
    end
end)

--------------------------------------------------------------------------
-- Spurensuche und Sichern
--------------------------------------------------------------------------
Law.Cb.Register('evidence:scan', { perm = 'evidence', rate = math.max(500, (Cfg.ScanCooldown or 3) * 1000 - 500) }, function(src)
    local me = Law.GetCoords(src)
    if not me then return Law.Result(false, 'failed') end
    local radius = Cfg.ScanRadius or 30.0
    local found = {}
    for _, t in pairs(world) do
        local d = #(t.coords - me)
        if d <= radius then found[#found + 1] = { t = t, d = d } end
    end
    table.sort(found, function(a, b) return a.d < b.d end)
    -- Nur Art, Ort und Alter - KEINE Seriennummer, KEIN Besitzer
    local out = {}
    for i = 1, math.min(#found, 60) do
        local t = found[i].t
        out[#out + 1] = { id = t.id, kind = t.kind, coords = Law.VecToTable(t.coords), ageClass = ageClass(t) }
    end
    return Law.Result(true, out)
end)

local function itemDescription(kind, evId, zone, t, count)
    local text = L('evidence_item_desc', typeLabel(kind), evId, zone or L('evidence_zone_unknown'), fmtTime(t))
    if count and count > 1 then text = text .. ' ' .. L('evidence_item_count', count) end
    return text
end

Law.Cb.Register('evidence:collect', { perm = 'evidence', rate = 1000, notCuffed = true, alive = true }, function(src, ctx, id)
    id = Law.ToInt(id, 1)
    local t = id and world[id]
    if not t then return Law.Result(false, 'evidence_gone') end
    if not Law.IsNearCoords(src, t.coords, Cfg.CollectDistance or 2.0) then return Law.Result(false, 'too_far') end
    local itemName = ITEM_BY_TYPE[t.kind]
    -- Womit wird gesichert? Blut: steriles Tuch, sonst Beweismittelbeutel
    local tool = (Cfg.CollectWith or {})[t.kind] or Config.Items.EvidenceBag
    local noTool = tool == Config.Items.SterileCloth and 'evidence_no_sterile' or 'evidence_no_bag'
    if Law.Items.Count(src, tool) < 1 then return Law.Result(false, noTool) end
    if not Law.Inv:canCarryItem(src, itemName, 1) then return Law.Result(false, 'cant_carry') end

    -- Spur sofort aus der Welt nehmen: ein zweiter Officer kann sie nicht mehr sichern
    removeTrace(id)
    if not Law.Items.Take(src, tool, 1) then
        putTrace(t)
        return Law.Result(false, noTool)
    end

    -- oxmysql-.await WIRFT bei SQL-Fehlern -> Law.DB.Try, sonst waere der Beutel weg
    local now = Law.Now()
    local okInsert, evId = Law.DB.Try(MySQL.insert.await, [[INSERT INTO ara_law_evidence
        (type, weapon, serial, owner_charid, blood_type, x, y, z, zone, created_at, collected_by, collected_by_name, collected_at, department, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'collected')]],
        { t.kind, t.weapon, t.serial, t.ownerCharId, t.bloodType, t.coords.x, t.coords.y, t.coords.z, t.zone,
          t.createdAt, ctx.charId, ctx.name, now, ctx.dept or '' })
    if not okInsert or not evId then
        Law.Items.Give(src, tool, 1)
        putTrace(t)
        return Law.Result(false, 'failed')
    end

    local desc = itemDescription(t.kind, evId, t.zone, t.createdAt, t.count)
    -- Geruchstraeger mit Ablauf (z.B. Blut 60 Min.): bis wann taugt er fuer den Hund?
    local minutes = Law.Scent.ItemMinutes and Law.Scent.ItemMinutes(itemName) or 0
    if minutes > 0 then desc = desc .. ' ' .. L('evidence_item_scent_until', os.date('%H:%M', t.createdAt + minutes * 60)) end
    local meta = { evidence_id = evId, description = desc }
    if not Law.Items.Give(src, itemName, 1, meta) then
        Law.DB.Try(MySQL.update.await, 'DELETE FROM ara_law_evidence WHERE id = ?', { evId })
        Law.Items.Give(src, tool, 1)
        putTrace(t)
        return Law.Result(false, 'cant_carry')
    end

    Law.Audit(ctx, 'evidence.collect', t.ownerCharId, { id = evId, type = t.kind, zone = t.zone, count = t.count })
    return Law.Result(true, { evidenceId = evId, kind = t.kind }, L('evidence_collected', typeLabel(t.kind), evId))
end)

--------------------------------------------------------------------------
-- Asservatenkammer (vorp-Custom-Inventar je Behoerde)
--------------------------------------------------------------------------
local lockers = {}  -- [invId] = true (fuer das Aufraeumen)

local function lockerId(dept)
    return 'ara_law_evidence_' .. dept
end

local function ensureLocker(dept)
    local id = lockerId(dept)
    if not Law.Inv:isCustomInventoryRegistered(id) then
        local d = Law.GetDept(dept)
        Law.Inv:registerInventory({
            id = id,
            name = L('evidence_locker_name', d and d.short or dept),
            limit = Cfg.LockerLimit or 500,
            acceptWeapons = true,
            shared = true,
            ignoreItemStackLimit = true,
            whitelistItems = false,
            UsePermissions = false,
            UseBlackList = false,
            whitelistWeapons = false,
        })
    end
    lockers[id] = true
    return id
end

Law.Net.On('evidence:openLocker', { perm = 'evidence', rate = 1500, notCuffed = true }, function(src, ctx)
    local station = Law.Stations.NearPoint(src, 'evidence')
    if not station or not Law.Stations.AllowsDept(station, ctx.dept) then
        return Law.Notify(src, L('err_not_at_point'), 'error')
    end
    Law.Inv:openInventory(src, ensureLocker(ctx.dept))
    Law.Audit(ctx, 'evidence.locker', nil, { station = station })
end)

--------------------------------------------------------------------------
-- Labor
--------------------------------------------------------------------------
Law.Cb.Register('evidence:myItems', { perm = 'evidence', rate = 1000 }, function(src)
    local out = {}
    for _, it in ipairs(Law.Inv:getUserInventoryItems(src) or {}) do
        local kind = TYPE_BY_ITEM[it.name]
        local meta = type(it.metadata) == 'table' and it.metadata or {}
        if kind and ANALYZABLE[kind] and tonumber(meta.evidence_id) then
            out[#out + 1] = {
                id          = it.id,
                name        = it.name,
                kind        = kind,
                typeLabel   = typeLabel(kind),
                evidenceId  = tonumber(meta.evidence_id),
                description = meta.description or it.desc or '',
            }
        end
    end
    table.sort(out, function(a, b) return a.evidenceId > b.evidenceId end)
    return Law.Result(true, out)
end)

--- Ergebnis der Auswertung. Liest nur aus der DB - Item-Metadaten sind nur Verweis.
local function buildAnalysis(row)
    local lines, match, summary = {}, nil, nil
    local owner = tonumber(row.owner_charid)

    if row.type == 'casing' then
        local wl = weaponLabel(row.weapon)
        lines[#lines + 1] = L('evidence_an_weapon', wl)
        local serial = row.serial
        if type(serial) ~= 'string' or serial == '' then
            lines[#lines + 1] = L('evidence_an_no_serial')
            summary = L('evidence_sum_casing_noserial', wl)
        elseif serial == Config.Weapons.FiledSerial then
            lines[#lines + 1] = L('evidence_an_filed')
            summary = L('evidence_sum_casing_filed', wl)
        else
            lines[#lines + 1] = L('evidence_an_serial', serial)
            local reg = MySQL.single.await('SELECT owner_charid, owner_name, status FROM ara_law_weapons WHERE serial = ?', { serial })
            if reg then
                lines[#lines + 1] = L('evidence_an_registered', reg.owner_name or '?', L('weapons_status_' .. tostring(reg.status)))
                if tonumber(reg.owner_charid) then
                    match = { charId = tonumber(reg.owner_charid), name = reg.owner_name or Law.GetCharName(reg.owner_charid) }
                end
            else
                lines[#lines + 1] = L('evidence_an_unregistered')
            end
            if Cfg.RevealCurrentHolder then
                local holder = Law.Weapons.CurrentHolder and Law.Weapons.CurrentHolder(serial) or nil
                if holder then
                    lines[#lines + 1] = L('evidence_an_holder', holder.name)
                    -- Ohne Registereintrag ist der aktuelle Besitzer die einzige Spur
                    if not match and holder.charId then match = { charId = holder.charId, name = holder.name } end
                end
            end
            summary = match and L('evidence_sum_casing_match', wl, match.name) or L('evidence_sum_casing', wl, serial)
        end
    elseif row.type == 'blood' then
        local bt = (type(row.blood_type) == 'string' and row.blood_type ~= '') and row.blood_type or '?'
        lines[#lines + 1] = L('evidence_an_blood', bt)
        local n = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM ara_law_citizens WHERE has_sample = 1 AND blood_type = ?', { bt })) or 0
        lines[#lines + 1] = L('evidence_an_blood_samples', n)
        if owner then
            local c = Law.Citizens.Get(owner)
            -- Treffer nur, wenn eine Probe in der Akte liegt UND die Blutgruppe passt
            if c and c.hasSample and c.bloodType == bt then match = { charId = owner, name = Law.GetCharName(owner) } end
        end
        summary = match and L('evidence_sum_blood_match', bt, match.name) or L('evidence_sum_blood', bt)
    elseif row.type == 'cloth' then
        lines[#lines + 1] = L('evidence_an_cloth')
        if owner then
            local c = Law.Citizens.Get(owner)
            if c and c.hasSample then match = { charId = owner, name = Law.GetCharName(owner) } end
        end
        summary = match and L('evidence_sum_cloth_match', match.name) or L('evidence_sum_cloth')
    end

    lines[#lines + 1] = match and L('evidence_an_match', match.name) or L('evidence_an_nomatch')
    return { summary = summary or '-', lines = lines, match = match }
end

local function evidenceDocument(row, analysis)
    analysis = analysis or {}
    return {
        kind      = 'evidence',
        title     = L('evidence_doc_title', row.id),
        subtitle  = analysis.summary or typeLabel(row.type),
        fields    = {
            { label = L('evidence_doc_type'),      value = typeLabel(row.type) },
            { label = L('evidence_doc_place'),     value = row.zone or L('evidence_zone_unknown') },
            { label = L('evidence_doc_found'),     value = fmtTime(row.created_at) },
            { label = L('evidence_doc_collected'), value = ('%s (%s)'):format(row.collected_by_name or '?', fmtTime(row.collected_at)) },
            { label = L('evidence_doc_analyzed'),  value = ('%s (%s)'):format(row.analyzed_by_name or '?', fmtTime(row.analyzed_at)) },
        },
        body      = table.concat(analysis.lines or {}, '\n'),
        footer    = L('evidence_doc_footer'),
        seal      = sealOf(row.department),
        signature = row.analyzed_by_name,
    }
end

local function finishAnalysis(evId, itemId, officer)
    analyzing[evId] = nil
    local row = MySQL.single.await('SELECT * FROM ara_law_evidence WHERE id = ?', { evId })
    if not row or row.status ~= 'analyzing' then return end
    local analysis = buildAnalysis(row)
    local now = Law.Now()
    local affected = MySQL.update.await("UPDATE ara_law_evidence SET status = 'analyzed', analysis = ?, analyzed_by_name = ?, analyzed_at = ? WHERE id = ? AND status = 'analyzing'",
        { json.encode(analysis), officer.name, now, evId })
    if affected ~= 1 then return end
    row.status, row.analyzed_by_name, row.analyzed_at = 'analyzed', officer.name, now

    if analysis.match then
        Law.Records.Add(analysis.match.charId, 'evidence', L('evidence_record_title', typeLabel(row.type), evId), analysis.summary, officer, evId)
    end
    Law.Audit(officer, 'evidence.analyzed', analysis.match and analysis.match.charId or nil,
        { id = evId, type = row.type, summary = analysis.summary })

    local src = Law.SrcByCharId(officer.charId)
    if not src then return end
    local item = Law.Items.GetById(src, itemId)
    if item and type(item.metadata) == 'table' and tonumber(item.metadata.evidence_id) == evId then
        local meta = Law.Copy(item.metadata)
        meta.description = L('evidence_item_desc_analyzed', typeLabel(row.type), evId, analysis.summary)
        Law.Items.SetMetadata(src, itemId, meta)
    end
    Law.Notify(src, L('evidence_analysis_done', evId), 'success')
    TriggerClientEvent('ara_law:cl:evidence:document', src, evidenceDocument(row, analysis))
end

Law.Cb.Register('evidence:analyze', { perm = 'evidence_analyze', rate = 2000, notCuffed = true }, function(src, ctx, itemId)
    itemId = Law.ToInt(itemId, 1)
    if not itemId then return Law.Result(false, 'invalid') end
    local station = Law.Stations.NearPoint(src, 'evidence')
    if not station or not Law.Stations.AllowsDept(station, ctx.dept) then return Law.Result(false, 'not_at_point') end

    local item = Law.Items.GetById(src, itemId)
    local kind = item and TYPE_BY_ITEM[item.name]
    local meta = item and type(item.metadata) == 'table' and item.metadata or {}
    local evId = tonumber(meta.evidence_id)
    if not kind or not ANALYZABLE[kind] or not evId then return Law.Result(false, 'evidence_not_item') end

    local row = MySQL.single.await('SELECT * FROM ara_law_evidence WHERE id = ?', { evId })
    if not row or row.type ~= kind then return Law.Result(false, 'evidence_not_item') end
    if row.status == 'destroyed' then return Law.Result(false, 'evidence_destroyed') end
    if row.status == 'analyzed' then
        -- Schon ausgewertet: nur den Bericht erneut zeigen
        TriggerClientEvent('ara_law:cl:evidence:document', src, evidenceDocument(row, Law.DB.Decode(row.analysis, {})))
        return Law.Result(true, { seconds = 0, done = true })
    end
    if row.status ~= 'collected' then return Law.Result(false, 'evidence_busy') end

    local affected = MySQL.update.await("UPDATE ara_law_evidence SET status = 'analyzing' WHERE id = ? AND status = 'collected'", { evId })
    if affected ~= 1 then return Law.Result(false, 'evidence_busy') end

    local officer = { charId = ctx.charId, name = ctx.name, dept = ctx.dept }
    analyzing[evId] = src
    local seconds = Cfg.AnalysisSeconds or 60
    SetTimeout(seconds * 1000, function()
        CreateThread(function()
            local ok, err = xpcall(finishAnalysis, debug.traceback, evId, itemId, officer)
            if not ok then
                Law.Warn('Auswertung #%s fehlgeschlagen: %s', tostring(evId), tostring(err))
                MySQL.update("UPDATE ara_law_evidence SET status = 'collected' WHERE id = ? AND status = 'analyzing'", { evId })
            end
        end)
    end)
    Law.Audit(ctx, 'evidence.analyze', nil, { id = evId, type = kind })
    return Law.Result(true, { seconds = seconds }, L('evidence_analysis_started', seconds))
end)

--------------------------------------------------------------------------
-- Dienstbuch (Tab "evidence")
--------------------------------------------------------------------------
local function toPublic(r)
    local analyzed = r.status == 'analyzed'
    local analysis = analyzed and Law.DB.Decode(r.analysis, nil) or nil
    local pub = {
        id              = tonumber(r.id),
        type            = r.type,
        typeLabel       = typeLabel(r.type),
        zone            = r.zone,
        createdAt       = tonumber(r.created_at),
        collectedByName = r.collected_by_name,
        collectedAt     = tonumber(r.collected_at),
        status          = r.status,
        statusLabel     = statusLabel(r.status),
        department      = r.department,
        analyzedByName  = r.analyzed_by_name,
        analyzedAt      = tonumber(r.analyzed_at),
        analysis        = analysis,
    }
    -- Fakten erst nach dem Labor zeigen (sonst waere das Labor ueberfluessig)
    if analyzed and r.type == 'casing' then
        pub.weaponLabel = weaponLabel(r.weapon)
        pub.serial = r.serial
    elseif analyzed and r.type == 'blood' then
        pub.bloodType = r.blood_type
    end
    -- Geruchsprobe wurde an einer bekannten Person genommen
    if r.type == 'scent' and tonumber(r.owner_charid) then
        pub.subjectName = Law.GetCharName(r.owner_charid)
    end
    return pub
end

Law.Cb.Register('evidence:list', { perm = 'evidence', rate = 800 }, function(src, ctx, filter)
    local status, kind, idFilter
    if type(filter) == 'table' then
        status = Law.ToStr(filter.status, 12)
        kind = Law.ToStr(filter.type, 12)
        idFilter = Law.ToInt(filter.id or filter.query, 1)
    elseif type(filter) == 'string' or type(filter) == 'number' then
        local f = Law.ToStr(filter, 12)
        if f and (STATUS[f] or f == 'all') then status = f
        elseif f and TYPES[f] then kind = f
        else idFilter = Law.ToInt(f, 1) end
    end

    local where, params = {}, {}
    if status and STATUS[status] then
        where[#where + 1] = 'status = ?'
        params[#params + 1] = status
    elseif status ~= 'all' then
        where[#where + 1] = "status <> 'destroyed'"
    end
    if kind and TYPES[kind] then
        where[#where + 1] = 'type = ?'
        params[#params + 1] = kind
    end
    if idFilter then
        where[#where + 1] = 'id = ?'
        params[#params + 1] = idFilter
    end
    local sql = 'SELECT * FROM ara_law_evidence'
    if #where > 0 then sql = sql .. ' WHERE ' .. table.concat(where, ' AND ') end
    sql = sql .. ' ORDER BY id DESC LIMIT 100'

    local out = {}
    for _, r in ipairs(MySQL.query.await(sql, params) or {}) do out[#out + 1] = toPublic(r) end
    return Law.Result(true, out)
end)

Law.Cb.Register('evidence:get', { perm = 'evidence', rate = 500 }, function(src, ctx, id)
    id = Law.ToInt(id, 1)
    if not id then return Law.Result(false, 'invalid') end
    local r = MySQL.single.await('SELECT * FROM ara_law_evidence WHERE id = ?', { id })
    if not r then return Law.Result(false, 'not_found') end
    return Law.Result(true, toPublic(r))
end)

Law.Cb.Register('evidence:destroy', { perm = 'evidence_analyze', rate = 1500 }, function(src, ctx, id)
    id = Law.ToInt(id, 1)
    if not id then return Law.Result(false, 'invalid') end
    -- Vernichten nur in der Asservatenkammer und nur Beweise der eigenen Behoerde
    local station = Law.Stations.NearPoint(src, 'evidence')
    if not station or not Law.Stations.AllowsDept(station, ctx.dept) then return Law.Result(false, 'not_at_point') end
    local row = MySQL.single.await('SELECT department, status, owner_charid FROM ara_law_evidence WHERE id = ?', { id })
    if not row then return Law.Result(false, 'not_found') end
    if row.department ~= ctx.dept then return Law.Result(false, 'evidence_foreign_dept') end
    -- Niemand vernichtet Beweise gegen sich selbst (oder seinen Zweitcharakter)
    if tonumber(row.owner_charid) and Law.IsSelfOrAlt(ctx, row.owner_charid) then
        return Law.Result(false, 'self_target')
    end
    local affected = MySQL.update.await("UPDATE ara_law_evidence SET status = 'destroyed' WHERE id = ? AND department = ? AND status IN ('collected','analyzed')",
        { id, ctx.dept })
    if affected ~= 1 then return Law.Result(false, 'evidence_busy') end
    Law.Audit(ctx, 'evidence.destroy', nil, { id = id })
    return Law.Result(true, nil, L('evidence_destroyed', id))
end)

--------------------------------------------------------------------------
-- Schmauchspurentest
--------------------------------------------------------------------------
Law.Cb.Register('evidence:gsr', { perm = 'evidence', rate = 3000, notCuffed = true, alive = true }, function(src, ctx, targetSrc)
    targetSrc = Law.ToInt(targetSrc, 1)
    if not targetSrc or targetSrc == src then return Law.Result(false, 'invalid') end
    local target = Law.Ctx(targetSrc)
    if not target then return Law.Result(false, 'no_target') end
    if not Law.IsNear(src, targetSrc, (Cfg.Gsr and Cfg.Gsr.Distance) or 2.5) then return Law.Result(false, 'too_far') end
    local t = lastShotAt[target.charId]
    local positive = t ~= nil and Law.Now() - t <= ((Cfg.Gsr and Cfg.Gsr.Minutes) or 15) * 60
    Law.Notify(targetSrc, L('evidence_gsr_target', ctx.name), 'info')
    Law.Audit(ctx, 'evidence.gsr', target.charId, { positive = positive })
    return Law.Result(true, { positive = positive, name = target.name },
        positive and L('evidence_gsr_positive', target.name) or L('evidence_gsr_negative', target.name))
end)

--------------------------------------------------------------------------
-- Aufraeumen, Lebenszyklus
--------------------------------------------------------------------------
Law.Every(30000, function()
    local now = Law.Now()
    for id, t in pairs(world) do
        if now - t.createdAt > (Cfg.Lifetime[t.kind] or 1800) then removeTrace(id) end
    end
    local gsrLimit = now - ((Cfg.Gsr and Cfg.Gsr.Minutes) or 15) * 120
    for charId, at in pairs(lastShotAt) do
        if at < gsrLimit then lastShotAt[charId] = nil end
    end
    -- Drosseln fuer Verletzungen: alte Eintraege weg (GetGameTimer in ms)
    local ms = GetGameTimer()
    for charId, at in pairs(lastBleedAt) do if ms - at > 600000 then lastBleedAt[charId] = nil end end
    for charId, at in pairs(lastClothAt) do if ms - at > 600000 then lastClothAt[charId] = nil end end
end)

Law.Modules.Register('evidence', {
    init = function()
        -- Neustart waehrend einer Auswertung: zurueck auf "gesichert"
        MySQL.update.await("UPDATE ara_law_evidence SET status = 'collected' WHERE status = 'analyzing'")
    end,
    stop = function()
        for id in pairs(lockers) do
            pcall(function() Law.Inv:removeInventory(id) end)
        end
        lockers = {}
        world = {}
        worldCount = 0
    end,
})
