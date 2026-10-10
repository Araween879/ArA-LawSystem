--[[
    ArA-LawSystem - Stationen: EIN Naehe-Loop, EINE Prompt-Gruppe (Client)

    Module melden nur Punkt-Typen an (Law.Stations.RegisterPoint). Dieser
    Loop sucht alle Punkte aus Config.Stations und zeigt EINEN Prompt:
      - eine Aktion in Reichweite  -> ihr Prompt, Halten = onUse
      - mehrere (z.B. Zellentuer: Aufschliessen + Einbuchen, Garage +
        Eskorte am selben Fleck) -> ein Prompt, Halten oeffnet ein
        Auswahlmenue. So loest nie zufaellig die falsche Aktion aus.

    Weit weg: Wait(1000). Innerhalb 15 m: Wait(250). In Reichweite: Wait(0).
]]

Law.Stations = Law.Stations or {}

local registry = {}      -- [pointType] = def
local flatPoints = {}    -- { { station, type, coords, point } }
local prompts = {}       -- [pointType] = prompt
local multiPrompt = nil  -- ein Prompt fuer "mehrere Aktionen hier"
local group = GetRandomIntInRange(0, 0xffffff)
local blips = {}
local busy = false

local DEFAULT_DISTANCE = 1.8

--- Waagerechter Abstand + Hoehenunterschied (Punkte duerfen auf Tisch-/Schildhoehe liegen)
local function distTo(pos, c)
    local dx, dy = pos.x - c.x, pos.y - c.y
    return math.sqrt(dx * dx + dy * dy), math.abs(pos.z - c.z)
end

--- def = { label, law, perm, duty, canShow(stationKey, point), onUse(stationKey, point), hold, distance }
function Law.Stations.RegisterPoint(pointType, def)
    registry[pointType] = def
end

local function pointList(p)
    if not p then return {} end
    if p.coords then return { p } end
    return p
end

local function buildPoints()
    flatPoints = {}
    for key, st in pairs(Config.Stations) do
        for pType, p in pairs(st.points or {}) do
            for _, one in ipairs(pointList(p)) do
                flatPoints[#flatPoints + 1] = { station = key, type = pType, coords = Law.Vec(one.coords), point = one }
            end
        end
    end
end

local function newPrompt(hold)
    local prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, Config.Keys.Prompt)
    PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', 'ArA-Law'))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetHoldMode(prompt, hold or 500)
    PromptSetGroup(prompt, group, 0)
    PromptRegisterEnd(prompt)
    return prompt
end

local function createPrompt(pType, def)
    prompts[pType] = newPrompt(def.hold)
end

local function labelOf(def, stationKey, point)
    if type(def.label) == 'function' then return def.label(stationKey, point) end
    return def.label or ''
end

local function allowed(def, stationKey, point)
    if def.law and not Law.Me.dept then return false end
    if def.duty and not Law.Me.onDuty then return false end
    if def.perm and not Law.HasPerm(def.perm) then return false end
    local st = Config.Stations[stationKey]
    if (def.law or def.perm) and st and st.depts and not Law.Contains(st.depts, Law.Me.dept) then return false end
    -- jobs am Punkt: nur diese Jobs sehen den Prompt (gilt auch fuer Buerger-Punkte)
    if point and point.jobs and not Law.Contains(point.jobs, Law.Me.dept) then return false end
    if def.canShow and not def.canShow(stationKey, point) then return false end
    return true
end

local function runUse(def, stationKey, point)
    if busy then return end
    busy = true
    CreateThread(function()
        local ok, err = xpcall(def.onUse, debug.traceback, stationKey, point)
        if not ok then Law.Warn('Fehler an Punkt: %s', tostring(err)) end
        Wait(500)
        busy = false
    end)
end

local function createBlips()
    for key, st in pairs(Config.Stations) do
        if st.blip then
            -- Position: blip.coords, sonst Schalter, sonst Dienst-Punkt
            local p = st.points and (st.points.counter or st.points.duty)
            local c = Law.Vec(st.blip.coords) or (p and Law.Vec(p.coords or (p[1] and p[1].coords)))
            if c then
                blips[key] = Law.Util.AddBlip(c, st.blip.sprite, st.blip.name or st.label, st.blip.color, st.blip.style)
            end
        end
    end
end

local function showPrompt(prompt, text)
    PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', text))
    PromptSetVisible(prompt, true)
    PromptSetEnabled(prompt, not busy)
end

local function hidePrompt(prompt)
    PromptSetVisible(prompt, false)
    PromptSetEnabled(prompt, false)
end

--- Mehrere Aktionen am selben Fleck: Auswahlmenue, dann die gewaehlte Aktion
local function runChoice(list, stationKey)
    runUse({ onUse = function()
        local items = {}
        for i, e in ipairs(list) do
            items[#items + 1] = { id = 'a' .. i, label = labelOf(registry[e.type], e.fp.station, e.fp.point) }
        end
        local st = Config.Stations[stationKey]
        local choice = Law.UI.Menu({ title = st and st.label or 'ArA-Law', subtitle = L('prompt_multi_sub'), items = items })
        local e = type(choice) == 'string' and list[tonumber(choice:sub(2))]
        -- Beim Waehlen noch erlaubt? (Zustand kann sich geaendert haben, z.B. Tuer)
        if e and allowed(registry[e.type], e.fp.station, e.fp.point) then
            registry[e.type].onUse(e.fp.station, e.fp.point)
        end
    end }, stationKey, nil)
end

function Law.Stations.Start()
    buildPoints()
    for pType, def in pairs(registry) do createPrompt(pType, def) end
    multiPrompt = newPrompt(500)
    createBlips()

    CreateThread(function()
        while true do
            local sleep = 1000
            if Law.Ready and not Law.UI.IsOpen() and not Law.State.cuffed then
                local pos = GetEntityCoords(PlayerPedId())
                local nearestStation, nearestDist = nil, math.huge
                local active = {}

                local maxDz = (Config.Points and Config.Points.HeightTolerance) or 2.5
                for _, fp in ipairs(flatPoints) do
                    local def = registry[fp.type]
                    if def and fp.coords then
                        local d, dz = distTo(pos, fp.coords)
                        if d < 15.0 and sleep > 250 then sleep = 250 end
                        local reach = def.distance or DEFAULT_DISTANCE
                        if d <= reach and dz <= maxDz and allowed(def, fp.station, fp.point) then
                            -- je Typ nur der naechste Punkt
                            if not active[fp.type] or d < active[fp.type].dist then
                                active[fp.type] = { fp = fp, dist = d }
                            end
                            if d < nearestDist then nearestDist, nearestStation = d, fp.station end
                        end
                    end
                end

                if nearestStation then
                    sleep = 0
                    -- feste Reihenfolge: naechste Aktion zuerst (pairs() ist zufaellig)
                    local list = {}
                    for pType, a in pairs(active) do list[#list + 1] = { type = pType, fp = a.fp, dist = a.dist } end
                    table.sort(list, function(x, y)
                        if math.abs(x.dist - y.dist) > 0.01 then return x.dist < y.dist end
                        return x.type < y.type
                    end)
                    local single = #list == 1 and list[1] or nil
                    for pType, prompt in pairs(prompts) do
                        if single and single.type == pType then
                            showPrompt(prompt, labelOf(registry[pType], single.fp.station, single.fp.point))
                        else
                            hidePrompt(prompt)
                        end
                    end
                    if #list > 1 then
                        local texts = {}
                        for _, e in ipairs(list) do texts[#texts + 1] = labelOf(registry[e.type], e.fp.station, e.fp.point) end
                        local text = table.concat(texts, ' / ')
                        if #text > 70 then text = L('prompt_multi', #list) end
                        showPrompt(multiPrompt, text)
                    else
                        hidePrompt(multiPrompt)
                    end
                    local st = Config.Stations[nearestStation]
                    PromptSetActiveGroupThisFrame(group, CreateVarString(10, 'LITERAL_STRING', st and st.label or 'ArA-Law'))
                    if single then
                        local prompt = prompts[single.type]
                        if prompt and PromptHasHoldModeCompleted(prompt) then
                            runUse(registry[single.type], single.fp.station, single.fp.point)
                            Wait(250)
                        end
                    elseif #list > 1 and PromptHasHoldModeCompleted(multiPrompt) then
                        runChoice(list, nearestStation)
                        Wait(250)
                    end
                end
            end
            Wait(sleep)
        end
    end)
end

function Law.Stations.Stop()
    for _, prompt in pairs(prompts) do PromptDelete(prompt) end
    prompts = {}
    if multiPrompt then PromptDelete(multiPrompt) multiPrompt = nil end
    for _, b in pairs(blips) do Law.Util.RemoveBlip(b) end
    blips = {}
end
