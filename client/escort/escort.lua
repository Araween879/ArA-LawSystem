--[[
    ArA-LawSystem - Eskorte: Buero, Start, Abgabe, Abholung, HUD (Client)

    Buchen, eigene Auftraege, Stornieren und Abholen laufen ueber den
    Schalter (NUI, Tab "escort"); Annehmen/Verlassen ueber das Dienstbuch
    (Tab "escorts"). Hier: Eskort-Punkt (Start/Abgabe/Abholfach), Start von
    Personenschutz/-transport, Beutefach, HUD.
]]

Law.Escort = Law.Escort or {}
local EC = Law.Escort

EC.contracts = {}  -- eigene Auftraege als Begleiter (vom Server, escort:sync)
EC.loot = {}       -- [id] = true (Beutefaecher nach einem Ueberfall)
EC.hudId = nil

Law.On('escort:sync', function(list)
    EC.contracts = type(list) == 'table' and list or {}
end)

Law.On('escort:hud', function(data)
    if type(data) ~= 'table' then return end
    EC.hudId = data.id
    Law.UI.Hud('escort', data)
end)

Law.On('escort:ended', function(id, text)
    if EC.hudId == id then
        EC.hudId = nil
        Law.UI.Hud('escort', nil)
    end
    if EC.RemoveWagonBlip then EC.RemoveWagonBlip(id) end
    if EC.CleanupAmbush then EC.CleanupAmbush(id) end
    if text then Law.Notify(text) end
end)

-- Server oeffnet gleich ein vorp-Inventar: eigene NUI vorher schliessen
Law.On('escort:closeUi', function()
    if Law.UI.IsOpen() then Law.UI.Close() end
end)

Law.On('escort:lootList', function(ids)
    EC.loot = {}
    for _, id in ipairs(type(ids) == 'table' and ids or {}) do EC.loot[tonumber(id)] = true end
end)

--------------------------------------------------------------------------
-- Aktionen
--------------------------------------------------------------------------
function EC.RunAction(action, id)
    if action == 'start' then
        local res = Law.Cb.Await('escort:start', id)
        if not res or not res.ok then return Law.Notify(res and res.msg or L('err_failed')) end
        if res.data and res.data.spawnWagon then
            EC.SpawnWagon(id, res.data.model, res.data.spawn)
        else
            Law.Notify(res.msg or L('escort_started', id))
        end
    elseif action == 'deliver' then
        local res = Law.Cb.Await('escort:deliver', id)
        Law.Notify(res and res.msg or L('err_failed'))
    elseif action == 'claim' then
        local res = Law.Cb.Await('escort:claim', id)
        Law.Notify(res and res.msg or L('err_failed'))
    end
end

Law.Stations.RegisterPoint('escort', {
    label = L('escort_prompt_office'),
    onUse = function()
        local res = Law.Cb.Await('escort:here')
        if not res or not res.ok then return Law.Notify(res and res.msg or L('err_failed')) end
        local actions = res.data.actions or {}
        if #actions == 0 then return Law.Notify(L('escort_here_nothing')) end
        local items = {}
        for i, a in ipairs(actions) do items[#items + 1] = { id = i, label = a.label, desc = a.desc } end
        local choice = Law.UI.Menu({ title = L('escort_office_title'), subtitle = res.data.stationLabel, items = items })
        local a = choice and actions[tonumber(choice)]
        if not a then return end
        EC.RunAction(a.action, a.id)
    end,
})

--------------------------------------------------------------------------
-- Personenschutz / -transport starten (irgendwo, nah an der Person)
--------------------------------------------------------------------------
local function startable()
    local out = {}
    for _, c in ipairs(EC.contracts) do
        if c.isLeader and c.status == 'accepted' and c.type ~= 'cargo' then out[#out + 1] = c end
    end
    return out
end

Law.Interact.Register('escort_start', {
    label = L('escort_interact_start'), desc = L('escort_interact_start_desc'),
    order = 70, target = false, perm = 'escort_lead', duty = true,
    canShow = function() return #startable() > 0 end,
    onSelect = function()
        local list = startable()
        local items = {}
        for i, c in ipairs(list) do
            items[#items + 1] = { id = i, label = L('escort_action_start', c.id, c.typeLabel), desc = L('escort_interact_client', c.clientName or '?') }
        end
        local choice = Law.UI.Menu({ title = L('escort_office_title'), items = items })
        local c = choice and list[tonumber(choice)]
        if c then EC.RunAction('start', c.id) end
    end,
})

--------------------------------------------------------------------------
-- Beutefach (nur der Raeuber)
--------------------------------------------------------------------------
Law.Interact.Register('escort_loot', {
    label = L('escort_interact_loot'),
    order = 90, target = false,
    canShow = function() return next(EC.loot) ~= nil end,
    onSelect = function()
        local items = {}
        for id in pairs(EC.loot) do items[#items + 1] = { id = id, label = L('escort_loot_name', id) } end
        table.sort(items, function(a, b) return a.id > b.id end)
        local choice = Law.UI.Menu({ title = L('escort_interact_loot'), items = items })
        if not choice then return end
        local res = Law.Cb.Await('escort:openLoot', choice)
        Law.Notify(res and res.msg or L('err_failed'))
        if res and not res.ok then EC.loot[tonumber(choice)] = nil end
    end,
})

Law.Modules.Register('escort', {
    onStop = function()
        Law.UI.Hud('escort', nil)
        Law.UI.Hud('robbery', nil)
    end,
})
