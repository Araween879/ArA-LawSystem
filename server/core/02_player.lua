--[[
    ArA-LawSystem - Spieler-Kontext, Position, Rechte, Benachrichtigung (Server)

    WICHTIG: vorp liefert mit user.getUsedCharacter einen SCHNAPPSCHUSS.
    Geld, Job, Rang koennen sich jederzeit aendern - deshalb wird der Kontext
    bei jedem Aufruf frisch gebaut und nie zwischengespeichert.
]]

Law.Duty = Law.Duty or { active = {} }  -- [src] = { dept, grade, since, logId } (gesetzt in 10_duty.lua)

--------------------------------------------------------------------------
-- Tod serverseitig pruefen
--------------------------------------------------------------------------
-- vorp setzt char.isdead ueber das frei feuerbare Net-Event vorp:ImDead.
-- Ein Cheater koennte sich damit "tot" melden und waere nicht fesselbar.
-- Deshalb gilt nur als tot, wer es laut vorp IST UND dessen Ped serverseitig
-- keine Gesundheit mehr hat (OneSync). Config.General.ValidateDeath = false
-- schaltet die Ped-Pruefung ab, falls sie auf einem Server nicht greift.
function Law.IsPedDead(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    local ok, hp = pcall(GetEntityHealth, ped)
    if not ok or type(hp) ~= 'number' then return nil end -- unbekannt
    return hp <= 0
end

local function checkDead(src, flag)
    if not flag then return false end
    if Config.General.ValidateDeath == false then return true end
    local dead = Law.IsPedDead(src)
    if dead == nil then return true end -- Server kann es nicht pruefen -> vorp glauben
    return dead
end

--------------------------------------------------------------------------
-- Kontext
--------------------------------------------------------------------------
function Law.Ctx(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local user = Law.VORP.getUser(src)
    if not user then return nil end
    local char = user.getUsedCharacter
    if not char or not char.charIdentifier or tonumber(char.charIdentifier) == -1 then return nil end

    local job      = char.job
    local grade    = tonumber(char.jobGrade) or 0
    local deptCfg  = Law.GetDept(job)
    local gradeCfg = deptCfg and Law.GetGrade(job, grade) or nil
    local duty     = Law.Duty.active[src]

    local firstname = char.firstname or ''
    local lastname  = char.lastname or ''

    return {
        src        = src,
        user       = user,
        char       = char,
        charId     = tonumber(char.charIdentifier),
        identifier = char.identifier,
        firstname  = firstname,
        lastname   = lastname,
        name       = (firstname .. ' ' .. lastname):gsub('^%s+', ''):gsub('%s+$', ''),
        job        = job,
        grade      = grade,
        dept       = deptCfg and job or nil,
        deptCfg    = deptCfg,
        gradeCfg   = gradeCfg,
        onDuty     = duty ~= nil and duty.dept == job,
        group      = user.getGroup,
        isDead     = checkDead(src, char.isdead == true or char.isdead == 1),
        money      = tonumber(char.money) or 0,
        gold       = tonumber(char.gold) or 0,
    }
end

function Law.SrcByCharId(charId)
    charId = tonumber(charId)
    if not charId then return nil end
    for src, info in pairs(Law.Players) do
        if info.charId == charId and GetPlayerPing(src) > 0 then return src end
    end
    local user = Law.VORP.getUserByCharId(charId)
    if user and user.source then return tonumber(user.source) end
    return nil
end

function Law.CtxByCharId(charId)
    local src = Law.SrcByCharId(charId)
    if not src then return nil end
    return Law.Ctx(src)
end

--- Kern-Cache aktualisieren (bei Charakterwahl, Jobwechsel, Resource-Start)
function Law.RefreshPlayer(src)
    local ctx = Law.Ctx(src)
    if not ctx then return nil end
    local old = Law.Players[src]
    Law.Players[src] = {
        charId     = ctx.charId,
        name       = ctx.name,
        identifier = ctx.identifier,
        dept       = ctx.dept,
        grade      = ctx.grade,
        loadedAt   = old and old.charId == ctx.charId and old.loadedAt or Law.Now(),
    }
    return ctx
end

--------------------------------------------------------------------------
-- Namen von (auch Offline-)Charakteren
--------------------------------------------------------------------------
local nameCache = {}  -- [charId] = { name, t }

function Law.GetCharName(charId)
    charId = tonumber(charId)
    if not charId then return '?' end
    local src = Law.SrcByCharId(charId)
    if src and Law.Players[src] then return Law.Players[src].name end
    local c = nameCache[charId]
    if c and Law.Now() - c.t < 600 then return c.name end
    local row = MySQL.single.await('SELECT firstname, lastname FROM characters WHERE charidentifier = ? LIMIT 1', { charId })
    local name = row and ((row.firstname or '') .. ' ' .. (row.lastname or '')) or ('#' .. charId)
    nameCache[charId] = { name = name, t = Law.Now() }
    return name
end

--------------------------------------------------------------------------
-- Steam-ID eines (auch Offline-)Charakters, Selbst-/Zweitcharakter-Pruefung
--------------------------------------------------------------------------
local identCache = {}  -- [charId] = identifier (aendert sich nie)

function Law.IdentifierOf(charId)
    charId = tonumber(charId)
    if not charId then return nil end
    if identCache[charId] then return identCache[charId] end
    local live = Law.CtxByCharId(charId)
    local ident = live and live.identifier
    if not ident then
        local row = MySQL.single.await('SELECT identifier FROM characters WHERE charidentifier = ? LIMIT 1', { charId })
        ident = row and row.identifier or nil
    end
    if ident then identCache[charId] = ident end
    return ident
end

--- true, wenn charId der Handelnde selbst ODER ein anderer Charakter
--- desselben Spielers (gleiche Steam-ID) ist. Gegen Selbstbedienung
--- (eigene Bussgelder stornieren, Kopfgeld auf den Zweitchar ...).
function Law.IsSelfOrAlt(ctx, charId)
    charId = tonumber(charId)
    if not ctx or not charId then return false end
    if charId == ctx.charId then return true end
    local ident = Law.IdentifierOf(charId)
    return ident ~= nil and ident == ctx.identifier
end

--- Gleicher Spieler hinter zwei Charakteren?
function Law.SamePlayer(charIdA, charIdB)
    local a, b = Law.IdentifierOf(charIdA), Law.IdentifierOf(charIdB)
    return a ~= nil and a == b
end

--------------------------------------------------------------------------
-- Position (OneSync)
--------------------------------------------------------------------------
function Law.GetCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return GetEntityCoords(ped)
end

function Law.IsNear(srcA, srcB, maxDist)
    local a, b = Law.GetCoords(srcA), Law.GetCoords(srcB)
    if not a or not b then return false, math.huge end
    local d = #(a - b)
    return d <= maxDist, d
end

function Law.IsNearCoords(src, coords, maxDist)
    local a = Law.GetCoords(src)
    coords = Law.Vec(coords)
    if not a or not coords then return false, math.huge end
    local d = #(a - coords)
    return d <= maxDist, d
end

function Law.GetPlayersInRadius(coords, radius)
    coords = Law.Vec(coords)
    local out = {}
    if not coords then return out end
    for src in pairs(Law.Players) do
        local c = Law.GetCoords(src)
        if c and #(c - coords) <= radius then out[#out + 1] = src end
    end
    return out
end

function Law.EntityCoords(netId)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return nil, 0 end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil, 0 end
    return GetEntityCoords(ent), ent
end

--- Wie EntityCoords, wartet aber bis timeoutMs, bis der Server das frisch
--- gespawnte Entity kennt (Client meldet die NetId oft vor dem OneSync-Sync).
--- Nur in Handlern/Threads aufrufen.
function Law.EntityCoordsWait(netId, timeoutMs)
    local t = GetGameTimer() + (timeoutMs or 2000)
    repeat
        local coords, ent = Law.EntityCoords(netId)
        if coords then return coords, ent end
        Wait(100)
    until GetGameTimer() > t
    return nil, 0
end

--- Modellvergleich mit 32-Bit-Maske (GetEntityModel und joaat koennen sich im
--- Vorzeichen unterscheiden)
function Law.ModelMatches(ent, model)
    if not ent or ent == 0 then return false end
    local want = type(model) == 'number' and model or joaat(model)
    return (GetEntityModel(ent) & 0xFFFFFFFF) == (want & 0xFFFFFFFF)
end

--- Gehoert das Entity (netzwerktechnisch) diesem Spieler?
--- Server loescht fremde Entities NIE aufgrund einer Client-NetId.
function Law.IsEntityOwner(ent, src)
    if not ent or ent == 0 then return false end
    local ok, owner = pcall(NetworkGetEntityOwner, ent)
    return ok and owner == tonumber(src)
end

--------------------------------------------------------------------------
-- Rechte / Dienst
--------------------------------------------------------------------------
local function toCtx(srcOrCtx)
    if type(srcOrCtx) == 'table' then return srcOrCtx end
    return Law.Ctx(srcOrCtx)
end

function Law.IsLaw(srcOrCtx)
    local ctx = toCtx(srcOrCtx)
    return ctx ~= nil and ctx.dept ~= nil
end

function Law.IsOnDuty(src)
    local d = Law.Duty.active[tonumber(src)]
    if not d then return false, nil end
    return true, d.dept
end

--- needDuty: nil -> Config.General.RequireDuty
function Law.HasPerm(srcOrCtx, perm, needDuty)
    local ctx = toCtx(srcOrCtx)
    if not ctx or not ctx.dept then return false end
    if needDuty == nil then needDuty = Config.General.RequireDuty end
    if needDuty and not ctx.onDuty then return false end
    return Law.GradeHasPerm(ctx.job, ctx.grade, perm)
end

--- { [src] = dept } aller Spieler im Dienst, optional nur mit Recht
function Law.GetOnDuty(perm)
    local out = {}
    for src, d in pairs(Law.Duty.active) do
        if not perm or Law.GradeHasPerm(d.dept, d.grade, perm) then
            out[src] = d.dept
        end
    end
    return out
end

function Law.IsCuffed(src)   return Law.State.cuffed[tonumber(src)] ~= nil end
function Law.IsJailed(src)   return Law.State.jailed[tonumber(src)] ~= nil end
function Law.IsEscorted(src) return Law.State.escortedBy[tonumber(src)] ~= nil end

--- Kuerzlich gestorben? (Respawn im Krankenhaus ist keine Flucht)
function Law.DiedRecently(src, seconds)
    local t = Law.State.lastDeath[tonumber(src)]
    return t ~= nil and Law.Now() - t <= (seconds or 60)
end

--------------------------------------------------------------------------
-- Benachrichtigung
--------------------------------------------------------------------------
function Law.Notify(src, text, kind, ms)
    ms = ms or 5000
    kind = kind or 'info'
    if kind == 'objective' then
        Law.VORP.NotifyObjective(src, text, ms)
    elseif kind == 'left' then
        Law.VORP.NotifyLeft(src, 'ArA-Law', text, 'generic_textures', 'tick', ms, 'COLOR_WHITE')
    else
        -- info/success/error: gleiche vorp-Anzeige (Farbcodes sind in RedM
        -- nicht verlaesslich und wuerden sonst als Rohtext erscheinen)
        Law.VORP.NotifyRightTip(src, text, ms)
    end
end

function Law.NotifyLaw(text, perm, kind)
    for src in pairs(Law.GetOnDuty(perm)) do
        Law.Notify(src, text, kind or 'info')
    end
end

function Law.SendLaw(eventName, perm, ...)
    for src in pairs(Law.GetOnDuty(perm)) do
        TriggerClientEvent(eventName, src, ...)
    end
end
