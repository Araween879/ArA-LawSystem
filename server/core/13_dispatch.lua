--[[
    ArA-LawSystem - Leitstelle (Server)

    Einsaetze leben nur im Speicher (kurzlebig). Jeder Einsatz geht an alle
    im Dienst mit Recht `dispatch` (optional anderes Recht / nur bestimmte
    Behoerden). Position kommt IMMER vom Server, nie vom Client.

    Quellen:
      /sheriff <Text>      Buerger-Notruf
      /panik               Gesetzeshueter in Not
      Schalter "Anzeige"   dispatch:report
      Schuesse in Staedten Law.Dispatch.ShotsFired (von Agent B aufgerufen)
      Module               Law.Dispatch.Create (Flucht, Ueberfall, NPC ...)
]]

Law.Dispatch = Law.Dispatch or {}
Law.Dispatch.alerts = {}

local nextId = 0
local zoneCooldown = {}

local function zoneOf(coords)
    for _, z in ipairs(Config.Dispatch.ShotsFired.Zones or {}) do
        if #(coords - z.coords) <= z.radius then return z end
    end
    return nil
end

local function responderNames(a)
    local names = {}
    for src in pairs(a.responders) do
        local p = Law.Players[src]
        names[#names + 1] = p and p.name or ('#' .. src)
    end
    return names
end

--- Form fuer Client/NUI (Vertrag 10.6 Alert)
function Law.Dispatch.Public(a, forSrc)
    return {
        id = a.id, kind = a.kind, title = a.title, text = a.text,
        coords = Law.VecToTable(a.coords), zone = a.zone, priority = a.priority,
        createdAt = a.createdAt, expiresAt = a.expiresAt,
        responders = responderNames(a), mine = forSrc ~= nil and a.responders[forSrc] == true,
        blip = a.blip,
    }
end

local function recipients(a)
    local out = {}
    for src, dept in pairs(Law.GetOnDuty(a.perm or 'dispatch')) do
        if not a.depts or Law.Contains(a.depts, dept) then out[#out + 1] = src end
    end
    return out
end

local function broadcast(a, event)
    for _, src in ipairs(recipients(a)) do
        TriggerClientEvent(event, src, Law.Dispatch.Public(a, src))
    end
end

--- Vertrag 4: alert = { kind, coords, title, text, priority, fuzz, perm, depts, callerSrc, expires, blip }
function Law.Dispatch.Create(alert)
    local coords = Law.Vec(alert.coords)
    if not coords then return nil end
    if alert.fuzz and alert.fuzz > 0 then
        local ang = math.random() * math.pi * 2
        local r = math.random() * alert.fuzz
        coords = vector3(coords.x + math.cos(ang) * r, coords.y + math.sin(ang) * r, coords.z)
    end

    -- Obergrenze: aeltesten Einsatz verwerfen
    if Law.Count(Law.Dispatch.alerts) >= (Config.Dispatch.MaxOpenAlerts or 30) then
        local oldest
        for id, a in pairs(Law.Dispatch.alerts) do
            if not oldest or a.createdAt < Law.Dispatch.alerts[oldest].createdAt then oldest = id end
        end
        if oldest then Law.Dispatch.Close(oldest) end
    end

    nextId = nextId + 1
    local z = zoneOf(coords)
    local a = {
        id         = nextId,
        kind       = alert.kind or 'system',
        title      = alert.title or L('dispatch_title_' .. (alert.kind or 'system')),
        text       = alert.text or '',
        coords     = coords,
        zone       = z and z.label or nil,
        priority   = Law.ToInt(alert.priority, 1, 3) or 1,
        createdAt  = Law.Now(),
        expiresAt  = Law.Now() + (alert.expires or Config.Dispatch.AlertLifetime or 900),
        responders = {},
        callerSrc  = alert.callerSrc,
        perm       = alert.perm,
        depts      = alert.depts,
        blip       = alert.blip,
        -- optionale Server-Rueckrufe fuer Module (z.B. NPC-Einsatz startet erst bei Annahme)
        onAccept   = type(alert.onAccept) == 'function' and alert.onAccept or nil,  -- fn(src, ctx, alert, firstResponder)
        onClose    = type(alert.onClose) == 'function' and alert.onClose or nil,    -- fn(alert, reasonText)
        data       = alert.data,  -- freie Moduldaten, gehen NICHT an Clients
    }
    Law.Dispatch.alerts[a.id] = a
    broadcast(a, 'ara_law:cl:dispatch:new')
    Law.Log('Einsatz #%d %s: %s', a.id, a.kind, a.title)
    return a.id
end

function Law.Dispatch.Close(id, reasonText)
    local a = Law.Dispatch.alerts[id]
    if not a then return false end
    Law.Dispatch.alerts[id] = nil
    for _, src in ipairs(recipients(a)) do
        TriggerClientEvent('ara_law:cl:dispatch:remove', src, id, reasonText)
    end
    for src in pairs(a.responders) do
        TriggerClientEvent('ara_law:cl:dispatch:remove', src, id, reasonText)
    end
    if a.onClose then
        local ok, err = xpcall(a.onClose, debug.traceback, a, reasonText)
        if not ok then Law.Warn('Dispatch onClose #%d: %s', id, tostring(err)) end
    end
    return true
end

function Law.Dispatch.Get(id)
    return Law.Dispatch.alerts[id]
end

function Law.Dispatch.ShotsFired(src, coords, weaponLabel)
    local cfg = Config.Dispatch.ShotsFired
    if not cfg or not cfg.Enabled then return end
    if cfg.IgnoreLawOnDuty and Law.Duty.active[src] then return end
    coords = Law.Vec(coords)
    if not coords then return end
    local z = zoneOf(coords)
    if not z then return end
    local now = Law.Now()
    if zoneCooldown[z.label] and now - zoneCooldown[z.label] < (cfg.ZoneCooldown or 60) then return end
    zoneCooldown[z.label] = now
    local delay = math.random(cfg.Delay[1] or 5, cfg.Delay[2] or 15) * 1000
    SetTimeout(delay, function()
        Law.Dispatch.Create({
            kind = 'shots', coords = coords, fuzz = cfg.Fuzz or 60, priority = 2,
            title = L('dispatch_title_shots'),
            text = weaponLabel and L('dispatch_shots_text_weapon', z.label, weaponLabel) or L('dispatch_shots_text', z.label),
        })
    end)
end

--------------------------------------------------------------------------
-- Annehmen / Schliessen
--------------------------------------------------------------------------
local function accept(src, ctx, id)
    local a = Law.Dispatch.alerts[id]
    if not a then return Law.Result(false, 'not_found') end
    if a.depts and not Law.Contains(a.depts, ctx.dept) then return Law.Result(false, 'no_permission') end
    if a.perm and not Law.HasPerm(ctx, a.perm) then return Law.Result(false, 'no_permission') end
    local first = next(a.responders) == nil
    local already = a.responders[src] == true
    a.responders[src] = true
    broadcast(a, 'ara_law:cl:dispatch:update')
    if a.onAccept and not already then
        local ok, err = xpcall(a.onAccept, debug.traceback, src, ctx, a, first)
        if not ok then Law.Warn('Dispatch onAccept #%d: %s', id, tostring(err)) end
    end
    if a.callerSrc and GetPlayerPing(a.callerSrc) > 0 then
        Law.Notify(a.callerSrc, L('dispatch_caller_help_coming', ctx.name), 'success')
    end
    Law.Audit(ctx, 'dispatch.accept', nil, { id = id, kind = a.kind })
    return Law.Result(true, { coords = Law.VecToTable(a.coords) })
end

Law.Cb.Register('dispatch:accept', { perm = 'dispatch', rate = 1000 }, function(src, ctx, id)
    id = Law.ToInt(id, 1)
    if not id then return Law.Result(false, 'invalid') end
    return accept(src, ctx, id)
end)

Law.Cb.Register('dispatch:close', { perm = 'dispatch', rate = 1000 }, function(src, ctx, id)
    id = Law.ToInt(id, 1)
    local a = id and Law.Dispatch.alerts[id]
    if not a then return Law.Result(false, 'not_found') end
    -- Einsaetze mit eigenem Recht (z.B. NPC-Streifen) schliesst nur, wer dieses
    -- Recht hat - und Modul-Einsaetze mit onClose nur ein Annehmender
    if a.perm and not Law.HasPerm(ctx, a.perm) then return Law.Result(false, 'no_permission') end
    if a.depts and not Law.Contains(a.depts, ctx.dept) then return Law.Result(false, 'no_permission') end
    if a.onClose and not a.responders[src] and not Law.GradeHasPerm(ctx.job, ctx.grade, 'all') then
        return Law.Result(false, 'no_permission')
    end
    Law.Dispatch.Close(id, L('dispatch_closed_by', ctx.name))
    Law.Audit(ctx, 'dispatch.close', nil, { id = id })
    return Law.Result(true)
end)

Law.Cb.Register('dispatch:list', { perm = 'dispatch', rate = 1000 }, function(src, ctx)
    return Law.Result(true, Law.Dispatch.ListFor(src, ctx))
end)

--- Alle Einsaetze, die dieser Officer sehen darf (Behoerde + Recht des Einsatzes)
function Law.Dispatch.ListFor(src, ctx)
    local list = {}
    for _, a in pairs(Law.Dispatch.alerts) do
        local deptOk = not a.depts or Law.Contains(a.depts, ctx.dept)
        local permOk = Law.GradeHasPerm(ctx.job, ctx.grade, a.perm or 'dispatch')
        if deptOk and permOk then list[#list + 1] = Law.Dispatch.Public(a, src) end
    end
    table.sort(list, function(x, y) return x.createdAt > y.createdAt end)
    return list
end

RegisterCommand(Config.Commands.Accept, function(src, args)
    if src <= 0 then return end
    local ctx = Law.Ctx(src)
    if not ctx or not Law.HasPerm(ctx, 'dispatch') then return Law.Notify(src, L('err_no_permission'), 'error') end
    if not Law.RateLimit(src, 'cmd:accept', 1000) then return end
    local id = Law.ToInt(args[1], 1)
    if not id then return Law.Notify(src, L('dispatch_usage_accept'), 'error') end
    local res = accept(src, ctx, id)
    if res.ok then
        TriggerClientEvent('ara_law:cl:dispatch:waypoint', src, res.data.coords)
        Law.Notify(src, L('dispatch_accepted', id), 'success')
    else
        Law.Notify(src, res.msg, 'error')
    end
end, false)

--------------------------------------------------------------------------
-- Buerger-Notruf, Panik, Anzeige am Schalter
--------------------------------------------------------------------------
RegisterCommand(Config.Commands.CallLaw, function(src, args)
    if src <= 0 then return end
    local ctx = Law.Ctx(src)
    if not ctx then return end
    if Law.IsJailed(src) then return Law.Notify(src, L('dispatch_no_call_jailed'), 'error') end
    if ctx.isDead and not Config.Dispatch.AllowCallWhenDead then return end
    if not Law.RateLimit(src, 'cmd:calllaw', (Config.Dispatch.CallCooldown or 120) * 1000) then
        return Law.Notify(src, L('dispatch_call_cooldown'), 'error')
    end
    local text = Law.ToStr(table.concat(args or {}, ' '), 200, true) or ''
    if text == '' then text = ctx.isDead and L('dispatch_call_dead') or L('dispatch_call_default') end
    local coords = Law.GetCoords(src)
    if not coords then return end
    Law.Dispatch.Create({
        kind = 'citizen', coords = coords, callerSrc = src, priority = ctx.isDead and 2 or 1,
        title = L('dispatch_title_citizen'), text = ('%s: %s'):format(ctx.name, text),
    })
    if Law.Count(Law.GetOnDuty('dispatch')) == 0 then
        Law.Notify(src, L('dispatch_call_nobody'), 'info')
    else
        Law.Notify(src, L('dispatch_call_sent'), 'success')
    end
    Law.Audit(ctx, 'dispatch.call', nil, { text = text })
end, false)

RegisterCommand(Config.Commands.Panic, function(src)
    if src <= 0 then return end
    local ctx = Law.Ctx(src)
    if not ctx or not ctx.dept or not ctx.onDuty then return Law.Notify(src, L('err_not_on_duty'), 'error') end
    if not Law.RateLimit(src, 'cmd:panic', (Config.Dispatch.PanicCooldown or 60) * 1000) then return end
    local coords = Law.GetCoords(src)
    if not coords then return end
    Law.Dispatch.Create({
        kind = 'panic', coords = coords, priority = 3, callerSrc = src, perm = 'duty',
        title = L('dispatch_title_panic'), text = L('dispatch_panic_text', ctx.deptCfg.short, ctx.name),
    })
    Law.Audit(ctx, 'dispatch.panic')
end, false)

Law.Cb.Register('dispatch:report', { rate = 30000, notJailed = true, notCuffed = true }, function(src, ctx, text)
    text = Law.ToStr(text, 500, false, true)
    if not text then return Law.Result(false, 'invalid') end
    local stationKey = Law.Stations.NearPoint(src, 'counter')
    if not stationKey then return Law.Result(false, 'not_at_point') end
    Law.Dispatch.Create({
        kind = 'citizen', coords = Law.GetCoords(src), callerSrc = src, priority = 1,
        title = L('dispatch_title_report', Config.Stations[stationKey].label), text = ('%s: %s'):format(ctx.name, text),
    })
    Law.Audit(ctx, 'dispatch.report', nil, { station = stationKey, text = text })
    return Law.Result(true, nil, L('dispatch_report_ok'))
end)

--------------------------------------------------------------------------
-- Aufraeumen, Sync bei Dienstbeginn
--------------------------------------------------------------------------
Law.Every(30000, function()
    local now = Law.Now()
    for id, a in pairs(Law.Dispatch.alerts) do
        if a.expiresAt <= now then Law.Dispatch.Close(id, L('dispatch_expired')) end
    end
end)

Law.Modules.Register('dispatch', {
    dutyChanged = function(src, ctx, onDuty)
        if not onDuty then
            for _, a in pairs(Law.Dispatch.alerts) do a.responders[src] = nil end
            TriggerClientEvent('ara_law:cl:dispatch:clear', src)
            return
        end
        local list = {}
        for _, a in pairs(Law.Dispatch.alerts) do
            if (not a.depts or Law.Contains(a.depts, ctx.dept)) and Law.GradeHasPerm(ctx.job, ctx.grade, a.perm or 'dispatch') then
                list[#list + 1] = Law.Dispatch.Public(a, src)
            end
        end
        TriggerClientEvent('ara_law:cl:dispatch:list', src, list)
    end,
    playerDropped = function(src)
        for _, a in pairs(Law.Dispatch.alerts) do
            a.responders[src] = nil
            if a.callerSrc == src then a.callerSrc = nil end
        end
    end,
})
