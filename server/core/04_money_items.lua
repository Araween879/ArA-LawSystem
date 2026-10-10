--[[
    ArA-LawSystem - Geld und Items (Server)

    Module benutzen NUR diese Funktionen, nie die vorp-Exports direkt fuer
    Geld/Items. Grund (im vorp_inventory-Quelltext geprueft):
      - subItem mit Metadaten und subItemById pruefen NICHT, ob genug Stueck
        da sind (quitCount kann ins Minus laufen) -> hier wird vorher gezaehlt.
      - getUsedCharacter ist ein Schnappschuss -> Geld wird direkt vor dem
        Abziehen frisch gelesen, ohne Wait/await dazwischen.
]]

Law.Money = Law.Money or {}
Law.Items = Law.Items or {}

local CURRENCY_FIELD = { [0] = 'money', [1] = 'gold' }

--------------------------------------------------------------------------
-- Geld (0 = Dollar, 1 = Gold)
--------------------------------------------------------------------------
function Law.Money.Get(src, currency)
    currency = currency or 0
    local user = Law.VORP.getUser(src)
    if not user then return 0 end
    local char = user.getUsedCharacter
    return tonumber(char and char[CURRENCY_FIELD[currency] or 'money']) or 0
end

function Law.Money.Take(src, amount, currency)
    currency = currency or 0
    amount = Law.ToMoney(amount, 0)
    if not amount or not CURRENCY_FIELD[currency] then return false end
    if amount == 0 then return true end
    local user = Law.VORP.getUser(src)
    if not user then return false end
    local char = user.getUsedCharacter
    if not char or (tonumber(char[CURRENCY_FIELD[currency]]) or 0) < amount then return false end
    char.removeCurrency(currency, amount)
    return true
end

function Law.Money.Give(src, amount, currency)
    currency = currency or 0
    amount = Law.ToMoney(amount, 0)
    if not amount or not CURRENCY_FIELD[currency] then return false end
    if amount == 0 then return true end
    local user = Law.VORP.getUser(src)
    if not user then return false end
    local char = user.getUsedCharacter
    if not char or not char.addCurrency then return false end
    char.addCurrency(currency, amount)
    return true
end

--- Geld an einen Charakter - online sofort, offline beim naechsten Login.
--- Rueckgabe: true (ausgezahlt oder sicher vorgemerkt)
function Law.Money.GiveCharId(charId, amount, currency, reason)
    charId = tonumber(charId)
    currency = currency or 0
    amount = Law.ToMoney(amount, 0)
    if not charId or not amount or not CURRENCY_FIELD[currency] then return false end
    if amount == 0 then return true end
    local src = Law.SrcByCharId(charId)
    -- Frisch pruefen: der Kern-Cache kann direkt nach einer Charakterwahl
    -- noch den vorherigen Charakter derselben src enthalten
    local live = src and Law.Ctx(src)
    if live and live.charId == charId and Law.Money.Give(src, amount, currency) then
        return true
    end
    MySQL.insert.await('INSERT INTO ara_law_payouts (charid, amount, currency, reason, created_at) VALUES (?, ?, ?, ?, ?)',
        { charId, amount, currency, (reason or ''):sub(1, 64), Law.Now() })
    return true
end

--- Offene Auszahlungen beim Login. Jede Zeile wird ERST geloescht und nur
--- bei affectedRows == 1 ausgezahlt -> keine doppelte Auszahlung, auch wenn
--- das zweimal gleichzeitig laeuft.
function Law.Money.PayPending(src, charId)
    local rows = MySQL.query.await('SELECT id, amount, currency, reason FROM ara_law_payouts WHERE charid = ?', { charId }) or {}
    for _, r in ipairs(rows) do
        -- Charakter gewechselt waehrend der Schleife? Dann nicht an den falschen zahlen
        local live = Law.Ctx(src)
        if not live or live.charId ~= charId then return end
        local affected = MySQL.update.await('DELETE FROM ara_law_payouts WHERE id = ?', { r.id })
        if affected == 1 then
            local currency = tonumber(r.currency) or 0
            if Law.Money.Give(src, tonumber(r.amount), currency) then
                Law.Notify(src, L(currency == 1 and 'payout_received_gold' or 'payout_received', tonumber(r.amount),
                    L('payout_reason_' .. (r.reason ~= '' and r.reason or 'other'))), 'success')
            else
                -- zurueck in die Tabelle, naechster Login versucht es erneut
                MySQL.insert.await('INSERT INTO ara_law_payouts (charid, amount, currency, reason, created_at) VALUES (?, ?, ?, ?, ?)',
                    { charId, r.amount, r.currency, r.reason, Law.Now() })
            end
        end
    end
end

--------------------------------------------------------------------------
-- Items
--------------------------------------------------------------------------
function Law.Items.Count(src, name, metadata)
    local n = Law.Inv:getItemCount(src, nil, name, metadata)
    return tonumber(n) or 0
end

function Law.Items.Has(src, name, amount, metadata)
    return Law.Items.Count(src, name, metadata) >= (amount or 1)
end

function Law.Items.Take(src, name, amount, metadata)
    amount = Law.ToInt(amount or 1, 1)
    if not amount then return false end
    if Law.Items.Count(src, name, metadata) < amount then return false end
    return Law.Inv:subItem(src, name, amount, metadata) == true
end

function Law.Items.Give(src, name, amount, metadata)
    amount = Law.ToInt(amount or 1, 1)
    if not amount then return false end
    if not Law.Inv:canCarryItem(src, name, amount) then return false end
    local ok = Law.Inv:addItem(src, name, amount, metadata)
    return ok ~= false
end

--- { id, name, label, metadata, count, ... } | nil
function Law.Items.GetById(src, itemId)
    itemId = Law.ToInt(itemId, 1)
    if not itemId then return nil end
    return Law.Inv:getItemById(src, itemId)
end

function Law.Items.TakeById(src, itemId, amount)
    amount = Law.ToInt(amount or 1, 1)
    local item = Law.Items.GetById(src, itemId)
    if not amount or not item or (tonumber(item.count) or 0) < amount then return false end
    return Law.Inv:subItemById(src, item.id, nil, nil, amount) == true
end

--- Metadaten eines Items ersetzen (Anzahl 1)
function Law.Items.SetMetadata(src, itemId, metadata)
    local item = Law.Items.GetById(src, itemId)
    if not item then return false end
    Law.Inv:setItemMetadata(src, item.id, metadata, 1)
    return true
end

--- Benutzbares Item registrieren.
--- handler(src, ctx, item) - item = { id, name, label, metadata, ... }
--- opts wie Law.Net.On (perm, duty, law, rate, notCuffed, notJailed, alive)
---
--- Beim Laden wird nur vorgemerkt. Wirklich bei vorp_inventory angemeldet
--- wird in Law.Items.ApplyUsable() (server/zz_boot.lua) - dann ist sicher,
--- dass vorp_inventory seine Items geladen hat. Startet vorp_inventory neu,
--- meldet der Kern alles erneut an.
local usable = {}

local function applyOne(name, handler, opts)
    Law.Inv:registerUsableItem(name, function(data)
        local src = data.source
        Law.Inv:closeInventory(src)

        local ctx = Law.Ctx(src)
        if not ctx then return end
        if not Law.RateLimit(src, 'item:' .. name, opts.rate or 1000) then return end

        local needDuty = opts.duty
        if needDuty == nil then needDuty = opts.perm ~= nil and Config.General.RequireDuty end
        if (opts.law or opts.perm) and not ctx.dept then
            return Law.Notify(src, L('err_not_law'), 'error')
        end
        if needDuty and not ctx.onDuty then
            return Law.Notify(src, L('err_not_on_duty'), 'error')
        end
        if opts.perm and not Law.GradeHasPerm(ctx.job, ctx.grade, opts.perm) then
            return Law.Notify(src, L('err_no_permission'), 'error')
        end
        if opts.notCuffed and Law.IsCuffed(src) then return Law.Notify(src, L('err_cuffed'), 'error') end
        if opts.notJailed and Law.IsJailed(src) then return Law.Notify(src, L('err_jailed'), 'error') end
        if opts.alive and ctx.isDead then return end

        local ok, err = xpcall(handler, debug.traceback, src, ctx, data.item or {})
        if not ok then Law.Warn('Fehler in Item %s: %s', name, tostring(err)) end
    end, GetCurrentResourceName())
end

function Law.Items.RegisterUsable(name, handler, opts)
    if usable[name] then
        Law.Warn('Item %s doppelt als benutzbar angemeldet - letzte Anmeldung gilt', tostring(name))
    end
    usable[name] = { handler = handler, opts = opts or {} }
end

function Law.Items.ApplyUsable()
    for name, u in pairs(usable) do
        applyOne(name, u.handler, u.opts)
    end
end

function Law.Items.UnregisterAll()
    for name in pairs(usable) do
        pcall(function() Law.Inv:unRegisterUsableItem(name) end)
    end
end

--- Beim Start: fehlen Items in der DB? (sql/items.sql nicht eingespielt)
function Law.Items.CheckDefinitions()
    local missing = {}
    for _, name in pairs(Config.Items) do
        local def = Law.Inv:getItemDB(name)
        if not def then missing[#missing + 1] = name end
    end
    if #missing > 0 then
        Law.Warn('Items fehlen in der Tabelle `items`: %s -> sql/items.sql einspielen und Server neu starten', table.concat(missing, ', '))
    end
end
