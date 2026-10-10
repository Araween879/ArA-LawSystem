--[[
    ArA-LawSystem - Festnahme (Client, Agent A)

    Gefesselt:  jede Frame Tasten sperren, SetEnableHandcuffs, HUD "cuffed"
    Abfuehren:  Ped haengt am Officer (Server schickt dessen Server-ID)
    Wagen:      einsetzen / herausholen
    Interaktionen (F6): Fesseln, Loesen, Abfuehren, Wagen, Durchsuchen,
                        Akte pruefen, Handschellen knacken

    Alles hier ist Anzeige/Ausfuehrung - entschieden hat vorher der Server.
    Statebags anderer Spieler werden nur gelesen, um Menuepunkte zu zeigen.
]]

Law.Justice = Law.Justice or {}

--------------------------------------------------------------------------
-- Gemeinsame Client-Helfer der Justiz-Dateien
--------------------------------------------------------------------------
--- RedM liefert BOOL-Natives je nach Deklaration als true/false oder 1/0
local function yes(v) return v == true or v == 1 end
Law.Justice.Yes = yes

function Law.Justice.PedOf(serverId)
    serverId = tonumber(serverId)
    if not serverId then return 0 end
    local pid = GetPlayerFromServerId(serverId)
    if not pid or pid == -1 then return 0 end
    return GetPlayerPed(pid)
end

function Law.Justice.StateOf(serverId, key)
    local p = serverId and Player(serverId)
    local st = p and p.state
    return st and st[key] or nil
end

function Law.Justice.PlayOfficerAnim()
    local a = Config.Arrest.Anim
    if a and a.dict then Law.Util.PlayAnim(PlayerPedId(), a.dict, a.name, 0, a.ms or 2500) end
end

--- Nach einer Menue-Auswahl kurz warten: die NUI schliesst den leeren
--- Stapel per "close" - ein sofort geoeffnetes Formular wuerde sonst mit
--- geschlossen.
function Law.Justice.AfterMenu()
    Wait(200)
end

--- Bildschirm abdunkeln, teleportieren, Welt laden lassen
function Law.Justice.Teleport(pos)
    if type(pos) ~= 'table' and type(pos) ~= 'vector4' and type(pos) ~= 'vector3' then return end
    DoScreenFadeOut(800)
    local t = GetGameTimer() + 3000
    while not yes(IsScreenFadedOut()) and GetGameTimer() < t do Wait(0) end
    local ped = PlayerPedId()
    if yes(IsPedInAnyVehicle(ped, false)) then ClearPedTasksImmediately(ped) end
    DetachEntity(ped, true, false)
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    SetEntityCoords(ped, pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, false, false, false, false)
    SetEntityHeading(ped, (pos.w or 0.0) + 0.0)
    t = GetGameTimer() + 5000
    while not yes(HasCollisionLoadedAroundEntity(ped)) and GetGameTimer() < t do Wait(0) end
    Wait(1000)
    DoScreenFadeIn(800)
end

--------------------------------------------------------------------------
-- Zustand
--------------------------------------------------------------------------
local cuffed, cuffedBy = false, nil
local escortBy = nil
local controlLoop, escortLoop = false, false

local function startControlLoop()
    if controlLoop then return end
    controlLoop = true
    CreateThread(function()
        local list = Config.Arrest.DisabledControls or {}
        while cuffed do
            for i = 1, #list do DisableControlAction(0, list[i], true) end
            Wait(0)
        end
        controlLoop = false
    end)
end

local function startEscortLoop()
    if escortLoop then return end
    escortLoop = true
    CreateThread(function()
        while escortBy do
            local me = PlayerPedId()
            local officerPed = Law.Justice.PedOf(escortBy)
            if officerPed ~= 0 and officerPed ~= me and DoesEntityExist(officerPed) and not yes(IsPedInAnyVehicle(me, false)) then
                if not yes(IsEntityAttachedToEntity(me, officerPed)) then
                    local o = Config.Arrest.EscortOffset or vector3(0.3, 0.5, 0.0)
                    AttachEntityToEntity(me, officerPed, Config.Arrest.EscortBone or 0, o.x, o.y, o.z, 0.0, 0.0, 0.0,
                        false, false, false, false, 2, true, false, false)
                end
            end
            Wait(500)
        end
        local me = PlayerPedId()
        if yes(IsEntityAttached(me)) then DetachEntity(me, true, false) end
        escortLoop = false
    end)
end

local function setEscort(officerSrc)
    escortBy = tonumber(officerSrc)
    Law.State.escorted = escortBy ~= nil
    if escortBy then
        startEscortLoop()
    else
        local me = PlayerPedId()
        if yes(IsEntityAttached(me)) then DetachEntity(me, true, false) end
    end
end

local function applyCuffed(on, byName)
    local ped = PlayerPedId()
    if on then
        cuffed, cuffedBy = true, byName
        Law.State.cuffed = true
        if Law.UI.IsOpen() then Law.UI.Close() end
        SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true, 0, false, false)
        CuffPed(ped)
        SetEnableHandcuffs(ped, true, false)
        SetPedCanPlayGestureAnims(ped, false)
        DisplayRadar(false)
        Law.UI.Hud('cuffed', { by = byName })
        startControlLoop()
    else
        local was = cuffed
        cuffed, cuffedBy = false, nil
        Law.State.cuffed = false
        setEscort(nil)
        if was then
            UncuffPed(ped)
            SetEnableHandcuffs(ped, false, false)
            SetPedCanPlayGestureAnims(ped, true)
            DisplayRadar(true)
        end
        Law.UI.Hud('cuffed', nil)
    end
end

--------------------------------------------------------------------------
-- Server -> Client
--------------------------------------------------------------------------
Law.On('arrest:setCuffed', function(state, byName)
    applyCuffed(state == true, byName)
    if state == true then
        Law.Notify(byName and L('arrest_cuffed_you_by', byName) or L('arrest_cuffed_you'), 'objective', 6000)
    end
end)

Law.On('arrest:setEscort', function(officerSrc)
    setEscort(officerSrc)
end)

Law.On('arrest:anim', function()
    Law.Justice.PlayOfficerAnim()
end)

Law.On('arrest:putInVehicle', function(netId)
    CreateThread(function()
        setEscort(nil)
        local veh = Law.Util.NetToEnt(netId, 3000)
        if not veh or veh == 0 or not DoesEntityExist(veh) then return end
        local ped = PlayerPedId()
        DetachEntity(ped, true, false)
        Wait(150)
        for _, seat in ipairs(Config.Arrest.VehicleSeats or { 1, 0 }) do
            if yes(IsVehicleSeatFree(veh, seat)) then
                SetPedIntoVehicle(ped, veh, seat)
                return
            end
        end
        Law.Notify(L('arrest_no_seat'))
    end)
end)

Law.On('arrest:takeOut', function(officerSrc)
    CreateThread(function()
        local ped = PlayerPedId()
        if not yes(IsPedInAnyVehicle(ped, false)) then return end
        TaskLeaveAnyVehicle(ped, 0, 0)
        local t = GetGameTimer() + 3000
        while yes(IsPedInAnyVehicle(ped, false)) and GetGameTimer() < t do Wait(100) end
        if yes(IsPedInAnyVehicle(ped, false)) then
            -- gefesselt klappt das Aussteigen nicht immer -> neben den Officer setzen
            local officerPed = Law.Justice.PedOf(officerSrc)
            local c
            if officerPed ~= 0 and DoesEntityExist(officerPed) then
                c = GetOffsetFromEntityInWorldCoords(officerPed, 0.0, 1.0, 0.0)
            else
                c = GetOffsetFromEntityInWorldCoords(ped, 2.5, 0.0, 0.0)
            end
            ClearPedTasksImmediately(ped)
            SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false)
        end
        if cuffed then
            CuffPed(ped)
            SetEnableHandcuffs(ped, true, false)
        end
    end)
end)

-- Tod beendet das Abfuehren sofort (Server bestaetigt ohnehin)
AddEventHandler('vorp_core:Client:OnPlayerDeath', function()
    if escortBy then setEscort(nil) end
end)

--------------------------------------------------------------------------
-- Interaktionen (F6)
--------------------------------------------------------------------------
local function targetCuffed(t)
    return Law.Justice.StateOf(t, 'law_cuffed') == true
end

local function targetInVehicle(t)
    local ped = Law.Justice.PedOf(t)
    return ped ~= 0 and yes(IsPedInAnyVehicle(ped, false))
end

local function canCuffDisplay()
    return Law.HasPerm('cuff') or Law.Justice.hasLicense == true
end

local function canEscortDisplay()
    return Law.HasPerm('escort') or Law.Justice.hasLicense == true
end

local function nearestVehicleNet(maxDist)
    local ok, pool = pcall(GetGamePool, 'CVehicle')
    if not ok or type(pool) ~= 'table' then return 0 end
    local pos = GetEntityCoords(PlayerPedId())
    local best, bestD
    for _, veh in ipairs(pool) do
        if DoesEntityExist(veh) and yes(NetworkGetEntityIsNetworked(veh)) then
            local d = #(GetEntityCoords(veh) - pos)
            if d <= maxDist and (not bestD or d < bestD) then best, bestD = veh, d end
        end
    end
    return best and NetworkGetNetworkIdFromEntity(best) or 0
end

Law.Interact.Register('arrest_cuff', {
    label = L('interact_cuff'), order = 10, target = true,
    canShow = function(t) return not targetCuffed(t) and canCuffDisplay() end,
    onSelect = function(t) Law.Net.Send('arrest:cuff', t) end,
})

Law.Interact.Register('arrest_uncuff', {
    label = L('interact_uncuff'), order = 11, target = true,
    canShow = function(t) return targetCuffed(t) and canCuffDisplay() end,
    onSelect = function(t) Law.Net.Send('arrest:uncuff', t) end,
})

Law.Interact.Register('arrest_escort', {
    label = function(t)
        if Law.Justice.StateOf(t, 'law_escorted') == GetPlayerServerId(PlayerId()) then return L('interact_escort_stop') end
        return L('interact_escort')
    end,
    order = 12, target = true,
    canShow = function(t) return targetCuffed(t) and not targetInVehicle(t) and canEscortDisplay() end,
    onSelect = function(t) Law.Net.Send('arrest:escort', t) end,
})

Law.Interact.Register('arrest_vehicle_in', {
    label = L('interact_vehicle_in'), order = 13, target = true,
    canShow = function(t) return targetCuffed(t) and not targetInVehicle(t) and canEscortDisplay() end,
    onSelect = function(t)
        Law.Net.Send('arrest:putInVehicle', t, nearestVehicleNet((Config.Arrest.VehicleDistance or 6.0) + 2.0))
    end,
})

Law.Interact.Register('arrest_vehicle_out', {
    label = L('interact_vehicle_out'), order = 14, target = true,
    canShow = function(t) return targetCuffed(t) and targetInVehicle(t) and canEscortDisplay() end,
    onSelect = function(t) Law.Net.Send('arrest:takeOutVehicle', t) end,
})

Law.Interact.Register('arrest_search', {
    label = L('interact_search'), order = 20, target = true, perm = 'search',
    canShow = function(t)
        if not Config.Arrest.SearchRequiresCuffs or targetCuffed(t) then return true end
        local ped = Law.Justice.PedOf(t)
        return ped ~= 0 and yes(IsEntityDead(ped))
    end,
    onSelect = function(t) Law.Net.Send('arrest:search', t) end,
})

Law.Interact.Register('arrest_idcheck', {
    label = L('interact_idcheck'), order = 21, target = true, perm = 'idcheck',
    onSelect = function(t)
        local res = Law.Cb.Await('arrest:idcheck', t)
        if not res or not res.ok then return Law.Notify(res and res.msg or L('err_failed')) end
        if res.data.full then
            Law.Justice.AfterMenu()
            Law.OpenLedger('people', res.data.charId)
        else
            Law.Notify(L('arrest_idcheck_result', res.data.name or '?',
                res.data.wanted and L('arrest_idcheck_wanted') or L('arrest_idcheck_clean')), 'objective', 8000)
        end
    end,
})

Law.Interact.Register('arrest_lockpick', {
    label = L('interact_lockpick'), order = 30, target = true,
    canShow = function(t) return targetCuffed(t) and not Law.State.cuffed and not Law.State.jailed end,
    onSelect = function(t)
        local res = Law.Cb.Await('arrest:lockpickStart', t)
        if not res or not res.ok then return Law.Notify(res and res.msg or L('err_failed')) end
        local ped = PlayerPedId()
        local a = Config.Arrest.Anim
        if a and a.dict and Law.Util.LoadAnimDict(a.dict) then
            TaskPlayAnim(ped, a.dict, a.name, 8.0, -8.0, -1, 1, 0.0, false, false, false)
        end
        Law.Util.Progress(L('arrest_lockpick_progress'), ((res.data and res.data.seconds) or 8) * 1000)
        ClearPedTasks(ped)
        local fin = Law.Cb.Await('arrest:lockpickFinish')
        Law.Notify(fin and fin.msg or L('err_failed'))
    end,
})

--------------------------------------------------------------------------
-- Modul
--------------------------------------------------------------------------
Law.Modules.Register('arrest', {
    onSync = function()
        -- core:sync setzt Law.State.cuffed - Natives angleichen
        if Law.State.cuffed and not cuffed then
            applyCuffed(true, cuffedBy)
        elseif not Law.State.cuffed and cuffed then
            applyCuffed(false)
        end
    end,
    onStop = function()
        local ped = PlayerPedId()
        local was = cuffed
        cuffed, escortBy = false, nil
        if yes(IsEntityAttached(ped)) then DetachEntity(ped, true, false) end
        if was then
            UncuffPed(ped)
            SetEnableHandcuffs(ped, false, false)
            SetPedCanPlayGestureAnims(ped, true)
            DisplayRadar(true)
        end
        Law.UI.Hud('cuffed', nil)
    end,
})
