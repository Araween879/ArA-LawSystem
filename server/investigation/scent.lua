--[[
    ArA-LawSystem - Geruchsspur (Server)

    Der Server zeichnet von JEDEM geladenen Spieler alle RecordInterval
    Sekunden die Server-Position auf (nur bei Bewegung >= MinStep). Die Spur
    haengt am Charakter (charId), nicht an der Verbindung - nach dem Logout
    bleibt sie bis MaxAge bestehen und endet am Ausloggpunkt.
    Keine DB: Geruch verfliegt, ein Neustart loescht ihn.

    Ringpuffer mit absoluten Indizes (first/last): eine laufende Verfolgung
    (k9.lua) behaelt ihren Index, auch wenn vorne alte Punkte verfallen.
]]

local SCfg = Config.Scent

Law.Scent = Law.Scent or {}

local trails = {}  -- [charId] = { first, last, points = { [i] = { x, y, z, t } } }

local function newTrail()
    return { first = 1, last = 0, points = {} }
end

local function prune(tr, now)
    local limit = now - (SCfg.MaxAge or 1800)
    while tr.first <= tr.last and tr.points[tr.first].t < limit do
        tr.points[tr.first] = nil
        tr.first = tr.first + 1
    end
end

local function record()
    local now = Law.Now()
    local step = SCfg.MinStep or 3.0
    for src, info in pairs(Law.Players) do
        local c = info.charId and Law.GetCoords(src)
        -- (0,0,0) = Ped noch nicht gestreamt / Ladebildschirm
        if c and not (c.x == 0.0 and c.y == 0.0) then
            local tr = trails[info.charId]
            if not tr then
                tr = newTrail()
                trails[info.charId] = tr
            end
            local lastP = tr.last >= tr.first and tr.points[tr.last] or nil
            local dist = lastP and #(vector3(lastP.x, lastP.y, lastP.z) - c) or nil
            if not lastP or dist >= step then
                tr.last = tr.last + 1
                -- Sprung (Teleport, Knast, Respawn): hier beginnt eine NEUE Spur. Der
                -- Hund laeuft nie querfeldein ueber diese Luecke (k9.lua endet an gap).
                -- Der alte Abschnitt bleibt erhalten (Spur bis zum Tatort/Ausloggpunkt).
                local gap = dist ~= nil and dist > (SCfg.JumpReset or 150.0)
                tr.points[tr.last] = { x = c.x, y = c.y, z = c.z, t = now, gap = gap or nil }
            end
        end
    end
    for charId, tr in pairs(trails) do
        prune(tr, now)
        if tr.first > tr.last then trails[charId] = nil end
    end
end

Law.Every((SCfg.RecordInterval or 5) * 1000, record)

--- Vertrag 4.1: gibt es eine noch nicht verflogene Spur?
function Law.Scent.HasTrail(charId)
    local tr = trails[tonumber(charId)]
    if not tr or tr.first > tr.last then return false end
    return Law.Now() - tr.points[tr.last].t <= (SCfg.MaxAge or 1800)
end

--- Intern (k9.lua): Ringpuffer eines Charakters. Nie an Clients geben.
function Law.Scent.GetTrail(charId)
    return trails[tonumber(charId)]
end

--- Staerke nach Alter eines Punktes
function Law.Scent.Strength(t)
    local age = Law.Now() - (tonumber(t) or 0)
    local s = SCfg.Strength or {}
    if age <= (s.fresh or 300) then return 'fresh' end
    if age <= (s.medium or 900) then return 'medium' end
    return 'weak'
end

--------------------------------------------------------------------------
-- Geruchsprobe am gefesselten (oder bewusstlosen) Ziel
--------------------------------------------------------------------------
Law.Cb.Register('scent:sample', { perm = 'scent_sample', rate = 2000, notCuffed = true, alive = true }, function(src, ctx, targetSrc)
    targetSrc = Law.ToInt(targetSrc, 1)
    if not targetSrc or targetSrc == src then return Law.Result(false, 'invalid') end
    local target = Law.Ctx(targetSrc)
    if not target then return Law.Result(false, 'no_target') end
    if not Law.IsNear(src, targetSrc, SCfg.SampleDistance or 3.0) then return Law.Result(false, 'too_far') end
    if not (Law.IsCuffed(targetSrc) or target.isDead) then return Law.Result(false, 'scent_target_not_cuffed') end
    if not Law.RateLimit(src, 'scent:sample:cd', (SCfg.SampleCooldown or 30) * 1000) then return Law.Result(false, 'cooldown') end

    local itemName = Config.Items.ScentCloth
    if not Law.Inv:canCarryItem(src, itemName, 1) then return Law.Result(false, 'cant_carry') end

    local coords = Law.GetCoords(src) or vector3(0.0, 0.0, 0.0)
    local zone = Law.Evidence.ZoneOf(coords)
    local now = Law.Now()
    local okDb, evId = Law.DB.Try(MySQL.insert.await, [[INSERT INTO ara_law_evidence
        (type, weapon, serial, owner_charid, blood_type, x, y, z, zone, created_at, collected_by, collected_by_name, collected_at, department, status)
        VALUES ('scent', NULL, NULL, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'collected')]],
        { target.charId, coords.x, coords.y, coords.z, zone, now, ctx.charId, ctx.name, now, ctx.dept or '' })
    if not okDb or not evId then return Law.Result(false, 'failed') end

    local uses = SCfg.UsesPerItem or 3
    local base = L('scent_item_desc', evId, target.name)
    local meta = { evidence_id = evId, description = base .. ' ' .. L('scent_uses_suffix', uses), uses = uses, base = base }
    if not Law.Items.Give(src, itemName, 1, meta) then
        Law.DB.Try(MySQL.update.await, 'DELETE FROM ara_law_evidence WHERE id = ?', { evId })
        return Law.Result(false, 'cant_carry')
    end

    -- Probe liegt jetzt in der Akte (Labor kann Blut/Stoff zuordnen)
    Law.Citizens.SetSample(target.charId, true)
    Law.Records.Add(target.charId, 'evidence', L('scent_record_sample', evId), nil, ctx, evId)
    Law.Notify(targetSrc, L('scent_sample_target', ctx.name), 'info')
    Law.Audit(ctx, 'evidence.scent_sample', target.charId, { id = evId })
    return Law.Result(true, { evidenceId = evId }, L('scent_sample_ok', target.name))
end)

Law.Modules.Register('scent', {
    stop = function()
        trails = {}
    end,
})
