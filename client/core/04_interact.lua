--[[
    ArA-LawSystem - Interaktionsmenue (Client)

    Taste Config.Keys.Interact (F6) oder /lawmenu. Zeigt:
      - Aktionen am naechsten Spieler (target = true), z.B. fesseln, durchsuchen
      - eigene Aktionen (target = false), z.B. Spurensuche, Hundebefehle, Panik
    Module melden Eintraege mit Law.Interact.Register an.
]]

Law.Interact = Law.Interact or {}

Config.Interact = Config.Interact or { TargetDistance = 3.0 }

local entries = {}  -- [id] = def

--- def = { label, desc, order, target, perm, law, duty, canShow(targetSrc), onSelect(targetSrc) }
function Law.Interact.Register(id, def)
    entries[id] = def
end

local function visible(def, targetSrc)
    if def.target and not targetSrc then return false end
    if def.law and not Law.Me.dept then return false end
    if def.duty and not Law.Me.onDuty then return false end
    if def.perm and not Law.HasPerm(def.perm) then return false end
    if def.canShow then
        local ok, res = pcall(def.canShow, targetSrc)
        if not ok or not res then return false end
    end
    return true
end

function Law.Interact.Open()
    if not Law.Ready or Law.UI.IsOpen() or Law.State.cuffed then return end
    local targetSrc = Law.Util.GetClosestPlayer((Config.Interact and Config.Interact.TargetDistance) or 3.0)

    local list = {}
    for id, def in pairs(entries) do
        if visible(def, targetSrc) then list[#list + 1] = { id = id, def = def } end
    end
    if #list == 0 then return Law.Notify(L('interact_nothing')) end
    table.sort(list, function(a, b)
        local ta, tb = a.def.target and 0 or 1, b.def.target and 0 or 1
        if ta ~= tb then return ta < tb end
        return (a.def.order or 50) < (b.def.order or 50)
    end)

    local items = {}
    for _, e in ipairs(list) do
        local label = type(e.def.label) == 'function' and e.def.label(targetSrc) or e.def.label
        items[#items + 1] = { id = e.id, label = label, desc = e.def.desc, badge = e.def.target and L('interact_badge_target') or nil }
    end

    CreateThread(function()
        local choice = Law.UI.Menu({
            title = L('interact_title'),
            subtitle = targetSrc and L('interact_subtitle_target', Law.Util.PlayerName(targetSrc)) or L('interact_subtitle_self'),
            items = items,
        })
        if not choice then return end
        local def = entries[choice]
        if not def then return end
        -- Ziel erneut pruefen (Menue war offen, Ziel kann weg sein)
        if def.target then
            local now = Law.Util.GetClosestPlayer((Config.Interact and Config.Interact.TargetDistance) or 3.0)
            if now ~= targetSrc then return Law.Notify(L('interact_target_gone')) end
        end
        local ok, err = xpcall(def.onSelect, debug.traceback, targetSrc)
        if not ok then Law.Warn('Fehler in Interaktion %s: %s', tostring(choice), tostring(err)) end
    end)
end

RegisterCommand(Config.Commands.Interact, function()
    Law.Interact.Open()
end, false)

function Law.Interact.StartKeyLoop()
    CreateThread(function()
        while true do
            Wait(0)
            if IsControlJustReleased(0, Config.Keys.Interact) then
                Law.Interact.Open()
                Wait(300)
            end
        end
    end)
end
