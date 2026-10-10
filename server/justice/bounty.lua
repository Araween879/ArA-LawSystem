--[[
    ArA-LawSystem - Kopfgeld & Kopfgeldjaeger-Lizenz (Server, Agent A)

    Vertrag 4.1:  Law.Bounty.GetActive(charId) -> [Bounty]
                  Law.Bounty.CanHunt(src)      -> bool (DB, 60 s Cache)
    Schalter:     bounty:licenseStatus · bounty:buyLicense · bounty:searchTarget(name)
                  bounty:placePrivate({ charId, amount, reason, deadOrAlive }) · bounty:minePlaced · bounty:cancelPrivate(id)
    Dienstbuch:   bounty:list(status) · bounty:approve(id) · bounty:cancel(id)
                  bounty:createOfficial(charId, amount, reason, deadOrAlive)   (Formular "bounty_official")
                  bounty:revokeLicense(charId)                                 (Zusatz, Recht license_manage)
    Brett:        bounty:board() -> { posters, bounties, contracts }
    Abgabe:       bounty:claim()

    Geld liegt TREUHAENDERISCH in der Zeile: privat = vom Auftraggeber
    bezahlt, offiziell = aus der Kasse (FundedBy 'society') oder erst bei
    Auszahlung erzeugt ('state'). Die Finanzierungsart steht bei
    offiziellen Kopfgeldern in placed_by_identifier ('society'|'state'),
    damit eine Erstattung auch nach Config-Aenderung richtig laeuft.
    Jede Auszahlung/Erstattung erst nach atomarem Statuswechsel.
]]

Law.Justice = Law.Justice or {}
Law.Bounty  = Law.Bounty or {}

local VALID_STATUS = { pending = true, active = true, claimed = true, cancelled = true, expired = true }
local huntCache = {}  -- [charId] = { ok, t }

--------------------------------------------------------------------------
-- Datenform (Vertrag 10.6 Bounty)
-- full = false: fuer das oeffentliche Brett (kein Auftraggeber sichtbar)
--------------------------------------------------------------------------
function Law.Justice.BountyPublic(r, full)
    local placedBy
    if full then
        placedBy = r.placed_by_name
    elseif r.kind == 'official' then
        placedBy = Law.Justice.DeptLabel(r.department)
    end
    return {
        id           = r.id,
        charId       = tonumber(r.charid),
        targetName   = r.target_name,
        kind         = r.kind,
        kindLabel    = L('bounty_kind_' .. tostring(r.kind)),
        amount       = tonumber(r.amount) or 0,
        reason       = r.reason,
        deadOrAlive  = tonumber(r.dead_or_alive) == 1,
        status       = r.status,
        statusLabel  = L('bounty_status_' .. tostring(r.status)),
        placedByName = placedBy,
        deptLabel    = Law.Justice.DeptLabel(r.department),
        warrantId    = tonumber(r.warrant_id),
        createdAt    = tonumber(r.created_at),
        expiresAt    = tonumber(r.expires_at),
        claimedByName = full and r.claimed_by_name or nil,
    }
end

--------------------------------------------------------------------------
-- Erstattung / Schliessen
--------------------------------------------------------------------------
--- Treuhandgeld zurueck (privat -> Auftraggeber, offiziell/Kasse -> Kasse). -> bool
local function refund(row, actorCtx)
    local amount = tonumber(row.amount) or 0
    if amount <= 0 then return true end
    if row.kind == 'private' then
        local placer = tonumber(row.placed_by)
        if not placer then return true end
        return Law.Justice.PayCharId(placer, amount, 'bounty_refund')
    elseif row.placed_by_identifier == 'society' and Law.GetDept(row.department) then
        return Law.Justice.SocietyAdd(row.department, amount, 'bounty_refund', actorCtx)
    end
    return true -- 'state': es wurde nie Geld hinterlegt
end

--- Kopfgeld schliessen (cancelled/expired) inkl. Erstattung. -> bool, row
--- Scheitert die Erstattung, wird der Status zurueckgesetzt (erneuter Versuch
--- spaeter moeglich, kein Geld verschwindet).
function Law.Justice.CloseBounty(id, newStatus, actorCtx)
    local okR, row = Law.DB.Try(MySQL.single.await, 'SELECT * FROM ara_law_bounties WHERE id = ?', { id })
    if not okR or not row then return false end
    local okU, affected = Law.DB.Try(MySQL.update.await,
        "UPDATE ara_law_bounties SET status = ? WHERE id = ? AND status IN ('pending','active')",
        { newStatus, id })
    if not okU or affected ~= 1 then return false end
    if not refund(row, actorCtx) then
        Law.DB.Try(MySQL.update.await, 'UPDATE ara_law_bounties SET status = ? WHERE id = ? AND status = ?', { row.status, id, newStatus })
        Law.Warn('Kopfgeld #%s: Erstattung fehlgeschlagen - Status zurueckgesetzt', tostring(id))
        return false
    end
    Law.Audit(actorCtx, 'bounty.' .. newStatus, row.charid, { id = id, amount = tonumber(row.amount), kind = row.kind })
    return true, row
end

function Law.Justice.CloseBountiesForWarrant(warrantId, newStatus, actorCtx)
    local rows = MySQL.query.await("SELECT id FROM ara_law_bounties WHERE warrant_id = ? AND status IN ('pending','active')", { warrantId }) or {}
    for _, r in ipairs(rows) do Law.Justice.CloseBounty(r.id, newStatus, actorCtx) end
end

function Law.Justice.CloseBountiesForTarget(charId, newStatus, actorCtx)
    local rows = MySQL.query.await("SELECT id FROM ara_law_bounties WHERE charid = ? AND status IN ('pending','active')", { charId }) or {}
    local n = 0
    for _, r in ipairs(rows) do
        if Law.Justice.CloseBounty(r.id, newStatus, actorCtx) then n = n + 1 end
    end
    return n
end

--------------------------------------------------------------------------
-- Offizielles Kopfgeld anlegen
-- p = { charId, amount, reason, deadOrAlive, warrantId?, status, dept?, actorCtx? }
-- -> id | nil, errCode
--------------------------------------------------------------------------
function Law.Justice.CreateOfficialBounty(p)
    local cfg = Config.Bounty.Official
    local charId = tonumber(p.charId)
    local amount = Law.ToMoney(p.amount, 1, cfg.Max)
    if not charId or not amount then return nil, 'invalid_amount' end
    local dept = (p.dept and Law.GetDept(p.dept)) and p.dept or cfg.SystemDept
    local funding = cfg.FundedBy == 'state' and 'state' or 'society'
    local actor = type(p.actorCtx) == 'table' and p.actorCtx or nil
    -- Ersteller != Ziel, auch nicht ueber einen Zweitcharakter (gleiche Steam-ID)
    if actor and Law.IsSelfOrAlt(actor, charId) then return nil, 'self_target' end

    -- alles, was die DB lesen muss, VOR der Abbuchung aus der Kasse
    local targetName = Law.GetCharName(charId)
    local now = Law.Now()
    local status = (p.status == 'pending') and 'pending' or 'active'
    local reason = Law.ToStr(p.reason, 255) or L('bounty_reason_default')

    if funding == 'society' and not Law.Justice.SocietyRemove(dept, amount, 'bounty_official', actor) then
        return nil, 'society_empty'
    end
    local okI, id = Law.DB.Try(MySQL.insert.await,
        'INSERT INTO ara_law_bounties (charid, target_name, kind, warrant_id, amount, placed_by, placed_by_name, placed_by_identifier, department, reason, dead_or_alive, status, created_at, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { charId, targetName, 'official', tonumber(p.warrantId), amount, actor and actor.charId or nil,
          actor and actor.name or L('system_name'), funding, dept, reason, p.deadOrAlive and 1 or 0, status, now,
          now + (cfg.ExpireDays or 7) * 86400 })
    if not okI or not id then
        if funding == 'society' and not Law.Justice.SocietyAdd(dept, amount, 'bounty_refund', actor) then
            Law.Warn('Kopfgeld: Rueckbuchung an Kasse %s fehlgeschlagen ($%s)', tostring(dept), tostring(amount))
        end
        return nil, 'failed'
    end
    Law.Records.Add(charId, 'bounty', L('record_bounty_official', amount), reason, actor, id)
    Law.Audit(actor, 'bounty.official', charId, { id = id, amount = amount, dept = dept, funding = funding, status = status })
    if status == 'active' then
        local tsrc = Law.SrcByCharId(charId)
        if tsrc then Law.Notify(tsrc, L('bounty_on_you'), 'objective', 8000) end
    end
    return id
end

--------------------------------------------------------------------------
-- Vertrag 4.1
--------------------------------------------------------------------------
function Law.Bounty.GetActive(charId)
    charId = tonumber(charId)
    if not charId then return {} end
    local out = {}
    for _, r in ipairs(MySQL.query.await("SELECT * FROM ara_law_bounties WHERE charid = ? AND status = 'active' ORDER BY id DESC", { charId }) or {}) do
        out[#out + 1] = Law.Justice.BountyPublic(r, false)
    end
    return out
end

local function licenseRow(charId)
    return MySQL.single.await(
        "SELECT id, expires_at FROM ara_law_licenses WHERE charid = ? AND type = 'bounty' AND status = 'active' AND (expires_at IS NULL OR expires_at > ?) ORDER BY id DESC LIMIT 1",
        { charId, Law.Now() })
end

function Law.Bounty.CanHunt(src)
    local ctx = Law.Ctx(src)
    if not ctx then return false end
    local now = Law.Now()
    local c = huntCache[ctx.charId]
    if c and now - c.t < (Config.Bounty.License.CacheSeconds or 60) and (not c.expiresAt or c.expiresAt > now) then
        return c.ok
    end
    local row = licenseRow(ctx.charId)
    huntCache[ctx.charId] = { ok = row ~= nil, t = now, expiresAt = row and tonumber(row.expires_at) or nil }
    return row ~= nil
end

local function licenseChanged(charId)
    huntCache[charId] = nil
    local src = Law.SrcByCharId(charId)
    if src then TriggerClientEvent('ara_law:cl:bounty:license', src, Law.Bounty.CanHunt(src)) end
end

--------------------------------------------------------------------------
-- Lizenz
--------------------------------------------------------------------------
Law.Cb.Register('bounty:licenseStatus', { rate = 800 }, function(src, ctx)
    local row = licenseRow(ctx.charId)
    local cfg = Config.Bounty.License
    return Law.Result(true, {
        active = row ~= nil, expiresAt = row and tonumber(row.expires_at) or nil,
        price = cfg.Price, days = cfg.Days,
    })
end)

Law.Cb.Register('bounty:buyLicense', { rate = 2500, notCuffed = true, notJailed = true, alive = true }, function(src, ctx)
    if not Law.Stations.NearPoint(src, 'counter') then return Law.Result(false, 'not_at_point') end
    local cfg = Config.Bounty.License
    local price = Law.ToMoney(cfg.Price, 0) or 0
    local now = Law.Now()
    local current = licenseRow(ctx.charId)

    if not Law.Money.Take(src, price, 0) then return Law.Result(false, 'no_money') end

    local expires
    local okDb, res
    if current then
        -- Verlaengern ab dem alten Ablaufdatum
        expires = math.max(now, tonumber(current.expires_at) or now) + cfg.Days * 86400
        okDb, res = Law.DB.Try(MySQL.update.await, 'UPDATE ara_law_licenses SET expires_at = ? WHERE id = ?', { expires, current.id })
        okDb = okDb and res == 1
    else
        expires = now + cfg.Days * 86400
        okDb, res = Law.DB.Try(MySQL.insert.await, "INSERT INTO ara_law_licenses (charid, type, status, issued_at, expires_at, issued_by) VALUES (?, 'bounty', 'active', ?, ?, NULL)",
            { ctx.charId, now, expires })
        okDb = okDb and res ~= nil
    end
    if not okDb then
        Law.Justice.GiveBack(src, ctx.charId, price, 'bounty_refund')
        return Law.Result(false, 'failed')
    end

    if price > 0 and not Law.Justice.SocietyAdd(cfg.Department, price, 'license', ctx) then
        Law.Warn('Lizenzgebuehr konnte nicht in Kasse %s gebucht werden', tostring(cfg.Department))
    end
    local meta = { charId = ctx.charId, expiresAt = expires, description = L('license_item_desc', ctx.name, Law.Justice.FormatDate(expires)) }
    local gaveItem = Law.Items.Give(src, Config.Items.BountyLicense, 1, meta)
    licenseChanged(ctx.charId)
    Law.Records.Add(ctx.charId, 'note', L('record_license_bought', Law.Justice.FormatDate(expires)), nil, nil)
    Law.Audit(ctx, 'bounty.license', ctx.charId, { price = price, expires = expires, renewed = current ~= nil })
    local msg = L('license_bought', Law.Justice.FormatDate(expires))
    if not gaveItem then msg = msg .. ' ' .. L('license_no_item') end
    return Law.Result(true, { active = true, expiresAt = expires, price = cfg.Price, days = cfg.Days }, msg)
end)

Law.Cb.Register('bounty:revokeLicense', { perm = 'license_manage', rate = 1500 }, function(src, ctx, charId)
    charId = Law.ToInt(charId, 1)
    if not charId then return Law.Result(false, 'invalid') end
    local affected = MySQL.update.await("UPDATE ara_law_licenses SET status = 'revoked' WHERE charid = ? AND type = 'bounty' AND status = 'active'", { charId })
    if (affected or 0) < 1 then return Law.Result(false, 'no_license') end
    licenseChanged(charId)
    Law.Records.Add(charId, 'note', L('record_license_revoked'), nil, ctx)
    Law.Audit(ctx, 'bounty.license_revoke', charId, {})
    return Law.Result(true, nil, L('license_revoked'))
end)

-- Lizenz vorzeigen (Dokument). Gueltigkeit steht in der DB, nicht im Item.
Law.Items.RegisterUsable(Config.Items.BountyLicense, function(src, ctx, item)
    local meta = type(item.metadata) == 'table' and item.metadata or {}
    local holder = Law.ToInt(meta.charId, 1) or ctx.charId
    local row = MySQL.single.await("SELECT status, expires_at FROM ara_law_licenses WHERE charid = ? AND type = 'bounty' ORDER BY id DESC LIMIT 1", { holder })
    local valid = row ~= nil and row.status == 'active' and (row.expires_at == nil or tonumber(row.expires_at) > Law.Now())
    local dept = Config.Bounty.License.Department
    TriggerClientEvent('ara_law:cl:bounty:showDocument', src, {
        kind = 'license',
        title = L('license_doc_title'),
        subtitle = L('license_doc_subtitle'),
        fields = {
            { label = L('license_doc_holder'), value = Law.GetCharName(holder) },
            { label = L('license_doc_valid_until'), value = row and Law.Justice.FormatDate(row.expires_at) or '-' },
            { label = L('license_doc_status'), value = valid and L('license_doc_valid') or L('license_doc_invalid') },
        },
        body = L('license_doc_body'),
        footer = Law.Justice.DeptLabel(dept),
        seal = Law.Justice.DeptSeal(dept),
    })
end, { rate = 1500 })

--------------------------------------------------------------------------
-- Private Kopfgelder (Schalter)
--------------------------------------------------------------------------
-- Buerger duerfen hier nur gezielt suchen (kein Durchblaettern aller Charaktere)
Law.Cb.Register('bounty:searchTarget', { rate = 3000, notJailed = true }, function(src, ctx, name)
    if not Law.Stations.NearPoint(src, 'counter') then return Law.Result(false, 'not_at_point') end
    name = Law.ToStr(name, 60)
    if not name or utf8.len(name) < 3 then return Law.Result(false, 'query_short3') end
    local rows = MySQL.query.await(
        "SELECT charidentifier, firstname, lastname FROM characters WHERE CONCAT(firstname, ' ', lastname) LIKE ? AND charidentifier <> ? ORDER BY lastname ASC LIMIT 5",
        { '%' .. Law.DB.Like(name) .. '%', ctx.charId }) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = { charId = tonumber(r.charidentifier), name = Law.Justice.RowName(r) } end
    return Law.Result(true, out)
end)

Law.Cb.Register('bounty:placePrivate', { rate = 3000, notCuffed = true, notJailed = true, alive = true }, function(src, ctx, data)
    if type(data) ~= 'table' then return Law.Result(false, 'invalid') end
    local cfg = Config.Bounty.Private
    if not Law.Stations.NearPoint(src, 'counter') then return Law.Result(false, 'not_at_point') end
    local charId = Law.ToInt(data.charId, 1)
    local amount = Law.ToMoney(data.amount, cfg.Min, cfg.Max)
    local reason = Law.ToStr(data.reason, 200)
    local deadOrAlive = Law.ToBool(data.deadOrAlive)
    if not charId or not reason then return Law.Result(false, 'invalid') end
    if not amount then return Law.Result(false, 'invalid_amount') end
    if charId == ctx.charId then return Law.Result(false, 'self_target') end

    local row = Law.Justice.CharRow(charId)
    if not row then return Law.Result(false, 'not_found') end
    -- Anti-Absprache: nicht auf einen eigenen Zweitcharakter
    if Law.IsSelfOrAlt(ctx, charId) then return Law.Result(false, 'same_account') end

    local open = MySQL.scalar.await("SELECT COUNT(*) FROM ara_law_bounties WHERE kind = 'private' AND placed_by = ? AND status IN ('pending','active')", { ctx.charId })
    if (tonumber(open) or 0) >= (cfg.MaxPerPlacer or 5) then return Law.Result(false, 'bounty_limit') end

    local fee = Law.Round(amount * (cfg.FeePercent or 0), 2)
    local total = Law.Round(amount + fee, 2)
    local now = Law.Now()
    local status = cfg.RequireApproval and 'pending' or 'active'
    if not Law.Money.Take(src, total, 0) then return Law.Result(false, 'no_money') end

    local okI, id = Law.DB.Try(MySQL.insert.await,
        'INSERT INTO ara_law_bounties (charid, target_name, kind, warrant_id, amount, placed_by, placed_by_name, placed_by_identifier, department, reason, dead_or_alive, status, created_at, expires_at) VALUES (?, ?, ?, NULL, ?, ?, ?, ?, NULL, ?, ?, ?, ?, ?)',
        { charId, Law.Justice.RowName(row), 'private', amount, ctx.charId, ctx.name, ctx.identifier, reason,
          deadOrAlive and 1 or 0, status, now, now + (cfg.ExpireDays or 7) * 86400 })
    if not okI or not id then
        Law.Justice.GiveBack(src, ctx.charId, total, 'bounty_refund')
        return Law.Result(false, 'failed')
    end
    if fee > 0 and not Law.Justice.SocietyAdd(cfg.FeeDepartment, fee, 'bounty_fee', ctx) then
        Law.Warn('Kopfgeld-Gebuehr konnte nicht in Kasse %s gebucht werden', tostring(cfg.FeeDepartment))
    end
    Law.Records.Add(charId, 'bounty', L('record_bounty_private', amount), reason, nil, id)
    Law.Audit(ctx, 'bounty.private', charId, { id = id, amount = amount, fee = fee, status = status })
    if status == 'pending' then
        Law.NotifyLaw(L('bounty_pending_notice', Law.Justice.RowName(row), amount), 'bounty_manage')
    else
        local tsrc = Law.SrcByCharId(charId)
        if tsrc then Law.Notify(tsrc, L('bounty_on_you'), 'objective', 8000) end
    end
    return Law.Result(true, { id = id, status = status, fee = fee }, status == 'pending' and L('bounty_placed_pending', amount, fee) or L('bounty_placed_active', amount, fee))
end)

Law.Cb.Register('bounty:minePlaced', { rate = 800 }, function(src, ctx)
    local out = {}
    for _, r in ipairs(MySQL.query.await("SELECT * FROM ara_law_bounties WHERE kind = 'private' AND placed_by = ? ORDER BY id DESC LIMIT 30", { ctx.charId }) or {}) do
        out[#out + 1] = Law.Justice.BountyPublic(r, true)
    end
    return Law.Result(true, out)
end)

Law.Cb.Register('bounty:cancelPrivate', { rate = 2000, notJailed = true }, function(src, ctx, id)
    id = Law.ToInt(id, 1)
    if not id then return Law.Result(false, 'invalid') end
    if not Law.Stations.NearPoint(src, 'counter') then return Law.Result(false, 'not_at_point') end
    local row = MySQL.single.await("SELECT * FROM ara_law_bounties WHERE id = ? AND kind = 'private' AND placed_by = ?", { id, ctx.charId })
    if not row then return Law.Result(false, 'not_found') end
    local affected = MySQL.update.await(
        "UPDATE ara_law_bounties SET status = 'cancelled' WHERE id = ? AND kind = 'private' AND placed_by = ? AND status IN ('pending','active')",
        { id, ctx.charId })
    if affected ~= 1 then return Law.Result(false, 'already_done') end
    -- Erstattung ohne Gebuehr; scheitert sie, Status zuruecksetzen (kein Geldverlust)
    local amount = tonumber(row.amount) or 0
    if not Law.Justice.GiveBack(src, ctx.charId, amount, 'bounty_refund') then
        Law.DB.Try(MySQL.update.await, "UPDATE ara_law_bounties SET status = ? WHERE id = ? AND status = 'cancelled'", { row.status, id })
        return Law.Result(false, 'failed')
    end
    Law.Records.Add(row.charid, 'bounty', L('record_bounty_cancelled', id), nil, nil, id)
    Law.Audit(ctx, 'bounty.cancel_private', row.charid, { id = id, amount = amount })
    return Law.Result(true, { id = id, refund = amount }, L('bounty_cancelled_refund', amount))
end)

--------------------------------------------------------------------------
-- Dienstbuch
--------------------------------------------------------------------------
Law.Cb.Register('bounty:list', { perm = 'records_view', duty = false, rate = 800 }, function(src, ctx, status)
    status = Law.ToStr(status, 12) or 'open'
    local rows
    if status == 'open' then
        rows = MySQL.query.await("SELECT * FROM ara_law_bounties WHERE status IN ('pending','active') ORDER BY id DESC LIMIT 100")
    elseif VALID_STATUS[status] then
        rows = MySQL.query.await('SELECT * FROM ara_law_bounties WHERE status = ? ORDER BY id DESC LIMIT 100', { status })
    else
        rows = MySQL.query.await('SELECT * FROM ara_law_bounties ORDER BY id DESC LIMIT 100')
    end
    local out = {}
    for _, r in ipairs(rows or {}) do out[#out + 1] = Law.Justice.BountyPublic(r, true) end
    return Law.Result(true, out)
end)

Law.Cb.Register('bounty:approve', { perm = 'bounty_manage', rate = 1000 }, function(src, ctx, id)
    id = Law.ToInt(id, 1)
    if not id then return Law.Result(false, 'invalid') end
    local row = MySQL.single.await('SELECT charid, placed_by, placed_by_identifier FROM ara_law_bounties WHERE id = ?', { id })
    if not row then return Law.Result(false, 'not_found') end
    -- Niemand gibt sein eigenes Kopfgeld frei - und keines auf sich/Zweitchar
    if tonumber(row.placed_by) == ctx.charId or row.placed_by_identifier == ctx.identifier
        or (tonumber(row.placed_by) and Law.IsSelfOrAlt(ctx, row.placed_by))
        or Law.IsSelfOrAlt(ctx, row.charid) then
        return Law.Result(false, 'self_target')
    end
    local affected = MySQL.update.await("UPDATE ara_law_bounties SET status = 'active' WHERE id = ? AND status = 'pending'", { id })
    if affected ~= 1 then return Law.Result(false, 'already_done') end
    Law.Records.Add(row.charid, 'bounty', L('record_bounty_approved', id), nil, ctx, id)
    Law.Audit(ctx, 'bounty.approve', row.charid, { id = id })
    local tsrc = Law.SrcByCharId(row.charid)
    if tsrc then Law.Notify(tsrc, L('bounty_on_you'), 'objective', 8000) end
    return Law.Result(true, { id = id }, L('bounty_approved'))
end)

Law.Cb.Register('bounty:cancel', { perm = 'bounty_manage', rate = 1000 }, function(src, ctx, id)
    id = Law.ToInt(id, 1)
    if not id then return Law.Result(false, 'invalid') end
    local target = MySQL.scalar.await('SELECT charid FROM ara_law_bounties WHERE id = ?', { id })
    if not target then return Law.Result(false, 'not_found') end
    -- kein Stornieren von Kopfgeldern auf sich selbst / den Zweitchar
    if Law.IsSelfOrAlt(ctx, target) then return Law.Result(false, 'self_target') end
    local ok, row = Law.Justice.CloseBounty(id, 'cancelled', ctx)
    if not ok then return Law.Result(false, 'already_done') end
    Law.Records.Add(row.charid, 'bounty', L('record_bounty_cancelled', id), nil, ctx, id)
    return Law.Result(true, { id = id }, L('bounty_cancelled'))
end)

Law.Cb.Register('bounty:createOfficial', { perm = 'bounty_manage', rate = 2000 }, function(src, ctx, charId, amount, reason, deadOrAlive)
    charId = Law.ToInt(charId, 1)
    amount = Law.ToMoney(amount, 1, Config.Bounty.Official.Max)
    reason = Law.ToStr(reason, 200)
    if not charId or not reason then return Law.Result(false, 'invalid') end
    if not amount then return Law.Result(false, 'invalid_amount') end
    if not Law.Justice.CharRow(charId) then return Law.Result(false, 'not_found') end
    -- Steam-ID Ziel != Steam-ID Ersteller (M3)
    if Law.IsSelfOrAlt(ctx, charId) then return Law.Result(false, 'self_target') end
    local warrant = MySQL.single.await("SELECT id FROM ara_law_warrants WHERE charid = ? AND status = 'active' ORDER BY id DESC LIMIT 1", { charId })
    local id, err = Law.Justice.CreateOfficialBounty({
        charId = charId, amount = amount, reason = reason, deadOrAlive = Law.ToBool(deadOrAlive),
        warrantId = warrant and warrant.id or nil, status = 'active', dept = ctx.dept, actorCtx = ctx,
    })
    if not id then return Law.Result(false, err or 'failed') end
    return Law.Result(true, { id = id }, L('bounty_official_created', amount))
end)

--------------------------------------------------------------------------
-- Steckbriefbrett
--------------------------------------------------------------------------
Law.Cb.Register('bounty:board', { rate = 1000 }, function(src, ctx)
    if not Law.Stations.NearPoint(src, 'board', Config.Bounty.BoardDistance or 5.0) then
        return Law.Result(false, 'not_at_point')
    end
    local rows = MySQL.query.await("SELECT * FROM ara_law_bounties WHERE status = 'active' ORDER BY amount DESC LIMIT 100") or {}
    local bounties, byChar, order = {}, {}, {}
    for _, r in ipairs(rows) do
        bounties[#bounties + 1] = Law.Justice.BountyPublic(r, false)
        local cid = tonumber(r.charid)
        local p = byChar[cid]
        if not p then
            p = { charId = cid, name = r.target_name, reason = r.reason, amount = 0, deadOrAlive = false, crimes = {},
                  deptLabel = nil, createdAt = tonumber(r.created_at) }
            byChar[cid] = p
            order[#order + 1] = cid
        end
        p.amount = p.amount + (tonumber(r.amount) or 0)
        if tonumber(r.dead_or_alive) == 1 then p.deadOrAlive = true end
        if r.kind == 'official' and not p.deptLabel then p.deptLabel = Law.Justice.DeptLabel(r.department) end
        if tonumber(r.created_at) < p.createdAt then p.createdAt = tonumber(r.created_at) end
    end

    -- Delikte der Plakate aus den aktiven Haftbefehlen
    if #order > 0 then
        local q = ("SELECT charid, reason FROM ara_law_warrants WHERE status = 'active' AND charid IN (%s) ORDER BY id DESC"):format(Law.Justice.Placeholders(#order))
        for _, w in ipairs(MySQL.query.await(q, order) or {}) do
            local p = byChar[tonumber(w.charid)]
            if p and #p.crimes < 6 then p.crimes[#p.crimes + 1] = w.reason end
        end
    end

    local posters = {}
    for _, cid in ipairs(order) do
        local p = byChar[cid]
        p.amount = Law.Round(p.amount, 2)
        if #p.crimes == 0 then p.crimes[1] = p.reason end
        p.deptLabel = p.deptLabel or L('bounty_private_poster')
        posters[#posters + 1] = p
        if #posters >= 30 then break end
    end

    return Law.Result(true, { posters = posters, bounties = bounties, contracts = Law.Justice.NpcBoard(src) })
end)

--------------------------------------------------------------------------
-- Abliefern an der Abgabestelle
--------------------------------------------------------------------------
local function pairLocked(hunterCharId, targetCharId)
    local since = Law.Now() - (Config.Bounty.Claim.PairCooldownHours or 24) * 3600
    local n = MySQL.scalar.await("SELECT COUNT(*) FROM ara_law_bounties WHERE claimed_by = ? AND charid = ? AND status = 'claimed' AND claimed_at >= ?",
        { hunterCharId, targetCharId, since })
    return (tonumber(n) or 0) > 0
end

--- Welche aktiven Kopfgelder darf dieser Jaeger bei diesem Ziel einloesen?
--- -> rows, errCode
--- isLaw: Gesetz im Dienst - private Kopfgelder nur mit Config LawGetsPrivate
local function eligible(ctx, tctx, dead, isLaw)
    local cfg = Config.Bounty
    local rows = MySQL.query.await("SELECT * FROM ara_law_bounties WHERE charid = ? AND status = 'active'", { tctx.charId }) or {}
    if #rows == 0 then return {}, 'no_bounty' end
    if pairLocked(ctx.charId, tctx.charId) then return {}, 'pair_cooldown' end
    local minAge = (cfg.Private.MinAgeMinutes or 10) * 60
    local now = Law.Now()
    local out, err = {}, 'no_bounty'
    for _, r in ipairs(rows) do
        local placer = tonumber(r.placed_by)
        -- Steam-ID des Auftraggebers: privat steht sie in der Zeile, offiziell
        -- wird sie ueber den erstellenden Beamten nachgeschlagen (M3)
        local ident = r.kind == 'private' and r.placed_by_identifier or (placer and Law.IdentifierOf(placer)) or nil
        if placer == ctx.charId or (ident and ident == ctx.identifier) then
            err = 'own_bounty'
        elseif placer == tctx.charId or (ident and ident == tctx.identifier) then
            err = 'own_bounty'
        elseif isLaw and r.kind == 'private' and not cfg.Claim.LawGetsPrivate then
            err = 'law_private'
        elseif now - (tonumber(r.created_at) or now) < minAge then
            err = 'bounty_too_young'
        elseif dead and tonumber(r.dead_or_alive) ~= 1 then
            err = 'dead_not_allowed'
        else
            out[#out + 1] = r
        end
    end
    return out, err
end

Law.Cb.Register('bounty:claim', { rate = 3000, notCuffed = true, notJailed = true, alive = true }, function(src, ctx)
    local cfg = Config.Bounty.Claim
    local stationKey, point = Law.Stations.NearPoint(src, 'dropoff')
    if not stationKey or not point then return Law.Result(false, 'not_at_point') end
    -- Behoerdenmitglied gilt IMMER als Gesetz, auch ausser Dienst: sonst
    -- koennte ein Beamter im Dienst per Amtsrecht fesseln, ausstempeln, eine
    -- Lizenz kaufen und das (Kassen-)Kopfgeld privat kassieren.
    local isLaw = ctx.dept ~= nil
    if not isLaw and not Law.Bounty.CanHunt(src) then return Law.Result(false, 'no_license') end

    local center, radius = Law.Vec(point.coords), (point.radius or 8.0)
    local lastErr = 'no_target'
    for _, t in ipairs(Law.GetPlayersInRadius(center, radius)) do
        if t ~= src then
            local near = Law.IsNear(src, t, cfg.HunterRadius or 10.0)
            local tctx = near and Law.Ctx(t)
            if tctx then
                local dead = tctx.isDead == true
                local cuffedBy = Law.State.cuffed[t]
                local escortBy = Law.State.escortedBy[t]
                -- Nur eigene Gefangene: gefesselt oder abgefuehrt vom Einloesenden (K1)
                local mine = cuffedBy == src or escortBy == src
                local foreign = (cuffedBy ~= nil and cuffedBy ~= src) or (escortBy ~= nil and escortBy ~= src)
                if not dead and not cuffedBy then
                    lastErr = 'target_not_cuffed'
                elseif (not dead and not mine) or (dead and foreign) then
                    lastErr = 'target_not_yours'
                else
                    local rows, err = eligible(ctx, tctx, dead, isLaw)
                    if #rows == 0 then
                        lastErr = err
                    else
                        -- Atomar einloesen - erst danach Geld
                        local now, total, claimed, claimedRows = Law.Now(), 0, {}, {}
                        for _, r in ipairs(rows) do
                            local okU, affected = Law.DB.Try(MySQL.update.await,
                                "UPDATE ara_law_bounties SET status = 'claimed', claimed_by = ?, claimed_by_name = ?, claimed_at = ? WHERE id = ? AND status = 'active'",
                                { ctx.charId, ctx.name, now, r.id })
                            if okU and affected == 1 then
                                total = total + (tonumber(r.amount) or 0)
                                claimed[#claimed + 1] = r.id
                                claimedRows[#claimedRows + 1] = r
                            end
                        end
                        if #claimed == 0 then return Law.Result(false, 'already_done') end
                        total = Law.Round(total, 2)

                        -- Auszahlung: Gesetz im Dienst verdient an offiziellen Kopfgeldern
                        -- nichts - das Treuhandgeld geht zurueck in die Kasse.
                        local toHunter, toSociety = 0, 0
                        for _, r in ipairs(claimedRows) do
                            local amount = tonumber(r.amount) or 0
                            if isLaw and r.kind == 'official' then
                                if r.placed_by_identifier == 'society' and Law.GetDept(r.department) then
                                    if Law.Justice.SocietyAdd(r.department, amount, 'bounty_return', ctx) then
                                        toSociety = toSociety + amount
                                    else
                                        -- Geld darf nicht verschwinden: diese Zeile bleibt aktiv
                                        Law.DB.Try(MySQL.update.await,
                                            "UPDATE ara_law_bounties SET status = 'active', claimed_by = NULL, claimed_by_name = NULL, claimed_at = NULL WHERE id = ? AND status = 'claimed'", { r.id })
                                        Law.Warn('Kopfgeld #%s: Rueckbuchung an Kasse %s fehlgeschlagen - bleibt aktiv', tostring(r.id), tostring(r.department))
                                    end
                                end
                            else
                                toHunter = toHunter + amount
                            end
                        end
                        toHunter = Law.Round(toHunter, 2)
                        if toHunter > 0 and not Law.Justice.GiveBack(src, ctx.charId, toHunter, 'bounty_reward') then
                            -- Auszahlung unmoeglich -> Einloesung zuruecknehmen, Geld bleibt treuhaenderisch
                            for _, id in ipairs(claimed) do
                                Law.DB.Try(MySQL.update.await,
                                    "UPDATE ara_law_bounties SET status = 'active', claimed_by = NULL, claimed_by_name = NULL, claimed_at = NULL WHERE id = ? AND status = 'claimed'", { id })
                            end
                            return Law.Result(false, 'failed')
                        end

                        Law.Records.Add(tctx.charId, 'bounty', L('record_bounty_claimed', total, ctx.name), nil, isLaw and ctx or nil, claimed[1])
                        Law.Audit(ctx, 'bounty.claim', tctx.charId, {
                            ids = table.concat(claimed, ','), amount = total, hunter = toHunter, society = Law.Round(toSociety, 2),
                            dead = dead, station = stationKey, law = isLaw,
                        })

                        -- Ziel in Haft (tot: vorher wiederbeleben)
                        if not dead or cfg.DeadGoesToJail then
                            local w = MySQL.scalar.await("SELECT MAX(jail_minutes) FROM ara_law_warrants WHERE charid = ? AND status = 'active'", { tctx.charId })
                            local minutes = math.max(tonumber(w) or 0, 0)
                            if minutes <= 0 then minutes = cfg.DefaultJailMinutes or 15 end
                            if dead then Law.VORP.Player.Revive(t) end
                            local jailDept
                            for _, r in ipairs(rows) do
                                if r.kind == 'official' and Law.GetDept(r.department) then jailDept = r.department break end
                            end
                            local okJail, jailErr = Law.Jail.Sentence(t, minutes, L('jail_reason_bounty', ctx.name), ctx, {
                                location = Config.Jail.StationLocation[stationKey], dept = jailDept,
                            })
                            if not okJail then Law.Warn('Kopfgeld-Haft fehlgeschlagen fuer %s: %s', tostring(tctx.charId), tostring(jailErr)) end
                        end

                        Law.Dispatch.Create({
                            kind = 'bounty', coords = center, priority = 1, expires = 300,
                            title = L('dispatch_title_bounty_claim'),
                            text = L('bounty_claim_dispatch', ctx.name, tctx.name, Config.Stations[stationKey] and Config.Stations[stationKey].label or stationKey),
                        })
                        Law.Notify(t, L('bounty_claimed_you', ctx.name), 'objective', 8000)
                        local msg = toHunter > 0 and L('bounty_claim_ok', toHunter, tctx.name) or L('bounty_claim_law', Law.Round(toSociety, 2), tctx.name)
                        return Law.Result(true, { amount = toHunter, returned = Law.Round(toSociety, 2), ids = claimed }, msg)
                    end
                end
            end
        end
    end
    return Law.Result(false, lastErr)
end)

--------------------------------------------------------------------------
-- Ablauf (Kopfgelder und Lizenzen)
--------------------------------------------------------------------------
local function expire()
    local now = Law.Now()
    local rows = MySQL.query.await(
        "SELECT id, charid FROM ara_law_bounties WHERE status IN ('pending','active') AND expires_at IS NOT NULL AND expires_at < ? LIMIT 200",
        { now }) or {}
    for _, r in ipairs(rows) do
        if Law.Justice.CloseBounty(r.id, 'expired', nil) then
            Law.Records.Add(r.charid, 'bounty', L('record_bounty_expired', r.id), nil, nil, r.id)
        end
    end
    local n = MySQL.update.await("UPDATE ara_law_licenses SET status = 'expired' WHERE status = 'active' AND expires_at IS NOT NULL AND expires_at < ?", { now })
    if (n or 0) > 0 then huntCache = {} end
end

Law.Modules.Register('bounty', {
    init = function()
        expire()
        Law.Every(10 * 60000, expire)
    end,
    playerLoaded = function(src, ctx)
        huntCache[ctx.charId] = nil
        TriggerClientEvent('ara_law:cl:bounty:license', src, Law.Bounty.CanHunt(src))
    end,
    playerDropped = function(src, cache)
        if cache and cache.charId then huntCache[cache.charId] = nil end
    end,
})
