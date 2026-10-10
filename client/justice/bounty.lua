--[[
    ArA-LawSystem - Kopfgeld (Client, Agent A)

    Stationspunkt "dropoff": Kopfgeld einloesen (bounty:claim), NPC-Ziel
    abliefern (npc:deliver) oder Fluechtigen aus einer Streife abliefern.
    Formular "bounty_official" aus dem Dienstbuch -> bounty:createOfficial
    Lizenz-Anzeige: Law.Justice.hasLicense (nur Anzeige, der Server prueft selbst).
]]

Law.Justice = Law.Justice or {}
Law.Justice.hasLicense = false

local function refreshLicense()
    local res = Law.Cb.Await('bounty:licenseStatus')
    if res and res.ok and res.data then Law.Justice.hasLicense = res.data.active == true end
end

Law.On('bounty:license', function(active)
    Law.Justice.hasLicense = active == true
end)

Law.On('bounty:showDocument', function(doc)
    if type(doc) == 'table' then Law.UI.Document(doc) end
end)

--------------------------------------------------------------------------
-- Abgabestelle
--------------------------------------------------------------------------
local function lawOnDuty()
    return Law.Me.dept ~= nil and Law.Me.onDuty == true
end

Law.Stations.RegisterPoint('dropoff', {
    label = L('prompt_dropoff'),
    distance = 3.0,
    canShow = function()
        return Law.Justice.hasLicense or lawOnDuty() or Law.Justice.npcContract ~= nil
    end,
    onUse = function()
        local options = {}
        if Law.Justice.npcContract then
            options[#options + 1] = { id = 'npc', label = L('dropoff_npc', Law.Justice.npcContract.name or '?') }
        end
        if Law.Justice.hasLicense or lawOnDuty() then
            options[#options + 1] = { id = 'bounty', label = L('dropoff_bounty'), desc = L('dropoff_bounty_desc') }
        end
        if lawOnDuty() and not Law.Justice.npcContract then
            options[#options + 1] = { id = 'fugitive', label = L('dropoff_fugitive') }
        end
        if #options == 0 then return end
        local choice = options[1].id
        if #options > 1 then
            choice = Law.UI.Menu({ title = L('dropoff_title'), items = options })
            if not choice then return end
        end
        local res
        if choice == 'bounty' then
            res = Law.Cb.Await('bounty:claim')
        else
            res = Law.Cb.Await('npc:deliver')
        end
        Law.Notify(res and res.msg or L('err_failed'), 'objective', 6000)
    end,
})

--------------------------------------------------------------------------
-- Offizielles Kopfgeld (Dienstbuch)
--------------------------------------------------------------------------
Law.UI.RegisterForm('bounty_official', function(p)
    local charId = Law.ToInt(p and p.charId, 1)
    if not charId then return { ok = false, err = 'invalid', msg = L('err_invalid') } end
    local name = Law.Justice.CharName(charId)
    local values = Law.UI.Form({
        id = 'bounty_official', title = L('form_bounty_title'), subtitle = name, submitLabel = L('form_bounty_submit'),
        fields = {
            { name = 'charId', type = 'readonly', label = L('form_target'), default = name },
            { name = 'amount', type = 'money', label = L('form_bounty_amount'), required = true, min = 1, max = Config.Bounty.Official.Max },
            { name = 'reason', type = 'text', label = L('form_bounty_reason'), required = true, maxLength = 200 },
            { name = 'deadOrAlive', type = 'checkbox', label = L('form_dead_or_alive'), default = false },
        },
    })
    if not values then return { ok = false, err = 'cancelled', msg = L('err_cancelled') } end
    return Law.Cb.Await('bounty:createOfficial', charId, values.amount, values.reason, values.deadOrAlive)
end)

--------------------------------------------------------------------------
-- Modul
--------------------------------------------------------------------------
local refreshing = false

Law.Modules.Register('bounty', {
    onReady = function()
        CreateThread(refreshLicense)
        if refreshing then return end
        refreshing = true
        -- Lizenz kann ablaufen: alle 10 Minuten nachfragen (nur Anzeige)
        CreateThread(function()
            while refreshing do
                Wait(600000)
                if Law.Ready then refreshLicense() end
            end
        end)
    end,
    onStop = function()
        refreshing = false
    end,
})
