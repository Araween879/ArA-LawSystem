--[[
    ArA-LawSystem - NPC-Einsaetze (Server, Agent A)

    NPC-Kopfgelder (Steckbriefbrett):
      npc:accept(id)                        -> Auftrag + Zielgebiet an den Client
      npc:spawned(contractId, targetNet, gangNets)   (Net, Client meldet gespawnte Peds)
      npc:deliver()                         -> an der Abgabestelle (dropoff)
      npc:abort()                           (Zusatz) Auftrag abbrechen
      Law.Justice.NpcBoard(src)             -> [NpcContract] fuer bounty:board

    NPC-Streifen (Leitstelle):
      Server-Timer -> Law.Dispatch.Create{ kind='npc', perm='npc_calls', onAccept, onClose }
      erster Annehmender spawnt die NPCs -> npc:callSpawned(callId, nets)
      Abschluss wird serverseitig geprueft (Mindestzeit, Beamte am Ort, NPCs tot/weg).

    Anti-Farm: Modell + Position + Mindestdauer + Gesundheit serverseitig,
    Stundenlimit, Abklingzeit. NPCs sind vernetzt, der Server loescht sie.
]]

Law.Justice = Law.Justice or {}

local offers    = {}  -- [targetId] = { reward, expiresAt, takenBy = charId|nil }
local contracts = {}  -- [src] = contract
local history   = {}  -- [charId] = { accepts = { unix, ... }, lastEnd = unix }
local calls     = {}  -- [callId] = call
local nextContractId, nextCallId = 0, 0
local nextCallAt = 0

--------------------------------------------------------------------------
-- Helfer
--------------------------------------------------------------------------
local function targetCfg(id)
    for _, t in ipairs(Config.Npc.Bounties.Targets or {}) do
        if t.id == id then return t end
    end
    return nil
end

local function sameModel(ent, model)
    local h = GetEntityModel(ent)
    if not h then return false end
    return (h & 0xFFFFFFFF) == (joaat(model) & 0xFFFFFFFF)
end

local function modelIn(ent, list)
    for _, m in ipairs(list or {}) do
        if sameModel(ent, m) then return true end
    end
    return false
end

local function entityAlive(netId)
    local c, ent = Law.EntityCoords(netId)
    if not c then return false, false, nil end
    return GetEntityHealth(ent) > 0, true, ent
end

--- NetIds werden wiederverwendet: nur loeschen, was noch ein NPC-Ped ist -
--- nie ein Fahrzeug/Objekt und nie den Ped eines Spielers (Vertragsregel 4).
local function safeDeletePed(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    if GetEntityType(ent) ~= 1 then return end
    local okP, isPlayer = pcall(IsPedAPlayer, ent)
    if okP and isPlayer then return end
    DeleteEntity(ent)
end

local function deleteNet(netId)
    local _, ent = Law.EntityCoords(netId)
    safeDeletePed(ent)
end

local function rollRange(r, fallback)
    if type(r) ~= 'table' then return fallback end
    local a, b = tonumber(r[1]) or fallback, tonumber(r[2]) or tonumber(r[1]) or fallback
    if b < a then a, b = b, a end
    return math.random(math.floor(a), math.floor(b))
end

local function toTable(v)
    return Law.VecToTable(v)
end

--- Positionsprobe des NPC-Ziels (M9). Merkt letzte Position + Zeit; eine
--- unplausible Geschwindigkeit (Teleport) macht den Auftrag ungueltig.
--- -> false, wenn ungueltig
function Law.Justice.NpcSample(c)
    if c.invalid then return false end
    if not c.targetNet then return true end
    local coords = Law.EntityCoords(c.targetNet)
    if not coords then return true end  -- gerade nicht vorhanden: keine Aussage
    local t = GetGameTimer()
    if c.lastPos and c.lastAt then
        local dt = (t - c.lastAt) / 1000.0
        if dt >= 0.5 and #(coords - c.lastPos) / dt > (Config.Npc.Bounties.MaxSpeed or 40.0) then
            c.invalid = true
            return false
        end
    end
    c.lastPos, c.lastAt = coords, t
    c.samples = (c.samples or 0) + 1
    return true
end

--------------------------------------------------------------------------
-- NPC-Kopfgelder: Angebote am Brett
--------------------------------------------------------------------------
local function refreshOffers()
    local now = Law.Now()
    local life = (Config.Npc.Bounties.OfferMinutes or 60) * 60
    for _, t in ipairs(Config.Npc.Bounties.Targets or {}) do
        local o = offers[t.id]
        if not o or (not o.takenBy and o.expiresAt <= now) then
            offers[t.id] = { reward = rollRange(t.reward, 50), expiresAt = now + life, takenBy = nil }
        end
    end
end

function Law.Justice.NpcBoard(src)
    if not Config.Npc.Bounties.Enabled then return {} end
    refreshOffers()
    local out = {}
    for _, t in ipairs(Config.Npc.Bounties.Targets or {}) do
        local o = offers[t.id]
        if o and not o.takenBy then
            out[#out + 1] = {
                id = t.id, name = t.name, description = t.description, areaLabel = t.areaLabel,
                reward = o.reward, aliveBonus = t.aliveBonus or 0, gangSize = t.count or 0,
                difficulty = t.difficulty or 1, expiresAt = o.expiresAt,
            }
        end
    end
    return out
end

local function endContract(src, reasonKey)
    local c = contracts[src]
    if not c then return end
    contracts[src] = nil
    c.state = 'closed'
    if c.targetNet then deleteNet(c.targetNet) end
    for _, n in ipairs(c.gangNets or {}) do deleteNet(n) end
    local h = history[c.charId] or { accepts = {} }
    h.lastEnd = Law.Now()
    history[c.charId] = h
    local o = offers[c.targetId]
    if o and o.takenBy == c.charId then offers[c.targetId] = nil end  -- neues Angebot beim naechsten Blick aufs Brett
    if GetPlayerPing(src) > 0 then
        TriggerClientEvent('ara_law:cl:npc:cleanup', src, c.id)
        if reasonKey then Law.Notify(src, L(reasonKey, c.name), 'info', 8000) end
    end
end

--------------------------------------------------------------------------
-- Auftrag annehmen
--------------------------------------------------------------------------
Law.Cb.Register('npc:accept', { rate = 2000, notCuffed = true, notJailed = true, alive = true }, function(src, ctx, id)
    local cfg = Config.Npc.Bounties
    if not cfg.Enabled then return Law.Result(false, 'module_missing') end
    id = Law.ToStr(id, 32)
    local t = id and targetCfg(id)
    if not t then return Law.Result(false, 'not_found') end
    if not Law.Stations.NearPoint(src, 'board', Config.Bounty.BoardDistance or 5.0) then return Law.Result(false, 'not_at_point') end

    local isLaw = cfg.AllowLaw and ctx.dept ~= nil and ctx.onDuty
    if not isLaw and not Law.Bounty.CanHunt(src) then return Law.Result(false, 'no_license') end

    if contracts[src] then return Law.Result(false, 'contract_active') end
    local now = Law.Now()
    local h = history[ctx.charId] or { accepts = {} }
    history[ctx.charId] = h
    if h.lastEnd and now - h.lastEnd < (cfg.Cooldown or 600) then
        return Law.Result(false, 'contract_cooldown', L('err_contract_cooldown_time', Law.Duration((cfg.Cooldown or 600) - (now - h.lastEnd))))
    end
    local recent = {}
    for _, at in ipairs(h.accepts) do
        if now - at < 3600 then recent[#recent + 1] = at end
    end
    h.accepts = recent
    if #recent >= (cfg.PerHunterPerHour or 3) then return Law.Result(false, 'contract_limit') end

    refreshOffers()
    local o = offers[t.id]
    if not o or o.takenBy then return Law.Result(false, 'contract_taken') end
    -- ab hier ohne yield: Angebot sofort belegen
    o.takenBy = ctx.charId
    h.accepts[#h.accepts + 1] = now

    local areas = t.areas or {}
    local area = areas[math.random(1, math.max(1, #areas))]
    if not area then
        o.takenBy = nil
        return Law.Result(false, 'invalid')
    end
    nextContractId = nextContractId + 1
    local c = {
        id = nextContractId, charId = ctx.charId, targetId = t.id, name = t.name, model = t.model,
        area = Law.Vec(area), reward = o.reward, aliveBonus = t.aliveBonus or 0,
        acceptedAt = now, expiresAt = now + (cfg.MaxMinutes or 45) * 60,
        targetNet = nil, gangNets = {}, state = 'active',
    }
    contracts[src] = c

    local gang = {}
    local gm = t.gang or {}
    if #gm > 0 then
        for n = 1, (t.count or 0) do gang[n] = gm[math.random(1, #gm)] end
    end
    TriggerClientEvent('ara_law:cl:npc:contract', src, {
        id = c.id, name = t.name, model = t.model, gang = gang, area = toTable(c.area), areaLabel = t.areaLabel,
        radius = cfg.AreaRadius or 120.0, spawnDistance = cfg.SpawnDistance or 250.0,
        weapons = cfg.Weapons or {}, expiresAt = c.expiresAt, reward = c.reward, aliveBonus = c.aliveBonus,
    })
    Law.Audit(ctx, 'bounty.npc_accept', nil, { target = t.id, reward = c.reward })
    return Law.Result(true, { id = c.id, expiresAt = c.expiresAt }, L('npc_accepted', t.name, t.areaLabel))
end)

Law.Net.On('npc:spawned', { rate = 1000 }, function(src, ctx, contractId, targetNet, gangNets)
    local c = contracts[src]
    contractId = Law.ToInt(contractId, 1)
    targetNet = Law.ToInt(targetNet, 1)
    if not c or c.id ~= contractId or c.targetNet or not targetNet then return end
    local coords, ent = Law.EntityCoords(targetNet)
    local maxD = Config.Npc.Bounties.SpawnCheckRadius or 400.0
    if not coords or not sameModel(ent, c.model) or #(coords - c.area) > maxD then
        Law.Warn('NPC-Kopfgeld #%d: ungueltige Spawn-Meldung von %s', c.id, tostring(src))
        return
    end
    c.targetNet = targetNet
    c.spawnedAt = Law.Now()
    -- erste Positionsprobe (M9)
    c.lastPos, c.lastAt, c.samples = coords, GetGameTimer(), 1
    local t = targetCfg(c.targetId)
    local maxGang = (t and t.count or 0)
    if type(gangNets) == 'table' then
        for _, n in ipairs(gangNets) do
            n = Law.ToInt(n, 1)
            if n and #c.gangNets < maxGang then
                local gc, gent = Law.EntityCoords(n)
                if gc and #(gc - c.area) <= maxD and modelIn(gent, t and t.gang) then c.gangNets[#c.gangNets + 1] = n end
            end
        end
    end
end)

Law.Cb.Register('npc:abort', { rate = 2000 }, function(src, ctx)
    if not contracts[src] then return Law.Result(false, 'no_contract') end
    Law.Audit(ctx, 'bounty.npc_abort', nil, { target = contracts[src].targetId })
    endContract(src, 'npc_aborted')
    return Law.Result(true, nil, L('npc_aborted_ok'))
end)

--------------------------------------------------------------------------
-- NPC-Streifen: Fluechtigen an der Abgabestelle abliefern
--------------------------------------------------------------------------
local function completeCall(call, reasonKey, payTo)
    if call.state ~= 'active' then return end
    call.state = 'done'
    local reward = Config.Npc.Calls.Reward or 0
    local paid = 0
    for _, s in ipairs(payTo or {}) do
        if reward > 0 and GetPlayerPing(s) > 0 and Law.Money.Give(s, reward, 0) then
            paid = paid + 1
            Law.Notify(s, L('npc_call_reward', reward), 'success')
        end
    end
    Law.Audit(nil, 'dispatch.npc_done', nil, { call = call.id, type = call.type, paid = paid, reward = reward })
    Law.Dispatch.Close(call.alertId, L(reasonKey))
end

local function deliverFugitive(src, ctx, point)
    for _, call in pairs(calls) do
        if call.state == 'active' and call.type == 'fugitive' and call.nets[1] then
            local alert = Law.Dispatch.Get(call.alertId)
            if alert and alert.responders[src] then
                local coords, ent = Law.EntityCoords(call.nets[1])
                if coords and #(coords - Law.Vec(point.coords)) <= (point.radius or 8.0) + 2.0 then
                    if Law.Now() - (call.acceptedAt or Law.Now()) < (Config.Npc.Calls.MinSeconds or 120) then
                        return Law.Result(false, 'too_early')
                    end
                    safeDeletePed(ent)
                    local payTo = { src }
                    for s in pairs(alert.responders) do
                        if s ~= src and Law.IsNear(s, src, Config.Npc.Calls.CompleteRadius or 100.0) then payTo[#payTo + 1] = s end
                    end
                    completeCall(call, 'npc_call_delivered', payTo)
                    return Law.Result(true, { call = call.id }, L('npc_fugitive_delivered'))
                end
            end
        end
    end
    return nil
end

--------------------------------------------------------------------------
-- Abliefern (Kopfgeld-NPC oder Fluechtiger aus einer Streife)
--------------------------------------------------------------------------
Law.Cb.Register('npc:deliver', { rate = 2000, notCuffed = true, notJailed = true, alive = true }, function(src, ctx)
    local stationKey, point = Law.Stations.NearPoint(src, 'dropoff')
    if not stationKey or not point then return Law.Result(false, 'not_at_point') end

    local c = contracts[src]
    if not c then
        local res = ctx.dept and ctx.onDuty and deliverFugitive(src, ctx, point) or nil
        return res or Law.Result(false, 'no_contract')
    end
    if not c.targetNet then return Law.Result(false, 'not_spawned') end
    if Law.Now() - c.acceptedAt < (Config.Npc.Bounties.MinSeconds or 180) then return Law.Result(false, 'too_early') end

    local coords, ent = Law.EntityCoords(c.targetNet)
    if not coords then return Law.Result(false, 'target_gone') end
    if not sameModel(ent, c.model) then return Law.Result(false, 'wrong_model') end
    local center, radius = Law.Vec(point.coords), (point.radius or 8.0) + 2.0
    if #(coords - center) > radius then return Law.Result(false, 'target_not_in_zone') end

    -- M9: letzte Probe (Teleport kurz vor der Abgabe?) + genug Beobachtung
    if not Law.Justice.NpcSample(c) then
        Law.Audit(ctx, 'bounty.npc_invalid', nil, { target = c.targetId, at = 'deliver' })
        endContract(src, nil)
        return Law.Result(false, 'npc_invalid')
    end
    if (c.samples or 0) < (Config.Npc.Bounties.MinSamples or 6) then return Law.Result(false, 'npc_not_verified') end

    local alive = GetEntityHealth(ent) > 0
    -- atomar im Speicher: erst Zustand wechseln, dann zahlen
    if c.state ~= 'active' or contracts[src] ~= c then return Law.Result(false, 'already_done') end
    c.state = 'delivered'
    local amount = (tonumber(c.reward) or 0) + (alive and (tonumber(c.aliveBonus) or 0) or 0)
    Law.Justice.GiveBack(src, ctx.charId, amount, 'bounty_reward')
    endContract(src, nil)
    Law.Audit(ctx, 'bounty.npc_deliver', nil, { target = c.targetId, amount = amount, alive = alive, station = stationKey })
    return Law.Result(true, { amount = amount, alive = alive }, alive and L('npc_delivered_alive', c.name, amount) or L('npc_delivered_dead', c.name, amount))
end)

--------------------------------------------------------------------------
-- NPC-Streifen: Anlegen, Annehmen, Pruefen, Schliessen
--------------------------------------------------------------------------
local function pickType()
    local total, list = 0, {}
    for key, t in pairs(Config.Npc.Calls.Types or {}) do
        local w = tonumber(t.weight) or 1
        if w > 0 then total = total + w; list[#list + 1] = { key = key, w = w } end
    end
    if total <= 0 then return nil end
    table.sort(list, function(a, b) return a.key < b.key end)
    local r, acc = math.random() * total, 0
    for _, e in ipairs(list) do
        acc = acc + e.w
        if r <= acc then return e.key end
    end
    return list[#list].key
end

local function sendSpawn(call, src)
    call.spawner = src
    local tcfg = Config.Npc.Calls.Types[call.type]
    TriggerClientEvent('ara_law:cl:npc:callSpawn', src, {
        callId = call.id, type = call.type, coords = toTable(call.coords), models = call.models,
        weapons = tcfg and tcfg.weapons or {}, spawnDistance = Config.Npc.Calls.SpawnDistance or 200.0,
    })
end

local function onCallAccept(callId, src)
    local call = calls[callId]
    if not call or call.state ~= 'active' then return end
    call.acceptedAt = call.acceptedAt or Law.Now()
    if not call.spawner or GetPlayerPing(call.spawner) <= 0 then sendSpawn(call, src) end
end

local function onCallClose(callId)
    local call = calls[callId]
    if not call then return end
    calls[callId] = nil
    call.state = 'closed'
    for _, n in ipairs(call.nets) do deleteNet(n) end
    if call.spawner and GetPlayerPing(call.spawner) > 0 then
        TriggerClientEvent('ara_law:cl:npc:callCleanup', call.spawner, call.id)
    end
end

local function createCall()
    local cfg = Config.Npc.Calls
    local typeKey = pickType()
    local locs = cfg.Locations or {}
    if not typeKey or #locs == 0 then return end
    local loc = locs[math.random(1, #locs)]
    local tcfg = cfg.Types[typeKey]
    local count = rollRange(tcfg.count, 1)
    local models = {}
    for n = 1, math.max(1, count) do models[n] = tcfg.models[math.random(1, #tcfg.models)] end

    nextCallId = nextCallId + 1
    local call = {
        id = nextCallId, type = typeKey, coords = Law.Vec(loc.coords), label = loc.label, models = models,
        nets = {}, seenDead = {}, state = 'active', createdAt = Law.Now(),
    }
    calls[call.id] = call
    local callId = call.id
    call.alertId = Law.Dispatch.Create({
        kind = 'npc', perm = 'npc_calls', coords = call.coords, priority = 2, expires = cfg.Expires or 1800,
        title = L('npc_call_title_' .. typeKey), text = L('npc_call_text_' .. typeKey, loc.label, count),
        onAccept = function(src) onCallAccept(callId, src) end,
        onClose = function() onCallClose(callId) end,
        data = { callId = callId },
    })
    if not call.alertId then calls[callId] = nil end
end

Law.Net.On('npc:callSpawned', { perm = 'npc_calls', rate = 1000 }, function(src, ctx, callId, nets)
    callId = Law.ToInt(callId, 1)
    local call = callId and calls[callId]
    if not call or call.state ~= 'active' or call.spawner ~= src or #call.nets > 0 or type(nets) ~= 'table' then return end
    local tcfg = Config.Npc.Calls.Types[call.type]
    for _, n in ipairs(nets) do
        n = Law.ToInt(n, 1)
        if n and #call.nets < #call.models then
            local c, ent = Law.EntityCoords(n)
            if c and #(c - call.coords) <= 300.0 and modelIn(ent, tcfg and tcfg.models) then
                call.nets[#call.nets + 1] = n
            end
        end
    end
    call.spawnedAt = Law.Now()
end)

local function checkCalls()
    local cfg = Config.Npc.Calls
    local now = Law.Now()
    for id, call in pairs(calls) do
        if call.state == 'active' then
            local alert = Law.Dispatch.Get(call.alertId)
            if not alert then
                onCallClose(id)
            elseif #call.nets == 0 then
                -- Spawner weg, bevor er gespawnt hat -> naechsten Annehmenden beauftragen
                if call.spawner and GetPlayerPing(call.spawner) <= 0 then call.spawner = nil end
                if not call.spawner then
                    for s in pairs(alert.responders) do
                        if GetPlayerPing(s) > 0 then sendSpawn(call, s) break end
                    end
                end
            else
                local anyAlive, kills = false, 0
                for _, n in ipairs(call.nets) do
                    local alive, exists = entityAlive(n)
                    if exists and not alive then call.seenDead[n] = true end
                    if exists and alive then anyAlive = true end
                    if call.seenDead[n] then kills = kills + 1 end
                end
                if not anyAlive and now - (call.acceptedAt or now) >= (cfg.MinSeconds or 120) then
                    local payTo = {}
                    for s in pairs(alert.responders) do
                        if GetPlayerPing(s) > 0 and Law.IsNearCoords(s, call.coords, cfg.CompleteRadius or 100.0) then payTo[#payTo + 1] = s end
                    end
                    if kills == 0 then
                        -- alle geflohen/verschwunden: kein Lohn
                        completeCall(call, 'npc_call_fled', {})
                    elseif #payTo > 0 then
                        completeCall(call, 'npc_call_done', payTo)
                    end
                end
            end
        end
    end
end

local function scheduleNext()
    local r = Config.Npc.Calls.IntervalMin or { 20, 40 }
    nextCallAt = Law.Now() + rollRange(r, 30) * 60
end

local function callTimer()
    local cfg = Config.Npc.Calls
    if not cfg.Enabled or Law.Now() < nextCallAt then return end
    scheduleNext()
    if next(calls) ~= nil then return end
    if Law.Count(Law.GetOnDuty('npc_calls')) < (cfg.MinOnDuty or 1) then return end
    createCall()
end

local function checkContracts()
    local now = Law.Now()
    local list = {}
    for src, c in pairs(contracts) do list[#list + 1] = { src = src, c = c } end
    for _, e in ipairs(list) do
        local src, c = e.src, e.c
        if contracts[src] == c then
            if now >= c.expiresAt then
                endContract(src, 'npc_expired')
            elseif c.targetNet and not Law.Justice.NpcSample(c) then
                -- Teleport/Manipulation erkannt -> Auftrag ohne Lohn beendet (M9)
                Law.Audit(Law.Players[src] and { charId = Law.Players[src].charId, name = Law.Players[src].name } or nil,
                    'bounty.npc_invalid', nil, { target = c.targetId })
                endContract(src, 'npc_invalid')
            end
        end
    end
end

--------------------------------------------------------------------------
-- Lebenszyklus
--------------------------------------------------------------------------
Law.Modules.Register('npc', {
    init = function()
        scheduleNext()
        Law.Every(30000, callTimer)
        -- Kurzer Takt: Positionsproben der NPC-Ziele (M9)
        Law.Every((Config.Npc.Bounties.SampleSeconds or 5) * 1000, checkContracts)
        Law.Every((Config.Npc.Calls.CheckSeconds or 5) * 1000, checkCalls)
    end,
    playerLoaded = function(src)
        -- Resource-Neustart/Charakterwechsel: alter Auftrag gilt nicht mehr
        if contracts[src] then endContract(src, nil) end
    end,
    playerDropped = function(src)
        if contracts[src] then endContract(src, nil) end
        for _, call in pairs(calls) do
            if call.spawner == src then call.spawner = nil end
        end
    end,
    dutyChanged = function(src, ctx, onDuty)
        if onDuty then return end
        for _, call in pairs(calls) do
            if call.spawner == src and #call.nets == 0 then call.spawner = nil end
        end
    end,
    stop = function()
        -- nur synchrone Aufraeumarbeit
        for _, c in pairs(contracts) do
            if c.targetNet then deleteNet(c.targetNet) end
            for _, n in ipairs(c.gangNets or {}) do deleteNet(n) end
        end
        for _, call in pairs(calls) do
            for _, n in ipairs(call.nets) do deleteNet(n) end
        end
        contracts, calls = {}, {}
    end,
})
