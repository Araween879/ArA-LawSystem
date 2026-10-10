--[[
    ArA-LawSystem - Start und Lebenszyklus (Server)

    Diese Datei laedt als LETZTE Server-Datei. Alle Module haben sich bis
    hierher nur angemeldet. Jetzt:
      1. Datenbank anlegen/abgleichen
      2. Behoerden bei vorp als Jobs anmelden
      3. benutzbare Items bei vorp_inventory anmelden
      4. init-Hooks aller Module
      5. bereits verbundene Spieler laden (Resource-Neustart)

    Der Kern besitzt diese Events - Module registrieren sie NICHT selbst:
      vorp:SelectedCharacter, playerDropped, onResourceStop,
      vorp_core:Server:OnPlayerDeath / OnPlayerRevive / OnPlayerRespawn
]]

local booted = false
local loadedFor = {}  -- [src] = charId, verhindert doppeltes playerLoaded

local function playerLoaded(src)
    src = tonumber(src)
    local ctx = Law.RefreshPlayer(src)
    if not ctx then return end
    if loadedFor[src] == ctx.charId then
        Law.SyncPlayer(src)
        return
    end
    loadedFor[src] = ctx.charId
    Law.Citizens.Get(ctx.charId)
    Law.Modules.Call('playerLoaded', src, ctx)
    Law.SyncPlayer(src)
    -- Offene Auszahlungen (Kopfgeld-Erstattung, Eskort-Lohn, Versicherung ...)
    SetTimeout(5000, function()
        if GetPlayerPing(src) > 0 and Law.Players[src] and Law.Players[src].charId == ctx.charId then
            Law.Money.PayPending(src, ctx.charId)
        end
    end)
end

Law.PlayerLoaded = playerLoaded

-- Client fragt nach seinen Daten (Resource-Neustart, spaete Charakterwahl)
Law.Net.On('core:requestSync', { rate = 2000 }, function(src)
    if booted then playerLoaded(src) end
end)

local function registerJobs()
    if not Law.VORP.RegisterJobs then return end
    local data = {}
    for job, dept in pairs(Config.Departments) do
        data[job] = { grades = {} }
        for g, info in pairs(dept.grades) do
            data[job].grades[g] = { label = info.label }
        end
    end
    Law.VORP.RegisterJobs(data, GetCurrentResourceName())
end

MySQL.ready(function()
    CreateThread(function()
        Law.DB.Init()
        registerJobs()
        Law.Items.ApplyUsable()
        Law.Modules.Call('init')
        booted = true

        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)
            if src and Law.Ctx(src) then playerLoaded(src) end
        end

        SetTimeout(5000, Law.Items.CheckDefinitions)
        print(('^2[ArA-Law] gestartet - %d Module^7'):format(#Law.Modules.order))
    end)
end)

AddEventHandler('vorp:SelectedCharacter', function(src)
    if not booted then return end -- der Start laedt alle Online-Spieler selbst
    -- vorp setzt den Charakter im selben Tick - kurz warten, bis alles steht
    SetTimeout(1000, function()
        if GetPlayerPing(src) > 0 then playerLoaded(src) end
    end)
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    local cache = Law.Players[src] and Law.Copy(Law.Players[src]) or nil
    if Law.Duty.active[src] then Law.Duty.Set(src, false, 'dropped') end
    if cache then Law.Modules.Call('playerDropped', src, cache, reason) end
    -- Laufzeit-Zustand sicher leeren (Besitzer-Hooks sind schon gelaufen)
    Law.State.cuffed[src] = nil
    Law.State.escortedBy[src] = nil
    Law.State.jailed[src] = nil
    Law.State.lastDeath[src] = nil
    for victim, officer in pairs(Law.State.escortedBy) do
        if officer == src then Law.State.escortedBy[victim] = nil end
    end
    Law.Players[src] = nil
    loadedFor[src] = nil
end)

--------------------------------------------------------------------------
-- Tod / Wiederbelebung / Respawn (vorp)
--------------------------------------------------------------------------
-- Achtung: OnPlayerDeath ist ein Net-Event vom Client. Es dient nur als
-- Signal ("kuerzlich gestorben"), nie als Beweis fuer Belohnungen.
-- Ein Cheater kann dieses Event frei feuern. Deshalb: Rate-Limit und nur
-- wenn sein Ped serverseitig wirklich tot ist (Law.IsPedDead). Sonst koennte
-- er sich "kuerzlich tot" machen (Knast verlassen ohne Fluchtalarm, Abfuehren
-- beenden).
RegisterNetEvent('vorp_core:Server:OnPlayerDeath', function()
    local src = source
    if not Law.Players[src] then return end
    if not Law.RateLimit(src, 'core:death', 10000) then return end
    if Config.General.ValidateDeath ~= false and Law.IsPedDead(src) == false then return end
    Law.State.lastDeath[src] = Law.Now()
    Law.Escort.OnPlayerDeath(src)
    Law.Modules.Call('playerDied', src, Law.Ctx(src))
end)

AddEventHandler('vorp_core:Server:OnPlayerRevive', function(src)
    src = tonumber(src)
    if src and Law.Players[src] then Law.Modules.Call('playerRevived', src) end
end)

-- Respawn kann vorp ueber ein Client-Event ausloesen. "Kuerzlich tot" wird
-- deshalb nur aufgefrischt, wenn vorher ein GEPRUEFTER Tod da war
-- (Respawn-Countdown kann Minuten dauern -> Fenster 30 Min.).
-- vorp loest Respawn auch ueber das frei feuerbare Net-Event
-- vorp_core:PlayerRespawnInternal aus (ohne Pruefung). Ohne vorherigen
-- GEPRUEFTEN Tod laufen deshalb KEINE Modul-Hooks - sonst koennte ein
-- Gefesselter sich per gefaelschtem Respawn befreien (Hook loest Fesseln).
AddEventHandler('vorp_core:Server:OnPlayerRespawn', function(src)
    src = tonumber(src)
    if not src or not Law.Players[src] then return end
    if not Law.RateLimit(src, 'core:respawn', 10000) then return end
    local last = Law.State.lastDeath[src]
    if not (last and Law.Now() - last <= 1800) then return end
    Law.State.lastDeath[src] = Law.Now()
    Law.Modules.Call('playerRespawned', src)
end)

--------------------------------------------------------------------------
-- Resource-Ereignisse
--------------------------------------------------------------------------
AddEventHandler('onResourceStart', function(res)
    -- vorp_inventory neu gestartet -> benutzbare Items sind dort weg
    if res == 'vorp_inventory' and booted then
        SetTimeout(3000, Law.Items.ApplyUsable)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    Law.Modules.Call('stop')
    for src in pairs(Law.Duty.active) do
        local d = Law.Duty.active[src]
        if d and d.logId then
            MySQL.update('UPDATE ara_law_duty_log SET ended_at = ?, seconds = ? WHERE id = ?', { Law.Now(), Law.Now() - d.since, d.logId })
        end
    end
    for _, id in ipairs(GetPlayers()) do
        local st = Player(tonumber(id)).state
        st:set('law_duty', nil, true)
        st:set('law_cuffed', nil, true)
        st:set('law_escorted', nil, true)
        st:set('law_jailed', nil, true)
    end
    Law.Items.UnregisterAll()
end)
