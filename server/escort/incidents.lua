--[[
    ArA-LawSystem - Eskorte: Ueberwachung, Ueberfall, Versicherung, Hinterhalt (Server)

    Server-Tick (TickSeconds) je aktiver Eskorte:
      Wagen/VIP da? Leiter in der Naehe? Frist? Teilnahme-Ticks je Begleiter,
      NPC-Hinterhalt (einmal gewuerfelt beim Start), HUD an die Beteiligten.
    Wagen-Positionen gehen NIE an Unbeteiligte: der Raeuber-Client findet den
    Panzerwagen selbst (Modell in Sichtweite) und fragt nur fuer DIESEN Wagen.

    Jeder Endzustand laeuft ueber ein atomares UPDATE ... WHERE status='active'
    (ES.Finish / ES.Fail in contracts.lua, robbed hier) - der erste gewinnt,
    alle anderen bekommen affectedRows = 0 und tun nichts.
]]

Law.Escort = Law.Escort or {}
local ES = Law.Escort
local ECfg = Config.Escort
local RCfg = ECfg.Robbery or {}

local function radiusOf(a)
    if a.type == 'cargo' then return ECfg.ParticipationRadius or 75.0 end
    return ((ECfg.Types[a.type] or {}).VipRadius) or ECfg.ParticipationRadius or 75.0
end

--------------------------------------------------------------------------
-- HUD und Hinterhalt
--------------------------------------------------------------------------
local function sendHud(a, near, now)
    local data = {
        id = a.id,
        typeLabel = L('escort_type_' .. a.type),
        statusLabel = L('escort_status_active'),
        destinationLabel = a.destLabel or '-',
        timeLeft = math.max(0, (a.deadlineAt or now) - now),
        escortsNear = near,
        escortsTotal = #a.members,
    }
    local sent = {}
    for _, m in ipairs(a.members) do
        local s = Law.SrcByCharId(m.charId)
        if s and not sent[s] then
            sent[s] = true
            TriggerClientEvent('ara_law:cl:escort:hud', s, data)
        end
    end
    if a.type ~= 'cargo' then
        local vip = Law.SrcByCharId(a.clientCharId)
        if vip and not sent[vip] then TriggerClientEvent('ara_law:cl:escort:hud', vip, data) end
    end
end

--- Banditen SpawnAhead m vor dem Wagen Richtung Ziel. Gespawnt wird vom
--- Leiter (sonst einem Begleiter nah am Wagen), damit die NPCs im Umfeld
--- der Eskorte existieren.
local function triggerAmbush(a, anchor)
    local amb = ECfg.Ambush or {}
    local dir = a.destCoords - anchor
    local len = #dir
    if len < 1.0 then return false end
    local ahead = math.min(amb.SpawnAhead or 120.0, len)
    local p = anchor + (dir / len) * ahead

    local spawner
    local candidates = { a.leaderCharId }
    for _, m in ipairs(a.members) do candidates[#candidates + 1] = m.charId end
    for _, cid in ipairs(candidates) do
        local s = cid and Law.SrcByCharId(cid)
        local c = s and Law.GetCoords(s)
        if c and #(c - anchor) <= radiusOf(a) * 2 then
            spawner = s
            break
        end
    end
    if not spawner then return false end

    local cMin, cMax = (amb.Count or {})[1] or 3, (amb.Count or {})[2] or 6
    local count = math.random(math.min(cMin, cMax), math.max(cMin, cMax))
    TriggerClientEvent('ara_law:cl:escort:ambush', spawner, {
        id = a.id, x = p.x, y = p.y, z = p.z, count = count,
        models = amb.Models or {}, weapons = amb.Weapons or {},
        spread = amb.Spread or 15.0, despawn = amb.DespawnAfter or 900,
    })
    Law.Audit(nil, 'escort.ambush', a.clientCharId, { id = a.id, count = count })
    return true
end

--------------------------------------------------------------------------
-- Tick
--------------------------------------------------------------------------
local function tickOne(id, a, now)
    local anchor

    if a.type == 'cargo' then
        -- Nur wenn hinter der NetId noch ein Panzerwagen steckt (N1)
        local wc = a.wagonNetId and ES.WagonCoords(a.wagonNetId) or nil
        if wc then
            a.lostWagonSince = nil
            anchor = wc
        else
            a.lostWagonSince = a.lostWagonSince or now
            if now - a.lostWagonSince > (ECfg.WagonLostGrace or 120) then
                ES.Fail(id, 'wagon_lost')
                return
            end
        end
    else
        local vip = Law.SrcByCharId(a.clientCharId)
        anchor = vip and Law.GetCoords(vip) or nil
        if anchor then
            a.lostVipSince = nil
        else
            a.lostVipSince = a.lostVipSince or now
            if now - a.lostVipSince > (ECfg.LeaderLostGrace or 300) then
                -- Person hat die Stadt verlassen/ausgeloggt: Schutz gilt als geleistet
                if a.type == 'bodyguard' then ES.Finish(id, 'completed', 'vip_left') else ES.Fail(id, 'vip_lost') end
                return
            end
        end
    end

    local radius = radiusOf(a)
    local leaderSrc = a.leaderCharId and Law.SrcByCharId(a.leaderCharId) or nil
    local lc = leaderSrc and Law.GetCoords(leaderSrc) or nil
    if lc and (not anchor or #(lc - anchor) <= radius * 2) then
        a.lostLeaderSince = nil
    else
        a.lostLeaderSince = a.lostLeaderSince or now
        if now - a.lostLeaderSince > (ECfg.LeaderLostGrace or 300) then
            ES.Fail(id, 'leader_lost')
            return
        end
    end

    if now >= (a.deadlineAt or now) then
        if a.type == 'bodyguard' then ES.Finish(id, 'completed', 'time_done') else ES.Fail(id, 'deadline') end
        return
    end

    -- Teilnahme: nur Begleiter IM DIENST und nah am Wagen/an der Person (N4)
    local near = 0
    if anchor then
        for _, m in ipairs(a.members) do
            local s = Law.SrcByCharId(m.charId)
            local c = s and Law.Duty.active[s] and Law.GetCoords(s)
            if c and #(c - anchor) <= radius then
                m.ticks = (tonumber(m.ticks) or 0) + 1
                near = near + 1
            end
        end
    end
    -- Fuer die Versicherungspruefung: war beim letzten Tick jemand am Wagen?
    a.lastNear = anchor and near or 0

    -- Laufender Aufbruch: Raeuber weg vom Wagen -> abgebrochen (N3)
    local rob = a.robbery
    if rob then
        local rc = GetPlayerPing(rob.src) > 0 and Law.GetCoords(rob.src) or nil
        if not rc or not anchor or #(rc - anchor) > ((ECfg.Robbery and ECfg.Robbery.Distance) or 3.0) + 2.0 then
            a.robbery = nil
            if rc then Law.Notify(rob.src, L('escort_rob_aborted'), 'error') end
        end
    end

    if a.ambushAt and not a.ambushDone and anchor and a.pickupCoords and a.destCoords then
        local total = #(a.destCoords - a.pickupCoords)
        if total > 1.0 then
            local progress = 1.0 - math.min(1.0, #(a.destCoords - anchor) / total)
            if progress >= a.ambushAt and triggerAmbush(a, anchor) then a.ambushDone = true end
        end
    end

    MySQL.update('UPDATE ara_law_escorts SET escorts = ? WHERE id = ? AND status = ?', { json.encode(a.members), id, 'active' })
    sendHud(a, near, now)
end

Law.Every((ECfg.TickSeconds or 10) * 1000, function()
    local now = Law.Now()
    -- Erst die IDs sammeln: ES.Fail/Finish veraendern ES.Active und warten auf die DB
    local ids = {}
    for id in pairs(ES.Active) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do
        local a = ES.Active[id]
        if a then
            local ok, err = xpcall(tickOne, debug.traceback, id, a, now)
            if not ok then Law.Warn('Eskorte #%s Tick: %s', tostring(id), tostring(err)) end
        end
    end
    for id, p in pairs(ES.Pending) do
        if now - p.t > 90 then ES.Pending[id] = nil end
    end
end)

--------------------------------------------------------------------------
-- Tod der geschuetzten Person (Vertrag 4.1, Kern ruft auf)
--------------------------------------------------------------------------
function Law.Escort.OnPlayerDeath(src)
    local info = Law.Players[src]
    if not info or not info.charId then return end
    for id, a in pairs(ES.Active) do
        if a.clientCharId == info.charId and (a.type == 'bodyguard' or a.type == 'transport') then
            CreateThread(function()
                Wait(1500)
                -- Das Todes-Event kommt vom Client: serverseitig gegenpruefen (Kern-Helfer)
                if Law.IsPedDead(src) == false then return end
                if not ES.Active[id] then return end
                local rate = a.type == 'bodyguard' and ((ECfg.Types.bodyguard or {}).DeathRefund or 0.5) or (ECfg.RefundOnFail or 0.5)
                ES.Fail(id, 'vip_dead', rate)
            end)
        end
    end
end

--------------------------------------------------------------------------
-- Ueberfall auf den Panzerwagen
--------------------------------------------------------------------------
local function findByWagon(netId)
    return ES.FindByWagon(netId)
end

--- Begleiter im Dienst im Umkreis des Wagens (falls noch kein Tick gelaufen ist)
local function countNear(a, anchor)
    if not anchor then return 0 end
    local n = 0
    for _, m in ipairs(a.members) do
        local s = Law.SrcByCharId(m.charId)
        local c = s and Law.Duty.active[s] and Law.GetCoords(s)
        if c and #(c - anchor) <= radiusOf(a) then n = n + 1 end
    end
    return n
end

--- nil, wagonCoords = erlaubt; sonst Fehlercode
local function robDenied(src, ctx, a, netId, extra)
    if a.type ~= 'cargo' then return 'escort_not_robbable' end
    -- Kein Beteiligter - auch nicht mit einem anderen Charakter derselben Steam-ID
    if ctx.charId == a.clientCharId or ctx.charId == a.recipientCharId then return 'escort_rob_denied' end
    if ctx.identifier and (ctx.identifier == a.clientIdentifier or ctx.identifier == a.recipientIdentifier) then return 'escort_rob_denied' end
    for _, m in ipairs(a.members) do
        if m.charId == ctx.charId or (m.identifier and m.identifier == ctx.identifier) then return 'escort_rob_denied' end
    end
    if Law.Items.Count(src, RCfg.Item) < 1 then return 'escort_rob_item' end
    -- Server-Position des Wagens, nur wenn hinter der NetId noch ein Panzerwagen steckt (N1)
    local wc = ES.WagonCoords(netId)
    if not wc or not Law.IsNearCoords(src, wc, (RCfg.Distance or 3.0) + (extra or 0)) then return 'too_far' end
    return nil, wc
end

local function sendLootList(src, charId)
    local since = Law.Now() - (ECfg.ClaimExpireDays or 14) * 86400
    local ids = {}
    for _, r in ipairs(MySQL.query.await("SELECT id, cargo FROM ara_law_escorts WHERE status = 'robbed' AND robbed_by = ? AND finished_at >= ?",
        { charId, since }) or {}) do
        if #ES.CargoList(r) > 0 then ids[#ids + 1] = tonumber(r.id) end
    end
    TriggerClientEvent('ara_law:cl:escort:lootList', src, ids)
end

--- Versicherungsstand nach einem Ueberfall (K1). KEINE Auszahlung hier -
--- nur 'none' | 'pending' | 'denied' (+ Betrag, Grund fuer status_reason).
local function insuranceOnRobbery(r, a, ctx, nearAtStart)
    if tonumber(r.insurance) ~= 1 then return 'none', 0, nil end
    local insured = tonumber(r.insured_value) or 0  -- nur Warenwert, Bargeld/Gold nie
    if insured <= 0 then return 'none', 0, nil end
    local cfg = ECfg.Insurance or {}
    local amount = Law.Round(insured * (cfg.Coverage or 0.8), 2)

    -- (a) Beim letzten Tick vor dem Ueberfall war kein Begleiter am Wagen
    if (tonumber(nearAtStart) or 0) <= 0 then return 'denied', amount, 'ins_no_escort' end

    -- (b) Raeuber ist derselbe Spieler wie Kunde, Empfaenger oder ein Begleiter
    if Law.SamePlayer(ctx.charId, r.client_charid) then return 'denied', amount, 'ins_same_player' end
    if tonumber(r.recipient_charid) and Law.SamePlayer(ctx.charId, r.recipient_charid) then return 'denied', amount, 'ins_same_player' end
    for _, m in ipairs(a.members) do
        if Law.SamePlayer(ctx.charId, m.charId) then return 'denied', amount, 'ins_same_player' end
    end

    -- (c) Kunde (auch Zweitcharaktere) hatte in den letzten 7 Tagen schon einen Fall
    local since = Law.Now() - 7 * 86400
    local n
    if type(r.client_identifier) == 'string' and r.client_identifier ~= '' then
        n = MySQL.scalar.await("SELECT COUNT(*) FROM ara_law_escorts WHERE client_identifier = ? AND insurance_state IN ('pending','paid') AND finished_at >= ? AND id <> ?",
            { r.client_identifier, since, r.id })
    else
        n = MySQL.scalar.await("SELECT COUNT(*) FROM ara_law_escorts WHERE client_charid = ? AND insurance_state IN ('pending','paid') AND finished_at >= ? AND id <> ?",
            { r.client_charid, since, r.id })
    end
    if (tonumber(n) or 0) >= (cfg.MaxClaimsPerWeek or 1) then return 'denied', amount, 'ins_limit' end

    return 'pending', amount, nil
end

Law.Cb.Register('escort:canRob', { rate = 750 }, function(src, ctx, netId)
    netId = Law.ToInt(netId, 1)
    if not netId then return Law.Result(true, { canRob = false }) end
    local rb = ES.Robbed[netId]
    if rb then return Law.Result(true, { canRob = false, canLoot = rb.robberCharId == ctx.charId, id = rb.id }) end
    local id, a = findByWagon(netId)
    if not a or Law.IsCuffed(src) or Law.IsJailed(src) or ctx.isDead then return Law.Result(true, { canRob = false }) end
    local denied = robDenied(src, ctx, a, netId, 3.0)
    return Law.Result(true, { canRob = denied == nil, id = id })
end)

Law.Cb.Register('escort:robStart', { rate = 2000, notCuffed = true, notJailed = true, alive = true }, function(src, ctx, netId)
    netId = Law.ToInt(netId, 1)
    local id, a = findByWagon(netId)
    if not a then return Law.Result(false, 'escort_not_robbable') end
    local denied, wc = robDenied(src, ctx, a, netId, 0.5)
    if denied then return Law.Result(false, denied) end
    local rob = a.robbery
    if rob and rob.src ~= src and GetPlayerPing(rob.src) > 0 and GetGameTimer() - rob.startedAt < (RCfg.Seconds or 60) * 2000 then
        return Law.Result(false, 'escort_rob_active')
    end
    if not Law.RateLimit(src, 'escort:rob:cd', (RCfg.Cooldown or 300) * 1000) then return Law.Result(false, 'cooldown') end

    -- Stand "Begleiter am Wagen" vom letzten Tick VOR dem Ueberfall (Versicherung)
    local nearAtStart = a.lastNear
    if nearAtStart == nil then nearAtStart = countNear(a, wc) end
    a.robbery = { src = src, charId = ctx.charId, startedAt = GetGameTimer(), nearAtStart = nearAtStart }
    -- Sofort Alarm: Begleiter und Leitstelle
    Law.Dispatch.Create({
        kind = 'robbery', priority = 3, coords = wc, fuzz = 25, expires = 900,
        title = L('escort_rob_dispatch_title'), text = L('escort_rob_dispatch_text', id),
    })
    for _, m in ipairs(a.members) do ES.NotifyChar(m.charId, L('escort_rob_members', id), 'error') end
    Law.Audit(ctx, 'escort.rob_start', a.clientCharId, { id = id })
    return Law.Result(true, { id = id, seconds = RCfg.Seconds or 60 })
end)

Law.Net.On('escort:robAbort', { rate = 500 }, function(src, ctx, netId)
    local _, a = findByWagon(Law.ToInt(netId, 1))
    if a and a.robbery and a.robbery.src == src then a.robbery = nil end
end)

Law.Cb.Register('escort:robFinish', { rate = 2000, notCuffed = true, notJailed = true, alive = true }, function(src, ctx, netId)
    netId = Law.ToInt(netId, 1)
    local id, a = findByWagon(netId)
    if not a then return Law.Result(false, 'escort_not_robbable') end
    local rob = a.robbery
    if not rob or rob.src ~= src then return Law.Result(false, 'escort_rob_time') end
    -- Zeit misst der Server (Start-Zeitpunkt), nicht der Client
    if GetGameTimer() - rob.startedAt < (RCfg.Seconds or 60) * 1000 - 1000 then return Law.Result(false, 'escort_rob_time') end
    local denied, wc = robDenied(src, ctx, a, netId, 1.0)
    if denied then
        a.robbery = nil
        return Law.Result(false, denied)
    end

    return ES.WithLock(id, function()
        local nearAtStart = rob.nearAtStart
        a.robbery = nil
        local r = ES.Row(id)
        if not r or r.status ~= 'active' then return Law.Result(false, 'already_done') end
        -- Versicherungsstand VOR dem Wechsel bestimmen (DB-Abfragen), ausgezahlt wird hier nichts
        local insState, insAmount, insReason = insuranceOnRobbery(r, a, ctx, nearAtStart)

        if not Law.Items.Take(src, RCfg.Item, 1) then return Law.Result(false, 'escort_rob_item') end
        -- Atomar active -> robbed; oxmysql wirft bei SQL-Fehlern -> Law.DB.Try (Brecheisen zurueck)
        local okDb, affected = Law.DB.Try(MySQL.update.await, [[UPDATE ara_law_escorts SET status = 'robbed', status_reason = ?, finished_at = ?, escorts = ?,
            robbed_by = ?, robbed_by_identifier = ?, insurance_state = ?, insurance_amount = ? WHERE id = ? AND status = 'active']],
            { insReason or 'robbery', Law.Now(), json.encode(a.members), ctx.charId, ctx.identifier, insState, insAmount, id })
        if not okDb or affected ~= 1 then
            Law.Items.Give(src, RCfg.Item, 1)
            return Law.Result(false, 'already_done')
        end

        -- Wagen bleibt stehen (Tatort), verschwindet spaeter
        ES.EndRuntime(id, L('escort_ended_robbed', id), true)
        ES.Robbed[netId] = { id = id, robberCharId = ctx.charId }
        SetTimeout((RCfg.WagonDeleteAfter or 600) * 1000, function()
            local rb = ES.Robbed[netId]
            if rb and rb.id == id then
                ES.Robbed[netId] = nil
                ES.DeleteWagon(netId)
            end
        end)

        -- Preis + Praemie in die Kasse (aus ihr zahlt spaeter eine freigegebene Versicherung)
        -- Beute ZUERST (Status ist schon 'robbed' - ein DB-Fehler bei der Kasse
        -- darf die Beute nicht verschlucken), Kasse danach abgesichert
        local hasItems, money, gold = ES.GiveLoot(src, ctx, r)

        local income = Law.Round((tonumber(r.price) or 0) + (tonumber(r.premium) or 0), 2)
        if income > 0 then Law.DB.Try(Law.Society.Add, ECfg.Department, income, 'escort_contract', nil) end

        -- Spur am Tatort (Geruch des Raeubers fuer den Bluthund)
        if wc then Law.Evidence.CreateTrace('cloth', wc, { ownerCharId = ctx.charId }) end

        local client = tonumber(r.client_charid)
        local recipient = tonumber(r.recipient_charid) or client
        if insState == 'pending' then
            ES.NotifyChar(client, L('escort_client_robbed_pending', id, insAmount), 'error')
            ES.NotifyInsuranceDesk(L('escort_ins_new', id, insAmount))
        elseif insState == 'denied' then
            ES.NotifyChar(client, L('escort_client_robbed_denied', id, L('escort_' .. insReason)), 'error')
        else
            ES.NotifyChar(client, L('escort_client_robbed', id), 'error')
        end
        if recipient ~= client then ES.NotifyChar(recipient, L('escort_recipient_robbed', id), 'error') end

        Law.Audit(ctx, 'escort.robbed', client, {
            id = id, money = money, gold = gold, cargo = r.cargo,
            insuranceState = insState, insuranceAmount = insAmount, insuranceReason = insReason, escortsNear = nearAtStart,
        })
        CreateThread(function() sendLootList(src, ctx.charId) end)
        return Law.Result(true, { id = id, opened = hasItems, money = money, gold = gold }, L('escort_rob_success', id))
    end)
end)

--- Beutefach erneut oeffnen (nur der Raeuber, Items liegen unter seiner charId)
Law.Cb.Register('escort:openLoot', { rate = 2000, notCuffed = true, notJailed = true, alive = true }, function(src, ctx, id)
    id = Law.ToInt(id, 1)
    local r = id and ES.Row(id)
    if not r or r.status ~= 'robbed' or tonumber(r.robbed_by) ~= ctx.charId or #ES.CargoList(r) == 0 then
        return Law.Result(false, 'not_found')
    end
    ES.OpenInv(src, ES.LootId(id), L('escort_loot_name', id), nil)
    return Law.Result(true, nil, L('escort_loot_opened', id))
end)

Law.Modules.Register('escort_incidents', {
    playerLoaded = function(src, ctx)
        sendLootList(src, ctx.charId)
    end,
    playerDropped = function(src)
        for _, a in pairs(ES.Active) do
            if a.robbery and a.robbery.src == src then a.robbery = nil end
        end
    end,
})
