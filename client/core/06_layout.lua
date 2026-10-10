--[[
    ArA-LawSystem - Oberflaeche anpassen (Client)

    /editlawinterface zeigt alle Anzeigen (Dienst-Abzeichen, Hinweise, Haft,
    Handschellen, Ueberfall, Bluthund, Eskorte, Spurensuche, Marke) mit
    Beispieldaten. Jeder Spieler verschiebt/vergroessert sie selbst.

    Gespeichert wird PRO SPIELER auf seinem eigenen PC (Resource-KVP) -
    bleibt ueber Neustarts erhalten, braucht keine Datenbank.
    Die NUI wendet das Layout bei init an (client/core/01_ui.lua).
]]

Law.Layout = Law.Layout or {}

local KVP_KEY = 'ara_law_layout'
local KEYS = { 'duty', 'notify', 'jail', 'cuffed', 'robbery', 'k9', 'escort', 'evidence', 'badge' }
local MIN_S, MAX_S = 0.5, 2.0

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

--- Nur bekannte Anzeigen mit Zahlen im erlaubten Bereich (Daten kommen aus der NUI)
local function sanitize(t)
    local out = {}
    if type(t) ~= 'table' then return out end
    for _, key in ipairs(KEYS) do
        local v = t[key]
        if type(v) == 'table' then
            local x, y, s = tonumber(v.x), tonumber(v.y), tonumber(v.s) or 1.0
            if x and y and x == x and y == y and s == s then
                out[key] = { x = clamp(x, 0.0, 1.0), y = clamp(y, 0.0, 1.0), s = clamp(s, MIN_S, MAX_S) }
            end
        end
    end
    return out
end

function Law.Layout.Load()
    local raw = GetResourceKvpString(KVP_KEY)
    if not raw or raw == '' then return {} end
    local ok, data = pcall(json.decode, raw)
    return ok and sanitize(data) or {}
end

function Law.Layout.Save(layout)
    local clean = sanitize(layout)
    if next(clean) == nil then
        DeleteResourceKvp(KVP_KEY)
    else
        SetResourceKvp(KVP_KEY, json.encode(clean))
    end
    return clean
end

-- Speichern aus dem Editor
Law.UI.OnAction('layout', 'save', function(p)
    local clean = Law.Layout.Save(type(p) == 'table' and p.layout or nil)
    return { ok = true, data = { layout = clean }, msg = L('layout_saved') }
end)

RegisterCommand(Config.Commands.EditUi or 'editlawinterface', function()
    if Law.UI.IsOpen() or Law.State.cuffed then return end
    local me = Law.Me or {}
    Law.UI.Open('layout', {
        layout  = Law.Layout.Load(),
        samples = {
            name = me.name,
            seal = me.dept and Config.Departments[me.dept] and (Config.Departments[me.dept].seal or me.dept) or nil,
            duty = me.dept and { deptLabel = me.deptLabel, gradeLabel = me.gradeLabel, badgeNumber = me.badgeNumber } or nil,
        },
    })
end, false)

-- Hinweise vom Server (Config.General.NotifyStyle = 'nui')
Law.On('core:notify', function(text, kind, ms)
    Law.Notify(text, kind, ms)
end)
