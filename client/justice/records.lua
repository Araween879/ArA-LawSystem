--[[
    ArA-LawSystem - Akten & Haftbefehle (Client, Agent A)

    Formulare aus dem Dienstbuch (action ledger:openForm):
      note     { charId }  -> records:addNote(charId, title, text)
      warrant  { charId }  -> warrants:create(charId, codes, reason, jailMinutes, deadOrAlive, bounty)

    Law.Justice.PenalOptions() liefert den Strafkatalog im Format des
    Feldtyps "penalcode" (Vertrag 10.3) - Betraege rechnet trotzdem der Server.
]]

Law.Justice = Law.Justice or {}

local penalOptions

function Law.Justice.PenalOptions()
    if not penalOptions then
        penalOptions = {}
        for _, p in ipairs(Config.PenalCode or {}) do
            penalOptions[#penalOptions + 1] = { value = p.id, label = p.label, category = p.category, fine = p.fine, jail = p.jail }
        end
    end
    return penalOptions
end

--- Name eines (auch offline) Charakters fuer Formular-Kopfzeilen
function Law.Justice.CharName(charId)
    local res = Law.Cb.Await('records:brief', charId)
    if res and res.ok and res.data then return res.data.name end
    return ('#%s'):format(tostring(charId))
end

local function cancelled()
    return { ok = false, err = 'cancelled', msg = L('err_cancelled') }
end

local function invalid()
    return { ok = false, err = 'invalid', msg = L('err_invalid') }
end

--------------------------------------------------------------------------
-- Notiz
--------------------------------------------------------------------------
Law.UI.RegisterForm('note', function(p)
    local charId = Law.ToInt(p and p.charId, 1)
    if not charId then return invalid() end
    local name = Law.Justice.CharName(charId)
    local values = Law.UI.Form({
        id = 'note', title = L('form_note_title'), subtitle = name, submitLabel = L('form_save'),
        fields = {
            { name = 'title', type = 'text', label = L('form_note_heading'), required = true, maxLength = 128 },
            { name = 'text', type = 'textarea', label = L('form_note_text'), maxLength = 2000 },
        },
    })
    if not values then return cancelled() end
    return Law.Cb.Await('records:addNote', charId, values.title, values.text)
end)

--------------------------------------------------------------------------
-- Haftbefehl
--------------------------------------------------------------------------
Law.UI.RegisterForm('warrant', function(p)
    local charId = Law.ToInt(p and p.charId, 1)
    if not charId then return invalid() end
    local name = Law.Justice.CharName(charId)
    local fields = {
        { name = 'charId', type = 'readonly', label = L('form_target'), default = name },
        { name = 'codes', type = 'penalcode', label = L('form_codes'), required = true, options = Law.Justice.PenalOptions() },
        { name = 'reason', type = 'text', label = L('form_warrant_reason'), maxLength = 120, placeholder = L('form_note_placeholder') },
        { name = 'jailMinutes', type = 'number', label = L('form_extra_minutes'), min = 0, max = Config.Jail.MaxExtraMinutes, default = 0,
          help = L('form_extra_minutes_help') },
        { name = 'deadOrAlive', type = 'checkbox', label = L('form_dead_or_alive'), default = false },
    }
    if Law.HasPerm('bounty_manage') then
        fields[#fields + 1] = { name = 'bounty', type = 'money', label = L('form_bounty_amount'), min = 0, max = Config.Bounty.Official.Max,
            default = 0, help = L('form_bounty_help') }
    end
    local values = Law.UI.Form({
        id = 'warrant', title = L('form_warrant_title'), subtitle = name, submitLabel = L('form_warrant_submit'),
        summary = 'penalcode', fields = fields,
    })
    if not values then return cancelled() end
    return Law.Cb.Await('warrants:create', charId, values.codes, values.reason, values.jailMinutes, values.deadOrAlive, values.bounty)
end)
