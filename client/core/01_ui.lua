--[[
    ArA-LawSystem - NUI-Bruecke (Client)

    Protokoll: docs/01_CONTRACT.md Abschnitt 10.
    Fokus-Regel: Lua gibt den Fokus, sobald eine fokussierte App aufgeht.
    Die NUI verwaltet selbst einen Stapel (Formular ueber Dienstbuch usw.)
    und ruft `close` erst, wenn der Stapel leer ist - dann gibt Lua den
    Fokus frei.
]]

Law.UI = Law.UI or {}

local focused = false
local nuiReady = false
-- Jede fokussierte "open"-Nachricht bekommt eine fortlaufende Nummer. Die NUI
-- schickt beim "close" die letzte Nummer mit, die sie gesehen hat. Ist Lua
-- inzwischen weiter (z.B. Formular direkt nach Menue-Auswahl geoeffnet), ist
-- das "close" veraltet und wird ignoriert - sonst wuerde es das neue Fenster
-- sofort wieder schliessen.
local openSeq = 0
local actionHandlers = {}   -- ['app:name'] = fn(payload) -> result
local formHandlers = {}     -- [formId] = fn(payload) -> result
local pendingMenu, pendingForm

local function setFocus(on)
    focused = on
    SetNuiFocus(on, on)
end

local function send(msg)
    SendNUIMessage(msg)
end

local function sendInit()
    send({
        type = 'init',
        data = {
            locale   = Config.General.Locale,
            strings  = Law.LocaleUi(),
            currency = Config.General.Currency or '$',
            resource = GetCurrentResourceName(),
            layout   = Law.Layout and Law.Layout.Load() or nil,   -- eigenes Layout (client/core/06_layout.lua)
        },
    })
end

--------------------------------------------------------------------------
-- Oeffentliche API
--------------------------------------------------------------------------
function Law.UI.IsOpen()
    return focused
end

--- NUI geladen? (vorher gehen Hinweise ueber vorp)
function Law.UI.IsReady()
    return nuiReady
end

function Law.UI.Open(app, data)
    openSeq = openSeq + 1
    send({ type = 'open', app = app, data = data or {}, seq = openSeq })
    setFocus(true)
end

--- Ohne Fokus anzeigen (z.B. Marke)
function Law.UI.Show(app, data)
    send({ type = 'open', app = app, data = data or {}, nofocus = true })
end

function Law.UI.Update(app, data)
    send({ type = 'update', app = app, data = data or {} })
end

function Law.UI.Close()
    send({ type = 'close' })
    setFocus(false)
    if pendingMenu then local p = pendingMenu; pendingMenu = nil; p:resolve(nil) end
    if pendingForm then local p = pendingForm; pendingForm = nil; p:resolve(nil) end
end

function Law.UI.Hud(name, data)
    send({ type = 'hud', hud = name, data = data })
end

function Law.UI.Toast(title, text, kind, ms)
    send({ type = 'toast', data = { title = title, text = text, kind = kind or 'info', ms = ms or 6000 } })
end

--- Blockierend: gewaehlte id oder nil
function Law.UI.Menu(def)
    if pendingMenu then local p = pendingMenu; pendingMenu = nil; p:resolve(nil) end
    local p = promise.new()
    pendingMenu = p
    Law.UI.Open('menu', def)
    return Citizen.Await(p)
end

--- Blockierend: values-Tabelle oder nil
function Law.UI.Form(def)
    if pendingForm then local p = pendingForm; pendingForm = nil; p:resolve(nil) end
    local p = promise.new()
    pendingForm = p
    Law.UI.Open('form', def)
    return Citizen.Await(p)
end

function Law.UI.Document(def)
    Law.UI.Open('document', def)
end

function Law.UI.OnAction(app, name, fn)
    actionHandlers[app .. ':' .. name] = fn
end

--- Formular, das aus dem Dienstbuch (action ledger:openForm) geoeffnet wird.
--- fn(payload) -> Ergebnis (geht an die NUI zurueck)
function Law.UI.RegisterForm(formId, fn)
    formHandlers[formId] = fn
end

--------------------------------------------------------------------------
-- NUI -> Lua
--------------------------------------------------------------------------
RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    sendInit()
    cb({ ok = true })
end)

RegisterNUICallback('close', function(body, cb)
    local seq = type(body) == 'table' and tonumber(body.seq) or nil
    if seq and seq < openSeq then
        -- veraltet: Lua hat danach schon ein neues Fenster geoeffnet
        return cb({ ok = true, stale = true })
    end
    setFocus(false)
    if pendingMenu then local p = pendingMenu; pendingMenu = nil; p:resolve(nil) end
    if pendingForm then local p = pendingForm; pendingForm = nil; p:resolve(nil) end
    cb({ ok = true })
end)

RegisterNUICallback('menuSelect', function(body, cb)
    if pendingMenu then local p = pendingMenu; pendingMenu = nil; p:resolve(body and body.id) end
    cb({ ok = true })
end)

RegisterNUICallback('menuCancel', function(_, cb)
    if pendingMenu then local p = pendingMenu; pendingMenu = nil; p:resolve(nil) end
    cb({ ok = true })
end)

RegisterNUICallback('formSubmit', function(body, cb)
    if pendingForm then local p = pendingForm; pendingForm = nil; p:resolve(body and body.values or {}) end
    cb({ ok = true })
end)

RegisterNUICallback('formCancel', function(_, cb)
    if pendingForm then local p = pendingForm; pendingForm = nil; p:resolve(nil) end
    cb({ ok = true })
end)

-- Server-Callback durchreichen. Der Server prueft alles selbst.
RegisterNUICallback('cb', function(body, cb)
    local name = type(body) == 'table' and body.name
    if type(name) ~= 'string' or not name:match('^[%w_]+:[%w_]+$') then
        return cb({ ok = false, err = 'invalid' })
    end
    local args = type(body.args) == 'table' and body.args or {}
    CreateThread(function()
        local res = Law.Cb.Await(name, table.unpack(args, 1, 8))
        cb(res or { ok = false, err = 'no_response' })
    end)
end)

RegisterNUICallback('action', function(body, cb)
    if type(body) ~= 'table' or type(body.app) ~= 'string' or type(body.name) ~= 'string' then
        return cb({ ok = false, err = 'invalid' })
    end
    local fn = actionHandlers[body.app .. ':' .. body.name]
    if not fn then return cb({ ok = false, err = 'no_handler' }) end
    CreateThread(function()
        local ok, res = xpcall(fn, debug.traceback, body.payload or {})
        if not ok then
            Law.Warn('Fehler in NUI-Aktion %s:%s: %s', body.app, body.name, tostring(res))
            return cb({ ok = false, err = 'internal' })
        end
        cb(res or { ok = true })
    end)
end)

--------------------------------------------------------------------------
-- Standard-Aktionen
--------------------------------------------------------------------------
Law.UI.OnAction('ledger', 'setWaypoint', function(p)
    local v = Law.Vec(p)
    if v then Law.Util.SetWaypoint(v) end
    return { ok = true }
end)

Law.UI.OnAction('ledger', 'openForm', function(p)
    local fn = formHandlers[p.form]
    if not fn then return { ok = false, err = 'no_form' } end
    return fn(p) or { ok = true }
end)

-- Aufraeumen: Fokus darf nie haengen bleiben
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)
