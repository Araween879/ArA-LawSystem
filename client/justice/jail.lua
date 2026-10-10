--[[
    ArA-LawSystem - Knast (Client, Agent A)

    Stationspunkt "jail" (Recht jail, im Dienst): Formular Haftstrafe fuer
    gefesselte Spieler in Reichweite -> jail:sentence
    Haeftling: HUD "jail", Tastensperre (Pferd/Wagen rufen), Knastarbeit an
    den work-Punkten (eigene Prompts, nur in Haft), Teleport rein/raus.

    Zeit und Flucht entscheidet der Server - der Client zeigt nur an.
]]

Law.Justice = Law.Justice or {}

local yes = function(v) return v == true or v == 1 end

local jail = nil          -- Daten vom Server (jail:enter)
local working = false
local controlLoop, workLoop = false, false
local workPrompt, promptGroup

--------------------------------------------------------------------------
-- Helfer
--------------------------------------------------------------------------
local function waitAlive(ms)
    local t = GetGameTimer() + (ms or 8000)
    while (Law.State.dead or yes(IsEntityDead(PlayerPedId()))) and GetGameTimer() < t do Wait(250) end
end

local function ensurePrompt()
    if workPrompt then return end
    promptGroup = GetRandomIntInRange(0, 0xffffff)
    workPrompt = PromptRegisterBegin()
    PromptSetControlAction(workPrompt, Config.Keys.Prompt)
    PromptSetText(workPrompt, CreateVarString(10, 'LITERAL_STRING', L('jail_work_prompt')))
    PromptSetEnabled(workPrompt, true)
    PromptSetVisible(workPrompt, true)
    PromptSetHoldMode(workPrompt, 1000)
    PromptSetGroup(workPrompt, promptGroup, 0)
    PromptRegisterEnd(workPrompt)
end

local function deletePrompt()
    if workPrompt then PromptDelete(workPrompt) end
    workPrompt = nil
end

local function doWork(w)
    working = true
    local res = Law.Cb.Await('jail:workStart', w.index)
    if not res or not res.ok then
        Law.Notify(res and res.msg or L('err_failed'))
        working = false
        return
    end
    local ped = PlayerPedId()
    local scenario = res.data and res.data.scenario
    if scenario then TaskStartScenarioInPlace(ped, joaat(scenario), -1, true, false, false, false) end
    Law.Util.Progress(L('jail_work_progress', w.label or ''), ((res.data and res.data.seconds) or 10) * 1000)
    ClearPedTasks(ped)
    local fin = Law.Cb.Await('jail:workFinish')
    Law.Notify(fin and fin.msg or L('err_failed'))
    working = false
end

local function startLoops()
    if not controlLoop then
        controlLoop = true
        CreateThread(function()
            local list = Config.Jail.DisabledControls or {}
            while jail do
                for i = 1, #list do DisableControlAction(0, list[i], true) end
                Wait(0)
            end
            controlLoop = false
        end)
    end
    if not workLoop then
        workLoop = true
        CreateThread(function()
            while jail do
                local sleep = 1000
                if not working and not Law.State.cuffed and not Law.UI.IsOpen() and workPrompt then
                    local pos = GetEntityCoords(PlayerPedId())
                    local best, bestD
                    for _, w in ipairs(jail.work or {}) do
                        local d = #(pos - vector3(w.coords.x, w.coords.y, w.coords.z))
                        if d < 20.0 and sleep > 250 then sleep = 250 end
                        if d <= (jail.workDistance or 2.5) and (not bestD or d < bestD) then best, bestD = w, d end
                    end
                    if best then
                        sleep = 0
                        PromptSetText(workPrompt, CreateVarString(10, 'LITERAL_STRING', best.label or L('jail_work_prompt')))
                        PromptSetActiveGroupThisFrame(promptGroup, CreateVarString(10, 'LITERAL_STRING', L('jail_work_group')))
                        if yes(PromptHasHoldModeCompleted(workPrompt)) then
                            doWork(best)
                            sleep = 500
                        end
                    end
                end
                Wait(sleep)
            end
            workLoop = false
        end)
    end
end

local function enter(data)
    if type(data) ~= 'table' then return end
    local first = jail == nil
    jail = data
    Law.State.jailed = true
    if Law.UI.IsOpen() then Law.UI.Close() end
    Law.UI.Hud('jail', data.hud)
    ensurePrompt()
    startLoops()
    if data.teleport and data.spawn then
        CreateThread(function()
            waitAlive()
            Law.Justice.Teleport(data.spawn)
        end)
    end
    if first then Law.Notify(L('jail_entered', data.label or ''), 'objective', 8000) end
end

local function leave(data)
    jail = nil
    working = false
    Law.State.jailed = false
    Law.UI.Hud('jail', nil)
    deletePrompt()
    if type(data) == 'table' and data.release then
        CreateThread(function()
            waitAlive()
            Law.Justice.Teleport(data.release)
        end)
    end
end

--------------------------------------------------------------------------
-- Server -> Client
--------------------------------------------------------------------------
Law.On('jail:enter', enter)

Law.On('jail:hud', function(h)
    if jail and type(h) == 'table' then
        jail.hud = h
        Law.UI.Hud('jail', h)
    end
end)

Law.On('jail:teleport', function(spawn)
    if not jail or type(spawn) ~= 'table' then return end
    CreateThread(function()
        waitAlive()
        Law.Justice.Teleport(spawn)
        Law.Notify(L('jail_back_to_cell'))
    end)
end)

Law.On('jail:leave', leave)

-- Server oeffnet gleich ein vorp-Inventar (Habseligkeiten) -> eigene NUI zu
Law.On('jail:closeUi', function()
    if Law.UI.IsOpen() then Law.UI.Close() end
end)

--------------------------------------------------------------------------
-- Einbuchungspunkt
--------------------------------------------------------------------------
local function locationOptions()
    local out = {}
    for key, l in pairs(Config.Jail.Locations or {}) do
        -- Zellen mit Tueren nicht hier: dort wird an der Zellentuer eingebucht
        if l.enabled ~= false and l.mode ~= 'cells' then out[#out + 1] = { value = key, label = l.label or key } end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

Law.Stations.RegisterPoint('jail', {
    perm = 'jail', duty = true,
    label = L('prompt_jail'),
    onUse = function(stationKey)
        local players = {}
        for _, p in ipairs(Law.Util.GetPlayersInRange(Config.Jail.SentenceDistance or 5.0)) do
            if Law.Justice.StateOf(p.serverId, 'law_cuffed') == true then
                players[#players + 1] = { value = p.serverId, label = p.name }
            end
        end
        if #players == 0 then return Law.Notify(L('jail_no_cuffed_near')) end

        local locs = locationOptions()
        if #locs == 0 then return Law.Notify(L('err_no_location')) end
        local defLoc = Config.Jail.StationLocation[stationKey] or Config.Jail.DefaultLocation
        local values = Law.UI.Form({
            id = 'jail', title = L('form_jail_title'), subtitle = Config.Stations[stationKey] and Config.Stations[stationKey].label or nil,
            submitLabel = L('form_jail_submit'), summary = 'penalcode',
            fields = {
                { name = 'target', type = 'select', label = L('form_target'), required = true, options = players, default = players[1].value },
                { name = 'codes', type = 'penalcode', label = L('form_codes'), required = true, options = Law.Justice.PenalOptions() },
                { name = 'minutes', type = 'number', label = L('form_extra_minutes'), min = 0, max = Config.Jail.MaxExtraMinutes, default = 0,
                  help = L('form_extra_minutes_help') },
                { name = 'bail', type = 'money', label = L('form_bail'), min = 0, max = Config.Jail.Bail.MaxAmount, default = 0,
                  help = L('form_bail_help') },
                { name = 'location', type = 'select', label = L('form_location'), required = true, options = locs, default = defLoc },
                { name = 'note', type = 'text', label = L('form_note'), maxLength = 120, placeholder = L('form_note_placeholder') },
            },
        })
        if not values then return end
        local res = Law.Cb.Await('jail:sentence', values.target, values.codes, values.minutes, values.bail, values.note, values.location)
        Law.Notify(res and res.msg or L('err_failed'))
    end,
})

--------------------------------------------------------------------------
-- Einbuchen an der Zellentuer (Zellen mit Tueren, kein Teleport hinein)
-- Tuer abgeschlossen + jemand steht IN der Zelle -> Prompt erscheint.
--------------------------------------------------------------------------
local function cellOf(stationKey, idx)
    local loc = Config.Jail.Locations[stationKey]
    return loc and loc.mode == 'cells' and (loc.cells or {})[idx] or nil
end

--- Spieler, die gerade in der Zelle stehen und noch nicht eingebucht sind
local function playersInCell(cell)
    local out = {}
    local me = PlayerPedId()
    for _, pid in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(pid)
        if ped ~= me and DoesEntityExist(ped) then
            local c = GetEntityCoords(ped)
            local dx, dy = c.x - cell.center.x, c.y - cell.center.y
            if math.sqrt(dx * dx + dy * dy) <= cell.radius + 0.3 and math.abs(c.z - cell.center.z) <= 3.0 then
                local sid = GetPlayerServerId(pid)
                if Law.Justice.StateOf(sid, 'law_jailed') ~= true then
                    out[#out + 1] = { value = sid, label = Law.Util.PlayerName(sid) }
                end
            end
        end
    end
    return out
end

Law.Stations.RegisterPoint('cellbook', {
    perm = 'jail', duty = true,
    distance = (Config.Jail.Cells and Config.Jail.Cells.DoorReach) or 2.0,
    label = function(_, point) return L('prompt_cell_book', point.label or '') end,
    canShow = function(stationKey, point)
        if not Law.Doors.IsLocked(point.door) then return false end
        local cell = cellOf(stationKey, point.cell)
        return cell ~= nil and #playersInCell(cell) > 0
    end,
    onUse = function(stationKey, point)
        local cell = cellOf(stationKey, point.cell)
        if not cell then return end
        local players = playersInCell(cell)
        if #players == 0 then return Law.Notify(L('jail_nobody_in_cell')) end
        local values = Law.UI.Form({
            id = 'jailcell', title = L('form_cell_title', cell.label), subtitle = Config.Stations[stationKey] and Config.Stations[stationKey].label or nil,
            submitLabel = L('form_jail_submit'), summary = 'penalcode',
            fields = {
                { name = 'target', type = 'select', label = L('form_target'), required = true, options = players, default = players[1].value },
                { name = 'codes', type = 'penalcode', label = L('form_codes'), required = true, options = Law.Justice.PenalOptions() },
                { name = 'minutes', type = 'number', label = L('form_extra_minutes'), min = 0, max = Config.Jail.MaxExtraMinutes, default = 0,
                  help = L('form_extra_minutes_help') },
                { name = 'bail', type = 'money', label = L('form_bail'), min = 0, max = Config.Jail.Bail.MaxAmount, default = 0,
                  help = L('form_bail_help') },
                { name = 'note', type = 'text', label = L('form_note'), maxLength = 120, placeholder = L('form_note_placeholder') },
            },
        })
        if not values then return end
        local res = Law.Cb.Await('jail:sentenceCell', point.door, values.target, values.codes, values.minutes, values.bail, values.note)
        Law.Notify(res and res.msg or L('err_failed'), res and res.ok and 'success' or 'error')
    end,
})

--------------------------------------------------------------------------
-- Modul
--------------------------------------------------------------------------
Law.Modules.Register('jail', {
    onSync = function()
        if Law.State.jailed and not jail then
            -- z.B. Resource-Neustart: eigene Haftdaten holen (ohne Teleport)
            CreateThread(function()
                local r = Law.Cb.Await('jail:myStatus')
                if r and r.ok and type(r.data) == 'table' then enter(r.data) end
            end)
        elseif not Law.State.jailed and jail then
            leave(nil)
        end
    end,
    onStop = function()
        if working then ClearPedTasks(PlayerPedId()) end
        jail, working = nil, false
        Law.UI.Hud('jail', nil)
        deletePrompt()
    end,
})
