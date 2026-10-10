--[[
    ArA-LawSystem - Client-Helfer

    Natives ohne Namen werden per Hash aufgerufen - jeder Hash steht mit
    Zweck im Kommentar.
]]

Law.Util = Law.Util or {}

function Law.Notify(text, kind, ms)
    ms = ms or 5000
    if kind == 'objective' then
        Law.VORP.NotifyObjective(text, ms)
    else
        Law.VORP.NotifyRightTip(text, ms)
    end
end

--------------------------------------------------------------------------
-- Spieler in der Naehe
--------------------------------------------------------------------------
--- Name eines anderen Spielers aus dem vorp-Statebag "Character" (nur Anzeige)
function Law.Util.PlayerName(serverId)
    local st = Player(serverId).state
    local c = st and st.Character
    if type(c) == 'table' and c.FirstName then
        return ((c.FirstName or '') .. ' ' .. (c.LastName or '')):gsub('^%s+', ''):gsub('%s+$', '')
    end
    return ('#%d'):format(serverId)
end

function Law.Util.GetPlayersInRange(maxDist)
    local me = PlayerPedId()
    local myPos = GetEntityCoords(me)
    local out = {}
    for _, pid in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(pid)
        if ped ~= me and DoesEntityExist(ped) then
            local d = #(GetEntityCoords(ped) - myPos)
            if d <= maxDist then
                local sid = GetPlayerServerId(pid)
                out[#out + 1] = { serverId = sid, ped = ped, dist = d, name = Law.Util.PlayerName(sid) }
            end
        end
    end
    table.sort(out, function(a, b) return a.dist < b.dist end)
    return out
end

function Law.Util.GetClosestPlayer(maxDist)
    local list = Law.Util.GetPlayersInRange(maxDist or 3.0)
    local first = list[1]
    if not first then return nil end
    return first.serverId, first.ped, first.dist
end

--------------------------------------------------------------------------
-- Modelle / Animationen
--------------------------------------------------------------------------
function Law.Util.LoadModel(model, timeoutMs)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelValid(hash) then return false end
    RequestModel(hash, false)
    local t = GetGameTimer() + (timeoutMs or 5000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > t then return false end
        Wait(10)
    end
    return true
end

function Law.Util.LoadAnimDict(dict, timeoutMs)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + (timeoutMs or 3000)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > t then return false end
        Wait(10)
    end
    return true
end

function Law.Util.PlayAnim(ped, dict, anim, flag, durationMs)
    if not Law.Util.LoadAnimDict(dict) then return false end
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, durationMs or -1, flag or 0, 0.0, false, false, false)
    return true
end

--------------------------------------------------------------------------
-- Blips
--------------------------------------------------------------------------
--- style/sprite/color als Namen (werden gehasht)
function Law.Util.AddBlip(coords, sprite, name, color, style)
    coords = Law.Vec(coords)
    if not coords then return nil end
    local blip = BlipAddForCoords(joaat(style or 'BLIP_STYLE_FRIENDLY_ON_RADAR'), coords.x, coords.y, coords.z)
    if sprite then SetBlipSprite(blip, type(sprite) == 'number' and sprite or joaat(sprite), true) end
    if color then BlipAddModifier(blip, joaat(color)) end
    if name then SetBlipName(blip, name) end
    return blip
end

function Law.Util.RemoveBlip(blip)
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
end

--- GPS-Route zum Ziel (gleiches Muster wie vorp_police). Loescht sich
--- selbst, sobald man < 15 m am Ziel ist oder eine neue Route gesetzt wird.
local routeToken = 0

function Law.Util.SetWaypoint(coords)
    coords = Law.Vec(coords)
    if not coords then return end
    routeToken = routeToken + 1
    local token = routeToken
    ClearGpsMultiRoute()
    StartGpsMultiRoute(joaat('COLOR_RED'), true, true)
    AddPointToGpsMultiRoute(coords.x, coords.y, coords.z, false)
    SetGpsMultiRouteRender(true)
    CreateThread(function()
        while token == routeToken do
            Wait(1000)
            if #(GetEntityCoords(PlayerPedId()) - coords) < 15.0 then
                if token == routeToken then ClearGpsMultiRoute() end
                return
            end
        end
    end)
end

function Law.Util.ClearWaypoint()
    routeToken = routeToken + 1
    ClearGpsMultiRoute()
end

--------------------------------------------------------------------------
-- Fortschritt (vorp_progressbar, falls vorhanden)
--------------------------------------------------------------------------
function Law.Util.Progress(text, ms)
    if GetResourceState('vorp_progressbar') == 'started' then
        local p = promise.new()
        local ok = pcall(function()
            exports.vorp_progressbar:initiate().start(text, ms, function() p:resolve(true) end, 'linear', nil, nil, false)
        end)
        if ok then
            -- Sicherheitsnetz, falls die Leiste nie fertig meldet
            SetTimeout(ms + 3000, function() p:resolve(true) end)
            return Citizen.Await(p)
        end
    end
    Wait(ms)
    return true
end

--------------------------------------------------------------------------
-- Entities
--------------------------------------------------------------------------
function Law.Util.NetToEnt(netId, timeoutMs)
    netId = tonumber(netId)
    if not netId then return 0 end
    local t = GetGameTimer() + (timeoutMs or 2000)
    while not NetworkDoesNetworkIdExist(netId) do
        if GetGameTimer() > t then return 0 end
        Wait(50)
    end
    return NetworkGetEntityFromNetworkId(netId)
end

function Law.Util.DeleteEntity(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    SetEntityAsMissionEntity(ent, true, true)
    DeleteEntity(ent)
end

--- Kontrolle ueber ein vernetztes Entity holen (fuer Loeschen/Bewegen)
function Law.Util.RequestControl(ent, timeoutMs)
    if not ent or ent == 0 then return false end
    local t = GetGameTimer() + (timeoutMs or 1500)
    NetworkRequestControlOfEntity(ent)
    while not NetworkHasControlOfEntity(ent) do
        if GetGameTimer() > t then return false end
        NetworkRequestControlOfEntity(ent)
        Wait(20)
    end
    return true
end
