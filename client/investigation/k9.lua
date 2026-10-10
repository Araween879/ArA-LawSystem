--[[
    ArA-LawSystem - Bluthund (Client)

    Der Client spawnt den Hund erst nach Freigabe durch den Server und meldet
    die NetId (k9:spawned). Die Spur kommt stueckweise vom Server: der Hund
    laeuft Punkt fuer Punkt, am Stueckende fragt der Client nach dem naechsten
    (scent:next) - der Server prueft dabei die ECHTE Hunde-Position.
    Entfernt sich der Hundefuehrer zu weit, wartet der Hund.
]]

local KCfg = Config.K9

local K9 = {
    ped = nil, netId = nil, blip = nil,
    state = 'idle', strength = nil,
    session = nil,   -- { id, points, idx, strength }
}

local function dogAlive()
    return K9.ped ~= nil and DoesEntityExist(K9.ped) and not IsEntityDead(K9.ped)
end

local function setHud(state, strength, text)
    K9.state = state
    K9.strength = strength
    if not K9.ped then return Law.UI.Hud('k9', nil) end
    Law.UI.Hud('k9', { state = state, strength = strength, text = text or L('k9_state_' .. state) })
end

local function scenario(name, ms)
    if not dogAlive() then return end
    ClearPedTasks(K9.ped)
    TaskStartScenarioInPlace(K9.ped, joaat(name), ms or -1, true, false, false, false)
end

local function follow()
    if not dogAlive() then return end
    ClearPedTasks(K9.ped)
    TaskFollowToOffsetOfEntity(K9.ped, PlayerPedId(), 0.0, -1.5, 0.0, 1.5, -1, 2.0, true, true, false, false, false)
    setHud('following')
end

local function stay()
    scenario('WORLD_ANIMAL_DOG_SITTING', -1)
    setHud('staying')
end

local function deleteDog()
    K9.session = nil
    if K9.blip and DoesBlipExist(K9.blip) then RemoveBlip(K9.blip) end
    K9.blip = nil
    local ped = K9.ped
    K9.ped, K9.netId = nil, nil
    Law.UI.Hud('k9', nil)
    if ped then Law.Util.DeleteEntity(ped) end
end

--------------------------------------------------------------------------
-- Spawn
--------------------------------------------------------------------------
local function spawnDog(model, spawn)
    if K9.ped or K9.spawning then return end
    K9.spawning = true
    if not Law.Util.LoadModel(model, 8000) then
        K9.spawning = false
        return Law.Notify(L('k9_model_failed'))
    end
    local hash = joaat(model)
    local me = PlayerPedId()
    local x, y, z, h
    if spawn and spawn.exact then
        -- eigener Spawn-Punkt am Zwinger (config/stations/<stadt>.lua -> kennel.spawn)
        x, y, z, h = spawn.x, spawn.y, spawn.z, spawn.w or 0.0
    elseif spawn then
        x, y, z, h = spawn.x + 1.5, spawn.y + 1.5, spawn.z, spawn.w or 0.0
    else
        -- Pfeife: hinter dem Hundefuehrer
        local off = GetOffsetFromEntityInWorldCoords(me, 0.0, -6.0, 0.0)
        x, y, z, h = off.x, off.y, off.z, GetEntityHeading(me)
        local found, gz = GetGroundZFor_3dCoord(x, y, z + 5.0, false)
        if found then z = gz end
    end
    local ped = CreatePed(hash, x, y, z, h, true, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then
        K9.spawning = false
        return Law.Notify(L('k9_model_failed'))
    end

    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)  -- SetRandomOutfitVariation (sonst unsichtbar)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)           -- flieht nicht bei Schuessen
    SetPedAsGroupMember(ped, GetPedGroupIndex(me))       -- Begleiter des Hundefuehrers
    if KCfg.Invincible then SetEntityInvincible(ped, true) end

    -- Erst melden, wenn der Hund vernetzt ist - sonst kennt der Server die NetId noch nicht (H3)
    local t = GetGameTimer() + 3000
    while not NetworkGetEntityIsNetworked(ped) and GetGameTimer() < t do Wait(50) end
    local netId = NetworkGetNetworkIdFromEntity(ped)
    SetNetworkIdExistsOnAllMachines(netId, true)
    K9.ped, K9.netId = ped, netId
    K9.spawning = false
    if KCfg.Blip then
        K9.blip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, -1749618580, ped)  -- BlipAddForEntity (Begleiter-Blip)
    end
    follow()
    Wait(250)
    Law.Net.Send('k9:spawned', netId)
    Law.Notify(L('k9_arrived'))
end

Law.On('k9:spawn', function(data)
    if type(data) ~= 'table' then return end
    CreateThread(function() spawnDog(data.model or KCfg.Model, nil) end)
end)

-- Server hat den Hund entfernt ODER beim Spawn abgelehnt: lokal aufraeumen und
-- Zustand zuruecksetzen (kein "Geister-Hund", der nur auf diesem Client lebt)
Law.On('k9:removed', function(reason)
    K9.spawning = false
    deleteDog()
    if reason == 'lost' then Law.Notify(L('k9_lost_dog'))
    elseif reason == 'duty' then Law.Notify(L('k9_duty_end'))
    elseif reason == 'rejected' then Law.Notify(L('k9_rejected')) end
end)

Law.On('k9:sessionEnded', function(reason)
    if not K9.session then return end
    K9.session = nil
    setHud('lost', nil, L('k9_track_ended'))
    Law.Notify(L('k9_track_ended'))
    SetTimeout(4000, function()
        if not K9.session and dogAlive() then follow() end
    end)
end)

Law.Stations.RegisterPoint('kennel', {
    perm = 'k9', duty = true,
    label = function() return K9.ped and L('k9_prompt_return') or L('k9_prompt_get') end,
    canShow = function() return KCfg.FromKennel end,
    onUse = function()
        if K9.ped then return Law.Net.Send('k9:dismiss') end
        local res = Law.Cb.Await('k9:request')
        if not res or not res.ok then return Law.Notify(res and res.msg or L('err_failed')) end
        spawnDog(res.data.model, res.data.spawn)
    end,
})

-- Tod / Verschwinden des Hundes
CreateThread(function()
    while true do
        Wait(1000)
        local ped = K9.ped
        if ped then
            if not DoesEntityExist(ped) then
                K9.ped = nil
                deleteDog()
                Law.Net.Send('k9:dismiss', true)
                Law.Notify(L('k9_lost_dog'))
            elseif IsEntityDead(ped) then
                K9.session = nil
                if K9.blip and DoesBlipExist(K9.blip) then RemoveBlip(K9.blip) end
                K9.blip = nil
                K9.ped, K9.netId = nil, nil
                Law.UI.Hud('k9', nil)
                Law.Net.Send('k9:died')
                Law.Notify(L('k9_died'))
                SetTimeout(15000, function() Law.Util.DeleteEntity(ped) end)
            end
        end
    end
end)

--------------------------------------------------------------------------
-- Spurverfolgung
--------------------------------------------------------------------------
local function toVec(p) return vector3((tonumber(p.x) or 0) + 0.0, (tonumber(p.y) or 0) + 0.0, (tonumber(p.z) or 0) + 0.0) end

local function finishFound(serverId)
    local player = serverId and GetPlayerFromServerId(serverId) or -1
    local targetPed = player ~= -1 and GetPlayerPed(player) or 0
    if targetPed ~= 0 and dogAlive() then
        ClearPedTasks(K9.ped)
        TaskGoToEntity(K9.ped, targetPed, 5000, 2.0, 2.0, 0, 0)
        Wait(2000)
    end
    scenario('WORLD_ANIMAL_DOG_BARKING_GROUND', 10000)
    setHud('found', 'fresh', L('k9_found'))
    Law.Notify(L('k9_found'), 'objective', 6000)
end

local function finishLost(reason)
    scenario('WORLD_ANIMAL_DOG_HOWLING_SITTING', 5000)
    local text = reason == 'timeout' and L('k9_track_timeout') or L('k9_track_lost')
    setHud('lost', nil, text)
    Law.Notify(text)
end

local function trackLoop(s)
    setHud('tracking', s.strength)
    local lastTask, waitingHandler = 0, false
    local reach = KCfg.PointReach or 3.0
    while K9.session == s do
        if not dogAlive() then break end
        local dogPos = GetEntityCoords(K9.ped)
        local handlerDist = #(GetEntityCoords(PlayerPedId()) - dogPos)

        if handlerDist > (KCfg.HandlerMaxDistance or 60.0) then
            -- Hundefuehrer zu weit weg: Hund wartet
            if not waitingHandler then
                waitingHandler = true
                scenario('WORLD_ANIMAL_DOG_SITTING', -1)
                setHud('waiting', s.strength)
            end
            Wait(500)
        else
            if waitingHandler then
                waitingHandler = false
                lastTask = 0
                ClearPedTasks(K9.ped)
                setHud('tracking', s.strength)
            end
            local p = s.points[s.idx]
            if p then
                local target = toVec(p)
                if #(dogPos - target) <= reach then
                    s.idx = s.idx + 1
                    lastTask = 0
                elseif GetGameTimer() - lastTask > 3000 then
                    lastTask = GetGameTimer()
                    -- Hundefuehrer weit hinten -> langsamer
                    local speed = handlerDist > (KCfg.HandlerMaxDistance or 60.0) * 0.6 and KCfg.Speed.walk or KCfg.Speed.run
                    TaskGoToCoordAnyMeans(K9.ped, target.x, target.y, target.z, speed, 0, false, 0, 0.5)
                end
                Wait(250)
            else
                -- Stueckende: Server prueft, ob der Hund wirklich hier ist
                local res = Law.Cb.Await('scent:next', s.id)
                if K9.session ~= s then break end
                if res and res.ok then
                    local d = res.data or {}
                    if d.found then
                        K9.session = nil
                        finishFound(d.serverId)
                        break
                    elseif d.lost then
                        K9.session = nil
                        finishLost(d.reason)
                        break
                    elseif d.wait then
                        scenario('WORLD_ANIMAL_DOG_SNIFFING_GROUND', 3000)
                        setHud('sniffing', d.strength or s.strength)
                        Wait(3000)
                        lastTask = 0
                    elseif d.points and #d.points > 0 then
                        s.points, s.idx = d.points, 1
                        s.strength = d.strength or s.strength
                        setHud('tracking', s.strength)
                        lastTask = 0
                    else
                        Wait(1500)
                    end
                else
                    local err = res and res.err
                    if err == 'scent_too_fast' or err == 'rate_limited' or err == 'timeout' or err == 'k9_handler_far' then
                        Wait(1500)
                    elseif err == 'scent_not_there' then
                        -- Zurueck zum letzten Punkt und erneut fragen
                        s.idx = math.max(1, #s.points)
                        lastTask = 0
                        Wait(1000)
                    else
                        K9.session = nil
                        Law.Notify(res and res.msg or L('err_failed'))
                        setHud('lost', nil, L('k9_track_lost'))
                        break
                    end
                end
            end
        end
    end
    Wait(6000)
    if not K9.session and dogAlive() then follow() end
end

local function chooseScent()
    local res = Law.Cb.Await('k9:scentItems')
    if not res or not res.ok then return Law.Notify(res and res.msg or L('err_failed')) end
    local items = {}
    for _, it in ipairs(res.data or {}) do
        local uses = tonumber(it.uses) or 0   -- -1 = unbegrenzt (Kleidung)
        local badge = (it.faded and L('k9_scent_faded')) or (uses < 0 and L('k9_scent_unlimited')) or L('k9_scent_uses', uses)
        items[#items + 1] = {
            id = it.id, label = L('k9_scent_item', it.typeLabel, it.evidenceId), desc = it.description,
            badge = badge, disabled = it.faded == true or uses == 0,
        }
    end
    if #items == 0 then return Law.Notify(L('k9_scent_none_items')) end
    local choice = Law.UI.Menu({ title = L('k9_scent_title'), subtitle = L('k9_scent_subtitle'), items = items })
    if not choice or not dogAlive() then return end

    -- Hund schnueffelt am Geruchstraeger
    scenario('WORLD_ANIMAL_DOG_SNIFFING_GROUND', 4000)
    setHud('sniffing')
    Wait(3500)
    local r = Law.Cb.Await('scent:start', choice)
    if not r or not r.ok then
        if r and r.err == 'scent_none' then
            -- Kein Geruch im Umkreis: Hund winselt
            scenario('WORLD_ANIMAL_DOG_HOWLING_SITTING', 4000)
            setHud('lost', nil, L('err_scent_none'))
        end
        Law.Notify(r and r.msg or L('err_failed'))
        SetTimeout(4000, function() if not K9.session and dogAlive() then follow() end end)
        return
    end
    local d = r.data or {}
    local s = { id = d.sessionId, points = d.points or {}, idx = 1, strength = d.strength }
    K9.session = s
    Law.Notify(L('k9_track_started'))
    CreateThread(function() trackLoop(s) end)
end

local function search()
    if not dogAlive() then return end
    setHud('searching')
    scenario('WORLD_ANIMAL_DOG_SNIFFING_GROUND', 3000)
    Wait(3000)
    local res = Law.Cb.Await('k9:search')
    if not dogAlive() then return end
    if not res or not res.ok then
        Law.Notify(res and res.msg or L('err_failed'))
        return follow()
    end
    local d = res.data or {}
    if not d.found then
        Law.Notify(L('k9_search_nothing'))
        return follow()
    end
    local player = GetPlayerFromServerId(d.serverId or -1)
    local targetPed = player ~= -1 and GetPlayerPed(player) or 0
    ClearPedTasks(K9.ped)
    if targetPed ~= 0 then
        TaskGoToEntity(K9.ped, targetPed, 20000, 2.0, 2.0, 0, 0)
    elseif d.coords then
        local c = toVec(d.coords)
        TaskGoToCoordAnyMeans(K9.ped, c.x, c.y, c.z, KCfg.Speed.run, 0, false, 0, 0.5)
    end
    local untilT = GetGameTimer() + 20000
    while dogAlive() and GetGameTimer() < untilT do
        local goal = targetPed ~= 0 and GetEntityCoords(targetPed) or (d.coords and toVec(d.coords))
        if not goal or #(GetEntityCoords(K9.ped) - goal) <= 3.0 then break end
        Wait(250)
    end
    scenario('WORLD_ANIMAL_DOG_BARKING_GROUND', 8000)
    setHud('found', nil, L('k9_search_found'))
    Law.Notify(L('k9_search_found'))
    Wait(8000)
    if not K9.session and dogAlive() then follow() end
end

--------------------------------------------------------------------------
-- Hunde-Menue: eigene Taste (Config.Keys.K9Menu, Standard F12) oder /hund
-- (nicht mehr im F6-Interaktionsmenue)
--------------------------------------------------------------------------
local function hasDog() return dogAlive() end

-- Reihenfolge = Reihenfolge im Menue. show() entscheidet, ob der Eintrag erscheint.
local DOG_COMMANDS = {
    { id = 'follow', label = 'k9_cmd_follow',
      show = function() return hasDog() and K9.session == nil end,
      run = function() follow() end },
    { id = 'stay', label = 'k9_cmd_stay',
      show = function() return hasDog() and K9.session == nil end,
      run = function() stay() end },
    { id = 'search', label = 'k9_cmd_search', desc = 'k9_cmd_search_desc',
      show = function() return hasDog() and K9.session == nil end,
      run = function() search() end },
    { id = 'scent', label = 'k9_cmd_scent', desc = 'k9_cmd_scent_desc',
      show = function() return hasDog() and K9.session == nil end,
      run = function() chooseScent() end },
    { id = 'stop', label = 'k9_cmd_stop',
      show = function() return hasDog() and K9.session ~= nil end,
      run = function()
          local s = K9.session
          K9.session = nil
          if s then Law.Net.Send('scent:stop', s.id) end
          follow()
      end },
    { id = 'attack', label = 'k9_cmd_attack', target = true,
      show = function(targetSrc) return KCfg.AllowAttack and hasDog() and targetSrc ~= nil end,
      run = function(targetSrc)
          local res = Law.Cb.Await('k9:attack', targetSrc)
          if not res or not res.ok then return Law.Notify(res and res.msg or L('err_failed')) end
          local player = GetPlayerFromServerId(targetSrc)
          local targetPed = player ~= -1 and GetPlayerPed(player) or 0
          if targetPed ~= 0 and dogAlive() then
              ClearPedTasks(K9.ped)
              TaskCombatPed(K9.ped, targetPed, 0, 16)
              setHud('tracking', nil, L('k9_cmd_attack'))
          end
      end },
    { id = 'home', label = 'k9_cmd_home',
      show = function() return K9.ped ~= nil end,
      run = function() Law.Net.Send('k9:dismiss') end },
}

local menuOpen = false

local function openDogMenu()
    if menuOpen or not Law.Ready or Law.UI.IsOpen() or Law.State.cuffed then return end
    if not Law.Me.onDuty or not Law.HasPerm('k9') then return end
    if not K9.ped then return Law.Notify(L('err_k9_no_dog'), 'error') end
    local targetSrc = Law.Util.GetClosestPlayer((Config.Interact and Config.Interact.TargetDistance) or 3.0)

    local items = {}
    for _, c in ipairs(DOG_COMMANDS) do
        if c.show(targetSrc) then
            items[#items + 1] = {
                id = c.id, label = L(c.label), desc = c.desc and L(c.desc) or nil,
                badge = c.target and Law.Util.PlayerName(targetSrc) or nil,
            }
        end
    end
    if #items == 0 then return end

    menuOpen = true
    CreateThread(function()
        local choice = Law.UI.Menu({
            title = L('k9_menu_title'),
            subtitle = L('k9_state_' .. tostring(K9.state or 'idle')),
            items = items,
        })
        menuOpen = false
        if not choice then return end
        for _, c in ipairs(DOG_COMMANDS) do
            if c.id == choice then
                -- Zustand kann sich geaendert haben, waehrend das Menue offen war
                local now = c.target and Law.Util.GetClosestPlayer((Config.Interact and Config.Interact.TargetDistance) or 3.0) or targetSrc
                if c.target and now ~= targetSrc then return Law.Notify(L('interact_target_gone')) end
                if not c.show(now) then return end
                local ok, err = xpcall(c.run, debug.traceback, now)
                if not ok then Law.Warn('Fehler im Hunde-Menue (%s): %s', tostring(choice), tostring(err)) end
                return
            end
        end
    end)
end

Law.K9 = Law.K9 or {}
Law.K9.OpenMenu = openDogMenu

RegisterCommand(Config.Commands.K9 or 'hund', function()
    openDogMenu()
end, false)

-- Taste: Windows-Tastencode (F12 = 0x7B), abgefragt nur solange ein Hund da ist
CreateThread(function()
    local key = Config.Keys and Config.Keys.K9Menu
    if not key then return end
    while true do
        if K9.ped then
            Wait(0)
            if IsRawKeyReleased(key) then
                openDogMenu()
                Wait(300)
            end
        else
            Wait(500)
        end
    end
end)

-- Geruchsprobe am gefesselten oder bewusstlosen Ziel
Law.Interact.Register('scent_sample', {
    label = L('scent_interact_sample'), desc = L('scent_interact_sample_desc'),
    order = 46, target = true, perm = 'scent_sample', duty = true,
    canShow = function(targetSrc)
        local st = Player(targetSrc).state
        if st and st.law_cuffed then return true end
        local player = GetPlayerFromServerId(targetSrc)
        local ped = player ~= -1 and GetPlayerPed(player) or 0
        return ped ~= 0 and IsEntityDead(ped)
    end,
    onSelect = function(targetSrc)
        local ped = PlayerPedId()
        TaskStartScenarioInPlace(ped, `WORLD_HUMAN_INSPECT`, 3000, true, false, false, false)
        Wait(3000)
        ClearPedTasks(ped)
        local res = Law.Cb.Await('scent:sample', targetSrc)
        Law.Notify(res and res.msg or L('err_failed'))
    end,
})

Law.Modules.Register('k9', {
    onDuty = function(onDuty)
        -- Server entfernt den Hund selbst (dutyChanged); hier nur die Anzeige
        if not onDuty and K9.session then K9.session = nil end
    end,
    onStop = function()
        K9.session = nil
        deleteDog()
    end,
})
