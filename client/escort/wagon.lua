--[[
    ArA-LawSystem - Eskorte: Panzerwagen (Client)

    Der Leiter spawnt den Wagen am Abholbuero (Server hat freigegeben) und
    meldet die NetId (escort:wagonSpawned), sobald der Wagen vernetzt ist.
    Der Server prueft Besitzer, Modell, Ort und dass die NetId keinem anderen
    Auftrag gehoert. Lehnt er ab (escort:wagonRejected), entfernt DIESER
    Client seinen lokal erzeugten Wagen selbst - der Server loescht nie ein
    Entity aufgrund einer Client-NetId.
    Nur Begleiter bekommen die NetId (escort:wagon) fuer einen Blip am Wagen;
    Unbeteiligte erfahren die Position nie.
]]

Law.Escort = Law.Escort or {}
local EC = Law.Escort

local wagonBlips = {}   -- [id] = blip
local pending = {}      -- [id] = { veh, netId } gemeldet, noch nicht bestaetigt
local spawning = {}     -- [id] = true (kein Doppel-Wagen bei Doppelklick)

local function deleteLocal(veh)
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        Law.Util.RequestControl(veh, 1000)
        Law.Util.DeleteEntity(veh)
    end
end

function EC.SpawnWagon(id, model, s)
    if spawning[id] or pending[id] then return end
    if type(s) ~= 'table' then return Law.Notify(L('escort_wagon_failed')) end
    spawning[id] = true
    if not Law.Util.LoadModel(model, 10000) then
        spawning[id] = nil
        return Law.Notify(L('escort_wagon_failed'))
    end
    local hash = joaat(model)
    local veh = CreateVehicle(hash, s.x + 0.0, s.y + 0.0, s.z + 0.0, (s.w or 0.0) + 0.0, true, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not veh or veh == 0 then
        spawning[id] = nil
        return Law.Notify(L('escort_wagon_failed'))
    end
    Citizen.InvokeNative(0x7263332501E07F52, veh, true)  -- SetVehicleOnGroundProperly
    SetEntityAsMissionEntity(veh, true, true)
    -- Erst melden, wenn der Wagen vernetzt ist - sonst kennt der Server die NetId noch nicht (H3)
    local t = GetGameTimer() + 3000
    while not NetworkGetEntityIsNetworked(veh) and GetGameTimer() < t do Wait(50) end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    SetNetworkIdExistsOnAllMachines(netId, true)
    pending[id] = { veh = veh, netId = netId }
    spawning[id] = nil
    Wait(250)
    Law.Net.Send('escort:wagonSpawned', id, netId)
    -- Keine Antwort (Server-Neustart o.ae.): lokalen Wagen nicht ewig stehen lassen
    SetTimeout(20000, function()
        local p = pending[id]
        if p and p.veh == veh then
            pending[id] = nil
            deleteLocal(veh)
        end
    end)
end

function EC.RemoveWagonBlip(id)
    local b = wagonBlips[id]
    wagonBlips[id] = nil
    if b and DoesBlipExist(b) then RemoveBlip(b) end
end

-- Server hat den Wagen NICHT angenommen: nur den eigenen, lokal erzeugten Wagen entfernen
Law.On('escort:wagonRejected', function(id, netId)
    local p = pending[id]
    pending[id] = nil
    spawning[id] = nil
    if p and p.netId == netId then
        deleteLocal(p.veh)
    end
    Law.Notify(L('escort_wagon_rejected'))
end)

-- Wagen angenommen (bzw. Begleiter bekommt die NetId): Blip am Wagen
Law.On('escort:wagon', function(id, netId)
    local p = pending[id]
    if p and p.netId == netId then
        pending[id] = nil
        Law.Notify(L('escort_wagon_ready'))  -- nur beim Leiter, der ihn gespawnt hat
    end
    CreateThread(function()
        local ent = Law.Util.NetToEnt(netId, 5000)
        if not ent or ent == 0 then return end
        EC.RemoveWagonBlip(id)
        local blip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, joaat('BLIP_STYLE_FRIENDLY_ON_RADAR'), ent)  -- BlipAddForEntity
        if blip and blip ~= 0 then
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, L('escort_wagon_blip', id))  -- Blip-Name setzen
            wagonBlips[id] = blip
        end
    end)
end)

Law.Modules.Register('escort_wagon', {
    onStop = function()
        for id in pairs(wagonBlips) do EC.RemoveWagonBlip(id) end
        for _, p in pairs(pending) do
            if p.veh and DoesEntityExist(p.veh) then Law.Util.DeleteEntity(p.veh) end
        end
        pending, spawning = {}, {}
    end,
})
