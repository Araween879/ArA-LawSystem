--[[
    ArA-LawSystem - Eskorte: Auftraege, Preise, Zustandsautomat (Server)

    Zustaende (ara_law_escorts.status) und erlaubte Wechsel - JEDER Wechsel
    ist ein atomares UPDATE ... WHERE id = ? AND status = ? mit
    affectedRows == 1. Geld/Ware fliessen erst NACH dem Wechsel:
      open      -> accepted (erste Annahme) | cancelled (Kunde) | expired
      accepted  -> active (Start) | open (alle weg) | expired
      active    -> delivered (Werttransport) | completed (Schutz/Transport)
                 | failed (Wagen/Leiter weg, Frist, VIP tot) | robbed (Ueberfall)
      delivered -> claimed (Empfaenger am Zielbuero)
    Neustart: active -> accepted (Wagen weg, neu starten).

    Preise nur hier. Eskort-Bueros = Config.Stations mit points.escort.
]]

Law.Escort = Law.Escort or {}
local ES = Law.Escort
local ECfg = Config.Escort

ES.Active  = ES.Active or {}   -- [id] = Laufzeit einer aktiven Eskorte (incidents.lua prueft sie)
ES.Pending = ES.Pending or {}  -- [id] = { src, t, spawn } Wagen-Spawn angefragt
ES.Alerts  = ES.Alerts or {}   -- [id] = Leitstellen-Einsatz der Buchung
ES.Robbed  = ES.Robbed or {}   -- [netId] = { id, robberCharId } ueberfallener Wagen (Beute)

local TYPE_ORDER = { 'bodyguard', 'transport', 'cargo' }
local RETURN_STATES = { failed = true, cancelled = true, expired = true }

--------------------------------------------------------------------------
-- Bueros
--------------------------------------------------------------------------
local function pointList(p)
    if not p then return {} end
    if p.coords then return { p } end
    return p
end

function ES.Point(key)
    local st = key and Config.Stations[key]
    local list = st and st.points and pointList(st.points.escort) or {}
    return list[1]
end

function ES.PointCoords(key)
    local p = ES.Point(key)
    return p and Law.Vec(p.coords) or nil
end

function ES.StationLabel(key)
    local st = key and Config.Stations[key]
    return st and st.label or tostring(key or '-')
end

function ES.Offices()
    local out = {}
    for key in pairs(Config.Stations) do
        if ES.Point(key) then out[#out + 1] = key end
    end
    table.sort(out, function(a, b) return ES.StationLabel(a) < ES.StationLabel(b) end)
    return out
end

--- Luftlinie in km zwischen zwei Eskort-Punkten
function ES.Km(a, b)
    local pa, pb = ES.PointCoords(a), ES.PointCoords(b)
    if not pa or not pb then return 0 end
    return #(pa - pb) / 1000.0
end

--- Steht der Spieler am Schalter oder Eskort-Punkt eines Eskort-Bueros?
function ES.AtOffice(src)
    local k = Law.Stations.NearPoint(src, 'counter')
    if k and ES.Point(k) then return k end
    return Law.Stations.NearPoint(src, 'escort')
end

function ES.DeptAllowed(dept)
    return dept ~= nil and Law.Contains(ECfg.AllowedDepts or {}, dept)
end

function ES.NotifyChar(charId, text, kind)
    local s = Law.SrcByCharId(charId)
    if s then Law.Notify(s, text, kind or 'info') end
end

function ES.Row(id)
    id = tonumber(id)
    if not id then return nil end
    return MySQL.single.await('SELECT * FROM ara_law_escorts WHERE id = ?', { id })
end

--- Begleiter: waehrend der Fahrt aus der Laufzeit (dort zaehlen die Ticks), sonst aus der DB
function ES.Members(r)
    local a = r and ES.Active[tonumber(r.id)]
    if a then return a.members end
    local list = Law.DB.Decode(r and r.escorts, {})
    local out = {}
    if type(list) == 'table' then
        for _, m in ipairs(list) do
            if type(m) == 'table' and tonumber(m.charId) then
                out[#out + 1] = {
                    charId = tonumber(m.charId), name = tostring(m.name or '?'), identifier = m.identifier,
                    dept = m.dept, ticks = tonumber(m.ticks) or 0,
                }
            end
        end
    end
    return out
end

local function copyList(list)
    local out = {}
    for i, v in ipairs(list) do out[i] = v end
    return out
end

function ES.ClaimOffice(r)
    if r.claim_office and r.claim_office ~= '' then return r.claim_office end
    if r.status == 'delivered' or r.status == 'claimed' then return r.destination end
    return r.pickup
end

--- Darf charId etwas aus diesem Auftrag abholen?
function ES.CanClaim(r, charId)
    charId = tonumber(charId)
    if not charId then return false end
    local client = tonumber(r.client_charid)
    local recipient = tonumber(r.recipient_charid) or client
    if r.status == 'delivered' then
        if recipient == charId then return true end
        -- Nach ClaimExpireDays darf auch der Auftraggeber abholen (Ware verfaellt nie)
        local finished = tonumber(r.finished_at) or 0
        return client == charId and Law.Now() - finished > (ECfg.ClaimExpireDays or 14) * 86400
    end
    if r.status == 'claimed' then
        return r.status_reason == ('claim:' .. charId)  -- Fach erneut oeffnen
    end
    if RETURN_STATES[r.status] then
        return client == charId and #ES.CargoList(r) > 0
    end
    return false
end

function ES.CargoSummary(r)
    local items = ES.GetCargoItems()
    local parts = {}
    for _, e in ipairs(ES.CargoList(r)) do
        parts[#parts + 1] = ('%dx %s'):format(e.amount, items[e.name] and items[e.name].label or e.name)
    end
    local money, gold = tonumber(r.cargo_money) or 0, tonumber(r.cargo_gold) or 0
    if money > 0 then parts[#parts + 1] = L('escort_summary_money', money) end
    if gold > 0 then parts[#parts + 1] = L('escort_summary_gold', gold) end
    if #parts == 0 then return nil end
    return table.concat(parts, ', ')
end

--- Vertrag 10.6 Escort (+ Zusatzfelder)
function ES.Public(r, viewerCharId)
    local members = ES.Members(r)
    local names, joined = {}, false
    for _, m in ipairs(members) do
        names[#names + 1] = m.name
        if m.charId == viewerCharId then joined = true end
    end
    local price = tonumber(r.price) or 0
    local required = math.max(1, tonumber(r.escorts_required) or 1)
    local office = ES.ClaimOffice(r)
    return {
        id               = tonumber(r.id),
        type             = r.type,
        typeLabel        = L('escort_type_' .. tostring(r.type)),
        clientName       = r.client_name,
        recipientName    = r.recipient_name,
        pickup           = r.pickup,
        pickupLabel      = ES.StationLabel(r.pickup),
        destination      = r.destination,
        destinationLabel = r.destination and ES.StationLabel(r.destination) or nil,
        durationMin      = tonumber(r.duration_min),
        escortsRequired  = required,
        escorts          = names,
        leaderName       = r.leader_name,
        price            = price,
        payoutEstimate   = Law.Round(price * (1 - (ECfg.DepartmentCut or 0.25)) / required, 2),
        insurance        = tonumber(r.insurance) == 1,
        premium          = tonumber(r.premium) or 0,
        insuredValue     = tonumber(r.insured_value) or 0,
        status           = r.status,
        statusLabel      = L('escort_status_' .. tostring(r.status)),
        reasonLabel      = r.status == 'failed' and L('escort_reason_' .. tostring(r.status_reason)) or nil,
        createdAt        = tonumber(r.created_at),
        startedAt        = tonumber(r.started_at),
        finishedAt       = tonumber(r.finished_at),
        deadlineAt       = tonumber(r.deadline_at),
        cargoSummary     = ES.CargoSummary(r),
        canClaim         = viewerCharId ~= nil and ES.CanClaim(r, viewerCharId) or false,
        claimOffice      = office,
        claimOfficeLabel = office and ES.StationLabel(office) or nil,
        joined           = joined,
        full             = #members >= required,
        isLeader         = viewerCharId ~= nil and tonumber(r.leader_charid) == viewerCharId,
        -- Versicherungsfall (K1): Kunde sieht den Stand im Schalter
        insuranceState       = r.insurance_state or 'none',
        insuranceStateLabel  = L('escort_ins_state_' .. tostring(r.insurance_state or 'none')),
        insuranceAmount      = tonumber(r.insurance_amount) or 0,
        insuranceReasonLabel = ES.InsuranceReasonLabel(r),
    }
end

--- Grund einer abgelehnten Versicherung (status_reason 'ins_*')
function ES.InsuranceReasonLabel(r)
    if r.insurance_state ~= 'denied' or type(r.status_reason) ~= 'string' or r.status_reason:sub(1, 4) ~= 'ins_' then return nil end
    return L('escort_' .. r.status_reason)
end

--- Auftraege, in denen charId Begleiter ist (fuer den Client: Start-Aktion, HUD)
function ES.MemberContracts(charId)
    local out = {}
    for _, r in ipairs(MySQL.query.await("SELECT * FROM ara_law_escorts WHERE status IN ('accepted','active') ORDER BY id ASC LIMIT 100") or {}) do
        for _, m in ipairs(ES.Members(r)) do
            if m.charId == charId then
                out[#out + 1] = {
                    id = tonumber(r.id), type = r.type, typeLabel = L('escort_type_' .. r.type), status = r.status,
                    isLeader = tonumber(r.leader_charid) == charId, clientName = r.client_name,
                    pickup = r.pickup, pickupLabel = ES.StationLabel(r.pickup),
                    destination = r.destination, destinationLabel = r.destination and ES.StationLabel(r.destination) or nil,
                }
                break
            end
        end
    end
    return out
end

function ES.PushMember(charId)
    charId = tonumber(charId)
    local src = charId and Law.SrcByCharId(charId)
    if not src then return end
    CreateThread(function()
        TriggerClientEvent('ara_law:cl:escort:sync', src, ES.MemberContracts(charId))
    end)
end

--- Ein Auftrag = eine Sperre (serialisiert Annahme, Start, Abgabe, Storno ...)
local locks = {}
function ES.WithLock(id, fn)
    id = tonumber(id)
    if not id then return Law.Result(false, 'invalid') end
    if locks[id] then return Law.Result(false, 'escort_busy') end
    locks[id] = true
    local ok, res = xpcall(fn, debug.traceback)
    locks[id] = nil
    if not ok then
        Law.Warn('Eskorte #%s: %s', tostring(id), tostring(res))
        return Law.Result(false, 'internal')
    end
    return res
end

function ES.CloseAlert(id)
    local alertId = ES.Alerts[id]
    ES.Alerts[id] = nil
    if alertId then Law.Dispatch.Close(alertId, L('escort_alert_closed')) end
end

--- Leitstellen-Hinweis "Auftrag offen" an die berechtigten Behoerden
--- (bei Buchung und wenn ein Auftrag von accepted auf open zurueckfaellt)
function ES.CreateAlert(id, typeKey, pickup, destination)
    ES.CloseAlert(id)
    local alertId = Law.Dispatch.Create({
        kind = 'escort', coords = ES.PointCoords(pickup), priority = 1, perm = 'escort_contracts', depts = ECfg.AllowedDepts,
        title = L('escort_dispatch_title', L('escort_type_' .. tostring(typeKey))),
        text = L('escort_dispatch_text', id, ES.StationLabel(pickup), destination and ES.StationLabel(destination) or '-'),
        expires = 1800,
        onClose = function(alert)
            -- nur den eigenen Einsatz austragen (nicht einen spaeter neu erstellten)
            if alert and ES.Alerts[id] == alert.id then ES.Alerts[id] = nil end
        end,
    })
    ES.Alerts[id] = alertId
    return alertId
end

--------------------------------------------------------------------------
-- Preis (nur serverseitig)
--------------------------------------------------------------------------
local function deadlineMinutes(typeKey, km, durationMin)
    local t = ECfg.Types[typeKey] or {}
    if typeKey == 'bodyguard' then return tonumber(durationMin) or 30 end
    return math.max(t.MinMinutes or 15, math.ceil((km or 0) * (t.MinutesPerKm or 6)))
end

--- Leere Formularfelder ("") wie "nicht angegeben" behandeln
local function orDefault(v, default)
    if v == nil or v == '' then return default end
    return v
end

--- values (NUI) pruefen -> q | nil, errCode
local function parseValues(values, pickup)
    if type(values) ~= 'table' then return nil, 'invalid' end
    local typeKey = Law.ToStr(values.type, 16)
    local tcfg = typeKey and ECfg.Types[typeKey]
    if not tcfg then return nil, 'escort_bad_type' end

    local q = { type = typeKey, pickup = pickup, cargo = {}, money = 0, gold = 0, cargoValue = 0, insurance = false, km = 0 }
    q.escorts = Law.ToInt(orDefault(values.escorts, tcfg.MinEscorts or 1), tcfg.MinEscorts or 1, tcfg.MaxEscorts or 4)
    if not q.escorts then return nil, 'escort_bad_escorts' end

    if typeKey == 'bodyguard' then
        q.durationMin = Law.ToInt(values.durationMin)
        if not q.durationMin or not Law.Contains(tcfg.Durations or {}, q.durationMin) then return nil, 'escort_bad_duration' end
    else
        q.destination = Law.ToStr(values.destination, 32)
        if not q.destination or q.destination == pickup or not ES.Point(q.destination) then return nil, 'escort_bad_destination' end
        q.km = ES.Km(pickup, q.destination)
    end

    if typeKey == 'cargo' then
        local known = ES.GetCargoItems()
        q.insurance = Law.ToBool(values.insurance)
        q.recipientName = Law.ToStr(values.recipientName, 100, true) or ''
        if values.cargo ~= nil and type(values.cargo) ~= 'table' then return nil, 'escort_bad_cargo' end
        local merged, order, n = {}, {}, 0
        for _, e in ipairs(values.cargo or {}) do
            n = n + 1
            if n > (ECfg.MaxCargoEntries or 10) or type(e) ~= 'table' then return nil, 'escort_bad_cargo' end
            local name = Law.ToStr(e.name or e.value, 64)
            local amount = Law.ToInt(orDefault(e.amount or e.count, 0), 0, 100000)
            if not name or not amount then return nil, 'escort_bad_cargo' end
            if amount > 0 then
                if not known[name] then return nil, 'escort_bad_cargo' end
                if not merged[name] then
                    merged[name] = 0
                    order[#order + 1] = name
                end
                merged[name] = merged[name] + amount
            end
        end
        for _, name in ipairs(order) do
            q.cargo[#q.cargo + 1] = { name = name, amount = merged[name], label = known[name].label }
            q.cargoValue = q.cargoValue + merged[name] * known[name].value
        end
        -- Warenwert = nur Items. Nur er ist versicherbar (K1: Bargeld/Gold nie).
        q.goodsValue = Law.Round(q.cargoValue, 2)
        q.money = Law.ToMoney(orDefault(values.money, 0), 0, ECfg.MaxMoney or 20000)
        q.gold = Law.ToMoney(orDefault(values.gold, 0), 0, ECfg.MaxGold or 100)
        if not q.money or not q.gold then return nil, 'escort_bad_cargo' end
        q.uninsuredValue = Law.Round(q.money + q.gold * (ECfg.GoldValue or 20), 2)
        q.cargoValue = Law.Round(q.goodsValue + q.uninsuredValue, 2)
        if #q.cargo == 0 and q.money <= 0 and q.gold <= 0 then return nil, 'escort_empty_cargo' end
        if q.cargoValue > (ECfg.MaxCargoValue or 50000) then return nil, 'escort_too_valuable' end
        -- Ohne Ware gibt es nichts zu versichern
        q.insurance = q.insurance and q.goodsValue > 0
        q.insuredValue = q.insurance and q.goodsValue or 0
    end
    q.goodsValue = q.goodsValue or 0
    q.uninsuredValue = q.uninsuredValue or 0
    q.insuredValue = q.insuredValue or 0
    return q
end

local function price(q)
    local t = ECfg.Types[q.type]
    local bd = {}
    local function add(key, amount, ...)
        amount = Law.Round(amount, 2)
        if amount ~= 0 then bd[#bd + 1] = { label = L(key, ...), amount = amount } end
        return amount
    end
    local p = add('escort_bd_base', t.Base or 0)
    if q.type == 'bodyguard' then
        p = p + add('escort_bd_duration', (t.PerMinute or 0) * q.durationMin, q.durationMin)
    else
        p = p + add('escort_bd_distance', (t.PerKm or 0) * q.km, Law.Round(q.km, 2))
    end
    if q.type == 'cargo' then p = p + add('escort_bd_value', (t.ValuePercent or 0) * q.cargoValue) end
    if q.escorts > 1 then p = p + add('escort_bd_escorts', (ECfg.PerExtraEscort or 0) * (q.escorts - 1), q.escorts - 1) end
    q.price = Law.Round(p, 2)
    q.premium = 0
    if q.type == 'cargo' and q.insurance then
        -- Praemie nur auf den versicherten Warenwert
        q.premium = add('escort_bd_premium', q.insuredValue * ((ECfg.Insurance and ECfg.Insurance.PremiumPercent) or 0))
    end
    if q.money > 0 then add('escort_bd_money', q.money) end
    q.total = Law.Round(q.price + q.premium + q.money, 2)
    q.goldTotal = q.gold
    q.breakdown = bd
    q.deadlineMinutes = deadlineMinutes(q.type, q.km, q.durationMin)
    return q
end

--------------------------------------------------------------------------
-- Schalter (Tab "escort")
--------------------------------------------------------------------------
Law.Cb.Register('escort:options', { rate = 1000 }, function(src, ctx, station)
    if not ECfg.Enabled then return Law.Result(false, 'module_missing') end
    local here = ES.AtOffice(src)
    station = Law.ToStr(station, 32)
    if not here or (station and station ~= here) then return Law.Result(false, 'not_at_point') end

    local types = {}
    for _, key in ipairs(TYPE_ORDER) do
        local t = ECfg.Types[key]
        if t then
            types[#types + 1] = {
                value = key, key = key, label = L('escort_type_' .. key), desc = L('escort_type_desc_' .. key),
                durations = key == 'bodyguard' and t.Durations or nil,
                minEscorts = t.MinEscorts or 1, maxEscorts = t.MaxEscorts or 4,
                needsDestination = key ~= 'bodyguard', needsDuration = key == 'bodyguard',
                allowsCargo = key == 'cargo', allowsInsurance = key == 'cargo',
                base = t.Base, perMinute = t.PerMinute, perKm = t.PerKm, valuePercent = t.ValuePercent,
            }
        end
    end
    local destinations = {}
    for _, k in ipairs(ES.Offices()) do
        if k ~= here then
            destinations[#destinations + 1] = { value = k, label = ES.StationLabel(k), km = Law.Round(ES.Km(here, k), 2) }
        end
    end
    local cargoItems = {}
    for name, def in pairs(ES.GetCargoItems()) do
        cargoItems[#cargoItems + 1] = { value = name, name = name, label = def.label, unitValue = def.value, owned = Law.Items.Count(src, name) }
    end
    table.sort(cargoItems, function(a, b) return a.label < b.label end)

    return Law.Result(true, {
        station = here, stationLabel = ES.StationLabel(here),
        types = types, destinations = destinations, cargoItems = cargoItems,
        insurance = {
            available = true,
            premiumPercent = (ECfg.Insurance and ECfg.Insurance.PremiumPercent) or 0,
            coverage = (ECfg.Insurance and ECfg.Insurance.Coverage) or 0,
            coversCash = false,                  -- Bargeld und Gold sind NIE versichert
            manualReview = true,                 -- Auszahlung erst nach Pruefung durch die Behoerde
            note = L('escort_insurance_note'),
        },
        perExtraEscort = ECfg.PerExtraEscort or 0,
        maxMoney = ECfg.MaxMoney, maxGold = ECfg.MaxGold, maxCargoValue = ECfg.MaxCargoValue,
        maxCargoEntries = ECfg.MaxCargoEntries or 10, goldValue = ECfg.GoldValue or 20,
        myMoney = Law.Money.Get(src, 0), myGold = Law.Money.Get(src, 1),
    })
end)

Law.Cb.Register('escort:quote', { rate = 300 }, function(src, ctx, values)
    local here = ES.AtOffice(src)
    if not here then return Law.Result(false, 'not_at_point') end
    local q, err = parseValues(values, here)
    if not q then return Law.Result(false, err) end
    price(q)
    return Law.Result(true, {
        price = q.price, premium = q.premium, total = q.total, goldTotal = q.goldTotal,
        cargoValue = q.cargoValue, km = Law.Round(q.km or 0, 2), deadlineMinutes = q.deadlineMinutes,
        breakdown = q.breakdown,
        -- Versicherung klar ausweisen: nur Warenwert, Bargeld/Gold nicht
        insured = q.insurance == true,
        insuredValue = q.insuredValue,
        uninsuredValue = q.uninsuredValue,
        coverageAmount = Law.Round(q.insuredValue * ((ECfg.Insurance and ECfg.Insurance.Coverage) or 0), 2),
        insuranceNote = L('escort_insurance_note'),
    })
end)

Law.Cb.Register('escort:book', { rate = 3000, notCuffed = true, notJailed = true, alive = true }, function(src, ctx, values)
    if not ECfg.Enabled then return Law.Result(false, 'module_missing') end
    local here = ES.AtOffice(src)
    if not here then return Law.Result(false, 'not_at_point') end
    local q, err = parseValues(values, here)
    if not q then return Law.Result(false, err) end
    price(q)

    -- Empfaenger (nur Werttransport): exakter Vor- und Nachname, sonst der Kunde selbst
    local recipientCharId, recipientName
    if q.type == 'cargo' then
        if q.recipientName ~= '' then
            local rows = MySQL.query.await("SELECT charidentifier, firstname, lastname FROM characters WHERE CONCAT(firstname, ' ', lastname) = ? LIMIT 2",
                { q.recipientName }) or {}
            if #rows == 0 then return Law.Result(false, 'escort_recipient_unknown') end
            if #rows > 1 then return Law.Result(false, 'escort_recipient_ambiguous') end
            recipientCharId = tonumber(rows[1].charidentifier)
            recipientName = ((rows[1].firstname or '') .. ' ' .. (rows[1].lastname or ''))
        else
            recipientCharId, recipientName = ctx.charId, ctx.name
        end
    end

    -- 1) ALLE Mengen pruefen (kein await ab hier bis zum Abziehen)
    if Law.Money.Get(src, 0) < q.total then return Law.Result(false, 'no_money') end
    if q.gold > 0 and Law.Money.Get(src, 1) < q.gold then return Law.Result(false, 'escort_no_gold') end
    for _, c in ipairs(q.cargo) do
        if Law.Items.Count(src, c.name) < c.amount then
            return Law.Result(false, 'escort_missing_item', L('err_escort_missing_item', c.label, c.amount))
        end
    end

    -- 2) Abziehen - bei Teilfehlschlag alles bereits Abgezogene zurueck
    local taken = {}
    local function rollback(dollars, gold)
        for _, c in ipairs(taken) do
            if not Law.Items.Give(src, c.name, c.amount) then
                Law.Warn('Eskorte: Rueckgabe %dx %s an %s fehlgeschlagen', c.amount, c.name, tostring(ctx.charId))
                Law.Audit(ctx, 'escort.rollback_error', nil, { item = c.name, amount = c.amount })
            end
        end
        if dollars and dollars > 0 then Law.Money.Give(src, dollars, 0) end
        if gold and gold > 0 then Law.Money.Give(src, gold, 1) end
    end
    if not Law.Money.Take(src, q.total, 0) then return Law.Result(false, 'no_money') end
    if q.gold > 0 and not Law.Money.Take(src, q.gold, 1) then
        rollback(q.total, 0)
        return Law.Result(false, 'escort_no_gold')
    end
    for _, c in ipairs(q.cargo) do
        if Law.Items.Take(src, c.name, c.amount) then
            taken[#taken + 1] = c
        else
            rollback(q.total, q.gold)
            return Law.Result(false, 'escort_missing_item', L('err_escort_missing_item', c.label, c.amount))
        end
    end

    -- 3) Treuhand-Zeile
    local cargoJson = {}
    for _, c in ipairs(q.cargo) do cargoJson[#cargoJson + 1] = { name = c.name, amount = c.amount } end
    -- oxmysql-.await WIRFT bei SQL-Fehlern -> Law.DB.Try, sonst waeren Geld und Ware weg
    local now = Law.Now()
    local okDb, id = Law.DB.Try(MySQL.insert.await, [[INSERT INTO ara_law_escorts
        (type, client_charid, client_name, client_identifier, recipient_charid, recipient_name, pickup, destination, duration_min,
         escorts_required, price, insurance, premium, insured_value, cargo, cargo_money, cargo_gold, department,
         leader_charid, leader_name, escorts, status, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, '[]', 'open', ?)]],
        { q.type, ctx.charId, ctx.name, ctx.identifier or '', recipientCharId, recipientName, here, q.destination, q.durationMin,
          q.escorts, q.price, q.insurance and 1 or 0, q.premium, q.insuredValue, json.encode(cargoJson),
          q.money, q.gold, ECfg.Department, now })
    if not okDb or not id then
        rollback(q.total, q.gold)
        Law.Audit(ctx, 'escort.book_failed', nil, { price = q.price, money = q.money, gold = q.gold, cargo = json.encode(cargoJson) })
        return Law.Result(false, 'failed')
    end

    ES.CreateAlert(id, q.type, here, q.destination)

    Law.Audit(ctx, 'escort.book', recipientCharId, {
        id = id, type = q.type, price = q.price, premium = q.premium, money = q.money, gold = q.gold,
        cargo = json.encode(cargoJson), pickup = here, destination = q.destination,
    })
    return Law.Result(true, { id = id, total = q.total, gold = q.gold }, L('escort_booked', id))
end)

Law.Cb.Register('escort:mine', { rate = 1000 }, function(src, ctx)
    local since = Law.Now() - (ECfg.ClaimExpireDays or 14) * 86400
    local rows = MySQL.query.await([[SELECT * FROM ara_law_escorts WHERE (client_charid = ? OR recipient_charid = ?)
        AND (status IN ('open','accepted','active','delivered') OR COALESCE(finished_at, created_at) >= ?)
        ORDER BY id DESC LIMIT 30]], { ctx.charId, ctx.charId, since }) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = ES.Public(r, ctx.charId) end
    return Law.Result(true, out)
end)

--- Volle Erstattung (Storno, Verfall): Geld sofort, Ware ins Abholfach am Abholbuero
function ES.RefundFull(r)
    local client = tonumber(r.client_charid)
    local dollars = Law.Round((tonumber(r.price) or 0) + (tonumber(r.premium) or 0) + (tonumber(r.cargo_money) or 0), 2)
    local gold = tonumber(r.cargo_gold) or 0
    if dollars > 0 then Law.Money.GiveCharId(client, dollars, 0, 'escort_refund') end
    if gold > 0 then Law.Money.GiveCharId(client, gold, 1, 'escort_refund') end
    return ES.ReturnGoods(r, client), dollars, gold
end

Law.Cb.Register('escort:cancel', { rate = 2000, notCuffed = true, notJailed = true }, function(src, ctx, id)
    id = Law.ToInt(id, 1)
    return ES.WithLock(id, function()
        local r = ES.Row(id)
        if not r or tonumber(r.client_charid) ~= ctx.charId then return Law.Result(false, 'not_found') end
        if r.status ~= 'open' then return Law.Result(false, 'escort_not_open') end
        if ES.AtOffice(src) ~= r.pickup then
            return Law.Result(false, 'escort_wrong_office', L('err_escort_wrong_office', ES.StationLabel(r.pickup)))
        end
        local affected = MySQL.update.await("UPDATE ara_law_escorts SET status = 'cancelled', status_reason = 'cancelled', finished_at = ?, claim_office = ? WHERE id = ? AND status = 'open'",
            { Law.Now(), r.pickup, id })
        if affected ~= 1 then return Law.Result(false, 'already_done') end
        ES.CloseAlert(id)
        local hasGoods, dollars, gold = ES.RefundFull(r)
        if hasGoods then ES.OpenInv(src, ES.FachId(id), L('escort_fach_name', id), ES.CargoList(r)) end
        Law.Audit(ctx, 'escort.cancel', nil, { id = id, refund = dollars, gold = gold })
        return Law.Result(true, { opened = hasGoods }, L('escort_cancelled', id, dollars))
    end)
end)

Law.Cb.Register('escort:claim', { rate = 2000, notCuffed = true, notJailed = true, alive = true }, function(src, ctx, id)
    id = Law.ToInt(id, 1)
    return ES.WithLock(id, function()
        local r = ES.Row(id)
        if not r or not ES.CanClaim(r, ctx.charId) then return Law.Result(false, 'not_found') end
        local office = ES.ClaimOffice(r)
        if ES.AtOffice(src) ~= office then
            return Law.Result(false, 'escort_wrong_office', L('err_escort_wrong_office', ES.StationLabel(office)))
        end
        if r.status == 'delivered' then return ES.ClaimDelivered(src, ctx, r) end
        -- claimed / failed / cancelled / expired: Ware liegt schon im Fach -> nur oeffnen
        ES.OpenInv(src, ES.FachId(id), L('escort_fach_name', id))
        return Law.Result(true, { opened = true }, L('escort_fach_opened', id))
    end)
end)

--------------------------------------------------------------------------
-- Dienstbuch (Tab "escorts")
--------------------------------------------------------------------------
Law.Cb.Register('escort:listOpen', { perm = 'escort_contracts', rate = 1000 }, function(src, ctx)
    if not ES.DeptAllowed(ctx.dept) then return Law.Result(true, {}) end
    local out = {}
    for _, r in ipairs(MySQL.query.await("SELECT * FROM ara_law_escorts WHERE status IN ('open','accepted') ORDER BY id ASC LIMIT 50") or {}) do
        out[#out + 1] = ES.Public(r, ctx.charId)
    end
    return Law.Result(true, out)
end)

Law.Cb.Register('escort:listMine', { perm = 'escort_contracts', rate = 1000 }, function(src, ctx)
    local since = Law.Now() - 7 * 86400
    local out = {}
    local rows = MySQL.query.await([[SELECT * FROM ara_law_escorts WHERE status IN ('accepted','active')
        OR (finished_at IS NOT NULL AND finished_at >= ? AND escorts <> '[]') ORDER BY id DESC LIMIT 200]], { since }) or {}
    for _, r in ipairs(rows) do
        for _, m in ipairs(ES.Members(r)) do
            if m.charId == ctx.charId then
                out[#out + 1] = ES.Public(r, ctx.charId)
                break
            end
        end
    end
    return Law.Result(true, out)
end)

Law.Cb.Register('escort:accept', { perm = 'escort_contracts', rate = 1500, notCuffed = true }, function(src, ctx, id)
    if not ES.DeptAllowed(ctx.dept) then return Law.Result(false, 'escort_dept') end
    id = Law.ToInt(id, 1)
    return ES.WithLock(id, function()
        local r = ES.Row(id)
        if not r or (r.status ~= 'open' and r.status ~= 'accepted' and r.status ~= 'active') then return Law.Result(false, 'not_found') end
        -- Kein Eigenauftrag (auch nicht mit einem anderen Charakter derselben Steam-ID)
        if Law.IsSelfOrAlt(ctx, r.client_charid) or (tonumber(r.recipient_charid) and Law.IsSelfOrAlt(ctx, r.recipient_charid))
            or (r.client_identifier ~= '' and r.client_identifier == ctx.identifier) then
            return Law.Result(false, 'escort_own')
        end
        local members = copyList(ES.Members(r))
        for _, m in ipairs(members) do
            if m.charId == ctx.charId then return Law.Result(false, 'escort_member') end
        end
        if #members >= (tonumber(r.escorts_required) or 1) then return Law.Result(false, 'escort_full') end

        members[#members + 1] = { charId = ctx.charId, name = ctx.name, identifier = ctx.identifier, dept = ctx.dept, ticks = 0 }
        local leader, leaderName = tonumber(r.leader_charid), r.leader_name
        local becameLeader = false
        if not leader and Law.HasPerm(ctx, 'escort_lead') then
            leader, leaderName, becameLeader = ctx.charId, ctx.name, true
        end
        local newStatus = r.status == 'open' and 'accepted' or r.status
        local affected = MySQL.update.await('UPDATE ara_law_escorts SET escorts = ?, leader_charid = ?, leader_name = ?, status = ?, accepted_at = COALESCE(accepted_at, ?) WHERE id = ? AND status = ?',
            { json.encode(members), leader, leaderName, newStatus, Law.Now(), id, r.status })
        if affected ~= 1 then return Law.Result(false, 'already_done') end

        local a = ES.Active[id]
        if a then
            a.members = members
            a.leaderCharId = leader
            if a.wagonNetId then TriggerClientEvent('ara_law:cl:escort:wagon', src, id, a.wagonNetId) end
        end
        if r.status == 'open' then ES.CloseAlert(id) end
        ES.NotifyChar(tonumber(r.client_charid), L('escort_client_accepted', id, ctx.name), 'info')
        for _, m in ipairs(members) do ES.PushMember(m.charId) end
        Law.Audit(ctx, 'escort.accept', tonumber(r.client_charid), { id = id, leader = becameLeader })
        r.escorts, r.leader_charid, r.leader_name, r.status = json.encode(members), leader, leaderName, newStatus
        return Law.Result(true, ES.Public(r, ctx.charId), becameLeader and L('escort_accepted_leader', id) or L('escort_accepted', id))
    end)
end)

-- Ohne Behoerden-Pruefung: auch Entlassene muessen einen Auftrag verlassen koennen (N4)
Law.Cb.Register('escort:leave', { rate = 1500 }, function(src, ctx, id)
    id = Law.ToInt(id, 1)
    return ES.WithLock(id, function()
        local r = ES.Row(id)
        if not r or (r.status ~= 'accepted' and r.status ~= 'active') then return Law.Result(false, 'not_found') end
        local members = copyList(ES.Members(r))
        local idx
        for i, m in ipairs(members) do
            if m.charId == ctx.charId then idx = i break end
        end
        if not idx then return Law.Result(false, 'escort_not_member') end
        table.remove(members, idx)

        local leader, leaderName = tonumber(r.leader_charid), r.leader_name
        if leader == ctx.charId then
            -- Neuer Leiter: naechster Begleiter mit Recht escort_lead
            leader, leaderName = nil, nil
            for _, m in ipairs(members) do
                local mctx = Law.CtxByCharId(m.charId)
                if mctx and Law.HasPerm(mctx, 'escort_lead') then
                    leader, leaderName = m.charId, m.name
                    break
                end
            end
        end
        local newStatus = (r.status == 'accepted' and #members == 0) and 'open' or r.status
        local affected = MySQL.update.await('UPDATE ara_law_escorts SET escorts = ?, leader_charid = ?, leader_name = ?, status = ? WHERE id = ? AND status = ?',
            { json.encode(members), leader, leaderName, newStatus, id, r.status })
        if affected ~= 1 then return Law.Result(false, 'already_done') end

        local a = ES.Active[id]
        if a then
            a.members = members
            a.leaderCharId = leader
        end
        TriggerClientEvent('ara_law:cl:escort:ended', src, id, nil)
        ES.PushMember(ctx.charId)
        for _, m in ipairs(members) do
            ES.PushMember(m.charId)
            ES.NotifyChar(m.charId, L('escort_member_left', ctx.name, id), 'info')
        end
        -- Wieder offen: die Leitstelle muss es neu erfahren (N10)
        if newStatus == 'open' then ES.CreateAlert(id, r.type, r.pickup, r.destination) end
        Law.Audit(ctx, 'escort.leave', tonumber(r.client_charid), { id = id, newLeader = leader, reopened = newStatus == 'open' })
        return Law.Result(true, nil, L('escort_left', id))
    end)
end)

--------------------------------------------------------------------------
-- Start, Abgabe, Ende
--------------------------------------------------------------------------
--- accepted -> active (atomar), Laufzeit anlegen
function ES.Activate(r, netId)
    local now = Law.Now()
    local id = tonumber(r.id)
    local km = r.destination and ES.Km(r.pickup, r.destination) or 0
    local deadline = now + deadlineMinutes(r.type, km, r.duration_min) * 60
    local affected = MySQL.update.await("UPDATE ara_law_escorts SET status = 'active', started_at = ?, deadline_at = ? WHERE id = ? AND status = 'accepted'",
        { now, deadline, id })
    if affected ~= 1 then return false end

    local members = ES.Members(r)
    -- Steam-ID des Empfaengers (Ueberfall durch einen Zweitcharakter des Empfaengers sperren)
    local rcid = tonumber(r.recipient_charid)
    local recipientIdentifier = rcid and Law.IdentifierOf(rcid) or nil
    local amb = ECfg.Ambush or {}
    local ambushAt = nil
    if r.type == 'cargo' and amb.Enabled and math.random() < (amb.Chance or 0) then
        local p1, p2 = (amb.Progress or {})[1] or 0.3, (amb.Progress or {})[2] or 0.7
        ambushAt = p1 + math.random() * math.max(0, p2 - p1)
    end
    ES.Active[id] = {
        id               = id,
        type             = r.type,
        clientCharId     = tonumber(r.client_charid),
        recipientCharId  = tonumber(r.recipient_charid),
        clientIdentifier = r.client_identifier,
        recipientIdentifier = recipientIdentifier,
        leaderCharId     = tonumber(r.leader_charid),
        members          = members,
        wagonNetId       = netId,
        startedAt        = now,
        deadlineAt       = deadline,
        pickup           = r.pickup,
        destination      = r.destination,
        pickupCoords     = ES.PointCoords(r.pickup),
        destCoords       = r.destination and ES.PointCoords(r.destination) or nil,
        destLabel        = r.destination and ES.StationLabel(r.destination) or nil,
        ambushAt         = ambushAt,
        ambushDone       = false,
        lastNear         = nil,   -- Begleiter am Wagen beim letzten Tick (Versicherungspruefung)
    }
    if netId then ES.KeepWagon(netId) end

    for _, m in ipairs(members) do
        local s = Law.SrcByCharId(m.charId)
        if s then
            Law.Notify(s, L('escort_started', id), 'success')
            if netId then TriggerClientEvent('ara_law:cl:escort:wagon', s, id, netId) end
        end
        ES.PushMember(m.charId)
    end
    ES.NotifyChar(tonumber(r.client_charid), L('escort_client_started', id), 'info')
    Law.Audit(nil, 'escort.start', tonumber(r.client_charid), { id = id, type = r.type, leader = r.leader_charid, wagon = netId })
    return true
end

--- Laufzeit beenden: Wagen weg (ausser Ueberfall), Clients informieren
function ES.EndRuntime(id, text, keepWagon)
    local a = ES.Active[id]
    ES.Active[id] = nil
    ES.Pending[id] = nil
    if not a then return end
    if a.wagonNetId and not keepWagon then ES.DeleteWagon(a.wagonNetId) end
    local targets = {}
    for _, m in ipairs(a.members) do
        local s = Law.SrcByCharId(m.charId)
        if s then targets[s] = true end
    end
    if a.type ~= 'cargo' then
        local vip = Law.SrcByCharId(a.clientCharId)
        if vip then targets[vip] = true end
    end
    for s in pairs(targets) do TriggerClientEvent('ara_law:cl:escort:ended', s, id, text) end
    for _, m in ipairs(a.members) do ES.PushMember(m.charId) end
end

--- Lohn nach Teilnahme, Rest + Anteil + Praemie in die Kasse (nichts verschwindet)
function ES.Payout(r, members)
    local total = tonumber(r.price) or 0
    local cut = Law.Round(total * (ECfg.DepartmentCut or 0.25), 2)
    local pool = math.max(0, total - cut)
    local ticks = 0
    for _, m in ipairs(members) do ticks = ticks + (tonumber(m.ticks) or 0) end
    local paid = 0
    if ticks > 0 and pool > 0 then
        for _, m in ipairs(members) do
            local share = math.floor(pool * (tonumber(m.ticks) or 0) / ticks * 100) / 100
            if share > 0 then
                Law.Money.GiveCharId(m.charId, share, 0, 'escort_pay')
                paid = paid + share
                ES.NotifyChar(m.charId, L('escort_paid', share, r.id), 'success')
            end
        end
    end
    local toSociety = Law.Round(total - paid + (tonumber(r.premium) or 0), 2)
    if toSociety > 0 then Law.Society.Add(ECfg.Department, toSociety, 'escort_contract', nil) end
    return paid, toSociety
end

--- Erfolg: active -> delivered (Werttransport) | completed (Schutz, Transport)
function ES.Finish(id, toStatus, reason)
    local r = ES.Row(id)
    if not r or r.status ~= 'active' then return false end
    local a = ES.Active[id]
    local members = a and a.members or ES.Members(r)
    local claimOffice = toStatus == 'delivered' and r.destination or nil
    local affected = MySQL.update.await('UPDATE ara_law_escorts SET status = ?, status_reason = ?, finished_at = ?, escorts = ?, claim_office = ? WHERE id = ? AND status = ?',
        { toStatus, reason, Law.Now(), json.encode(members), claimOffice, id, 'active' })
    if affected ~= 1 then return false end

    ES.EndRuntime(id, L('escort_ended_' .. toStatus, id), false)
    local paid, society = ES.Payout(r, members)
    local client = tonumber(r.client_charid)
    if toStatus == 'delivered' then
        local recipient = tonumber(r.recipient_charid) or client
        ES.NotifyChar(recipient, L('escort_recipient_ready', id, ES.StationLabel(r.destination)), 'success')
        if recipient ~= client then ES.NotifyChar(client, L('escort_client_delivered', id, ES.StationLabel(r.destination)), 'success') end
    else
        ES.NotifyChar(client, L('escort_client_completed', id), 'success')
    end
    Law.Audit(nil, 'escort.' .. toStatus, client, { id = id, reason = reason, paid = paid, society = society })
    return true
end

--- Scheitern: active -> failed. Teil-Erstattung, Geld/Gold zurueck, Ware ins Abholfach am Abholbuero
function ES.Fail(id, reason, refundRate)
    local r = ES.Row(id)
    if not r or r.status ~= 'active' then return false end
    local a = ES.Active[id]
    local members = a and a.members or ES.Members(r)
    local affected = MySQL.update.await("UPDATE ara_law_escorts SET status = 'failed', status_reason = ?, finished_at = ?, escorts = ?, claim_office = ? WHERE id = ? AND status = 'active'",
        { reason, Law.Now(), json.encode(members), r.pickup, id })
    if affected ~= 1 then return false end

    ES.EndRuntime(id, L('escort_ended_failed', id, L('escort_reason_' .. reason)), false)
    local client = tonumber(r.client_charid)
    local total = tonumber(r.price) or 0
    local refund = Law.Round(total * (refundRate or ECfg.RefundOnFail or 0.5), 2)
    local money = tonumber(r.cargo_money) or 0
    local gold = tonumber(r.cargo_gold) or 0
    if refund + money > 0 then Law.Money.GiveCharId(client, Law.Round(refund + money, 2), 0, 'escort_refund') end
    if gold > 0 then Law.Money.GiveCharId(client, gold, 1, 'escort_refund') end
    local rest = Law.Round(total - refund + (tonumber(r.premium) or 0), 2)
    if rest > 0 then Law.Society.Add(ECfg.Department, rest, 'escort_failed', nil) end
    local hasGoods = ES.ReturnGoods(r, client)
    ES.NotifyChar(client, hasGoods and L('escort_client_failed_goods', id, refund, ES.StationLabel(r.pickup))
        or L('escort_client_failed', id, refund), 'error')
    Law.Audit(nil, 'escort.failed', client, { id = id, reason = reason, refund = refund, money = money, gold = gold })
    return true
end

Law.Cb.Register('escort:start', { perm = 'escort_lead', rate = 2000, notCuffed = true, alive = true }, function(src, ctx, id)
    id = Law.ToInt(id, 1)
    return ES.WithLock(id, function()
        local r = ES.Row(id)
        if not r or r.status ~= 'accepted' then return Law.Result(false, 'not_found') end
        if tonumber(r.leader_charid) ~= ctx.charId then return Law.Result(false, 'escort_not_leader') end

        if r.type == 'cargo' then
            local station, point = Law.Stations.NearPoint(src, 'escort')
            if station ~= r.pickup or not point then
                return Law.Result(false, 'escort_wrong_office', L('err_escort_wrong_office', ES.StationLabel(r.pickup)))
            end
            local s = point.spawn
            if not s then return Law.Result(false, 'escort_no_spawn') end
            local p = ES.Pending[id]
            if p and Law.Now() - p.t <= 60 then return Law.Result(false, 'escort_busy') end
            ES.Pending[id] = { src = src, t = Law.Now(), spawn = vector3(s.x, s.y, s.z) }
            return Law.Result(true, { spawnWagon = true, model = ECfg.WagonModel, spawn = { x = s.x, y = s.y, z = s.z, w = s.w or 0.0 } })
        end

        -- Personenschutz / -transport: die Person muss dabei sein
        local vip = Law.SrcByCharId(r.client_charid)
        if not vip or not Law.IsNear(src, vip, ECfg.StartDistance or 20.0) then return Law.Result(false, 'escort_client_far') end
        if not ES.Activate(r, nil) then return Law.Result(false, 'already_done') end
        Law.Audit(ctx, 'escort.started', tonumber(r.client_charid), { id = id })
        return Law.Result(true, { started = true }, L('escort_started', id))
    end)
end)

Law.Net.On('escort:wagonSpawned', { perm = 'escort_lead', rate = 1000 }, function(src, ctx, id, netId)
    id = Law.ToInt(id, 1)
    netId = Law.ToInt(netId, 1)
    local p = id and ES.Pending[id]
    if not netId then return end
    -- Der Server loescht hier NIE ein Entity (die NetId kommt vom Client). Er lehnt
    -- nur ab; der Client entfernt seinen lokal erzeugten Wagen selbst (H1/H3).
    local function reject()
        TriggerClientEvent('ara_law:cl:escort:wagonRejected', src, id, netId)
    end
    if not p or p.src ~= src or p.checking then return reject() end
    p.checking = true
    -- OneSync kennt frisch erzeugte Entities erst nach einem Moment
    local coords, ent = Law.EntityCoordsWait(netId, 3000)
    p.checking = nil
    if ES.Pending[id] ~= p then return reject() end
    ES.Pending[id] = nil
    local valid = coords and Law.Now() - p.t <= 60
        and Law.ModelMatches(ent, ECfg.WagonModel)
        and Law.IsEntityOwner(ent, src)
        and #(coords - p.spawn) <= 25.0
        and ES.FindByWagon(netId) == nil and ES.Robbed[netId] == nil  -- NetId gehoert keinem anderen Auftrag (N2)
    if not valid then return reject() end
    local res = ES.WithLock(id, function()
        local r = ES.Row(id)
        if not r or r.status ~= 'accepted' or tonumber(r.leader_charid) ~= ctx.charId then return false end
        return ES.Activate(r, netId)
    end)
    if res ~= true then return reject() end
    Law.Audit(ctx, 'escort.started', nil, { id = id, wagon = netId })
end)

Law.Cb.Register('escort:deliver', { perm = 'escort_lead', rate = 2000, notCuffed = true, alive = true }, function(src, ctx, id)
    id = Law.ToInt(id, 1)
    return ES.WithLock(id, function()
        local r = ES.Row(id)
        if not r or r.status ~= 'active' then return Law.Result(false, 'not_found') end
        if tonumber(r.leader_charid) ~= ctx.charId then return Law.Result(false, 'escort_not_leader') end
        if r.type == 'bodyguard' then return Law.Result(false, 'invalid') end
        local station, point = Law.Stations.NearPoint(src, 'escort')
        if station ~= r.destination or not point then
            return Law.Result(false, 'escort_wrong_office', L('err_escort_wrong_office', ES.StationLabel(r.destination)))
        end
        local zone = Law.Vec(point.coords)
        local radius = (point.radius or 25.0) + (ECfg.DeliverMargin or 10.0)

        if r.type == 'cargo' then
            local a = ES.Active[id]
            local wc = a and a.wagonNetId and ES.WagonCoords(a.wagonNetId)
            if not wc or #(wc - zone) > radius then return Law.Result(false, 'escort_wagon_far') end
            if not ES.Finish(id, 'delivered', 'delivered') then return Law.Result(false, 'already_done') end
        else
            local vip = Law.SrcByCharId(r.client_charid)
            local vc = vip and Law.GetCoords(vip)
            if not vc or #(vc - zone) > radius then return Law.Result(false, 'escort_client_far') end
            if not ES.Finish(id, 'completed', 'delivered') then return Law.Result(false, 'already_done') end
        end
        Law.Audit(ctx, 'escort.deliver', tonumber(r.client_charid), { id = id })
        return Law.Result(true, nil, L('escort_delivered_ok', id))
    end)
end)

--------------------------------------------------------------------------
-- Eskort-Buero (Stationspunkt "escort"): was ist hier moeglich?
--------------------------------------------------------------------------
Law.Cb.Register('escort:here', { rate = 1000 }, function(src, ctx)
    local station = Law.Stations.NearPoint(src, 'escort')
    if not station then return Law.Result(false, 'not_at_point') end
    local actions = {}

    if ctx.dept and ctx.onDuty then
        for _, r in ipairs(MySQL.query.await("SELECT * FROM ara_law_escorts WHERE leader_charid = ? AND status IN ('accepted','active') ORDER BY id ASC", { ctx.charId }) or {}) do
            local tl = L('escort_type_' .. r.type)
            if r.status == 'accepted' and (r.type ~= 'cargo' or r.pickup == station) then
                actions[#actions + 1] = { action = 'start', id = tonumber(r.id), label = L('escort_action_start', r.id, tl),
                    desc = r.destination and L('escort_action_to', ES.StationLabel(r.destination)) or nil }
            elseif r.status == 'active' and r.type ~= 'bodyguard' and r.destination == station then
                actions[#actions + 1] = { action = 'deliver', id = tonumber(r.id), label = L('escort_action_deliver', r.id, tl) }
            end
        end
    end

    for _, r in ipairs(MySQL.query.await([[SELECT * FROM ara_law_escorts WHERE (client_charid = ? OR recipient_charid = ?)
        AND status IN ('delivered','claimed','failed','cancelled','expired') ORDER BY id DESC LIMIT 20]], { ctx.charId, ctx.charId }) or {}) do
        if ES.CanClaim(r, ctx.charId) and ES.ClaimOffice(r) == station then
            actions[#actions + 1] = { action = 'claim', id = tonumber(r.id), label = L('escort_action_claim', r.id),
                desc = ES.CargoSummary(r) }
        end
    end
    return Law.Result(true, { station = station, stationLabel = ES.StationLabel(station), actions = actions })
end)

--------------------------------------------------------------------------
-- Verfall (offen / nie gestartet) mit voller Erstattung
--------------------------------------------------------------------------
function ES.ExpireOld()
    local cutoff = Law.Now() - (ECfg.OpenExpireHours or 24) * 3600
    local rows = MySQL.query.await([[SELECT * FROM ara_law_escorts WHERE (status = 'open' AND created_at < ?)
        OR (status = 'accepted' AND COALESCE(accepted_at, created_at) < ?)]], { cutoff, cutoff }) or {}
    for _, r in ipairs(rows) do
        local id = tonumber(r.id)
        local affected = MySQL.update.await("UPDATE ara_law_escorts SET status = 'expired', status_reason = 'expired', finished_at = ?, claim_office = ? WHERE id = ? AND status = ?",
            { Law.Now(), r.pickup, id, r.status })
        if affected == 1 then
            ES.CloseAlert(id)
            local hasGoods, dollars = ES.RefundFull(r)
            ES.NotifyChar(tonumber(r.client_charid), hasGoods and L('escort_client_expired_goods', id, ES.StationLabel(r.pickup))
                or L('escort_client_expired', id), 'info')
            for _, m in ipairs(ES.Members(r)) do ES.PushMember(m.charId) end
            Law.Audit(nil, 'escort.expired', tonumber(r.client_charid), { id = id, refund = dollars })
        end
    end
    ES.ExpireInsurance()
end

--------------------------------------------------------------------------
-- Versicherungsfaelle (K1). Ein Ueberfall zahlt NICHT automatisch aus: er
-- erzeugt einen Fall ('pending'), den die Behoerde Config.Escort.Department
-- (Recht boss_funds) prueft. Freigabe/Ablehnung sind atomare Wechsel auf
-- insurance_state; Geld fliesst erst nach dem Wechsel.
--------------------------------------------------------------------------
local INS = ECfg.Insurance or {}

--- Darf ctx Versicherungsfaelle sehen/entscheiden? (eigene Behoerde oder Recht all)
local function insuranceDesk(ctx)
    return ctx.dept == ECfg.Department or Law.GradeHasPerm(ctx.job, ctx.grade, 'all')
end

--- Hinweis an die Versicherungsstelle (nur Behoerde Department, Recht boss_funds, im Dienst)
function ES.NotifyInsuranceDesk(text)
    for s, dept in pairs(Law.GetOnDuty('boss_funds')) do
        if dept == ECfg.Department then Law.Notify(s, text, 'info') end
    end
end

--- Kunde, Empfaenger, Raeuber, Leiter und Begleiter (auch Zweitcharakter)
--- duerfen nicht ueber den Fall entscheiden (sonst Absprache Kunde +
--- Begleiter-Chef + Raeuber moeglich)
local function involved(ctx, r)
    if Law.IsSelfOrAlt(ctx, r.client_charid) then return true end
    if tonumber(r.recipient_charid) and Law.IsSelfOrAlt(ctx, r.recipient_charid) then return true end
    if tonumber(r.robbed_by) and Law.IsSelfOrAlt(ctx, r.robbed_by) then return true end
    if tonumber(r.leader_charid) and Law.IsSelfOrAlt(ctx, r.leader_charid) then return true end
    for _, m in ipairs(ES.Members(r) or {}) do
        if tonumber(m.charId) and Law.IsSelfOrAlt(ctx, m.charId) then return true end
    end
    return r.robbed_by_identifier ~= nil and r.robbed_by_identifier == ctx.identifier
end

--- Unbearbeitete Faelle verfallen nach Insurance.ExpireDays
function ES.ExpireInsurance()
    local cutoff = Law.Now() - (INS.ExpireDays or 14) * 86400
    for _, r in ipairs(MySQL.query.await("SELECT id, client_charid, insurance_amount FROM ara_law_escorts WHERE insurance_state = 'pending' AND finished_at < ?",
        { cutoff }) or {}) do
        local affected = MySQL.update.await("UPDATE ara_law_escorts SET insurance_state = 'expired', insurance_at = ? WHERE id = ? AND insurance_state = 'pending'",
            { Law.Now(), r.id })
        if affected == 1 then
            ES.NotifyChar(tonumber(r.client_charid), L('escort_ins_client_expired', r.id), 'info')
            Law.Audit(nil, 'escort.insurance_expired', tonumber(r.client_charid), { id = r.id, amount = tonumber(r.insurance_amount) })
        end
    end
end

Law.Cb.Register('escort:insuranceList', { perm = 'boss_funds', rate = 1000 }, function(src, ctx)
    if not insuranceDesk(ctx) then return Law.Result(false, 'no_permission') end
    local rows = MySQL.query.await("SELECT * FROM ara_law_escorts WHERE insurance_state <> 'none' ORDER BY (insurance_state = 'pending') DESC, id DESC LIMIT 50") or {}
    local out = {}
    for _, r in ipairs(rows) do
        local robber = tonumber(r.robbed_by)
        out[#out + 1] = {
            id               = tonumber(r.id),
            clientName       = r.client_name,
            recipientName    = r.recipient_name,
            robbedByName     = (INS.RevealRobber ~= false and robber) and Law.GetCharName(robber) or nil,
            pickupLabel      = ES.StationLabel(r.pickup),
            destinationLabel = r.destination and ES.StationLabel(r.destination) or nil,
            cargoSummary     = ES.CargoSummary(r),
            insuredValue     = tonumber(r.insured_value) or 0,
            amount           = tonumber(r.insurance_amount) or 0,
            robbedAt         = tonumber(r.finished_at),
            state            = r.insurance_state,
            stateLabel       = L('escort_ins_state_' .. tostring(r.insurance_state)),
            reasonLabel      = ES.InsuranceReasonLabel(r),
            decidedBy        = r.insurance_by,
            decidedAt        = tonumber(r.insurance_at),
            canDecide        = r.insurance_state == 'pending' and not involved(ctx, r),
        }
    end
    return Law.Result(true, out)
end)

Law.Cb.Register('escort:insuranceDecide', { perm = 'boss_funds', rate = 1500 }, function(src, ctx, id, approve)
    if not insuranceDesk(ctx) then return Law.Result(false, 'no_permission') end
    id = Law.ToInt(id, 1)
    approve = Law.ToBool(approve)
    return ES.WithLock(id, function()
        local r = ES.Row(id)
        if not r then return Law.Result(false, 'not_found') end
        if r.insurance_state ~= 'pending' then return Law.Result(false, 'already_done') end
        if involved(ctx, r) then return Law.Result(false, 'escort_ins_self') end
        local client = tonumber(r.client_charid)
        local amount = Law.Round(tonumber(r.insurance_amount) or 0, 2)
        local now = Law.Now()

        if not approve then
            local okDb, affected = Law.DB.Try(MySQL.update.await,
                "UPDATE ara_law_escorts SET insurance_state = 'denied', insurance_by = ?, insurance_at = ?, status_reason = 'ins_rejected' WHERE id = ? AND insurance_state = 'pending'",
                { ctx.name, now, id })
            if not okDb or affected ~= 1 then return Law.Result(false, 'already_done') end
            ES.NotifyChar(client, L('escort_ins_client_denied', id), 'error')
            Law.Audit(ctx, 'escort.insurance_denied', client, { id = id, amount = amount })
            return Law.Result(true, nil, L('escort_ins_denied_ok', id))
        end

        -- 1) atomar pending -> paid, 2) Kasse (atomar, nie ins Minus), 3) auszahlen
        local okDb, affected = Law.DB.Try(MySQL.update.await,
            "UPDATE ara_law_escorts SET insurance_state = 'paid', insurance_by = ?, insurance_at = ? WHERE id = ? AND insurance_state = 'pending'",
            { ctx.name, now, id })
        if not okDb or affected ~= 1 then return Law.Result(false, 'already_done') end
        if amount > 0 then
            local okS, removed = Law.DB.Try(Law.Society.Remove, ECfg.Department, amount, 'escort_insurance', ctx)
            if not okS or not removed then
                -- Kasse reicht nicht: Fall bleibt offen
                Law.DB.Try(MySQL.update.await,
                    "UPDATE ara_law_escorts SET insurance_state = 'pending', insurance_by = NULL, insurance_at = NULL WHERE id = ? AND insurance_state = 'paid'", { id })
                return Law.Result(false, 'society_empty')
            end
            local okPay, paid = Law.DB.Try(Law.Money.GiveCharId, client, amount, 0, 'escort_insurance')
            if not okPay or not paid then
                -- Auszahlung (Offline-Vormerkung) gescheitert: Kasse zurueck, Fall wieder offen
                Law.DB.Try(Law.Society.Add, ECfg.Department, amount, 'escort_insurance_refund', ctx)
                Law.DB.Try(MySQL.update.await,
                    "UPDATE ara_law_escorts SET insurance_state = 'pending', insurance_by = NULL, insurance_at = NULL WHERE id = ? AND insurance_state = 'paid'", { id })
                return Law.Result(false, 'failed')
            end
        end
        ES.NotifyChar(client, L('escort_ins_client_paid', id, amount), 'success')
        Law.Audit(ctx, 'escort.insurance_paid', client, { id = id, amount = amount })
        return Law.Result(true, { amount = amount }, L('escort_ins_paid_ok', id, amount))
    end)
end)

Law.Modules.Register('escort', {
    init = function()
        ES.BuildCargoItems()
        -- Neustart: laufende Fahrten zurueck auf "angenommen" (Wagen ist weg, neu starten)
        local n = MySQL.update.await("UPDATE ara_law_escorts SET status = 'accepted', started_at = NULL, deadline_at = NULL WHERE status = 'active'")
        if (tonumber(n) or 0) > 0 then Law.Warn('Eskorte: %d laufende Fahrt(en) auf "angenommen" zurueckgesetzt', tonumber(n)) end
        ES.ExpireOld()
        Law.Every(300000, ES.ExpireOld)
    end,
    playerLoaded = function(src, ctx)
        if ctx.dept then ES.PushMember(ctx.charId) end
    end,
    stop = function()
        for _, a in pairs(ES.Active) do
            if a.wagonNetId then ES.DeleteWagon(a.wagonNetId) end
        end
        for netId in pairs(ES.Robbed) do ES.DeleteWagon(netId) end
        ES.Active, ES.Pending, ES.Robbed = {}, {}, {}
        ES.RemoveInventories()
    end,
})
