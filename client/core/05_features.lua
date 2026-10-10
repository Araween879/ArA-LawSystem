--[[
    ArA-LawSystem - Kern-Funktionen am Client

    Stationspunkte des Kerns: duty, boss, storage, armory, garage, counter, board
    Dienstbuch (/dienstbuch), Einstellen-Formular, Marke anzeigen,
    Leitstelle (Toasts, Blips, Route), Dienst-HUD, /lawcoords.
]]

--------------------------------------------------------------------------
-- Stationspunkte
--------------------------------------------------------------------------
Law.Stations.RegisterPoint('duty', {
    law = true,
    label = function() return Law.Me.onDuty and L('prompt_duty_off') or L('prompt_duty_on') end,
    onUse = function() Law.Net.Send('duty:toggle') end,
})

local function hasBossPerm()
    for _, p in ipairs({ 'boss_hire', 'boss_fire', 'boss_promote', 'boss_funds', 'boss_logs' }) do
        if Law.HasPerm(p) then return true end
    end
    return false
end

local function openLedger(tab, focusCharId)
    if not Law.Me.dept then return Law.Notify(L('err_not_law')) end
    local res = Law.Cb.Await('core:ledgerOpen')
    if not res or not res.ok then return Law.Notify(res and res.msg or L('err_failed')) end
    Law.UI.Open('ledger', { officer = res.data.officer, tab = tab or 'overview', focusCharId = focusCharId })
end
Law.OpenLedger = openLedger

Law.Stations.RegisterPoint('boss', {
    law = true, duty = true,
    label = L('prompt_boss'),
    canShow = function() return hasBossPerm() end,
    onUse = function() openLedger('department') end,
})

Law.Stations.RegisterPoint('storage', {
    perm = 'storage', duty = true,
    label = L('prompt_storage'),
    onUse = function() Law.Net.Send('storage:open') end,
})

Law.Stations.RegisterPoint('armory', {
    perm = 'armory', duty = true,
    label = L('prompt_armory'),
    onUse = function()
        local res = Law.Cb.Await('armory:list')
        if not res or not res.ok then return Law.Notify(res and res.msg or L('err_failed')) end
        local items = {}
        for _, e in ipairs(res.data.items) do
            items[#items + 1] = {
                id = e.index, label = e.label,
                desc = L('armory_item_desc', e.price, e.amount),
                disabled = not e.allowed,
                badge = e.kind == 'weapon' and L('armory_badge_weapon') or nil,
            }
        end
        while true do
            local choice = Law.UI.Menu({ title = L('armory_title'), subtitle = L('armory_subtitle', res.data.balance), items = items })
            if not choice then return end
            local r = Law.Cb.Await('armory:take', choice)
            Law.Notify(r and r.msg or L('err_failed'))
        end
    end,
})

Law.Stations.RegisterPoint('counter', {
    label = L('prompt_counter'),
    onUse = function()
        local res = Law.Cb.Await('core:counterOpen')
        if not res or not res.ok then return Law.Notify(res and res.msg or L('err_failed')) end
        Law.UI.Open('counter', res.data)
    end,
})

Law.Stations.RegisterPoint('board', {
    label = L('prompt_board'),
    onUse = function()
        local res = Law.Cb.Await('core:boardOpen')
        if not res or not res.ok then return Law.Notify(res and res.msg or L('err_failed')) end
        Law.UI.Open('board', res.data)
    end,
})

--------------------------------------------------------------------------
-- Dienstwagen
--------------------------------------------------------------------------
local function spawnVehicle(model, s)
    if not Law.Util.LoadModel(model, 8000) then return Law.Notify(L('garage_model_failed')) end
    local hash = joaat(model)
    local veh = CreateVehicle(hash, s.x, s.y, s.z, s.w or 0.0, true, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not veh or veh == 0 then return Law.Notify(L('garage_model_failed')) end
    Citizen.InvokeNative(0x7263332501E07F52, veh, true) -- SetVehicleOnGroundProperly
    -- Erst melden, wenn das Fahrzeug vernetzt ist - sonst kennt der Server die NetId noch nicht
    local t = GetGameTimer() + 3000
    while not NetworkGetEntityIsNetworked(veh) and GetGameTimer() < t do Wait(50) end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    SetNetworkIdExistsOnAllMachines(netId, true)
    Wait(250)
    Law.Net.Send('garage:spawned', netId)
    Law.Notify(L('garage_spawned'))
end

-- Server hat den Wagen nicht angenommen -> lokal entfernen, sonst bleibt er ewig stehen
Law.On('garage:rejected', function(netId)
    local ent = Law.Util.NetToEnt(netId, 1000)
    if ent ~= 0 and Law.Util.RequestControl(ent) then Law.Util.DeleteEntity(ent) end
    Law.Notify(L('garage_rejected'))
end)

--- Wagen nach Kategorie sortieren (Reihenfolge wie Config.Garage.Categories)
local function garageGroups(vehicles)
    local byCat, known = {}, {}
    for _, c in ipairs(Config.Garage.Categories or {}) do known[c.id] = c end
    for _, v in ipairs(vehicles) do
        local cid = known[v.category] and v.category or '_other'
        byCat[cid] = byCat[cid] or {}
        table.insert(byCat[cid], v)
    end
    local cats = {}
    for _, c in ipairs(Config.Garage.Categories or {}) do
        if byCat[c.id] then cats[#cats + 1] = c end
    end
    if byCat._other then cats[#cats + 1] = { id = '_other', label = L('garage_cat_other'), icon = 'wagon' } end
    return cats, byCat
end

--- Seite 2: Wagen einer Kategorie. Rueckgabe: Index, 'back' oder nil (abgebrochen)
local function garageVehicleMenu(cat, list, d)
    local items = {}
    for _, v in ipairs(list) do
        local desc = v.desc
        if not v.allowed and v.needGrade then
            desc = L('garage_need_grade', v.needGrade) .. (v.desc and (' - ' .. v.desc) or '')
        elseif d.hasActive then
            desc = L('garage_store_first')
        end
        items[#items + 1] = {
            id = v.index, label = v.label, icon = cat.icon or 'wagon', desc = desc,
            disabled = not v.allowed or d.hasActive,
        }
    end
    items[#items + 1] = { id = 'back', label = L('garage_back') }
    return Law.UI.Menu({ title = cat.label, subtitle = d.stationLabel, items = items })
end

Law.Stations.RegisterPoint('garage', {
    perm = 'garage', duty = true,
    label = L('prompt_garage'),
    onUse = function()
        local res = Law.Cb.Await('garage:list')
        if not res or not res.ok then return Law.Notify(res and res.msg or L('err_failed')) end
        local d = res.data
        local cats, byCat = garageGroups(d.vehicles or {})
        if #cats == 0 and not d.hasActive then return Law.Notify(L('garage_none_available')) end

        while true do
            -- Seite 1: einparken + Kategorien
            local items = {}
            if d.hasActive then
                items[#items + 1] = {
                    id = 'store', label = L('garage_store'), icon = 'wagon',
                    desc = d.activeLabel and L('garage_active_desc', d.activeLabel) or nil,
                }
            end
            for _, c in ipairs(cats) do
                local free = 0
                for _, v in ipairs(byCat[c.id]) do if v.allowed then free = free + 1 end end
                items[#items + 1] = {
                    id = 'cat:' .. c.id, label = c.label, icon = c.icon or 'wagon', desc = c.desc,
                    badge = L('garage_cat_count', free, #byCat[c.id]),
                }
            end
            local choice = Law.UI.Menu({ title = L('garage_title'), subtitle = d.stationLabel, items = items })
            if not choice then return end
            if choice == 'store' then return Law.Net.Send('garage:store') end

            local cid = type(choice) == 'string' and choice:match('^cat:(.+)$')
            local cat
            for _, c in ipairs(cats) do if c.id == cid then cat = c end end
            if not cat then return end

            local pick = garageVehicleMenu(cat, byCat[cid], d)
            if pick == nil then return end
            if pick ~= 'back' then
                local r = Law.Cb.Await('garage:request', pick)
                if not r or not r.ok then return Law.Notify(r and r.msg or L('err_failed')) end
                return spawnVehicle(r.data.model, r.data.spawn)
            end
        end
    end,
})

--------------------------------------------------------------------------
-- Dienstbuch
--------------------------------------------------------------------------
RegisterCommand(Config.Commands.Ledger, function()
    if Law.UI.IsOpen() or Law.State.cuffed then return end
    CreateThread(function() openLedger('overview') end)
end, false)

-- Einstellen-Formular (aus dem Tab "Behoerde")
Law.UI.RegisterForm('hire', function()
    local players = Law.Util.GetPlayersInRange(Config.Boss.HireDistance or 5.0)
    if #players == 0 then return { ok = false, err = 'no_target', msg = L('err_no_target') } end
    local pOpts = {}
    for _, p in ipairs(players) do pOpts[#pOpts + 1] = { value = p.serverId, label = p.name } end
    local gOpts = {}
    for _, g in ipairs(Law.GradeList(Law.Me.dept)) do
        if g.grade < (Law.Me.grade or 0) then gOpts[#gOpts + 1] = { value = g.grade, label = g.label } end
    end
    if #gOpts == 0 then return { ok = false, err = 'grade_too_high', msg = L('err_grade_too_high') } end
    local values = Law.UI.Form({
        id = 'hire', title = L('boss_hire_title'), submitLabel = L('boss_hire_submit'),
        fields = {
            { name = 'player', type = 'select', label = L('boss_hire_player'), required = true, options = pOpts, default = pOpts[1].value },
            { name = 'grade',  type = 'select', label = L('boss_hire_grade'),  required = true, options = gOpts, default = gOpts[1].value },
        },
    })
    if not values then return { ok = false, err = 'cancelled' } end
    return Law.Cb.Await('boss:hire', values.player, values.grade)
end)

-- Rueckfrage an die Person, die eingestellt werden soll
Law.Answer('boss:confirmHire', function(p)
    if type(p) ~= 'table' then return false end
    -- Server wartet 12 s: danach Menue selbst schliessen, sonst bleibt es
    -- offen, obwohl die Antwort nicht mehr zaehlt
    local answered = false
    SetTimeout(11500, function()
        if not answered and Law.UI.IsOpen() then Law.UI.Close() end
    end)
    local choice = Law.UI.Menu({
        title = L('boss_confirm_title'),
        subtitle = L('boss_confirm_sub', tostring(p.byName or '?'), tostring(p.deptLabel or '?'), tostring(p.gradeLabel or '?')),
        items = {
            { id = 'yes', label = L('boss_confirm_yes'), desc = L('boss_confirm_yes_desc', tostring(p.oldJob or '-')) },
            { id = 'no',  label = L('boss_confirm_no') },
        },
    })
    answered = true
    return choice == 'yes'
end)

--------------------------------------------------------------------------
-- Marke anzeigen (ohne Fokus)
--------------------------------------------------------------------------
Law.On('core:badge', function(data)
    Law.UI.Show('badge', data)
end)

--------------------------------------------------------------------------
-- Leitstelle
--------------------------------------------------------------------------
local alerts = {}   -- [id] = alert
local alertBlips = {}

local function removeAlertBlip(id)
    if alertBlips[id] then
        Law.Util.RemoveBlip(alertBlips[id])
        alertBlips[id] = nil
    end
end

local function addAlertBlip(a)
    removeAlertBlip(a.id)
    local b = a.blip or {}
    local cfg = Config.Dispatch.Blip
    alertBlips[a.id] = Law.Util.AddBlip(a.coords, b.sprite or cfg.sprite, ('#%d %s'):format(a.id, a.title), b.color or cfg.color, b.style or cfg.style)
    local id = a.id
    SetTimeout((cfg.seconds or 180) * 1000, function()
        if alertBlips[id] then removeAlertBlip(id) end
    end)
end

Law.On('dispatch:new', function(a)
    alerts[a.id] = a
    addAlertBlip(a)
    Law.UI.Toast(('#%d %s'):format(a.id, a.title), a.text .. (a.zone and (' (' .. a.zone .. ')') or '') .. '\n' .. L('dispatch_hint_accept', a.id), a.priority >= 3 and 'alert' or 'info', a.priority >= 3 and 12000 or 8000)
    if Law.UI.IsOpen() then Law.UI.Update('ledger', { alertsChanged = true }) end
end)

Law.On('dispatch:update', function(a)
    alerts[a.id] = a
    if Law.UI.IsOpen() then Law.UI.Update('ledger', { alertsChanged = true }) end
end)

Law.On('dispatch:remove', function(id, reason)
    alerts[id] = nil
    removeAlertBlip(id)
    if Law.UI.IsOpen() then Law.UI.Update('ledger', { alertsChanged = true }) end
end)

Law.On('dispatch:list', function(list)
    for id in pairs(alertBlips) do removeAlertBlip(id) end
    alerts = {}
    for _, a in ipairs(list or {}) do alerts[a.id] = a end
end)

Law.On('dispatch:clear', function()
    for id in pairs(alertBlips) do removeAlertBlip(id) end
    alerts = {}
end)

Law.On('dispatch:waypoint', function(coords)
    Law.Util.SetWaypoint(coords)
end)

--------------------------------------------------------------------------
-- Admin: Koordinaten ausgeben
--------------------------------------------------------------------------
Law.On('core:printCoords', function()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    local v3 = ('vector3(%.2f, %.2f, %.2f)'):format(c.x, c.y, c.z)
    local v4 = ('vector4(%.2f, %.2f, %.2f, %.2f)'):format(c.x, c.y, c.z, h)
    print('[ArA-Law] ' .. v3)
    print('[ArA-Law] ' .. v4)
    Law.Notify(v4, 'objective', 8000)
end)

--------------------------------------------------------------------------
-- Modul: Dienst-HUD, Aufraeumen
--------------------------------------------------------------------------
Law.Modules.Register('core', {
    onSync = function(me)
        if Config.General.ShowDutyHud and me.onDuty then
            Law.UI.Hud('duty', { deptLabel = me.deptLabel, gradeLabel = me.gradeLabel, badgeNumber = me.badgeNumber })
        else
            Law.UI.Hud('duty', nil)
        end
    end,
    onStop = function()
        for id in pairs(alertBlips) do removeAlertBlip(id) end
        Law.Util.ClearWaypoint()
    end,
})
