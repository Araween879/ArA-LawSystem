--[[
    ArA-LawSystem - NPC-Einsaetze (Client, Agent A)

    NPC-Kopfgeld: Server schickt Auftrag + Zielgebiet (npc:contract). Ziel und
    Bande erscheinen erst, wenn man naeher als spawnDistance ist (vernetzte
    Peds), NetIds gehen an den Server (npc:spawned). Abliefern ueber den
    dropoff-Punkt (client/justice/bounty.lua).
    NPC-Streife: der erste Annehmende spawnt die NPCs (npc:callSpawn) und
    meldet sie (npc:callSpawned). Abschluss prueft der Server.

    Aufraeumen: Server loescht die Entities, der Client zusaetzlich seine
    eigenen (Blips, Peds) bei npc:cleanup / npc:callCleanup / onStop.
]]

Law.Justice = Law.Justice or {}
Law.Justice.npcContract = nil

local yes = function(v) return v == true or v == 1 end

local contract = nil                       -- Daten vom Server
local spawned = { target = nil, gang = {} }
local blips = {}
local calls = {}                           -- [callId] = { active, peds = {} }

--------------------------------------------------------------------------
-- Helfer
--------------------------------------------------------------------------
local function groundZ(x, y, z)
    RequestCollisionAtCoord(x, y, z)
    local found, gz = GetGroundZFor_3dCoord(x, y, z + 50.0, false)
    if yes(found) and type(gz) == 'number' and gz ~= 0.0 then return gz end
    return z
end

local function randomAround(center, radius)
    local ang = math.random() * math.pi * 2
    local r = math.random() * radius
    local x, y = center.x + math.cos(ang) * r, center.y + math.sin(ang) * r
    return vector3(x, y, groundZ(x, y, center.z))
end

local function spawnPed(model, pos, weapons)
    if not Law.Util.LoadModel(model, 8000) then
        Law.Warn('NPC-Modell %s nicht ladbar', tostring(model))
        return nil
    end
    local hash = joaat(model)
    local ped = CreatePed(hash, pos.x, pos.y, pos.z, math.random(0, 359) + 0.0, true, true, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return nil end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SetRandomOutfitVariation (sonst unsichtbar)
    SetEntityAsMissionEntity(ped, true, true)
    local netId = NetworkGetNetworkIdFromEntity(ped)
    SetNetworkIdExistsOnAllMachines(netId, true)
    if weapons and #weapons > 0 then
        local w = weapons[math.random(1, #weapons)]
        -- GiveWeaponToPed (0x5E3BDDBCB83F3D84): ped, hash, ammo, inHand, inHolster, attachPoint, multiCopies, p7, p8, addReason, ignoreUnlocks, degradation, p12
        Citizen.InvokeNative(0x5E3BDDBCB83F3D84, ped, joaat(w), 100, true, true, 0, false, 0.5, 1.0, joaat('ADD_REASON_DEFAULT'), false, 0.0, false)
    end
    return ped
end

local function deletePed(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    if Law.Util.RequestControl(ped, 1000) then Law.Util.DeleteEntity(ped) end
end

--- Feindlich werden, sobald der Spieler nah ist (nicht schon aus 250 m)
local function aggroLoop(peds, isActive)
    CreateThread(function()
        local engaged = {}
        while isActive() do
            local me = PlayerPedId()
            local pos = GetEntityCoords(me)
            local anyAlive = false
            for _, p in ipairs(peds) do
                if DoesEntityExist(p) and not yes(IsEntityDead(p)) then
                    anyAlive = true
                    if not engaged[p] and #(GetEntityCoords(p) - pos) < 80.0 then
                        engaged[p] = true
                        TaskCombatPed(p, me, 0, 16)
                    end
                end
            end
            if not anyAlive then break end
            Wait(1000)
        end
    end)
end

local function removeBlips()
    for k, b in pairs(blips) do
        Law.Util.RemoveBlip(b)
        blips[k] = nil
    end
end

--------------------------------------------------------------------------
-- NPC-Kopfgeld
--------------------------------------------------------------------------
local function cleanupContract(id)
    if id and contract and contract.id ~= id then return end
    contract = nil
    Law.Justice.npcContract = nil
    removeBlips()
    Law.Util.ClearWaypoint()
    local old = spawned
    spawned = { target = nil, gang = {} }
    CreateThread(function()
        deletePed(old.target)
        for _, p in ipairs(old.gang) do deletePed(p) end
    end)
end

local function spawnContract(data, area)
    local weapons = data.weapons or {}
    local target = spawnPed(data.model, randomAround(area, 25.0), weapons)
    if not target then return Law.Notify(L('npc_spawn_failed')) end
    spawned.target = target
    local gangNets, all = {}, { target }
    for _, m in ipairs(data.gang or {}) do
        local p = spawnPed(m, randomAround(area, 30.0), weapons)
        if p then
            spawned.gang[#spawned.gang + 1] = p
            all[#all + 1] = p
            gangNets[#gangNets + 1] = NetworkGetNetworkIdFromEntity(p)
        end
    end
    -- Blip direkt am Gesuchten (BlipAddForEntity 0x23F74C2FDA6E7C61)
    blips.target = Citizen.InvokeNative(0x23F74C2FDA6E7C61, joaat('BLIP_STYLE_ENEMY'), target)
    Law.Net.Send('npc:spawned', data.id, NetworkGetNetworkIdFromEntity(target), gangNets)
    local myId = data.id
    aggroLoop(all, function() return contract ~= nil and contract.id == myId end)
    Law.Notify(L('npc_target_spotted', data.name), 'objective', 6000)
end

local function startContract(data)
    if type(data) ~= 'table' or not data.area then return end
    cleanupContract(nil)
    contract = data
    Law.Justice.npcContract = { id = data.id, name = data.name }
    local area = vector3(data.area.x + 0.0, data.area.y + 0.0, data.area.z + 0.0)
    local bcfg = Config.Npc.Bounties.Blip or {}
    -- Suchkreis (BlipAddForRadius 0x45F13B7E0A15C880)
    blips.area = Citizen.InvokeNative(0x45F13B7E0A15C880, -1282792512, area.x, area.y, area.z, (data.radius or 120.0) + 0.0)
    blips.center = Law.Util.AddBlip(area, bcfg.sprite, L('npc_blip', data.name), bcfg.color)
    Law.Util.SetWaypoint(area)
    Law.Notify(L('npc_contract_started', data.name, data.areaLabel or ''), 'objective', 8000)

    local myId = data.id
    CreateThread(function()
        while contract and contract.id == myId and not spawned.target do
            local d = #(GetEntityCoords(PlayerPedId()) - area)
            if d <= (data.spawnDistance or 250.0) then
                spawnContract(data, area)
                break
            end
            Wait(d > 600.0 and 3000 or 1000)
        end
    end)
end

Law.On('npc:contract', startContract)
Law.On('npc:cleanup', function(id) cleanupContract(tonumber(id)) end)

Law.Interact.Register('npc_abort', {
    label = L('interact_npc_abort'), order = 80, target = false,
    canShow = function() return contract ~= nil end,
    onSelect = function()
        local res = Law.Cb.Await('npc:abort')
        Law.Notify(res and res.msg or L('err_failed'))
    end,
})

Law.Interact.Register('npc_route', {
    label = L('interact_npc_route'), order = 79, target = false,
    canShow = function() return contract ~= nil end,
    onSelect = function()
        if contract and contract.area then Law.Util.SetWaypoint(contract.area) end
    end,
})

--------------------------------------------------------------------------
-- NPC-Streife (Leitstelle)
--------------------------------------------------------------------------
local function cleanupCall(id)
    local c = calls[id]
    if not c then return end
    calls[id] = nil
    c.active = false
    CreateThread(function()
        for _, p in ipairs(c.peds) do deletePed(p) end
    end)
end

local function startCall(data)
    if type(data) ~= 'table' or not data.callId or not data.coords or calls[data.callId] then return end
    local c = { active = true, peds = {} }
    calls[data.callId] = c
    local area = vector3(data.coords.x + 0.0, data.coords.y + 0.0, data.coords.z + 0.0)
    CreateThread(function()
        while c.active do
            local d = #(GetEntityCoords(PlayerPedId()) - area)
            if d <= (data.spawnDistance or 200.0) then break end
            Wait(d > 600.0 and 3000 or 1000)
        end
        if not c.active then return end
        local nets = {}
        for _, m in ipairs(data.models or {}) do
            local p = spawnPed(m, randomAround(area, 20.0), data.weapons or {})
            if p then
                c.peds[#c.peds + 1] = p
                nets[#nets + 1] = NetworkGetNetworkIdFromEntity(p)
            end
        end
        if #nets == 0 then return Law.Notify(L('npc_spawn_failed')) end
        Law.Net.Send('npc:callSpawned', data.callId, nets)
        aggroLoop(c.peds, function() return c.active end)
        Law.Notify(L('npc_call_spotted'), 'objective', 6000)
    end)
end

Law.On('npc:callSpawn', startCall)
Law.On('npc:callCleanup', function(id) cleanupCall(tonumber(id)) end)

--------------------------------------------------------------------------
-- Modul
--------------------------------------------------------------------------
Law.Modules.Register('npc', {
    onStop = function()
        -- ohne Warten: die Ressource stoppt gerade (Server loescht zusaetzlich)
        removeBlips()
        local function drop(p)
            if p and p ~= 0 and DoesEntityExist(p) then
                SetEntityAsMissionEntity(p, true, true)
                DeleteEntity(p)
            end
        end
        drop(spawned.target)
        for _, p in ipairs(spawned.gang) do drop(p) end
        for _, c in pairs(calls) do
            c.active = false
            for _, p in ipairs(c.peds) do drop(p) end
        end
        contract, calls = nil, {}
        spawned = { target = nil, gang = {} }
        Law.Justice.npcContract = nil
    end,
})
