--[[
    ArA-LawSystem - Bussgeld (Server, Agent A)

    Ausstellen:  fines:issue(targetSrc, codes, note)        (vor Ort, <= FieldDistance)
                 fines:issueByCharId(charId, codes, note)   (aus der Akte, auch offline)
    Buerger:     fines:mine() · fines:pay(id)               (am Schalter)
    Vor Ort:     fines:listFor(targetSrc) (Zusatz) · fines:collect(targetSrc, id)
                 -> Law.Ask(target, 'fines:confirmPay', Fine)
    Dienstbuch:  fines:list(status) · fines:cancel(id)
    Item:        law_fineticket (Dokument aus der DB, metadata { fine_id, description })

    Zahlung: Geld nehmen -> atomar 'open'/'overdue' -> 'paid' -> sonst Geld
    zurueck. Erst danach Provision (Law.Money.GiveCharId) und Kasse.
]]

Law.Justice = Law.Justice or {}

local VALID_STATUS = { open = true, paid = true, cancelled = true, overdue = true }

--------------------------------------------------------------------------
-- Datenform (Vertrag 10.6 Fine)
--------------------------------------------------------------------------
function Law.Justice.FinePublic(r)
    local codes = Law.Justice.CodesPublic(r.codes)
    return {
        id          = r.id,
        charId      = tonumber(r.charid),
        targetName  = r.target_name,
        officerName = r.officer_name,
        dept        = r.department,
        deptLabel   = Law.Justice.DeptLabel(r.department),
        reason      = r.reason,
        codes       = codes,
        amount      = tonumber(r.amount) or 0,
        status      = r.status,
        statusLabel = L('fine_status_' .. tostring(r.status)),
        createdAt   = tonumber(r.created_at),
        dueAt       = tonumber(r.due_at),
        paidAt      = tonumber(r.paid_at),
    }
end

local function fineDept(row)
    if row and Law.GetDept(row.department) then return row.department end
    return Config.Fines.FallbackDepartment or 'sheriff'
end

--------------------------------------------------------------------------
-- Ausstellen (gemeinsam fuer Feld und Akte)
--------------------------------------------------------------------------
local function issue(ctx, charId, targetName, targetSrc, codes, note)
    -- nicht an sich selbst oder einen Zweitcharakter (Provision!)
    if Law.IsSelfOrAlt(ctx, charId) then return Law.Result(false, 'self_target') end
    local calc = Law.Justice.ComputeCodes(codes)
    if not calc then return Law.Result(false, 'invalid_codes') end
    local amount = math.min(calc.fine, Config.Fines.MaxAmount or 5000)
    if amount <= 0 then return Law.Result(false, 'amount_zero') end

    local open = MySQL.scalar.await("SELECT COUNT(*) FROM ara_law_fines WHERE charid = ? AND status IN ('open','overdue')", { charId })
    if (tonumber(open) or 0) >= (Config.Fines.MaxCount or 5) then return Law.Result(false, 'max_fines') end

    note = Law.ToStr(note, 120, true) or ''
    local reason = Law.ToStr(note ~= '' and (calc.text .. ' - ' .. note) or calc.text, 255) or calc.text
    local now = Law.Now()
    local id = MySQL.insert.await(
        'INSERT INTO ara_law_fines (charid, target_name, officer_charid, officer_name, department, reason, codes, amount, status, created_at, due_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { charId, targetName, ctx.charId, ctx.name, ctx.dept or Config.Fines.FallbackDepartment, reason, json.encode(calc.list), amount,
          'open', now, now + (Config.Fines.DueHours or 72) * 3600 })
    if not id then return Law.Result(false, 'failed') end

    Law.Records.Add(charId, 'fine', L('record_fine_issued', id, amount), reason, ctx, id)
    Law.Audit(ctx, 'fines.issue', charId, { id = id, amount = amount, reason = reason })

    local gaveTicket = false
    if targetSrc then
        -- Bescheid als Item (nur Verweis auf die DB, Kopieren bringt nichts)
        gaveTicket = Law.Items.Give(targetSrc, Config.Items.FineTicket, 1, {
            fine_id = id,
            description = L('fine_item_desc', id, amount, Law.Justice.FormatDate(now + (Config.Fines.DueHours or 72) * 3600)),
        })
        Law.Notify(targetSrc, L('fine_received', amount, ctx.name), 'objective', 8000)
        if not gaveTicket then Law.Notify(targetSrc, L('fine_no_ticket'), 'info') end
    end
    return Law.Result(true, { id = id, amount = amount }, L('fine_issued', amount, targetName))
end

Law.Cb.Register('fines:issue', { perm = 'fine', rate = 2000, notCuffed = true, alive = true }, function(src, ctx, targetSrc, codes, note)
    targetSrc = Law.ToInt(targetSrc, 1)
    if not targetSrc or targetSrc == src then return Law.Result(false, 'invalid') end
    local tctx = Law.Ctx(targetSrc)
    if not tctx then return Law.Result(false, 'no_target') end
    if not Law.IsNear(src, targetSrc, Config.Fines.FieldDistance or 5.0) then return Law.Result(false, 'too_far') end
    return issue(ctx, tctx.charId, tctx.name, targetSrc, codes, note)
end)

Law.Cb.Register('fines:issueByCharId', { perm = 'fine', rate = 2000 }, function(src, ctx, charId, codes, note)
    charId = Law.ToInt(charId, 1)
    if not charId then return Law.Result(false, 'invalid') end
    local row = Law.Justice.CharRow(charId)
    if not row then return Law.Result(false, 'not_found') end
    return issue(ctx, charId, Law.Justice.RowName(row), Law.SrcByCharId(charId), codes, note)
end)

--------------------------------------------------------------------------
-- Bezahlen (payerSrc zahlt aus seinem Geld)
--------------------------------------------------------------------------
local function settle(payerSrc, payerCtx, id, collectorCtx)
    local row = MySQL.single.await('SELECT * FROM ara_law_fines WHERE id = ?', { id })
    if not row then return Law.Result(false, 'not_found') end
    if row.status ~= 'open' and row.status ~= 'overdue' then return Law.Result(false, 'already_done') end
    local amount = tonumber(row.amount) or 0

    -- 1. Geld nehmen (pruefen + abziehen ohne yield)
    if amount > 0 and not Law.Money.Take(payerSrc, amount, 0) then return Law.Result(false, 'no_money') end

    -- 2. atomarer Statuswechsel (DB-Fehler -> Geld zurueck)
    local okU, affected = Law.DB.Try(MySQL.update.await,
        "UPDATE ara_law_fines SET status = 'paid', paid_at = ?, paid_by_charid = ? WHERE id = ? AND status IN ('open','overdue')",
        { Law.Now(), payerCtx.charId, id })
    if not okU or affected ~= 1 then
        if amount > 0 then Law.Justice.GiveBack(payerSrc, payerCtx.charId, amount, 'fine_refund') end
        return Law.Result(false, okU and 'already_done' or 'failed')
    end

    -- 3. verteilen: Provision an den ausstellenden Officer, Rest an die Kasse.
    --    Scheitert die Provision, geht ihr Anteil mit in die Kasse (kein Geldverlust).
    local commission = 0
    local officerId = tonumber(row.officer_charid)
    if officerId and officerId ~= tonumber(row.charid) and not Law.SamePlayer(officerId, row.charid) then
        commission = Law.Round(amount * (Config.Fines.OfficerCommission or 0), 2)
    end
    if commission > 0 and not Law.Justice.PayCharId(officerId, commission, 'fine_commission') then commission = 0 end
    local dept = fineDept(row)
    if amount - commission > 0 and not Law.Justice.SocietyAdd(dept, amount - commission, 'fine', payerCtx) then
        Law.Warn('Bussgeld #%s konnte nicht in Kasse %s gebucht werden', tostring(id), tostring(dept))
    end

    -- ueberfaellig bezahlt -> zugehoerigen Auto-Haftbefehl widerrufen
    if row.status == 'overdue' then Law.Justice.RevokeFineWarrants(tonumber(row.charid), id, collectorCtx or payerCtx) end

    Law.Records.Add(row.charid, 'fine', L('record_fine_paid', id, amount), nil, collectorCtx, id)
    Law.Audit(collectorCtx or payerCtx, 'fines.pay', row.charid, { id = id, amount = amount, commission = commission, dept = dept, payer = payerCtx.charId })
    return Law.Result(true, { id = id, amount = amount }, L('fine_paid_ok', amount))
end

Law.Cb.Register('fines:mine', { rate = 800 }, function(src, ctx)
    local rows = MySQL.query.await(
        "SELECT * FROM ara_law_fines WHERE charid = ? AND (status IN ('open','overdue') OR created_at >= ?) ORDER BY id DESC LIMIT 30",
        { ctx.charId, Law.Now() - 14 * 86400 }) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = Law.Justice.FinePublic(r) end
    return Law.Result(true, out)
end)

Law.Cb.Register('fines:pay', { rate = 2000, notCuffed = true, notJailed = true, alive = true }, function(src, ctx, id)
    id = Law.ToInt(id, 1)
    if not id then return Law.Result(false, 'invalid') end
    if not Law.Stations.NearPoint(src, 'counter') then return Law.Result(false, 'not_at_point') end
    local owner = MySQL.scalar.await('SELECT charid FROM ara_law_fines WHERE id = ?', { id })
    if tonumber(owner) ~= ctx.charId then return Law.Result(false, 'not_found') end
    return settle(src, ctx, id, nil)
end)

--------------------------------------------------------------------------
-- Vor Ort kassieren (mit Zustimmung des Ziels)
--------------------------------------------------------------------------
Law.Cb.Register('fines:listFor', { perm = 'fine', rate = 1000 }, function(src, ctx, targetSrc)
    targetSrc = Law.ToInt(targetSrc, 1)
    if not targetSrc or targetSrc == src then return Law.Result(false, 'invalid') end
    local tctx = Law.Ctx(targetSrc)
    if not tctx then return Law.Result(false, 'no_target') end
    if not Law.IsNear(src, targetSrc, Config.Fines.FieldDistance or 5.0) then return Law.Result(false, 'too_far') end
    local out = {}
    for _, r in ipairs(MySQL.query.await("SELECT * FROM ara_law_fines WHERE charid = ? AND status IN ('open','overdue') ORDER BY id DESC LIMIT 10", { tctx.charId }) or {}) do
        out[#out + 1] = Law.Justice.FinePublic(r)
    end
    return Law.Result(true, out)
end)

Law.Cb.Register('fines:collect', { perm = 'fine', rate = 3000, notCuffed = true, alive = true }, function(src, ctx, targetSrc, id)
    targetSrc = Law.ToInt(targetSrc, 1)
    id = Law.ToInt(id, 1)
    if not targetSrc or not id or targetSrc == src then return Law.Result(false, 'invalid') end
    local tctx = Law.Ctx(targetSrc)
    if not tctx then return Law.Result(false, 'no_target') end
    local dist = Config.Fines.FieldDistance or 5.0
    if not Law.IsNear(src, targetSrc, dist) then return Law.Result(false, 'too_far') end
    local row = MySQL.single.await("SELECT * FROM ara_law_fines WHERE id = ? AND charid = ? AND status IN ('open','overdue')", { id, tctx.charId })
    if not row then return Law.Result(false, 'not_found') end

    -- Ziel muss zustimmen (eigener Timeout < Client-Callback-Timeout)
    local answer = Law.Ask(targetSrc, 'fines:confirmPay', Law.Justice.FinePublic(row), 12000)
    if answer ~= true then return Law.Result(false, 'declined') end

    -- nach dem Warten alles neu pruefen
    tctx = Law.Ctx(targetSrc)
    if not tctx or tctx.charId ~= tonumber(row.charid) then return Law.Result(false, 'no_target') end
    if not Law.IsNear(src, targetSrc, dist) then return Law.Result(false, 'too_far') end
    local res = settle(targetSrc, tctx, id, ctx)
    if res.ok then Law.Notify(targetSrc, L('fine_paid_ok', tonumber(row.amount) or 0), 'success') end
    return res
end)

--------------------------------------------------------------------------
-- Dienstbuch
--------------------------------------------------------------------------
Law.Cb.Register('fines:list', { perm = 'records_view', duty = false, rate = 800 }, function(src, ctx, status)
    status = Law.ToStr(status, 12) or 'unpaid'
    local rows
    if status == 'unpaid' then
        rows = MySQL.query.await("SELECT * FROM ara_law_fines WHERE status IN ('open','overdue') ORDER BY id DESC LIMIT 100")
    elseif VALID_STATUS[status] then
        rows = MySQL.query.await('SELECT * FROM ara_law_fines WHERE status = ? ORDER BY id DESC LIMIT 100', { status })
    else
        rows = MySQL.query.await('SELECT * FROM ara_law_fines ORDER BY id DESC LIMIT 100')
    end
    local out = {}
    for _, r in ipairs(rows or {}) do out[#out + 1] = Law.Justice.FinePublic(r) end
    return Law.Result(true, out)
end)

Law.Cb.Register('fines:cancel', { perm = 'fine_cancel', rate = 1000 }, function(src, ctx, id)
    id = Law.ToInt(id, 1)
    if not id then return Law.Result(false, 'invalid') end
    local row = MySQL.single.await('SELECT charid, status, amount FROM ara_law_fines WHERE id = ?', { id })
    if not row then return Law.Result(false, 'not_found') end
    -- eigene Bussgelder (auch die eines Zweitcharakters) storniert niemand selbst
    if Law.IsSelfOrAlt(ctx, row.charid) then return Law.Result(false, 'self_target') end
    local affected = MySQL.update.await("UPDATE ara_law_fines SET status = 'cancelled' WHERE id = ? AND status IN ('open','overdue')", { id })
    if affected ~= 1 then return Law.Result(false, 'already_done') end
    if row.status == 'overdue' then Law.Justice.RevokeFineWarrants(tonumber(row.charid), id, ctx) end
    Law.Records.Add(row.charid, 'fine', L('record_fine_cancelled', id), nil, ctx, id)
    Law.Audit(ctx, 'fines.cancel', row.charid, { id = id, amount = tonumber(row.amount) })
    local tsrc = Law.SrcByCharId(row.charid)
    if tsrc then Law.Notify(tsrc, L('fine_cancelled_you', id), 'success') end
    return Law.Result(true, { id = id }, L('fine_cancelled'))
end)

--------------------------------------------------------------------------
-- Bescheid lesen (Item)
--------------------------------------------------------------------------
Law.Items.RegisterUsable(Config.Items.FineTicket, function(src, ctx, item)
    local meta = type(item.metadata) == 'table' and item.metadata or {}
    local id = Law.ToInt(meta.fine_id, 1)
    local row = id and MySQL.single.await('SELECT * FROM ara_law_fines WHERE id = ?', { id })
    if not row then return Law.Notify(src, L('fine_ticket_invalid'), 'error') end
    local f = Law.Justice.FinePublic(row)
    local lines = {}
    for _, c in ipairs(f.codes) do lines[#lines + 1] = c.count > 1 and ('%s x%d'):format(c.label, c.count) or c.label end
    TriggerClientEvent('ara_law:cl:fines:showTicket', src, {
        kind = 'ticket',
        title = L('fine_doc_title'),
        subtitle = L('fine_doc_subtitle', f.id),
        fields = {
            { label = L('fine_doc_target'),  value = f.targetName },
            { label = L('fine_doc_amount'),  value = ('%s%s'):format(Config.General.Currency or '$', f.amount) },
            { label = L('fine_doc_status'),  value = f.statusLabel },
            { label = L('fine_doc_issued'),  value = Law.Justice.FormatDate(f.createdAt) },
            { label = L('fine_doc_due'),     value = Law.Justice.FormatDate(f.dueAt) },
            { label = L('fine_doc_officer'), value = f.officerName or '-' },
        },
        body = #lines > 0 and table.concat(lines, '\n') or f.reason,
        footer = f.deptLabel,
        seal = Law.Justice.DeptSeal(row.department),
        signature = f.officerName,
    })
end, { rate = 1500 })

--------------------------------------------------------------------------
-- Faelligkeit
--------------------------------------------------------------------------
local function checkOverdue()
    local rows = MySQL.query.await("SELECT id, charid, department, amount FROM ara_law_fines WHERE status = 'open' AND due_at < ? LIMIT 200", { Law.Now() }) or {}
    for _, r in ipairs(rows) do
        local affected = MySQL.update.await("UPDATE ara_law_fines SET status = 'overdue' WHERE id = ? AND status = 'open'", { r.id })
        if affected == 1 then
            Law.Records.Add(r.charid, 'fine', L('record_fine_overdue', r.id), nil, nil, r.id)
            Law.Audit(nil, 'fines.overdue', r.charid, { id = r.id, amount = tonumber(r.amount) })
            if Config.Fines.AutoWarrantOnOverdue then
                Law.Warrants.CreateAuto(r.charid, L('fine_overdue_reason', r.id), {
                    jailMinutes = Config.Fines.OverdueJailMinutes, codes = { fine_id = r.id }, dept = r.department,
                })
            else
                local tsrc = Law.SrcByCharId(r.charid)
                if tsrc then Law.Notify(tsrc, L('fine_overdue_you', r.id), 'objective', 8000) end
            end
        end
    end
end

Law.Modules.Register('fines', {
    init = function()
        checkOverdue()
        Law.Every((Config.Fines.CheckMinutes or 10) * 60000, checkOverdue)
    end,
    playerLoaded = function(src, ctx)
        local n = MySQL.scalar.await("SELECT COUNT(*) FROM ara_law_fines WHERE charid = ? AND status IN ('open','overdue')", { ctx.charId })
        if (tonumber(n) or 0) > 0 then
            SetTimeout(10000, function()
                if GetPlayerPing(src) > 0 then Law.Notify(src, L('fine_login_notice', tonumber(n)), 'info', 8000) end
            end)
        end
    end,
})
