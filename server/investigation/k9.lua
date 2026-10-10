--[[
    ArA-LawSystem - Bluthund und Spurverfolgung (Server)

    Ablauf: Hundefuehrer holt den Hund (Zwinger oder Pfeife) -> Server gibt
    frei -> Client spawnt einen vernetzten Hund -> meldet die NetId -> Server
    prueft Modell und Abstand. Ein Hund je Hundefuehrer.

    Spurverfolgung (Masterplan 4.3 / Luecke 15 "Hund als Ortungswerkzeug"):
      - nur mit echtem Geruchstraeger aus dem Inventar (evidence_id -> DB-Besitzer)
      - neuester Spurpunkt <= SniffRadius vom HUND, nicht aelter als MaxAge
      - die Spur geht STUECKWEISE an den Client; vor jedem neuen Stueck prueft
        der Server die echte Hunde-Position (Law.EntityCoords), den Abstand
        zum Hundefuehrer und eine Mindestzeit (Hund kann nicht teleportieren)
      - Abklingzeit auch ohne Treffer (sonst waere "kein Geruch" eine Ortsauskunft)
]]

local KCfg = Config.K9
local SCfg = Config.Scent

local dogs        = {}  -- [src] = { charId, netId?, pendingAt?, spawnedAt? }
local deathAt     = {}  -- [charId] = unix (Tod des Hundes)
local sessions    = {}  -- [src] = { id, target, trail, lastIndex, lastPoint, lastSentAt, minMs, startedAt, strength }
local nextSession = 0

--- Entity hinter einer gespeicherten NetId - nur, wenn es noch ein Hund des
--- erlaubten Modells ist (NetIds werden nach dem Loeschen wiederverwendet).
local function dogEntity(netId)
    if not netId then return nil, 0 end
    local coords, ent = Law.EntityCoords(netId)
    if not coords or not Law.ModelMatches(ent, KCfg.Model) then return nil, 0 end
    return coords, ent
end

local function dogCoords(src)
    local d = dogs[src]
    if not d or not d.netId then return nil, 0 end
    return dogEntity(d.netId)
end

--- Nur beim Spawn gepruefte Hunde (eigenes, passendes Entity) werden geloescht,
--- und auch dann nur, wenn das Modell noch passt.
local function deleteDogEntity(d)
    if d and d.netId then
        local _, ent = dogEntity(d.netId)
        if ent and ent ~= 0 then DeleteEntity(ent) end
    end
end

--- Hund steht nah genug am Hundefuehrer? (Server-Positionen)
local function dogNearHandler(src, dogPos)
    return dogPos ~= nil and Law.IsNearCoords(src, dogPos, KCfg.SummonDistance or 10.0)
end

local function endSession(src, reason, notify)
    if not sessions[src] then return end
    sessions[src] = nil
    if notify and GetPlayerPing(src) > 0 then
        TriggerClientEvent('ara_law:cl:k9:sessionEnded', src, reason)
    end
end

local function removeDog(src, reason, notify)
    local d = dogs[src]
    dogs[src] = nil
    endSession(src, reason, false)
    if d then deleteDogEntity(d) end
    if notify and GetPlayerPing(src) > 0 then
        TriggerClientEvent('ara_law:cl:k9:removed', src, reason)
    end
end

--- Darf gerade ein Hund gerufen werden? -> nil oder Result
local function summonBlocked(src, ctx)
    local d = dogs[src]
    if d and d.netId then return Law.Result(false, 'k9_active') end
    if d and d.pendingAt and Law.Now() - d.pendingAt <= 30 then return Law.Result(false, 'k9_pending') end
    local died = deathAt[ctx.charId]
    local cd = KCfg.DeathCooldown or 300
    if died and Law.Now() - died < cd then
        return Law.Result(false, 'k9_dead_cooldown', L('err_k9_dead_cooldown', Law.Duration(cd - (Law.Now() - died))))
    end
    return nil
end

--------------------------------------------------------------------------
-- Hund holen / abgeben
--------------------------------------------------------------------------
Law.Cb.Register('k9:request', { perm = 'k9', rate = 2000, notCuffed = true, alive = true }, function(src, ctx)
    if not KCfg.FromKennel then return Law.Result(false, 'k9_disabled') end
    local station, point = Law.Stations.NearPoint(src, 'kennel')
    if not station or not point or not Law.Stations.AllowsDept(station, ctx.dept) then return Law.Result(false, 'not_at_point') end
    local blocked = summonBlocked(src, ctx)
    if blocked then return blocked end
    dogs[src] = { charId = ctx.charId, pendingAt = Law.Now() }
    -- Eigener Spawn am Zwinger (points.kennel.spawn) -> genau dort, sonst neben dem Prompt
    if point.spawn then
        local s = point.spawn
        return Law.Result(true, { model = KCfg.Model, spawn = { x = s.x, y = s.y, z = s.z, w = s.w or 0.0, exact = true } })
    end
    local c = Law.Vec(point.coords)
    return Law.Result(true, { model = KCfg.Model, spawn = { x = c.x, y = c.y, z = c.z, w = point.heading or 0.0 } })
end)

Law.Items.RegisterUsable(Config.Items.Whistle, function(src, ctx)
    local d = dogs[src]
    if d and d.netId then
        removeDog(src, 'dismissed', true)
        Law.Audit(ctx, 'k9.dismiss', nil, { via = 'whistle' })
        return Law.Notify(src, L('k9_dismissed'), 'info')
    end
    if not KCfg.FromWhistle then return Law.Notify(src, L('err_k9_disabled'), 'error') end
    local blocked = summonBlocked(src, ctx)
    if blocked then return Law.Notify(src, blocked.msg, 'error') end
    dogs[src] = { charId = ctx.charId, pendingAt = Law.Now() }
    TriggerClientEvent('ara_law:cl:k9:spawn', src, { model = KCfg.Model })
end, { perm = 'k9', notCuffed = true, alive = true })

Law.Net.On('k9:spawned', { perm = 'k9', rate = 1000 }, function(src, ctx, netId)
    netId = Law.ToInt(netId, 1)
    local d = dogs[src]
    if not d or d.netId or not d.pendingAt or d.checking or not netId then return end
    d.checking = true
    -- OneSync kennt frisch erzeugte Entities erst nach einem Moment
    local coords, ent = Law.EntityCoordsWait(netId, 3000)
    d.checking = nil
    if dogs[src] ~= d then return end
    -- Nur ein EIGENES Entity des erlaubten Modells nah am Hundefuehrer. Der Server
    -- loescht hier NIE etwas (die NetId kommt vom Client) - er lehnt nur ab,
    -- der Client raeumt sein lokales Objekt selbst weg.
    local valid = coords and Law.ModelMatches(ent, KCfg.Model) and Law.IsEntityOwner(ent, src)
        and Law.IsNearCoords(src, coords, 40.0)
    if not valid then
        dogs[src] = nil
        TriggerClientEvent('ara_law:cl:k9:removed', src, 'rejected', netId)
        Law.Warn('K9: Hund von %s abgelehnt (NetId %s)', tostring(src), tostring(netId))
        return
    end
    d.netId, d.pendingAt, d.spawnedAt = netId, nil, Law.Now()
    Law.Audit(ctx, 'k9.summon', nil, { netId = netId })
end)

Law.Net.On('k9:dismiss', { law = true, duty = false, rate = 1000 }, function(src, ctx, silent)
    if not dogs[src] then return end
    removeDog(src, 'dismissed', true)
    if not Law.ToBool(silent) then
        Law.Notify(src, L('k9_dismissed'), 'info')
        Law.Audit(ctx, 'k9.dismiss', nil, nil)
    end
end)

-- Nur Signal vom Client: schadet hoechstens dem Melder selbst (Abklingzeit)
Law.Net.On('k9:died', { law = true, duty = false, rate = 2000 }, function(src, ctx)
    local d = dogs[src]
    if not d or not d.netId then return end
    deathAt[ctx.charId] = Law.Now()
    dogs[src] = nil
    endSession(src, 'died', false)
    -- Kadaver spaeter serverseitig entfernen (nicht nur per Client-Timeout),
    -- und nur, wenn hinter der NetId noch ein Hund dieses Modells steckt
    local netId = d.netId
    SetTimeout(20000, function()
        local _, ent = dogEntity(netId)
        if ent and ent ~= 0 then DeleteEntity(ent) end
    end)
    Law.Audit(ctx, 'k9.died', nil, nil)
end)

--------------------------------------------------------------------------
-- Umgebung absuchen
--------------------------------------------------------------------------
Law.Cb.Register('k9:search', { perm = 'k9', rate = 1500, alive = true }, function(src, ctx)
    local dogPos = dogCoords(src)
    if not dogPos then return Law.Result(false, 'k9_no_dog') end
    -- Suche nur mit dem Hund an der Seite (sonst waere der Hund ein Fern-Radar)
    if not dogNearHandler(src, dogPos) then return Law.Result(false, 'k9_dog_far') end
    if not Law.RateLimit(src, 'k9:search:cd', ((KCfg.Search and KCfg.Search.Cooldown) or 60) * 1000) then
        return Law.Result(false, 'cooldown')
    end
    local radius = (KCfg.Search and KCfg.Search.Radius) or 25.0
    local best, bestDist, bestCoords
    for other in pairs(Law.Players) do
        -- Nicht der Hundefuehrer, kein Gesetz im Dienst
        if other ~= src and not Law.Duty.active[other] then
            local c = Law.GetCoords(other)
            local dist = c and #(c - dogPos)
            if dist and dist <= radius and (not bestDist or dist < bestDist) then
                best, bestDist, bestCoords = other, dist, c
            end
        end
    end
    local target = best and Law.Players[best]
    Law.Audit(ctx, 'k9.search', target and target.charId or nil, { found = best ~= nil })
    if not best then return Law.Result(true, { found = false }) end
    return Law.Result(true, { found = true, serverId = best, coords = Law.VecToTable(bestCoords) })
end)

--------------------------------------------------------------------------
-- Geruchstraeger aus dem Inventar
--------------------------------------------------------------------------
local function isScentSource(name)
    if not name or not (SCfg.SourceItems or {})[name] then return false end
    if name == Config.Items.Casing and not Config.Evidence.CasingHasScent then return false end
    return true
end

Law.Cb.Register('k9:scentItems', { perm = 'k9', rate = 1000 }, function(src)
    local out = {}
    for _, it in ipairs(Law.Inv:getUserInventoryItems(src) or {}) do
        local meta = type(it.metadata) == 'table' and it.metadata or {}
        if isScentSource(it.name) and tonumber(meta.evidence_id) then
            local kind = Law.Evidence.TypeByItem[it.name]
            out[#out + 1] = {
                id          = it.id,
                name        = it.name,
                typeLabel   = Law.Evidence.TypeLabel(kind),
                evidenceId  = tonumber(meta.evidence_id),
                uses        = tonumber(meta.uses) or (SCfg.UsesPerItem or 3),
                description = meta.description or it.desc or '',
            }
        end
    end
    return Law.Result(true, out)
end)

--------------------------------------------------------------------------
-- Spurverfolgung
--------------------------------------------------------------------------
local function toTable(p) return { x = Law.Round(p.x, 2), y = Law.Round(p.y, 2), z = Law.Round(p.z, 2) } end

--- Naechstes Stueck ab Index `from` (vorwaerts in der Zeit). Setzt lastIndex,
--- lastPoint und die Mindestzeit, die der Hund fuer dieses Stueck braucht.
local function nextChunk(s, from, startPos)
    local tr = s.trail
    local to = math.min(from + (SCfg.Chunk or 15) - 1, tr.last)
    -- An einem Sprung (gap, scent.lua) endet das Stueck: kein Lauf querfeldein
    for i = from + 1, to do
        if tr.points[i].gap then
            to = i - 1
            break
        end
    end
    local points, length, prev = {}, 0.0, startPos
    for i = from, to do
        local p = tr.points[i]
        local v = vector3(p.x, p.y, p.z)
        length = length + #(v - prev)
        prev = v
        points[#points + 1] = toTable(p)
    end
    s.lastIndex = to
    s.lastPoint = prev
    s.lastSentAt = GetGameTimer()
    s.minMs = math.floor(length / (SCfg.MaxDogSpeed or 10.0) * 1000)
    s.strength = Law.Scent.Strength(tr.points[from].t)
    return points
end

Law.Cb.Register('scent:start', { perm = 'k9', rate = 1500, notCuffed = true, alive = true }, function(src, ctx, itemId)
    itemId = Law.ToInt(itemId, 1)
    if not itemId then return Law.Result(false, 'invalid') end
    local item = Law.Items.GetById(src, itemId)
    if not item or not isScentSource(item.name) then return Law.Result(false, 'scent_bad_item') end
    local meta = type(item.metadata) == 'table' and Law.Copy(item.metadata) or {}
    local evId = tonumber(meta.evidence_id)
    if not evId then return Law.Result(false, 'scent_bad_item') end
    local uses = tonumber(meta.uses) or (SCfg.UsesPerItem or 3)
    if uses <= 0 then return Law.Result(false, 'scent_used_up') end

    local d = dogs[src]
    if not d or not d.netId then return Law.Result(false, 'k9_no_dog') end
    local dogPos = dogCoords(src)
    if not dogPos then
        removeDog(src, 'lost', true)
        return Law.Result(false, 'k9_no_dog')
    end
    if not Law.IsNearCoords(src, dogPos, KCfg.SummonDistance or 10.0) then return Law.Result(false, 'k9_dog_far') end

    local row = MySQL.single.await('SELECT owner_charid, status FROM ara_law_evidence WHERE id = ?', { evId })
    local owner = row and tonumber(row.owner_charid)
    if not row or row.status == 'destroyed' or not owner then return Law.Result(false, 'scent_bad_item') end

    -- Abklingzeit ab hier - auch wenn der Hund nichts findet
    if not Law.RateLimit(src, 'scent:start:cd', (SCfg.Cooldown or 60) * 1000) then return Law.Result(false, 'cooldown') end
    endSession(src, 'restart', false)

    -- Neuester Punkt <= SniffRadius vom Hund, nicht aelter als MaxAge
    local tr = Law.Scent.GetTrail(owner)
    local found
    if tr then
        local minT = Law.Now() - (SCfg.MaxAge or 1800)
        local radius = SCfg.SniffRadius or 200.0
        for i = tr.last, tr.first, -1 do
            local p = tr.points[i]
            if p.t < minT then break end
            if #(vector3(p.x, p.y, p.z) - dogPos) <= radius then
                found = i
                break
            end
        end
    end
    if not found then
        Law.Audit(ctx, 'k9.scent_none', owner, { evidence = evId })
        return Law.Result(false, 'scent_none')
    end

    nextSession = nextSession + 1
    local s = { id = nextSession, target = owner, trail = tr, startedAt = Law.Now() }
    local points = nextChunk(s, found, dogPos)
    sessions[src] = s

    -- Geruchstraeger nutzt sich ab
    uses = uses - 1
    meta.uses = uses
    meta.base = meta.base or meta.description
    meta.description = tostring(meta.base or '') .. ' ' .. L('scent_uses_suffix', uses)
    Law.Items.SetMetadata(src, itemId, meta)

    Law.Audit(ctx, 'k9.track_start', owner, { evidence = evId, strength = s.strength })
    return Law.Result(true, { sessionId = s.id, points = points, strength = s.strength }, L('k9_track_started'))
end)

Law.Cb.Register('scent:next', { perm = 'k9', rate = 800, alive = true }, function(src, ctx, sessionId)
    sessionId = Law.ToInt(sessionId, 1)
    local s = sessions[src]
    if not s or s.id ~= sessionId then return Law.Result(false, 'scent_no_session') end
    if Law.Now() - s.startedAt > (SCfg.SessionTimeout or 600) then
        endSession(src, 'timeout', false)
        return Law.Result(true, { lost = true, reason = 'timeout' })
    end

    local dogPos = dogCoords(src)
    if not dogPos then
        removeDog(src, 'lost', true)
        return Law.Result(false, 'k9_no_dog')
    end
    if #(dogPos - s.lastPoint) > (SCfg.Tolerance or 15.0) then return Law.Result(false, 'scent_not_there') end
    if not Law.IsNearCoords(src, dogPos, KCfg.HandlerMaxDistance or 60.0) then return Law.Result(false, 'k9_handler_far') end
    if GetGameTimer() - s.lastSentAt < (s.minMs or 0) then return Law.Result(false, 'scent_too_fast') end

    -- Person in Reichweite des Hundes? -> gestellt
    local tsrc = Law.SrcByCharId(s.target)
    local tpos = tsrc and Law.GetCoords(tsrc)
    if tpos and #(dogPos - tpos) <= (SCfg.FoundDistance or 5.0) then
        endSession(src, 'found', false)
        Law.Audit(ctx, 'k9.track_found', s.target, nil)
        return Law.Result(true, { found = true, serverId = tsrc }, L('k9_found'))
    end

    local tr = Law.Scent.GetTrail(s.target)
    if not tr or tr ~= s.trail or s.lastIndex + 1 < tr.first then
        endSession(src, 'lost', false)
        return Law.Result(true, { lost = true, reason = 'faded' })
    end
    if tr.last > s.lastIndex then
        if tr.points[s.lastIndex + 1].gap then
            -- Die Person ist hier "verschwunden" (Teleport, Knast, Respawn): Spur endet
            endSession(src, 'lost', false)
            Law.Audit(ctx, 'k9.track_lost', s.target, { reason = 'gap' })
            return Law.Result(true, { lost = true, reason = 'end' })
        end
        local points = nextChunk(s, s.lastIndex + 1, dogPos)
        return Law.Result(true, { points = points, strength = s.strength })
    end

    -- Ende der gespeicherten Spur
    if tpos and SCfg.FollowLive then
        -- Person steht am Spurende still (es entstehen keine neuen Punkte): letzter Schritt zu ihr
        if #(s.lastPoint - tpos) <= (SCfg.MinStep or 3.0) * 3 then
            s.lastPoint = tpos
            s.lastSentAt = GetGameTimer()
            s.minMs = math.floor(#(tpos - dogPos) / (SCfg.MaxDogSpeed or 10.0) * 1000)
            s.strength = 'fresh'
            return Law.Result(true, { points = { toTable(tpos) }, strength = 'fresh' })
        end
        return Law.Result(true, { wait = true, strength = s.strength })
    end
    -- Offline oder Live-Verfolgung aus: Spur endet hier (z.B. am Ausloggpunkt)
    endSession(src, 'lost', false)
    Law.Audit(ctx, 'k9.track_lost', s.target, nil)
    return Law.Result(true, { lost = true, reason = 'end' })
end)

Law.Net.On('scent:stop', { law = true, duty = false, rate = 500 }, function(src)
    endSession(src, 'stopped', false)
end)

--------------------------------------------------------------------------
-- Stellen / Angriff (nur wenn in der Config erlaubt)
--------------------------------------------------------------------------
Law.Cb.Register('k9:attack', { perm = 'k9', rate = 3000, alive = true }, function(src, ctx, targetSrc)
    if not KCfg.AllowAttack then return Law.Result(false, 'k9_disabled') end
    targetSrc = Law.ToInt(targetSrc, 1)
    local target = targetSrc and targetSrc ~= src and Law.Ctx(targetSrc)
    if not target then return Law.Result(false, 'no_target') end
    local dogPos = dogCoords(src)
    if not dogPos then return Law.Result(false, 'k9_no_dog') end
    if not dogNearHandler(src, dogPos) then return Law.Result(false, 'k9_dog_far') end
    if not Law.IsNearCoords(targetSrc, dogPos, 30.0) then return Law.Result(false, 'too_far') end
    Law.Audit(ctx, 'k9.attack', target.charId, nil)
    return Law.Result(true, { serverId = targetSrc })
end)

--------------------------------------------------------------------------
-- Pruefung, Lebenszyklus
--------------------------------------------------------------------------
Law.Every(5000, function()
    local now = Law.Now()
    for src, d in pairs(dogs) do
        if d.pendingAt and now - d.pendingAt > 30 then
            dogs[src] = nil  -- Spawn nie gemeldet
        elseif d.netId and not dogEntity(d.netId) then
            -- Hund weg oder NetId gehoert inzwischen einem anderen Entity
            removeDog(src, 'lost', true)
        end
    end
    for src, s in pairs(sessions) do
        if now - s.startedAt > (SCfg.SessionTimeout or 600) then endSession(src, 'timeout', true) end
    end
end)

Law.Modules.Register('k9', {
    dutyChanged = function(src, _, onDuty)
        if not onDuty and dogs[src] then removeDog(src, 'duty', true) end
    end,
    jobChanged = function(src)
        if dogs[src] then removeDog(src, 'duty', true) end
    end,
    playerDropped = function(src)
        removeDog(src, 'dropped', false)
    end,
    stop = function()
        for _, d in pairs(dogs) do deleteDogEntity(d) end
        dogs = {}
        sessions = {}
    end,
})
