--[[
    ArA-LawSystem - Kern: Grundobjekte (Server)

    Hier entstehen die Tabellen, an die alle Module sich haengen. Diese Datei
    wird als erste Server-Datei geladen (fxmanifest: server/core/*.lua,
    alphabetisch -> 00_ zuerst).
]]

Law = Law or {}
Law.IsServer = true

Law.VORP = exports.vorp_core:GetCore()
Law.Inv  = exports.vorp_inventory

--- Serverzeit in Unix-Sekunden. ALLE Zeitwerte in der DB sind so gespeichert.
function Law.Now()
    return os.time()
end

-- Laufzeit-Zustand. Wahrheit fuer Entscheidungen - Statebags sind nur Anzeige.
-- Schreiben nur durch den jeweiligen Besitzer (Vertrag Abschnitt 4).
Law.State = {
    cuffed     = {},  -- [src] = officerSrc | true      (Agent A)
    escortedBy = {},  -- [src] = officerSrc             (Agent A)
    jailed     = {},  -- [src] = charId                 (Agent A)
    lastDeath  = {},  -- [src] = unix                   (Kern)
}

-- Kern-Cache je Spieler, bleibt bis NACH den playerDropped-Hooks bestehen.
-- [src] = { charId, name, identifier, dept, grade, loadedAt }
Law.Players = {}

--------------------------------------------------------------------------
-- Module
--------------------------------------------------------------------------
Law.Modules = { list = {}, order = {} }

--- Modul anmelden. hooks: init, playerLoaded, playerDropped, playerDied,
--- playerRevived, playerRespawned, dutyChanged, jobChanged, stop
function Law.Modules.Register(name, hooks)
    if Law.Modules.list[name] then
        Law.Warn('Modul "%s" doppelt angemeldet - zweite Anmeldung ueberschreibt die erste', name)
    else
        Law.Modules.order[#Law.Modules.order + 1] = name
    end
    Law.Modules.list[name] = hooks or {}
end

--- Hook in allen Modulen aufrufen. Ein Fehler in einem Modul bricht die
--- anderen nicht ab.
function Law.Modules.Call(hook, ...)
    for _, name in ipairs(Law.Modules.order) do
        local fn = Law.Modules.list[name][hook]
        if fn then
            local ok, err = xpcall(fn, debug.traceback, ...)
            if not ok then
                Law.Warn('Fehler in %s.%s: %s', name, hook, tostring(err))
            end
        end
    end
end

--- Intervall-Thread, fehlerisoliert. Erster Lauf nach `ms`.
function Law.Every(ms, fn)
    CreateThread(function()
        while true do
            Wait(ms)
            local ok, err = xpcall(fn, debug.traceback)
            if not ok then Law.Warn('Fehler im Intervall: %s', tostring(err)) end
        end
    end)
end

--- Admin laut vorp-Gruppe
function Law.IsAdmin(src)
    local user = Law.VORP.getUser(src)
    if not user then return false end
    local group = user.getGroup
    return Law.Contains(Config.General.AdminGroups, group)
end
