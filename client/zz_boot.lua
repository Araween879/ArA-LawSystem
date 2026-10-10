--[[
    ArA-LawSystem - Start (Client)

    Laedt als LETZTE Client-Datei: alle Module haben ihre Punkte,
    Interaktionen und Handler angemeldet.
]]

CreateThread(function()
    Law.Modules.Call('init')
    Law.Stations.Start()
    Law.Interact.StartKeyLoop()

    -- Resource-Neustart mit schon gewaehltem Charakter: Server nach Daten fragen
    Wait(2000)
    Law.Net.Send('core:requestSync')
end)

-- Charakter gewaehlt: der Server schickt von sich aus core:sync, zur
-- Sicherheit fragt der Client nach kurzer Zeit noch einmal.
RegisterNetEvent('vorp:SelectedCharacter', function()
    SetTimeout(3000, function() Law.Net.Send('core:requestSync') end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    Law.Modules.Call('onStop')
    Law.Stations.Stop()
    Law.UI.Close()
    SetNuiFocus(false, false)
end)
