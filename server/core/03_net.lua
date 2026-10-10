--[[
    ArA-LawSystem - Netz: Events, Callbacks, Rate-Limit, Server->Client-Fragen

    JEDES Net-Event und JEDER Callback des Projekts laeuft hier durch
    (Vertrag Abschnitt 11). Der Wrapper prueft in dieser Reihenfolge:
      1. Spieler geladen (Charakter gewaehlt)
      2. Rate-Limit
      3. Behoerde / Recht / Dienst
      4. nicht gefesselt / nicht in Haft / lebendig (wenn verlangt)
    und faengt Fehler im Handler ab, damit ein kaputter Aufruf nie den
    Server-Thread mitreisst.
]]

Law.Net = Law.Net or {}
Law.Cb  = Law.Cb or {}

--------------------------------------------------------------------------
-- Rate-Limit
--------------------------------------------------------------------------
local lastCall = {}  -- [src] = { [key] = GetGameTimer() }

function Law.RateLimit(src, key, ms)
    local now = GetGameTimer()
    local byPlayer = lastCall[src]
    if not byPlayer then
        byPlayer = {}
        lastCall[src] = byPlayer
    end
    local last = byPlayer[key]
    if last and now - last < ms then return false end
    byPlayer[key] = now
    return true
end

AddEventHandler('playerDropped', function()
    lastCall[source] = nil
end)

--------------------------------------------------------------------------
-- Ergebnis-Umschlag fuer Callbacks
--------------------------------------------------------------------------
function Law.Result(ok, errOrData, msg)
    if ok then
        return { ok = true, data = errOrData, msg = msg }
    end
    local code = errOrData or 'failed'
    return { ok = false, err = code, msg = msg or L('err_' .. code) }
end

--------------------------------------------------------------------------
-- Gemeinsame Pruefung
--------------------------------------------------------------------------
-- Rueckgabe: ctx oder nil, Fehlercode
local function gate(src, name, opts)
    local ctx = Law.Ctx(src)
    if not ctx then return nil, 'not_loaded' end

    if not Law.RateLimit(src, name, opts.rate or 500) then
        return nil, 'rate_limited'
    end

    local needDuty = opts.duty
    if needDuty == nil then needDuty = opts.perm ~= nil and Config.General.RequireDuty end

    if opts.law and not ctx.dept then return nil, 'not_law' end
    if opts.perm then
        if not ctx.dept then return nil, 'not_law' end
        if needDuty and not ctx.onDuty then return nil, 'not_on_duty' end
        if not Law.GradeHasPerm(ctx.job, ctx.grade, opts.perm) then return nil, 'no_permission' end
    elseif needDuty and not ctx.onDuty then
        return nil, 'not_on_duty'
    end

    if opts.notCuffed and Law.IsCuffed(src) then return nil, 'cuffed' end
    if opts.notJailed and Law.IsJailed(src) then return nil, 'jailed' end
    if opts.alive and ctx.isDead then return nil, 'dead' end

    return ctx
end

--- Net-Event registrieren: 'ara_law:sv:' .. name
--- handler(src, ctx, ...)
function Law.Net.On(name, opts, handler)
    opts = opts or {}
    local eventName = 'ara_law:sv:' .. name
    RegisterNetEvent(eventName, function(...)
        local src = source
        local ctx, err = gate(src, eventName, opts)
        if not ctx then
            -- Rate-Limit leise verwerfen (Spam), alles andere dem Spieler sagen
            if err ~= 'rate_limited' and err ~= 'not_loaded' then
                Law.Notify(src, L('err_' .. err), 'error')
            end
            Law.Log('Net %s abgelehnt fuer %s: %s', name, tostring(src), tostring(err))
            return
        end
        local ok, e = xpcall(handler, debug.traceback, src, ctx, ...)
        if not ok then Law.Warn('Fehler in Net %s: %s', name, tostring(e)) end
    end)
end

--- Callback registrieren: 'ara_law:cb:' .. name
--- handler(src, ctx, ...) -> Ergebnis (am besten Law.Result(...))
function Law.Cb.Register(name, opts, handler)
    opts = opts or {}
    local cbName = 'ara_law:cb:' .. name
    Law.VORP.Callback.Register(cbName, function(src, cb, ...)
        local ctx, err = gate(src, cbName, opts)
        if not ctx then
            return cb(Law.Result(false, err))
        end
        local results = table.pack(xpcall(handler, debug.traceback, src, ctx, ...))
        if not results[1] then
            Law.Warn('Fehler in Callback %s: %s', name, tostring(results[2]))
            return cb(Law.Result(false, 'internal'))
        end
        local value = results[2]
        if value == nil then value = Law.Result(true) end
        cb(value)
    end)
end

--------------------------------------------------------------------------
-- Server -> Client fragen, mit Timeout (vorp-TriggerAwait kann ewig haengen)
--------------------------------------------------------------------------
local pending = {}
local nextId = 0

function Law.Ask(src, name, payload, timeoutMs)
    nextId = nextId + 1
    local id = nextId
    local p = promise.new()
    pending[id] = { p = p, src = tonumber(src) }
    TriggerClientEvent('ara_law:cl:core:ask', src, id, name, payload)
    SetTimeout(timeoutMs or Config.General.AskTimeout or 15000, function()
        if pending[id] then
            pending[id] = nil
            p:resolve(nil)
        end
    end)
    return Citizen.Await(p)
end

RegisterNetEvent('ara_law:sv:core:answer', function(id, result)
    local src = source
    id = tonumber(id)
    local entry = id and pending[id]
    -- Nur der gefragte Spieler darf antworten
    if not entry or entry.src ~= src then return end
    pending[id] = nil
    entry.p:resolve(result)
end)
