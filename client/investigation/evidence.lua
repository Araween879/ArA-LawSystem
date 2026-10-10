--[[
    ArA-LawSystem - Spurensuche, Labor, Schmauchtest (Client)

    Spurensuche-Modus: der Client FRAGT alle ScanCooldown Sekunden den Server
    (evidence:scan) und zeichnet nur, was zurueckkommt - Spuren liegen nie
    vorab auf dem Client. Sichern per Prompt (Halten) -> evidence:collect.
]]

local Cfg = Config.Evidence

local mode = false
local traces = {}          -- { id, kind, v = vector3, ageClass }
local busy = false
local promptGroup = GetRandomIntInRange(0, 0xffffff)
local collectPrompt = nil

local function hud()
    if mode then
        Law.UI.Hud('evidence', { active = true, count = #traces })
    else
        Law.UI.Hud('evidence', nil)
    end
end

local function createPrompt()
    if collectPrompt then return end
    collectPrompt = PromptRegisterBegin()
    PromptSetControlAction(collectPrompt, Config.Keys.Prompt)
    PromptSetText(collectPrompt, CreateVarString(10, 'LITERAL_STRING', L('evidence_prompt_collect')))
    PromptSetEnabled(collectPrompt, true)
    PromptSetVisible(collectPrompt, true)
    PromptSetHoldMode(collectPrompt, 800)
    PromptSetGroup(collectPrompt, promptGroup, 0)
    PromptRegisterEnd(collectPrompt)
end

local function deletePrompt()
    if collectPrompt then
        PromptDelete(collectPrompt)
        collectPrompt = nil
    end
end

local setMode

local function scanLoop()
    while mode do
        local res = Law.Cb.Await('evidence:scan')
        if not mode then break end
        if res and res.ok then
            local list = {}
            for _, t in ipairs(res.data or {}) do
                if t.coords then
                    list[#list + 1] = { id = t.id, kind = t.kind, ageClass = t.ageClass,
                        v = vector3(t.coords.x + 0.0, t.coords.y + 0.0, t.coords.z + 0.0) }
                end
            end
            traces = list
            hud()
        elseif res and res.err ~= 'rate_limited' and res.err ~= 'timeout' then
            Law.Notify(res.msg or L('err_failed'))
            setMode(false)
            break
        end
        Wait((Cfg.ScanCooldown or 3) * 1000)
    end
end

local function collect(id)
    busy = true
    CreateThread(function()
        local ped = PlayerPedId()
        TaskStartScenarioInPlace(ped, `WORLD_HUMAN_CROUCH_INSPECT`, 2500, true, false, false, false)
        Wait(2500)
        ClearPedTasks(ped)
        local res = Law.Cb.Await('evidence:collect', id)
        Law.Notify(res and res.msg or L('err_failed'))
        if res and (res.ok or res.err == 'evidence_gone') then
            for i, t in ipairs(traces) do
                if t.id == id then
                    table.remove(traces, i)
                    break
                end
            end
            hud()
        end
        Wait(500)
        busy = false
    end)
end

local function drawLoop()
    local maxDraw = Cfg.DrawDistance or 30.0
    local reach = Cfg.PromptDistance or 1.5
    while mode do
        local sleep = 500
        local pos = GetEntityCoords(PlayerPedId())
        local nearest, nearestDist
        for _, t in ipairs(traces) do
            local d = #(pos - t.v)
            if d <= maxDraw then
                sleep = 0
                local c = (Cfg.Colors or {})[t.kind] or { 200, 200, 200 }
                local alpha = (t.ageClass == 'fresh' and 220) or (t.ageClass == 'medium' and 150) or 90
                -- DrawMarker (0x2A32FAA57B937173), Typ 0x94FDAE17 = flacher Zylinder am Boden
                Citizen.InvokeNative(0x2A32FAA57B937173, 0x94FDAE17, t.v.x, t.v.y, t.v.z - 0.95,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.12, c[1], c[2], c[3], alpha, 0, 0, 2, 0, 0, 0, 0)
                if d <= reach and (not nearestDist or d < nearestDist) then nearest, nearestDist = t, d end
            end
        end
        if nearest and collectPrompt and not busy and not Law.UI.IsOpen() then
            PromptSetActiveGroupThisFrame(promptGroup, CreateVarString(10, 'LITERAL_STRING', L('evidence_type_' .. nearest.kind)))
            if PromptHasHoldModeCompleted(collectPrompt) then
                collect(nearest.id)
                Wait(300)
            end
        end
        Wait(sleep)
    end
end

setMode = function(on)
    if on == mode then return end
    mode = on
    traces = {}
    hud()
    if on then
        createPrompt()
        CreateThread(scanLoop)
        CreateThread(drawLoop)
        Law.Notify(L('evidence_mode_on'))
    else
        Law.Notify(L('evidence_mode_off'))
    end
end

--------------------------------------------------------------------------
-- Interaktionen
--------------------------------------------------------------------------
Law.Interact.Register('evidence_mode', {
    label = function() return mode and L('evidence_interact_mode_off') or L('evidence_interact_mode_on') end,
    desc = L('evidence_interact_mode_desc'),
    order = 20, target = false, perm = 'evidence', duty = true,
    onSelect = function() setMode(not mode) end,
})

Law.Interact.Register('evidence_gsr', {
    label = L('evidence_interact_gsr'),
    desc = L('evidence_interact_gsr_desc'),
    order = 45, target = true, perm = 'evidence', duty = true,
    onSelect = function(targetSrc)
        local ped = PlayerPedId()
        TaskStartScenarioInPlace(ped, `WORLD_HUMAN_INSPECT`, 3000, true, false, false, false)
        Wait(3000)
        ClearPedTasks(ped)
        local res = Law.Cb.Await('evidence:gsr', targetSrc)
        Law.Notify(res and res.msg or L('err_failed'), 'objective', 6000)
    end,
})

--------------------------------------------------------------------------
-- Labor und Asservatenkammer (Stationspunkt "evidence")
--------------------------------------------------------------------------
local function analyzeMenu()
    local res = Law.Cb.Await('evidence:myItems')
    if not res or not res.ok then return Law.Notify(res and res.msg or L('err_failed')) end
    local items = {}
    for _, it in ipairs(res.data or {}) do
        items[#items + 1] = { id = it.id, label = L('evidence_menu_item', it.typeLabel, it.evidenceId), desc = it.description }
    end
    if #items == 0 then return Law.Notify(L('evidence_lab_none')) end
    local choice = Law.UI.Menu({ title = L('evidence_lab_title'), subtitle = L('evidence_lab_subtitle'), items = items })
    if not choice then return end
    local r = Law.Cb.Await('evidence:analyze', choice)
    if not r or not r.ok then return Law.Notify(r and r.msg or L('err_failed')) end
    if r.data and (tonumber(r.data.seconds) or 0) > 0 then
        Law.UI.Toast(L('evidence_lab_title'), r.msg or '', 'info', 6000)
    end
end

Law.Stations.RegisterPoint('evidence', {
    perm = 'evidence', duty = true,
    label = L('evidence_prompt_lab'),
    onUse = function()
        local items = { { id = 'locker', label = L('evidence_menu_locker'), desc = L('evidence_menu_locker_desc') } }
        items[#items + 1] = {
            id = 'analyze', label = L('evidence_menu_analyze'), desc = L('evidence_menu_analyze_desc'),
            disabled = not Law.HasPerm('evidence_analyze'),
        }
        local choice = Law.UI.Menu({ title = L('evidence_station_title'), items = items })
        if choice == 'locker' then
            Law.Net.Send('evidence:openLocker')
        elseif choice == 'analyze' then
            analyzeMenu()
        end
    end,
})

-- Laborbericht (Server baut das Dokument aus der DB)
Law.On('evidence:document', function(def)
    if type(def) ~= 'table' then return end
    Law.UI.Document(def)
end)

Law.Modules.Register('evidence', {
    onDuty = function(onDuty)
        if not onDuty and mode then setMode(false) end
    end,
    onStop = function()
        mode = false
        traces = {}
        deletePrompt()
        Law.UI.Hud('evidence', nil)
    end,
})
