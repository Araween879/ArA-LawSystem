--[[
    ArA-LawSystem - Stationen: EIN Naehe-Loop, EINE Prompt-Gruppe (Client)

    Module melden nur Punkt-Typen an (Law.Stations.RegisterPoint). Dieser
    Loop sucht alle Punkte aus Config.Stations, zeigt fuer alle passenden
    Typen am naechsten Standort je einen Prompt und ruft onUse auf.

    Weit weg: Wait(1000). Innerhalb 15 m: Wait(250). In Reichweite: Wait(0).
]]

Law.Stations = Law.Stations or {}

local registry = {}      -- [pointType] = def
local flatPoints = {}    -- { { station, type, coords, point } }
local prompts = {}       -- [pointType] = prompt
local group = GetRandomIntInRange(0, 0xffffff)
local blips = {}
local busy = false

local DEFAULT_DISTANCE = 1.8

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

local function createPrompt(pType, def)
    local prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, Config.Keys.Prompt)
    PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', 'ArA-Law'))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetHoldMode(prompt, def.hold or 500)
    PromptSetGroup(prompt, group, 0)
    PromptRegisterEnd(prompt)
    prompts[pType] = prompt
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
            local p = st.points and (st.points.counter or st.points.duty)
            local c = p and Law.Vec(p.coords or (p[1] and p[1].coords))
            if c then
                blips[key] = Law.Util.AddBlip(c, st.blip.sprite, st.blip.name or st.label, st.blip.color, st.blip.style)
            end
        end
    end
end

function Law.Stations.Start()
    buildPoints()
    for pType, def in pairs(registry) do createPrompt(pType, def) end
    createBlips()

    CreateThread(function()
        while true do
            local sleep = 1000
            if Law.Ready and not Law.UI.IsOpen() and not Law.State.cuffed then
                local pos = GetEntityCoords(PlayerPedId())
                local nearestStation, nearestDist = nil, math.huge
                local active = {}

                for _, fp in ipairs(flatPoints) do
                    local def = registry[fp.type]
                    if def and fp.coords then
                        local d = #(pos - fp.coords)
                        if d < 15.0 and sleep > 250 then sleep = 250 end
                        local reach = def.distance or DEFAULT_DISTANCE
                        if d <= reach and allowed(def, fp.station, fp.point) then
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
                    for pType, prompt in pairs(prompts) do
                        local a = active[pType]
                        if a then
                            PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', labelOf(registry[pType], a.fp.station, a.fp.point)))
                            PromptSetVisible(prompt, true)
                            PromptSetEnabled(prompt, not busy)
                        else
                            PromptSetVisible(prompt, false)
                            PromptSetEnabled(prompt, false)
                        end
                    end
                    local st = Config.Stations[nearestStation]
                    PromptSetActiveGroupThisFrame(group, CreateVarString(10, 'LITERAL_STRING', st and st.label or 'ArA-Law'))
                    for pType, a in pairs(active) do
                        local prompt = prompts[pType]
                        if prompt and PromptHasHoldModeCompleted(prompt) then
                            runUse(registry[pType], a.fp.station, a.fp.point)
                            Wait(250)
                            break
                        end
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
    for _, b in pairs(blips) do Law.Util.RemoveBlip(b) end
    blips = {}
end
