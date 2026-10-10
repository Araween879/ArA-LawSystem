--[[
    ArA-LawSystem - Eskorte: Ueberfall und Hinterhalt (Client)

    Ueberfall: der Client findet einen Panzerwagen in seiner Naehe selbst
    (Modell) und fragt den Server NUR fuer diesen Wagen (escort:canRob).
    Start/Ende-Muster: escort:robStart -> Fortschritt -> escort:robFinish;
    die Zeit misst der Server.
    Hinterhalt: der Server schickt dem Leiter Ort und Anzahl, der Client
    spawnt feindliche Banditen und raeumt sie beim Vertragsende wieder weg.
]]

Law.Escort = Law.Escort or {}
local EC = Law.Escort
local ECfg = Config.Escort
local RCfg = ECfg.Robbery or {}

local function u32(h)
    h = math.tointeger(tonumber(h) or 0) or 0
    if h < 0 then h = h + 4294967296 end
    return h
end

local WAGON_HASH = u32(joaat(ECfg.WagonModel))

--------------------------------------------------------------------------
-- Ueberfall
--------------------------------------------------------------------------
local group = GetRandomIntInRange(0, 0xffffff)
local robPrompt, lootPrompt
local robbing = false
local checked = {}  -- [netId] = { t, canRob, canLoot, id }

local function makePrompt(text, hold)
    local p = PromptRegisterBegin()
    PromptSetControlAction(p, Config.Keys.Prompt)
    PromptSetText(p, CreateVarString(10, 'LITERAL_STRING', text))
    PromptSetEnabled(p, true)
    PromptSetVisible(p, true)
    PromptSetHoldMode(p, hold)
    PromptSetGroup(p, group, 0)
    PromptRegisterEnd(p)
    return p
end

local function createPrompts()
    if robPrompt then return end
    robPrompt = makePrompt(L('escort_rob_prompt'), 1500)
    lootPrompt = makePrompt(L('escort_loot_prompt'), 800)
end

local function nearestWagon(pos, maxDist)
    local best, bestDist
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if u32(GetEntityModel(veh)) == WAGON_HASH then
            local d = #(GetEntityCoords(veh) - pos)
            if d <= maxDist and (not bestDist or d < bestDist) then best, bestDist = veh, d end
        end
    end
    return best, bestDist
end

local function doRob(netId)
    robbing = true
    local res = Law.Cb.Await('escort:robStart', netId)
    if not res or not res.ok then
        Law.Notify(res and res.msg or L('err_failed'))
        robbing = false
        return
    end
    local total = (tonumber(res.data and res.data.seconds) or RCfg.Seconds or 60) * 1000
    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, `WORLD_HUMAN_CROUCH_INSPECT`, -1, true, false, false, false)
    local start = GetGameTimer()
    local aborted = false
    while GetGameTimer() - start < total do
        Wait(250)
        local veh = NetworkDoesNetworkIdExist(netId) and NetworkGetEntityFromNetworkId(netId) or 0
        if Law.State.cuffed or IsEntityDead(ped) or veh == 0
            or #(GetEntityCoords(ped) - GetEntityCoords(veh)) > (RCfg.Distance or 3.0) + 1.0 then
            aborted = true
            break
        end
        Law.UI.Hud('robbery', { progress = (GetGameTimer() - start) / total, text = L('escort_rob_progress') })
    end
    ClearPedTasks(ped)
    Law.UI.Hud('robbery', nil)
    if aborted then
        Law.Net.Send('escort:robAbort', netId)
        Law.Notify(L('escort_rob_aborted'))
        robbing = false
        return
    end
    local r = Law.Cb.Await('escort:robFinish', netId)
    Law.Notify(r and r.msg or L('err_failed'))
    checked[netId] = nil
    robbing = false
end

CreateThread(function()
    while true do
        local sleep = 1500
        if Law.Ready and not robbing and not Law.State.cuffed and not Law.State.dead and not Law.UI.IsOpen() then
            local pos = GetEntityCoords(PlayerPedId())
            local reach = RCfg.Distance or 3.0
            local veh, dist = nearestWagon(pos, reach + 4.0)
            if veh and NetworkGetEntityIsNetworked(veh) then
                sleep = 500
                local netId = NetworkGetNetworkIdFromEntity(veh)
                local info = checked[netId]
                if not info or GetGameTimer() - info.t > 8000 then
                    info = { t = GetGameTimer() }
                    checked[netId] = info
                    local res = Law.Cb.Await('escort:canRob', netId)
                    if res and res.ok and type(res.data) == 'table' then
                        info.canRob = res.data.canRob == true
                        info.canLoot = res.data.canLoot == true
                        info.id = res.data.id
                    end
                end
                if dist <= reach and (info.canRob or info.canLoot) then
                    createPrompts()
                    -- Solange der Spieler am Wagen steht: jeden Frame, ohne die Pool-Suche zu wiederholen
                    local untilT = GetGameTimer() + 500
                    while GetGameTimer() < untilT and not robbing do
                        PromptSetVisible(robPrompt, info.canRob)
                        PromptSetEnabled(robPrompt, info.canRob)
                        PromptSetVisible(lootPrompt, info.canLoot)
                        PromptSetEnabled(lootPrompt, info.canLoot)
                        PromptSetActiveGroupThisFrame(group, CreateVarString(10, 'LITERAL_STRING', L('escort_rob_group')))
                        if info.canRob and PromptHasHoldModeCompleted(robPrompt) then
                            checked[netId] = nil
                            robbing = true
                            CreateThread(function() doRob(netId) end)
                            break
                        elseif info.canLoot and PromptHasHoldModeCompleted(lootPrompt) then
                            local lootId = info.id
                            CreateThread(function()
                                local r = Law.Cb.Await('escort:openLoot', lootId)
                                Law.Notify(r and r.msg or L('err_failed'))
                            end)
                            Wait(1500)
                            break
                        end
                        Wait(0)
                    end
                    sleep = 0
                end
            end
        end
        Wait(sleep)
    end
end)

--------------------------------------------------------------------------
-- NPC-Hinterhalt
--------------------------------------------------------------------------
local ambush = {}  -- [id] = { peds }

-- Eigene Beziehungsgruppe (N7): die globale Gruppe `bandits` gehoert allen
-- Skripten (vorp_outlaws u.a.) und darf nicht dauerhaft verstellt werden.
local AMBUSH_GROUP_NAME = 'ara_law_ambush'
local ambushGroup = nil

local function getAmbushGroup()
    if ambushGroup then return ambushGroup end
    local ok, _, hash = pcall(AddRelationshipGroup, AMBUSH_GROUP_NAME)  -- ADD_RELATIONSHIP_GROUP (bool, Hash*)
    ambushGroup = (ok and type(hash) == 'number' and hash ~= 0) and hash or joaat(AMBUSH_GROUP_NAME)
    return ambushGroup
end

--- Feindschaft Gruppe <-> Spieler zuruecknehmen, sobald kein Hinterhalt mehr laeuft
local function resetAmbushRelations()
    if not ambushGroup or next(ambush) ~= nil then return end
    if ClearRelationshipBetweenGroups then
        pcall(ClearRelationshipBetweenGroups, 5, ambushGroup, `PLAYER`)
        pcall(ClearRelationshipBetweenGroups, 5, `PLAYER`, ambushGroup)
    else
        SetRelationshipBetweenGroups(3, ambushGroup, `PLAYER`)  -- 3 = neutral
        SetRelationshipBetweenGroups(3, `PLAYER`, ambushGroup)
    end
    if RemoveRelationshipGroup then pcall(RemoveRelationshipGroup, ambushGroup) end
    ambushGroup = nil
end

function EC.CleanupAmbush(id, fast)
    local list = ambush[id]
    ambush[id] = nil
    if not list then return end
    for _, ped in ipairs(list) do
        if DoesEntityExist(ped) then
            if not fast then Law.Util.RequestControl(ped, 500) end
            Law.Util.DeleteEntity(ped)
        end
    end
    resetAmbushRelations()
end

local function spawnAmbush(d)
    local models = type(d.models) == 'table' and d.models or {}
    local weapons = type(d.weapons) == 'table' and d.weapons or {}
    if #models == 0 then return end
    local me = PlayerPedId()
    local list = {}
    local group = getAmbushGroup()
    RequestCollisionAtCoord(d.x + 0.0, d.y + 0.0, d.z + 0.0)
    for _ = 1, math.min(tonumber(d.count) or 3, 10) do
        local model = models[math.random(#models)]
        if Law.Util.LoadModel(model, 5000) then
            local ang = math.random() * math.pi * 2
            local r = 3.0 + math.random() * (tonumber(d.spread) or 15.0)
            local x, y, z = d.x + math.cos(ang) * r, d.y + math.sin(ang) * r, d.z + 0.0
            local found, gz = GetGroundZFor_3dCoord(x, y, z + 50.0, false)
            if found then z = gz end
            local hash = joaat(model)
            local ped = CreatePed(hash, x, y, z, 0.0, true, false, false, false)
            SetModelAsNoLongerNeeded(hash)
            if ped and ped ~= 0 then
                Citizen.InvokeNative(0x283978A15512B2FE, ped, true)  -- SetRandomOutfitVariation (sonst unsichtbar)
                SetEntityAsMissionEntity(ped, true, true)
                SetPedRelationshipGroupHash(ped, group)
                if #weapons > 0 then
                    GiveWeaponToPed(ped, joaat(weapons[math.random(#weapons)]), 60, true, true, 0, false, 0.5, 1.0, 0, false, 0.0, false)
                end
                TaskCombatPed(ped, me, 0, 16)
                list[#list + 1] = ped
            end
        end
    end
    -- Banditen und Spieler sind Feinde (5 = hate, wie vorp_outlaws)
    SetRelationshipBetweenGroups(5, group, `PLAYER`)
    SetRelationshipBetweenGroups(5, `PLAYER`, group)
    ambush[d.id] = list
    Law.Notify(L('escort_ambush_warning'), 'objective', 6000)
    SetTimeout((tonumber(d.despawn) or 900) * 1000, function()
        if ambush[d.id] == list then EC.CleanupAmbush(d.id) end
    end)
end

Law.On('escort:ambush', function(d)
    if type(d) ~= 'table' or not d.id or not d.x then return end
    if ambush[d.id] then return end
    CreateThread(function() spawnAmbush(d) end)
end)

Law.Modules.Register('escort_incidents', {
    onStop = function()
        for id in pairs(ambush) do EC.CleanupAmbush(id, true) end
        if robPrompt then PromptDelete(robPrompt) end
        if lootPrompt then PromptDelete(lootPrompt) end
        robPrompt, lootPrompt = nil, nil
        Law.UI.Hud('robbery', nil)
    end,
})
