--[[
    ArA-LawSystem - Kern: Grundobjekte (Client)

    Der Client weiss ueber sich nur, was der Server per core:sync schickt.
    Law.Me / Law.HasPerm sind reine Anzeige-Hilfen - entschieden wird auf
    dem Server.
]]

Law = Law or {}
Law.IsServer = false

Law.VORP  = exports.vorp_core:GetCore()
Law.Ready = false
Law.Me    = { perms = {} }
Law.State = { cuffed = false, escorted = false, jailed = false, dead = false }

--------------------------------------------------------------------------
-- Module
--------------------------------------------------------------------------
Law.Modules = { list = {}, order = {} }

--- hooks: init, onReady, onSync(me), onDuty(onDuty), onStop
function Law.Modules.Register(name, hooks)
    if not Law.Modules.list[name] then
        Law.Modules.order[#Law.Modules.order + 1] = name
    end
    Law.Modules.list[name] = hooks or {}
end

function Law.Modules.Call(hook, ...)
    for _, name in ipairs(Law.Modules.order) do
        local fn = Law.Modules.list[name][hook]
        if fn then
            local ok, err = xpcall(fn, debug.traceback, ...)
            if not ok then Law.Warn('Fehler in %s.%s: %s', name, hook, tostring(err)) end
        end
    end
end

--------------------------------------------------------------------------
-- Netz
--------------------------------------------------------------------------
Law.Net = Law.Net or {}
Law.Cb  = Law.Cb or {}

function Law.Net.Send(name, ...)
    TriggerServerEvent('ara_law:sv:' .. name, ...)
end

function Law.On(name, fn)
    RegisterNetEvent('ara_law:cl:' .. name, fn)
end

--- Server-Callback mit Timeout (haengt nie ewig). Nur im Thread aufrufen.
function Law.Cb.Await(name, ...)
    local p = promise.new()
    local done = false
    Law.VORP.Callback.TriggerAsync('ara_law:cb:' .. name, function(result)
        if done then return end
        done = true
        p:resolve(result)
    end, ...)
    -- Laenger als Config.General.AskTimeout: ein Callback kann intern auf eine
    -- Rueckfrage an einen anderen Spieler warten (Law.Ask, z.B. Bussgeld kassieren)
    SetTimeout((Config.General.AskTimeout or 15000) + 5000, function()
        if done then return end
        done = true
        p:resolve({ ok = false, err = 'timeout', msg = L('err_timeout') })
    end)
    return Citizen.Await(p)
end

-- Antworten auf Law.Ask (Server fragt, Client antwortet)
local answers = {}

function Law.Answer(name, fn)
    answers[name] = fn
end

Law.On('core:ask', function(id, name, payload)
    local fn = answers[name]
    CreateThread(function()
        local result = nil
        if fn then
            local ok, res = xpcall(fn, debug.traceback, payload)
            if ok then result = res else Law.Warn('Fehler in Answer %s: %s', name, tostring(res)) end
        end
        TriggerServerEvent('ara_law:sv:core:answer', id, result)
    end)
end)

--------------------------------------------------------------------------
-- Eigene Daten (vom Server)
--------------------------------------------------------------------------
function Law.HasPerm(perm)
    if not Law.Me.dept then return false end
    if Config.General.RequireDuty and not Law.Me.onDuty then return false end
    return Law.Me.perms.all == true or Law.Me.perms[perm] == true
end

--- Recht unabhaengig vom Dienst (fuer Anzeige "im Dienst verfuegbar")
function Law.HasPermAnyDuty(perm)
    if not Law.Me.dept then return false end
    return Law.Me.perms.all == true or Law.Me.perms[perm] == true
end

Law.On('core:sync', function(data)
    local wasDuty = Law.Me.onDuty == true
    local set = {}
    for _, p in ipairs(data.perms or {}) do set[p] = true end
    data.perms = set
    Law.Me = data
    Law.State.cuffed   = data.cuffed == true
    Law.State.escorted = data.escorted == true
    Law.State.jailed   = data.jailed == true

    local first = not Law.Ready
    Law.Ready = true
    if first then Law.Modules.Call('onReady') end
    Law.Modules.Call('onSync', Law.Me)
    if wasDuty ~= (data.onDuty == true) then
        Law.Modules.Call('onDuty', data.onDuty == true)
    end
end)

--------------------------------------------------------------------------
-- Tod (vorp meldet lokal)
--------------------------------------------------------------------------
AddEventHandler('vorp_core:Client:OnPlayerDeath', function()
    Law.State.dead = true
end)
AddEventHandler('vorp_core:Client:OnPlayerRevive', function()
    Law.State.dead = false
end)
AddEventHandler('vorp_core:Client:OnPlayerRespawn', function()
    Law.State.dead = false
end)
