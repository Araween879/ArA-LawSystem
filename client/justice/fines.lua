--[[
    ArA-LawSystem - Bussgeld (Client, Agent A)

    Formular "fine"  aus der Akte ({ charId }) -> fines:issueByCharId
    Interaktion      "Bussgeld ausstellen" am Ziel -> fines:issue
    Interaktion      "Bussgeld kassieren" -> fines:listFor -> fines:collect
    Law.Answer       'fines:confirmPay' (Ziel stimmt der Zahlung zu)
    Dokument         Bussgeldbescheid (Item law_fineticket, Daten vom Server)
]]

Law.Justice = Law.Justice or {}

local function fineFields(targetLabel)
    return {
        { name = 'target', type = 'readonly', label = L('form_target'), default = targetLabel },
        { name = 'codes', type = 'penalcode', label = L('form_codes'), required = true, options = Law.Justice.PenalOptions() },
        { name = 'note', type = 'text', label = L('form_note'), maxLength = 120, placeholder = L('form_note_placeholder') },
    }
end

-- Aus dem Dienstbuch (Akte, auch offline)
Law.UI.RegisterForm('fine', function(p)
    local charId = Law.ToInt(p and p.charId, 1)
    if not charId then return { ok = false, err = 'invalid', msg = L('err_invalid') } end
    local name = Law.Justice.CharName(charId)
    local values = Law.UI.Form({
        id = 'fine', title = L('form_fine_title'), subtitle = name, submitLabel = L('form_fine_submit'),
        summary = 'penalcode', fields = fineFields(name),
    })
    if not values then return { ok = false, err = 'cancelled', msg = L('err_cancelled') } end
    return Law.Cb.Await('fines:issueByCharId', charId, values.codes, values.note)
end)

-- Im Feld am Ziel
Law.Interact.Register('fines_issue', {
    label = L('interact_fine'), order = 40, target = true, perm = 'fine',
    onSelect = function(t)
        local name = Law.Util.PlayerName(t)
        Law.Justice.AfterMenu()
        local values = Law.UI.Form({
            id = 'fine', title = L('form_fine_title'), subtitle = name, submitLabel = L('form_fine_submit'),
            summary = 'penalcode', fields = fineFields(name),
        })
        if not values then return end
        local res = Law.Cb.Await('fines:issue', t, values.codes, values.note)
        Law.Notify(res and res.msg or L('err_failed'))
    end,
})

Law.Interact.Register('fines_collect', {
    label = L('interact_fine_collect'), order = 41, target = true, perm = 'fine',
    onSelect = function(t)
        local res = Law.Cb.Await('fines:listFor', t)
        if not res or not res.ok then return Law.Notify(res and res.msg or L('err_failed')) end
        if #(res.data or {}) == 0 then return Law.Notify(L('fine_none_open')) end
        local items = {}
        for _, f in ipairs(res.data) do
            items[#items + 1] = {
                id = f.id,
                label = L('fine_menu_item', f.id, f.amount),
                desc = f.reason,
                badge = f.statusLabel,
            }
        end
        Law.Justice.AfterMenu()
        local choice = Law.UI.Menu({ title = L('fine_collect_title'), subtitle = Law.Util.PlayerName(t), items = items })
        if not choice then return end
        Law.Notify(L('fine_collect_waiting'))
        local r = Law.Cb.Await('fines:collect', t, choice)
        Law.Notify(r and r.msg or L('err_failed'))
    end,
})

-- Ziel: zustimmen oder ablehnen (Server wartet mit Timeout)
Law.Answer('fines:confirmPay', function(fine)
    if type(fine) ~= 'table' then return false end
    -- Der Server wartet nur 12 s. Bleibt das Menue laenger offen, schliessen
    -- wir es selbst (N7) - sonst haengt es, obwohl die Antwort nicht mehr zaehlt.
    local done = false
    SetTimeout(12000, function()
        if not done and Law.UI.IsOpen() then
            Law.UI.Close()
            Law.Notify(L('fine_confirm_timeout'))
        end
    end)
    -- Menue per Maus bedienbar - auch gefesselt (Tastensperre betrifft nur das Spiel)
    local choice = Law.UI.Menu({
        title = L('fine_confirm_title'),
        subtitle = L('fine_confirm_subtitle', fine.amount or 0, fine.officerName or '-'),
        items = {
            { id = 'yes', label = L('fine_confirm_yes'), desc = fine.reason },
            { id = 'no',  label = L('fine_confirm_no') },
        },
    })
    done = true
    return choice == 'yes'
end)

Law.On('fines:showTicket', function(doc)
    if type(doc) == 'table' then Law.UI.Document(doc) end
end)
