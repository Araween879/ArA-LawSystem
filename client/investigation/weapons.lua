--[[
    ArA-LawSystem - Waffenregister: Feldkontrolle, Waffenfeile, Waffenschein (Client)

    Der Schalter-Tab "weapons" laeuft komplett ueber die NUI (weapons:mine,
    weapons:register, weapons:reportStolen). Hier nur die Welt-Aktionen.
]]

local WCfg = Config.Weapons

--------------------------------------------------------------------------
-- Feldkontrolle (Recht weapons_registry ODER search)
--------------------------------------------------------------------------
Law.Interact.Register('weapons_inspect', {
    label = L('weapons_interact_inspect'),
    desc = L('weapons_interact_inspect_desc'),
    order = 40, target = true, law = true, duty = true,
    canShow = function()
        return Law.HasPerm('weapons_registry') or Law.HasPerm('search')
    end,
    onSelect = function(targetSrc)
        local res = Law.Cb.Await('weapons:inspect', targetSrc)
        if not res or not res.ok then return Law.Notify(res and res.msg or L('err_failed')) end
        local data = res.data or {}
        local items = {}
        for i, w in ipairs(data.weapons or {}) do
            local serialText = w.filed and L('weapons_inspect_filed') or (w.serial or L('weapons_inspect_noserial'))
            local desc = L('weapons_inspect_desc', serialText)
            if w.ownerName and w.foreign then desc = desc .. ' - ' .. L('weapons_inspect_foreign', w.ownerName) end
            items[#items + 1] = { id = i, label = w.weaponLabel or '?', desc = desc, badge = w.statusLabel }
        end
        if #items == 0 then return Law.Notify(L('weapons_inspect_none', data.name or '?')) end
        Law.UI.Menu({ title = L('weapons_inspect_title'), subtitle = data.name, items = items })
    end,
})

--------------------------------------------------------------------------
-- Waffenfeile: Server fragt, welche Waffe; Server misst die Zeit
--------------------------------------------------------------------------
Law.Answer('weapons:chooseFile', function(payload)
    local items = {}
    for _, w in ipairs((payload and payload.weapons) or {}) do
        items[#items + 1] = { id = w.id, label = w.label, desc = L('weapons_file_serial', w.serial) }
    end
    if #items == 0 then return nil end
    return Law.UI.Menu({ title = L('weapons_file_title'), subtitle = L('weapons_file_subtitle'), items = items })
end)

Law.On('weapons:fileStart', function(seconds)
    seconds = tonumber(seconds) or ((WCfg.File and WCfg.File.Seconds) or 10)
    CreateThread(function()
        local ped = PlayerPedId()
        TaskStartScenarioInPlace(ped, `WORLD_HUMAN_CROUCH_INSPECT`, seconds * 1000, true, false, false, false)
        Law.Util.Progress(L('weapons_file_progress'), seconds * 1000)
        ClearPedTasks(ped)
        local cancelled = Law.State.cuffed or IsEntityDead(PlayerPedId())
        Law.Net.Send('weapons:fileFinish', cancelled)
    end)
end)

--------------------------------------------------------------------------
-- Waffenschein (Dokument vom Server)
--------------------------------------------------------------------------
Law.On('weapons:document', function(def)
    if type(def) ~= 'table' then return end
    Law.UI.Document(def)
end)

--------------------------------------------------------------------------
-- Waffe verkaufen / umschreiben (Schalter-Reiter "weapons")
-- Die NUI sendet action { app='counter', name='transferWeapon', payload={ weaponId, serial } }.
-- Wer der Kaeufer ist, waehlt der Verkaeufer hier; alles Weitere prueft der Server.
--------------------------------------------------------------------------
local TRANSFER_RANGE = 3.0

Law.UI.OnAction('counter', 'transferWeapon', function(p)
    local weaponId = type(p) == 'table' and tonumber(p.weaponId) or nil
    if not weaponId then return { ok = false, err = 'invalid', msg = L('err_invalid') } end
    local players = Law.Util.GetPlayersInRange(TRANSFER_RANGE)
    if #players == 0 then return { ok = false, err = 'no_target', msg = L('err_no_target') } end
    local items = {}
    for _, pl in ipairs(players) do
        items[#items + 1] = { id = pl.serverId, label = Law.Util.PlayerName(pl.serverId) }
    end
    local choice = Law.UI.Menu({ title = L('weapons_transfer_title'), subtitle = L('weapons_transfer_subtitle', tostring(p.serial or '-')), items = items })
    local targetSrc = tonumber(choice)
    if not targetSrc then return { ok = false, err = 'cancelled', msg = L('err_cancelled') } end
    local res = Law.Cb.Await('weapons:transfer', weaponId, targetSrc)
    return res or { ok = false, err = 'no_response', msg = L('err_no_response') }
end)

-- Kaeufer: Rueckfrage des Servers (Law.Ask, 12 s). true = annehmen
Law.Answer('weapons:confirmTransfer', function(payload)
    payload = type(payload) == 'table' and payload or {}
    local answered = false
    -- Laeuft die Server-Frist ab, das Menue nicht offen stehen lassen
    SetTimeout(11500, function()
        if not answered then Law.UI.Close() end
    end)
    local choice = Law.UI.Menu({
        title = L('weapons_transfer_confirm_title'),
        subtitle = L('weapons_transfer_confirm_sub', tostring(payload.sellerName or '?'), tostring(payload.weaponLabel or '?'), tostring(payload.serial or '-')),
        items = {
            { id = 'accept',  label = L('weapons_transfer_accept') },
            { id = 'decline', label = L('weapons_transfer_decline') },
        },
    })
    answered = true
    return choice == 'accept'
end)
