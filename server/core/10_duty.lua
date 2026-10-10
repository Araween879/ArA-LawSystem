--[[
    ArA-LawSystem - Dienst, Dienstzeit, Lohn, Marke, Client-Sync (Server)
]]

Law.Duty = Law.Duty or { active = {} }

--------------------------------------------------------------------------
-- Client-Sync: was der Client ueber sich wissen darf (nur Anzeige)
--------------------------------------------------------------------------
function Law.SyncPlayer(src)
    local ctx = Law.Ctx(src)
    if not ctx then return end
    local perms = {}
    if ctx.dept then
        for p in pairs(Law.GradePerms(ctx.job, ctx.grade)) do perms[#perms + 1] = p end
    end
    TriggerClientEvent('ara_law:cl:core:sync', src, {
        charId      = ctx.charId,
        name        = ctx.name,
        job         = ctx.job,
        grade       = ctx.grade,
        dept        = ctx.dept,
        deptLabel   = ctx.deptCfg and ctx.deptCfg.label or nil,
        gradeLabel  = ctx.gradeCfg and ctx.gradeCfg.label or nil,
        badgeNumber = ctx.dept and Law.BadgeNumber(ctx.job, ctx.charId) or nil,
        onDuty      = ctx.onDuty,
        perms       = perms,
        cuffed      = Law.IsCuffed(src),
        escorted    = Law.IsEscorted(src),
        jailed      = Law.IsJailed(src),
    })
end

--------------------------------------------------------------------------
-- Dienst an/aus
--------------------------------------------------------------------------
function Law.Duty.Set(src, on, reason)
    src = tonumber(src)
    local current = Law.Duty.active[src]

    if on then
        local ctx = Law.Ctx(src)
        if not ctx or not ctx.dept then return false end
        if current then return true end
        local logId = MySQL.insert.await('INSERT INTO ara_law_duty_log (charid, name, department, grade, started_at, seconds) VALUES (?, ?, ?, ?, ?, 0)',
            { ctx.charId, ctx.name, ctx.dept, ctx.grade, Law.Now() })
        Law.Duty.active[src] = { dept = ctx.dept, grade = ctx.grade, since = Law.Now(), logId = logId, payAcc = 0, charId = ctx.charId }
        Player(src).state:set('law_duty', ctx.dept, true)
        ctx.onDuty = true
        Law.Audit(ctx, 'duty.on', nil, { dept = ctx.dept, grade = ctx.grade })
        Law.Modules.Call('dutyChanged', src, ctx, true)
        Law.SyncPlayer(src)
        return true
    end

    if not current then return true end
    local seconds = Law.Now() - current.since
    if current.logId then
        MySQL.update('UPDATE ara_law_duty_log SET ended_at = ?, seconds = ? WHERE id = ?', { Law.Now(), seconds, current.logId })
    end
    Law.Duty.active[src] = nil
    if GetPlayerPing(src) > 0 then
        Player(src).state:set('law_duty', nil, true)
    end
    local ctx = Law.Ctx(src)
    local cache = Law.Players[src]
    Law.Audit(ctx or (cache and { charId = cache.charId, name = cache.name }), 'duty.off', nil,
        { dept = current.dept, minutes = math.floor(seconds / 60), reason = reason })
    Law.Modules.Call('dutyChanged', src, ctx, false)
    if ctx then Law.SyncPlayer(src) end
    return true
end

Law.Net.On('duty:toggle', { law = true, duty = false, rate = 2000, notCuffed = true, notJailed = true }, function(src, ctx)
    if not Law.GradeHasPerm(ctx.job, ctx.grade, 'duty') then
        return Law.Notify(src, L('err_no_permission'), 'error')
    end
    if Config.Duty.OnlyAtPoint then
        local stationKey = Law.Stations.NearPoint(src, 'duty', (Config.Duty.PointRadius or 2.0) + 1.0)
        if not stationKey then return Law.Notify(src, L('duty_not_at_point'), 'error') end
        if not Law.Stations.AllowsDept(stationKey, ctx.dept) then
            return Law.Notify(src, L('duty_wrong_station'), 'error')
        end
    end
    if Law.Duty.active[src] then
        Law.Duty.Set(src, false, 'manual')
        Law.Notify(src, L('duty_off'), 'success')
    else
        Law.Duty.Set(src, true)
        Law.Notify(src, L('duty_on', ctx.deptCfg.label), 'success')
    end
end)

--------------------------------------------------------------------------
-- Lohn aus der Kasse (optional)
--------------------------------------------------------------------------
Law.Every(60000, function()
    if not Config.Payroll.Enabled then return end
    local interval = (Config.Payroll.IntervalMin or 30) * 60
    -- Kopie: die Schleife wartet auf die DB, waehrenddessen kann sich
    -- Law.Duty.active aendern ("invalid key to 'next'")
    local snapshot = {}
    for src, d in pairs(Law.Duty.active) do snapshot[src] = d end
    for src, d in pairs(snapshot) do
        if Law.Duty.active[src] ~= d then goto continue end
        d.payAcc = (d.payAcc or 0) + 60
        if d.payAcc >= interval then
            d.payAcc = 0
            local gradeCfg = Law.GetGrade(d.dept, d.grade)
            local salary = gradeCfg and tonumber(gradeCfg.salary) or 0
            if salary > 0 then
                local paid = true
                if Config.Payroll.FromSociety then
                    paid = Law.Society.Remove(d.dept, salary, 'payroll', nil)
                end
                local live = Law.Ctx(src)
                local sameChar = live ~= nil and live.charId == d.charId
                if not paid then
                    Law.Notify(src, L('duty_salary_empty'), 'error')
                elseif sameChar and Law.Money.Give(src, salary, 0) then
                    Law.Notify(src, L('duty_salary', salary), 'success')
                elseif Config.Payroll.FromSociety then
                    Law.Society.Add(d.dept, salary, 'payroll_refund', nil) -- Spieler weg: Geld zurueck in die Kasse
                end
            end
        end
        ::continue::
    end
end)

--------------------------------------------------------------------------
-- Marke zeigen
--------------------------------------------------------------------------
local function showBadge(src, ctx)
    if not Law.HasPerm(ctx, 'badge') then
        return Law.Notify(src, L('err_no_permission'), 'error')
    end
    if not Law.RateLimit(src, 'badge:show', (Config.Badge.Cooldown or 5) * 1000) then return end
    local data = {
        name        = ctx.name,
        deptLabel   = ctx.deptCfg.label,
        gradeLabel  = ctx.gradeCfg and ctx.gradeCfg.label or '',
        badgeNumber = Law.BadgeNumber(ctx.job, ctx.charId),
        seal        = ctx.deptCfg.seal or ctx.dept,
        ms          = Config.Badge.DurationMs,
    }
    local coords = Law.GetCoords(src)
    for _, target in ipairs(Law.GetPlayersInRadius(coords, Config.Badge.ShowDistance or 5.0)) do
        TriggerClientEvent('ara_law:cl:core:badge', target, data, src)
    end
end

Law.Items.RegisterUsable(Config.Items.Badge, function(src, ctx)
    showBadge(src, ctx)
end, { law = true, duty = false, notCuffed = true })

RegisterCommand(Config.Commands.Badge, function(src)
    if src <= 0 then return end
    local ctx = Law.Ctx(src)
    if not ctx or not ctx.dept then return end
    if Law.IsCuffed(src) then return end
    if Law.Items.Count(src, Config.Items.Badge) < 1 then
        return Law.Notify(src, L('badge_need_item'), 'error')
    end
    showBadge(src, ctx)
end, false)

--------------------------------------------------------------------------
-- Admin-Hilfe: Koordinaten
--------------------------------------------------------------------------
RegisterCommand(Config.Commands.Coords, function(src)
    if src <= 0 or not Law.IsAdmin(src) then return end
    TriggerClientEvent('ara_law:cl:core:printCoords', src)
end, false)
