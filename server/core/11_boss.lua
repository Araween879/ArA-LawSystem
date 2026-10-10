--[[
    ArA-LawSystem - Chef-Verwaltung (Server)

    Dienstbuch-Tab "Behoerde": Mitglieder, einstellen, entlassen, befoerdern,
    Kasse ein-/auszahlen, Kassenbuch.

    Regel fuer Raenge: Niemand vergibt einen Rang >= dem eigenen und niemand
    aendert jemanden mit Rang >= dem eigenen. Ausnahme: vorp-Admins.
]]

local UNEMPLOYED_JOB   = 'unemployed'
local UNEMPLOYED_LABEL = 'Arbeitslos'

local function anyBossPerm(ctx)
    for _, p in ipairs({ 'boss_hire', 'boss_fire', 'boss_promote', 'boss_funds', 'boss_logs' }) do
        if Law.HasPerm(ctx, p) then return true end
    end
    return false
end

local function jobLabel(dept, grade)
    local d = Law.GetDept(dept)
    local g = Law.GetGrade(dept, grade)
    return ('%s - %s'):format(d and d.short or dept, g and g.label or tostring(grade))
end

--- Darf ctx einen Rang `grade` vergeben?
local function canAssign(ctx, grade)
    if Law.IsAdmin(ctx.src) then return true end
    return grade < ctx.grade
end

--- Mitglied der Behoerde? -> { jobgrade } | nil
--- Online-Spieler: Job/Rang aus dem Speicher (vorp schreibt Aenderungen erst
--- beim naechsten Speichern in die DB - die DB waere veraltet).
local function memberRow(charId, dept)
    local online = Law.CtxByCharId(charId)
    if online then
        if online.job ~= dept then return nil end
        return { charidentifier = charId, jobgrade = online.grade, online = true }
    end
    return MySQL.single.await('SELECT charidentifier, firstname, lastname, job, jobgrade FROM characters WHERE charidentifier = ? AND job = ? LIMIT 1',
        { charId, dept })
end

--- Job setzen - online ueber vorp, offline direkt in der DB
local function setJob(charId, job, grade, label)
    local target = Law.CtxByCharId(charId)
    if target then
        target.char.setJob(job, true)
        target.char.setJobGrade(grade, true)
        target.char.setJobLabel(label, true)
        return target.src
    end
    MySQL.update.await('UPDATE characters SET job = ?, jobgrade = ?, joblabel = ? WHERE charidentifier = ?', { job, grade, label, charId })
    return nil
end

--------------------------------------------------------------------------
-- Uebersicht
--------------------------------------------------------------------------
Law.Cb.Register('boss:overview', { law = true, rate = 1000 }, function(src, ctx)
    if not anyBossPerm(ctx) then return Law.Result(false, 'no_permission') end

    local rows = MySQL.query.await('SELECT charidentifier, firstname, lastname, jobgrade FROM characters WHERE job = ? ORDER BY jobgrade DESC, lastname ASC LIMIT 200',
        { ctx.dept }) or {}
    local since = Law.Now() - 7 * 86400
    local hours = {}
    for _, r in ipairs(MySQL.query.await('SELECT charid, SUM(seconds) AS s FROM ara_law_duty_log WHERE department = ? AND started_at >= ? GROUP BY charid',
        { ctx.dept, since }) or {}) do
        hours[tonumber(r.charid)] = Law.Round((tonumber(r.s) or 0) / 3600, 1)
    end

    local members = {}
    for _, r in ipairs(rows) do
        local charId = tonumber(r.charidentifier)
        local online = Law.SrcByCharId(charId)
        local g = Law.GetGrade(ctx.dept, r.jobgrade)
        members[#members + 1] = {
            charId      = charId,
            name        = ((r.firstname or '') .. ' ' .. (r.lastname or '')),
            grade       = tonumber(r.jobgrade) or 0,
            gradeLabel  = g and g.label or tostring(r.jobgrade),
            online      = online ~= nil,
            onDuty      = online ~= nil and Law.Duty.active[online] ~= nil,
            dutyHours7d = hours[charId] or 0,
        }
    end

    local log = {}
    if Law.HasPerm(ctx, 'boss_logs') or Law.HasPerm(ctx, 'boss_funds') then
        for _, r in ipairs(MySQL.query.await('SELECT id, amount, balance_after, reason, actor_name, created_at FROM ara_law_society_log WHERE department = ? ORDER BY id DESC LIMIT 50',
            { ctx.dept }) or {}) do
            log[#log + 1] = {
                id = r.id, amount = tonumber(r.amount), balanceAfter = tonumber(r.balance_after),
                reason = r.reason, actorName = r.actor_name, createdAt = tonumber(r.created_at),
            }
        end
    end

    return Law.Result(true, {
        dept       = ctx.dept,
        deptLabel  = ctx.deptCfg.label,
        balance    = Law.Society.Get(ctx.dept),
        myGrade    = ctx.grade,
        grades     = Law.GradeList(ctx.dept),
        members    = members,
        log        = log,
        can = {
            hire    = Law.HasPerm(ctx, 'boss_hire'),
            fire    = Law.HasPerm(ctx, 'boss_fire'),
            promote = Law.HasPerm(ctx, 'boss_promote'),
            funds   = Law.HasPerm(ctx, 'boss_funds'),
            logs    = Law.HasPerm(ctx, 'boss_logs'),
        },
    })
end)

--------------------------------------------------------------------------
-- Einstellen (Spieler muss in der Naehe stehen)
--------------------------------------------------------------------------
Law.Cb.Register('boss:hire', { perm = 'boss_hire', rate = 2000 }, function(src, ctx, targetSrc, grade)
    targetSrc = Law.ToInt(targetSrc, 1)
    grade = Law.ToInt(grade, 0)
    if not targetSrc or not grade or targetSrc == src then return Law.Result(false, 'invalid') end
    if not Law.GetDept(ctx.dept).grades[grade] then return Law.Result(false, 'invalid') end
    if not canAssign(ctx, grade) then return Law.Result(false, 'grade_too_high') end

    local target = Law.Ctx(targetSrc)
    if not target then return Law.Result(false, 'no_target') end
    if not Law.IsNear(src, targetSrc, Config.Boss.HireDistance or 5.0) then return Law.Result(false, 'too_far') end
    if target.job == ctx.dept then return Law.Result(false, 'already_member') end

    -- Niemand wird ungefragt eingestellt (und verliert dabei seinen alten Job)
    local agreed = Law.Ask(targetSrc, 'boss:confirmHire', {
        deptLabel  = ctx.deptCfg.label,
        gradeLabel = Law.GetGrade(ctx.dept, grade).label,
        byName     = ctx.name,
        oldJob     = target.char.jobLabel or target.job,
    }, 12000)
    if agreed ~= true then return Law.Result(false, 'declined') end
    -- Waehrend der Rueckfrage kann sich alles geaendert haben - auch beim
    -- Einstellenden (Rang, Behoerde, Dienst)
    local dept = ctx.dept
    ctx = Law.Ctx(src)
    if not ctx or ctx.dept ~= dept or not Law.HasPerm(ctx, 'boss_hire') or not canAssign(ctx, grade) then
        return Law.Result(false, 'no_permission')
    end
    target = Law.Ctx(targetSrc)
    if not target or target.job == ctx.dept or not Law.IsNear(src, targetSrc, (Config.Boss.HireDistance or 5.0) + 2.0) then
        return Law.Result(false, 'no_target')
    end

    if Law.Duty.active[targetSrc] then Law.Duty.Set(targetSrc, false, 'job_change') end
    setJob(target.charId, ctx.dept, grade, jobLabel(ctx.dept, grade))
    Law.Notify(targetSrc, L('boss_hired_you', ctx.deptCfg.label), 'success')
    Law.Audit(ctx, 'boss.hire', target.charId, { dept = ctx.dept, grade = grade })
    return Law.Result(true, nil, L('boss_hired', target.name))
end)

--------------------------------------------------------------------------
-- Entlassen (auch offline)
--------------------------------------------------------------------------
Law.Cb.Register('boss:fire', { perm = 'boss_fire', rate = 2000 }, function(src, ctx, charId)
    charId = Law.ToInt(charId, 1)
    if not charId or charId == ctx.charId then return Law.Result(false, 'invalid') end
    local row = memberRow(charId, ctx.dept)
    if not row then return Law.Result(false, 'not_member') end
    if not canAssign(ctx, tonumber(row.jobgrade) or 0) then return Law.Result(false, 'grade_too_high') end

    local targetSrc = Law.SrcByCharId(charId)
    if targetSrc and Law.Duty.active[targetSrc] then Law.Duty.Set(targetSrc, false, 'fired') end
    setJob(charId, UNEMPLOYED_JOB, 0, UNEMPLOYED_LABEL)
    if targetSrc then Law.Notify(targetSrc, L('boss_fired_you', ctx.deptCfg.label), 'error') end
    Law.Audit(ctx, 'boss.fire', charId, { dept = ctx.dept })
    return Law.Result(true, nil, L('boss_fired'))
end)

--------------------------------------------------------------------------
-- Rang aendern (auch offline)
--------------------------------------------------------------------------
Law.Cb.Register('boss:setGrade', { perm = 'boss_promote', rate = 1500 }, function(src, ctx, charId, grade)
    charId = Law.ToInt(charId, 1)
    grade = Law.ToInt(grade, 0)
    if not charId or not grade or charId == ctx.charId then return Law.Result(false, 'invalid') end
    if not Law.GetDept(ctx.dept).grades[grade] then return Law.Result(false, 'invalid') end
    local row = memberRow(charId, ctx.dept)
    if not row then return Law.Result(false, 'not_member') end
    if not canAssign(ctx, tonumber(row.jobgrade) or 0) or not canAssign(ctx, grade) then
        return Law.Result(false, 'grade_too_high')
    end

    local targetSrc = setJob(charId, ctx.dept, grade, jobLabel(ctx.dept, grade))
    if targetSrc then
        -- neuer Rang = neue Rechte; die Dienstschicht laeuft mit dem neuen Rang weiter
        if Law.Duty.active[targetSrc] then Law.Duty.active[targetSrc].grade = grade end
        Law.SyncPlayer(targetSrc)
        Law.Notify(targetSrc, L('boss_grade_you', Law.GetGrade(ctx.dept, grade).label), 'info')
    end
    Law.Audit(ctx, 'boss.grade', charId, { dept = ctx.dept, from = tonumber(row.jobgrade), to = grade })
    return Law.Result(true, nil, L('boss_grade_set'))
end)

--------------------------------------------------------------------------
-- Kasse
--------------------------------------------------------------------------
Law.Cb.Register('boss:deposit', { perm = 'boss_funds', rate = 1500 }, function(src, ctx, amount)
    amount = Law.ToMoney(amount, 0.01, 1000000)
    if not amount then return Law.Result(false, 'invalid') end
    if not Law.Money.Take(src, amount, 0) then return Law.Result(false, 'no_money') end
    local okDb, added = Law.DB.Try(Law.Society.Add, ctx.dept, amount, 'deposit', ctx)
    if not okDb or not added then
        Law.Money.Give(src, amount, 0) -- zurueck, Kasse nicht erreichbar
        return Law.Result(false, 'failed')
    end
    Law.Audit(ctx, 'boss.deposit', nil, { dept = ctx.dept, amount = amount })
    return Law.Result(true, { balance = Law.Society.Get(ctx.dept) }, L('boss_deposit_ok', amount))
end)

Law.Cb.Register('boss:withdraw', { perm = 'boss_funds', rate = 1500 }, function(src, ctx, amount)
    amount = Law.ToMoney(amount, 0.01, Config.Society.MaxWithdraw or 5000)
    if not amount then return Law.Result(false, 'invalid') end
    local okDb, removed = Law.DB.Try(Law.Society.Remove, ctx.dept, amount, 'withdraw', ctx)
    if not okDb or not removed then return Law.Result(false, 'society_empty') end
    if not Law.Money.Give(src, amount, 0) then
        Law.Society.Add(ctx.dept, amount, 'withdraw_refund', ctx)
        return Law.Result(false, 'failed')
    end
    Law.Audit(ctx, 'boss.withdraw', nil, { dept = ctx.dept, amount = amount })
    return Law.Result(true, { balance = Law.Society.Get(ctx.dept) }, L('boss_withdraw_ok', amount))
end)

--------------------------------------------------------------------------
-- Jobwechsel von aussen (Admin, anderes Script)
--------------------------------------------------------------------------
-- vorp feuert diese Events, BEVOR es job/jobgrade im Charakter setzt.
-- Deshalb erst im naechsten Tick neu lesen und synchronisieren.
AddEventHandler('vorp:playerJobChange', function(src, newJob, oldJob)
    src = tonumber(src)
    if not src then return end
    if Law.Duty.active[src] and Law.Duty.active[src].dept ~= newJob then
        Law.Duty.Set(src, false, 'job_change')
    end
    SetTimeout(0, function()
        if GetPlayerPing(src) <= 0 then return end
        Law.RefreshPlayer(src)
        Law.Modules.Call('jobChanged', src, newJob, oldJob)
        Law.SyncPlayer(src)
    end)
end)

AddEventHandler('vorp:playerJobGradeChange', function(src, newGrade)
    src = tonumber(src)
    if not src then return end
    if Law.Duty.active[src] then Law.Duty.active[src].grade = tonumber(newGrade) or Law.Duty.active[src].grade end
    SetTimeout(0, function()
        if GetPlayerPing(src) <= 0 then return end
        Law.RefreshPlayer(src)
        Law.SyncPlayer(src)
    end)
end)
