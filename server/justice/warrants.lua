--[[
    ArA-LawSystem - Haftbefehle (Server, Agent A)

    Vertrag 4.1:  Law.Warrants.CreateAuto(charId, reason, opts?) -> id
                  Law.Warrants.GetActive(charId)                 -> [Warrant]
    Dienstbuch:   warrants:list(status) -> [Warrant]
                  warrants:approve(id) · warrants:revoke(id)
                  warrants:create(charId, codes, reason, extraMinutes, deadOrAlive, bounty)  (Formular "warrant")

    Status: pending -> active -> served | revoked | expired.
    Jeder Wechsel ist atomar (WHERE id = ? AND status ...). Haengen
    Kopfgelder am Haftbefehl, werden sie mit geschlossen und erstattet.
]]

Law.Justice  = Law.Justice or {}
Law.Warrants = Law.Warrants or {}

local VALID_STATUS = { pending = true, active = true, served = true, revoked = true, expired = true }

--------------------------------------------------------------------------
-- Datenform (Vertrag 10.6 Warrant)
--------------------------------------------------------------------------
local function warrantPublic(r, bountySum)
    local codes, fineId = Law.Justice.CodesPublic(r.codes)
    return {
        id             = r.id,
        charId         = tonumber(r.charid),
        targetName     = r.target_name,
        reason         = r.reason,
        codes          = codes,
        fineId         = fineId,
        jailMinutes    = tonumber(r.jail_minutes) or 0,
        deadOrAlive    = tonumber(r.dead_or_alive) == 1,
        dept           = r.department,
        deptLabel      = Law.Justice.DeptLabel(r.department),
        createdByName  = r.created_by_name,
        approvedByName = r.approved_by_name,
        status         = r.status,
        statusLabel    = L('warrant_status_' .. tostring(r.status)),
        createdAt      = tonumber(r.created_at),
        expiresAt      = tonumber(r.expires_at),
        bounty         = bountySum,
    }
end

--- Liste mit Kopfgeld-Summe je Haftbefehl (eine Abfrage fuer alle)
function Law.Justice.WarrantsPublic(rows)
    local ids = {}
    for _, r in ipairs(rows or {}) do ids[#ids + 1] = r.id end
    local sums = {}
    if #ids > 0 then
        local q = ("SELECT warrant_id, SUM(amount) AS s FROM ara_law_bounties WHERE status IN ('pending','active') AND warrant_id IN (%s) GROUP BY warrant_id")
            :format(Law.Justice.Placeholders(#ids))
        for _, s in ipairs(MySQL.query.await(q, ids) or {}) do
            sums[tonumber(s.warrant_id)] = tonumber(s.s)
        end
    end
    local out = {}
    for _, r in ipairs(rows or {}) do out[#out + 1] = warrantPublic(r, sums[tonumber(r.id)]) end
    return out
end

local function notifyWanted(charId, reason)
    local src = Law.SrcByCharId(charId)
    if src then Law.Notify(src, L('warrant_you_are_wanted', reason or ''), 'objective', 8000) end
end

--------------------------------------------------------------------------
-- Schliessen (widerrufen / abgelaufen) inkl. Kopfgelder
--------------------------------------------------------------------------
--- newStatus: 'revoked' | 'expired' | 'served'
local function closeWarrant(id, newStatus, actorCtx)
    local affected = MySQL.update.await(
        "UPDATE ara_law_warrants SET status = ?, closed_at = ? WHERE id = ? AND status IN ('pending','active')",
        { newStatus, Law.Now(), id })
    if affected ~= 1 then return false end
    -- Kopfgelder am Haftbefehl: bei "served" zahlt niemand mehr -> Erstattung
    Law.Justice.CloseBountiesForWarrant(id, newStatus == 'expired' and 'expired' or 'cancelled', actorCtx)
    return true
end
Law.Justice.CloseWarrant = closeWarrant

--- Auto-Haftbefehl eines bezahlten/stornierten Bussgelds widerrufen
function Law.Justice.RevokeFineWarrants(charId, fineId, actorCtx)
    local rows = MySQL.query.await("SELECT id, codes FROM ara_law_warrants WHERE charid = ? AND status IN ('pending','active')", { charId }) or {}
    for _, r in ipairs(rows) do
        local _, linked = Law.Justice.CodesPublic(r.codes)
        if linked and linked == tonumber(fineId) then
            if closeWarrant(r.id, 'revoked', actorCtx) then
                Law.Records.Add(charId, 'warrant', L('record_warrant_revoked_fine', r.id, fineId), nil, actorCtx, r.id)
                Law.Audit(actorCtx, 'warrants.revoke_fine', charId, { id = r.id, fine = fineId })
            end
        end
    end
end

--- Bei Inhaftierung: aktive Haftbefehle erledigt. -> Liste der ids
function Law.Justice.ServeWarrants(charId)
    local rows = MySQL.query.await("SELECT id FROM ara_law_warrants WHERE charid = ? AND status = 'active'", { charId }) or {}
    local served = {}
    for _, r in ipairs(rows) do
        local affected = MySQL.update.await("UPDATE ara_law_warrants SET status = 'served', closed_at = ? WHERE id = ? AND status = 'active'", { Law.Now(), r.id })
        if affected == 1 then served[#served + 1] = r.id end
    end
    return served
end

--------------------------------------------------------------------------
-- Vertrag 4.1
--------------------------------------------------------------------------
function Law.Warrants.GetActive(charId)
    charId = tonumber(charId)
    if not charId then return {} end
    local rows = MySQL.query.await("SELECT * FROM ara_law_warrants WHERE charid = ? AND status = 'active' ORDER BY id DESC", { charId }) or {}
    return Law.Justice.WarrantsPublic(rows)
end

--- System-Haftbefehl, sofort aktiv.
--- opts = { codes?, jailMinutes?, bounty?, deadOrAlive?, dept? }
function Law.Warrants.CreateAuto(charId, reason, opts)
    charId = tonumber(charId)
    if not charId then return nil end
    opts = opts or {}
    local now = Law.Now()
    local dept = (opts.dept and Law.GetDept(opts.dept)) and opts.dept or Config.Warrants.SystemDept
    local reasonText = Law.ToStr(reason, 255) or L('warrant_reason_default')
    local minutes = Law.ToInt(opts.jailMinutes or 0, 0, Config.Jail.MaxMinutes) or 0
    local codes = opts.codes ~= nil and json.encode(opts.codes) or nil
    local system = L('system_name')

    local id = MySQL.insert.await(
        'INSERT INTO ara_law_warrants (charid, target_name, reason, codes, jail_minutes, dead_or_alive, department, created_by, created_by_name, approved_by, approved_by_name, status, created_at, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?, NULL, ?, NULL, ?, ?, ?, ?)',
        { charId, Law.GetCharName(charId), reasonText, codes, minutes, opts.deadOrAlive and 1 or 0, dept,
          system, system, 'active', now, now + (Config.Warrants.ExpireDays or 7) * 86400 })
    if not id then return nil end

    Law.Records.Add(charId, 'warrant', L('record_warrant_auto', reasonText), nil, nil, id)
    Law.Audit(nil, 'warrants.auto', charId, { id = id, reason = reasonText, minutes = minutes })

    local bounty = Law.ToMoney(opts.bounty or 0, 0)
    if bounty and bounty > 0 then
        Law.Justice.CreateOfficialBounty({
            charId = charId, amount = bounty, reason = reasonText, deadOrAlive = opts.deadOrAlive == true,
            warrantId = id, status = 'active', dept = dept, actorCtx = nil,
        })
    end
    notifyWanted(charId, reasonText)
    return id
end

--------------------------------------------------------------------------
-- Dienstbuch
--------------------------------------------------------------------------
Law.Cb.Register('warrants:list', { perm = 'records_view', duty = false, rate = 800 }, function(src, ctx, status)
    status = Law.ToStr(status, 12) or 'open'
    local rows
    if status == 'open' then
        rows = MySQL.query.await("SELECT * FROM ara_law_warrants WHERE status IN ('pending','active') ORDER BY id DESC LIMIT 100")
    elseif VALID_STATUS[status] then
        rows = MySQL.query.await('SELECT * FROM ara_law_warrants WHERE status = ? ORDER BY id DESC LIMIT 100', { status })
    else
        rows = MySQL.query.await('SELECT * FROM ara_law_warrants ORDER BY id DESC LIMIT 100')
    end
    return Law.Result(true, Law.Justice.WarrantsPublic(rows or {}))
end)

--- Formular "warrant": Grund und Haftminuten kommen aus dem Strafkatalog,
--- extraMinutes (Feld jailMinutes) sind nur ein gedeckelter Zuschlag.
Law.Cb.Register('warrants:create', { perm = 'warrant_create', rate = 2000 }, function(src, ctx, charId, codes, reason, extraMinutes, deadOrAlive, bounty)
    charId = Law.ToInt(charId, 1)
    if not charId then return Law.Result(false, 'invalid') end
    local row = Law.Justice.CharRow(charId)
    if not row then return Law.Result(false, 'not_found') end
    if Law.IsSelfOrAlt(ctx, charId) then return Law.Result(false, 'self_target') end

    local calc = Law.Justice.ComputeCodes(codes)
    if not calc then return Law.Result(false, 'invalid_codes') end
    local extra = Law.ToInt(extraMinutes or 0, 0, Config.Jail.MaxExtraMinutes) or 0
    local minutes = math.min(calc.jail + extra, Config.Jail.MaxMinutes)
    local note = Law.ToStr(reason, 120, true) or ''
    local reasonText = note ~= '' and (calc.text .. ' - ' .. note) or calc.text
    reasonText = Law.ToStr(reasonText, 255) or calc.text
    deadOrAlive = Law.ToBool(deadOrAlive)

    local bountyAmount = Law.ToMoney(bounty or 0, 0, Config.Bounty.Official.Max) or 0
    if bountyAmount > 0 and not Law.HasPerm(ctx, 'bounty_manage') then
        return Law.Result(false, 'no_permission')
    end

    local approve = (not Config.Warrants.RequireApproval) or Law.HasPerm(ctx, 'warrant_approve')
    local status = approve and 'active' or 'pending'
    local now = Law.Now()
    local id = MySQL.insert.await(
        'INSERT INTO ara_law_warrants (charid, target_name, reason, codes, jail_minutes, dead_or_alive, department, created_by, created_by_name, approved_by, approved_by_name, status, created_at, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { charId, Law.Justice.RowName(row), reasonText, json.encode(calc.list), minutes, deadOrAlive and 1 or 0, ctx.dept,
          ctx.charId, ctx.name, approve and ctx.charId or nil, approve and ctx.name or nil, status, now,
          now + (Config.Warrants.ExpireDays or 7) * 86400 })
    if not id then return Law.Result(false, 'failed') end

    Law.Records.Add(charId, 'warrant', L('record_warrant_created', reasonText), L('record_warrant_minutes', minutes), ctx, id)
    Law.Audit(ctx, 'warrants.create', charId, { id = id, status = status, minutes = minutes, bounty = bountyAmount })

    local msg = approve and L('warrant_created_active') or L('warrant_created_pending')
    if bountyAmount > 0 then
        local bid, err = Law.Justice.CreateOfficialBounty({
            charId = charId, amount = bountyAmount, reason = reasonText, deadOrAlive = deadOrAlive,
            warrantId = id, status = status, dept = ctx.dept, actorCtx = ctx,
        })
        if not bid then msg = msg .. ' ' .. L('err_' .. tostring(err or 'failed')) end
    end
    if approve then
        notifyWanted(charId, reasonText)
    else
        Law.NotifyLaw(L('warrant_pending_notice', Law.Justice.RowName(row)), 'warrant_approve')
    end
    return Law.Result(true, { id = id, status = status }, msg)
end)

Law.Cb.Register('warrants:approve', { perm = 'warrant_approve', rate = 1000 }, function(src, ctx, id)
    id = Law.ToInt(id, 1)
    if not id then return Law.Result(false, 'invalid') end
    local row = MySQL.single.await('SELECT charid, reason, created_by FROM ara_law_warrants WHERE id = ?', { id })
    if not row then return Law.Result(false, 'not_found') end
    if Law.IsSelfOrAlt(ctx, row.charid) then return Law.Result(false, 'self_target') end
    local affected = MySQL.update.await(
        "UPDATE ara_law_warrants SET status = 'active', approved_by = ?, approved_by_name = ? WHERE id = ? AND status = 'pending'",
        { ctx.charId, ctx.name, id })
    if affected ~= 1 then return Law.Result(false, 'already_done') end
    -- vorgemerkte Kopfgelder am Haftbefehl werden mit freigegeben
    MySQL.update.await("UPDATE ara_law_bounties SET status = 'active' WHERE warrant_id = ? AND status = 'pending'", { id })
    Law.Records.Add(row.charid, 'warrant', L('record_warrant_approved', id), nil, ctx, id)
    Law.Audit(ctx, 'warrants.approve', row.charid, { id = id })
    notifyWanted(tonumber(row.charid), row.reason)
    return Law.Result(true, { id = id }, L('warrant_approved'))
end)

Law.Cb.Register('warrants:revoke', { perm = 'warrant_approve', rate = 1000 }, function(src, ctx, id)
    id = Law.ToInt(id, 1)
    if not id then return Law.Result(false, 'invalid') end
    local row = MySQL.single.await('SELECT charid FROM ara_law_warrants WHERE id = ?', { id })
    if not row then return Law.Result(false, 'not_found') end
    -- keinen Haftbefehl gegen sich selbst / den Zweitchar widerrufen
    if Law.IsSelfOrAlt(ctx, row.charid) then return Law.Result(false, 'self_target') end
    if not closeWarrant(id, 'revoked', ctx) then return Law.Result(false, 'already_done') end
    Law.Records.Add(row.charid, 'warrant', L('record_warrant_revoked', id), nil, ctx, id)
    Law.Audit(ctx, 'warrants.revoke', row.charid, { id = id })
    local tsrc = Law.SrcByCharId(row.charid)
    if tsrc then Law.Notify(tsrc, L('warrant_revoked_you'), 'success') end
    return Law.Result(true, { id = id }, L('warrant_revoked'))
end)

--------------------------------------------------------------------------
-- Ablauf
--------------------------------------------------------------------------
local function expireWarrants()
    local rows = MySQL.query.await(
        "SELECT id, charid FROM ara_law_warrants WHERE status IN ('pending','active') AND expires_at IS NOT NULL AND expires_at < ? LIMIT 200",
        { Law.Now() }) or {}
    for _, r in ipairs(rows) do
        if closeWarrant(r.id, 'expired', nil) then
            Law.Records.Add(r.charid, 'warrant', L('record_warrant_expired', r.id), nil, nil, r.id)
            Law.Audit(nil, 'warrants.expire', r.charid, { id = r.id })
        end
    end
end

Law.Modules.Register('warrants', {
    init = function()
        expireWarrants()
        Law.Every((Config.Warrants.CheckMinutes or 10) * 60000, expireWarrants)
    end,
    playerLoaded = function(src, ctx)
        -- Beim Login erinnern, dass man gesucht wird
        local n = MySQL.scalar.await("SELECT COUNT(*) FROM ara_law_warrants WHERE charid = ? AND status = 'active'", { ctx.charId })
        if (tonumber(n) or 0) > 0 then
            SetTimeout(8000, function()
                if GetPlayerPing(src) > 0 then Law.Notify(src, L('warrant_login_notice', tonumber(n)), 'objective', 8000) end
            end)
        end
    end,
})
