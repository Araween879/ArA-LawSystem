--[[
    ArA-LawSystem - Daten fuer die grossen NUI-Apps (Server)

    core:ledgerOpen     Dienstbuch oeffnen (Behoerde, auch ausser Dienst lesbar)
    core:ledgerOverview Tab "Uebersicht"
    core:counterOpen    Schalter (alle, am counter-Punkt)
    core:boardOpen      Steckbriefbrett (alle, am board-Punkt)
]]

Config.Counter = Config.Counter or {
    Tabs = { 'fines', 'bail', 'license', 'bounty', 'weapons', 'escort', 'property', 'report' },
}

Law.Cb.Register('core:ledgerOpen', { law = true, duty = false, rate = 1000 }, function(src, ctx)
    local perms = {}
    for p in pairs(Law.GradePerms(ctx.job, ctx.grade)) do perms[#perms + 1] = p end
    return Law.Result(true, {
        officer = {
            name        = ctx.name,
            dept        = ctx.dept,
            deptLabel   = ctx.deptCfg.label,
            gradeLabel  = ctx.gradeCfg and ctx.gradeCfg.label or '',
            badgeNumber = Law.BadgeNumber(ctx.job, ctx.charId),
            seal        = ctx.deptCfg.seal or ctx.dept,
            onDuty      = ctx.onDuty,
            perms       = perms,
        },
    })
end)

local function scalar(sql, params)
    local v = MySQL.scalar.await(sql, params or {})
    return tonumber(v) or 0
end

Law.Cb.Register('core:ledgerOverview', { law = true, duty = false, rate = 1000 }, function(src, ctx)
    local onDuty = {}
    for dsrc, d in pairs(Law.Duty.active) do
        local p = Law.Players[dsrc]
        local dept = Law.GetDept(d.dept)
        local g = Law.GetGrade(d.dept, d.grade)
        onDuty[#onDuty + 1] = {
            name = p and p.name or ('#' .. dsrc), dept = d.dept,
            deptLabel = dept and dept.label or d.dept, gradeLabel = g and g.label or '',
            since = d.since,
        }
    end
    table.sort(onDuty, function(a, b) return a.deptLabel < b.deptLabel end)

    local alerts = {}
    if ctx.onDuty and Law.HasPerm(ctx, 'dispatch') then
        alerts = Law.Dispatch.ListFor(src, ctx)
    end

    return Law.Result(true, {
        onDuty = onDuty,
        alerts = alerts,
        stats = {
            openWarrants   = scalar("SELECT COUNT(*) FROM ara_law_warrants WHERE status IN ('pending','active')"),
            activeBounties = scalar("SELECT COUNT(*) FROM ara_law_bounties WHERE status = 'active'"),
            inmates        = scalar('SELECT COUNT(*) FROM ara_law_jail'),
            openEscorts    = scalar("SELECT COUNT(*) FROM ara_law_escorts WHERE status IN ('open','accepted','active')"),
            balance        = Law.Society.Get(ctx.dept),
        },
    })
end)

Law.Cb.Register('core:counterOpen', { rate = 1000 }, function(src, ctx)
    local stationKey = Law.Stations.NearPoint(src, 'counter')
    if not stationKey then return Law.Result(false, 'not_at_point') end
    local st = Config.Stations[stationKey]
    local tabs = {}
    for _, t in ipairs(Config.Counter.Tabs) do
        if t ~= 'escort' or (st.points and st.points.escort) then tabs[#tabs + 1] = t end
    end
    return Law.Result(true, {
        station = stationKey, stationLabel = st.label,
        citizen = { name = ctx.name, charId = ctx.charId },
        tabs = tabs,
    })
end)

Law.Cb.Register('core:boardOpen', { rate = 1000 }, function(src, ctx)
    local stationKey = Law.Stations.NearPoint(src, 'board')
    if not stationKey then return Law.Result(false, 'not_at_point') end
    return Law.Result(true, {
        station = stationKey, stationLabel = Config.Stations[stationKey].label,
        canHunt = Law.Bounty.CanHunt(src) == true,
    })
end)
