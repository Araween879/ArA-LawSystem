--[[
    ArA-LawSystem - Eskorte: Ware, Abholfach, Beutefach, Panzerwagen (Server)

    Ware liegt treuhaenderisch als JSON in ara_law_escorts.cargo. Sie wird
    erst NACH einem atomaren Statuswechsel in ein vorp-Custom-Inventar
    gelegt (Abholfach ara_law_escort_<id> bzw. Beutefach
    ara_law_escort_loot_<id>).

    Die Faecher sind NICHT geteilt (shared = false): vorp speichert jedes
    Item mit der charId des Berechtigten und zeigt jedem Charakter nur seine
    eigenen Items. Hineinlegen ist gesperrt (sonst entstuende ein Lager, das
    nach einem Neustart niemand mehr oeffnet).

    vorp-Hinweis (Quelltext geprueft): AddCharIdPermissionTakeFromCustom /
    ...MoveToCustom kehren in dieser vorp-Version bei aktivierten Rechten
    sofort zurueck (Logikfehler in canContinue) - deshalb werden die Rechte
    ueber updateCustomInventoryData gesetzt.
]]

Law.Escort = Law.Escort or {}
local ES = Law.Escort
local ECfg = Config.Escort

local registered = {}  -- [invId] = true (fuer das Aufraeumen)

function ES.FachId(id) return 'ara_law_escort_' .. tostring(id) end
function ES.LootId(id) return 'ara_law_escort_loot_' .. tostring(id) end

--------------------------------------------------------------------------
-- Ware (Whitelist mit Werten und Beschriftung aus der Item-DB)
--------------------------------------------------------------------------
function ES.BuildCargoItems()
    local out = {}
    for name, def in pairs(ECfg.CargoItems or {}) do
        local db = Law.Inv:getItemDB(name)
        if db then
            local label = type(db) == 'table' and type(db.label) == 'string' and db.label or name
            out[name] = { value = tonumber(def.value) or 0, label = label }
        else
            Law.Warn('Eskorte: Ware "%s" fehlt in der Tabelle items - ausgeblendet', tostring(name))
        end
    end
    ES.CargoItemsMap = out
    return out
end

function ES.GetCargoItems()
    return ES.CargoItemsMap or ES.BuildCargoItems()
end

--- Ware eines Auftrags: { { name, amount }, ... } (nur gueltige Eintraege)
function ES.CargoList(r)
    local list = Law.DB.Decode(r and r.cargo, {})
    local out = {}
    if type(list) ~= 'table' then return out end
    for _, e in ipairs(list) do
        if type(e) == 'table' and type(e.name) == 'string' then
            local amount = math.floor(tonumber(e.amount) or 0)
            if amount > 0 then out[#out + 1] = { name = e.name, amount = amount } end
        end
    end
    return out
end

local function totalAmount(items)
    local n = 0
    for _, e in ipairs(items) do n = n + e.amount end
    return n
end

--------------------------------------------------------------------------
-- Faecher (vorp-Custom-Inventare)
--------------------------------------------------------------------------
function ES.EnsureInv(invId, label, slots)
    slots = math.max(tonumber(slots) or 50, 10)
    if not Law.Inv:isCustomInventoryRegistered(invId) then
        Law.Inv:registerInventory({
            id = invId,
            name = label,
            limit = slots,
            acceptWeapons = false,
            shared = false,
            ignoreItemStackLimit = true,
            whitelistItems = false,
            UsePermissions = true,
            UseBlackList = false,
            whitelistWeapons = false,
        })
        -- Hineinlegen fuer alle sperren (Job, den es nicht gibt)
        Law.Inv:updateCustomInventoryData(invId, { PermissionMoveTo = { ara_law_nobody = 99 } })
    else
        local cur = Law.Inv:getCustomInventorySlots(invId)
        if cur and tonumber(cur) and tonumber(cur) < slots then Law.Inv:updateCustomInventorySlots(invId, slots) end
    end
    registered[invId] = true
end

--- Items einem Charakter ins Fach legen. true = erledigt (oder nichts zu tun)
---
--- vorp (Quelltext geprueft, inventoryApiService ADD_ITEMS / inventoryService
--- updateItem): addItemsToCustomInventory(invId, items, charId, cb, identifier)
--- schreibt die Items synchron in die DB (character_id = charId). Den Cache
--- eines NICHT geteilten Fachs aktualisiert vorp aber nur, wenn der
--- identifier mitkommt ("inventory is not shared and you didnt pass
--- identifier") - ohne ihn bliebe ein schon geoeffnetes Fach bis zum Neustart
--- leer. Deshalb immer den identifier des Berechtigten mitgeben.
function ES.PutItems(invId, label, items, charId)
    if #items == 0 then return true end
    ES.EnsureInv(invId, label, totalAmount(items) + 20)
    local identifier = Law.IdentifierOf(charId)
    local okCall, res = Law.DB.Try(function()
        return Law.Inv:addItemsToCustomInventory(invId, items, charId, nil, identifier)
    end)
    return okCall and res == true
end

--- Wartet (max. ~5 s), bis vorp die erwartete Menge im Fach sieht
local function waitForItems(invId, expect)
    if type(expect) ~= 'table' or #expect == 0 then return true end
    local deadline = GetGameTimer() + 5000
    repeat
        local all = true
        for _, e in ipairs(expect) do
            local ok, n = pcall(function() return Law.Inv:getCustomInventoryItemCount(invId, e.name) end)
            if not ok or (tonumber(n) or 0) < e.amount then
                all = false
                break
            end
        end
        if all then return true end
        Wait(250)
    until GetGameTimer() > deadline
    return false
end

--- Fach oeffnen: erst die NUI schliessen (sonst haette sie den Fokus), dann
--- warten, bis die erwartete Ware im Fach sichtbar ist (statt fester Pause).
--- expect = Liste { name, amount } oder nil (Fach nur erneut oeffnen)
function ES.OpenInv(src, invId, label, expect)
    ES.EnsureInv(invId, label, 500)
    TriggerClientEvent('ara_law:cl:escort:closeUi', src)
    CreateThread(function()
        if not waitForItems(invId, expect) then
            Law.Warn('Eskorte: Fach %s zeigt die Ware noch nicht - wird trotzdem geoeffnet', tostring(invId))
        end
        Wait(300)
        if GetPlayerPing(src) > 0 then Law.Inv:openInventory(src, invId) end
    end)
end

--- Ware zurueck an den Auftraggeber (Abholfach am Abholbuero).
--- Rueckgabe: true, wenn es Ware gab (Kunde muss sie abholen)
function ES.ReturnGoods(r, charId)
    local items = ES.CargoList(r)
    if #items == 0 then return false end
    if not ES.PutItems(ES.FachId(r.id), L('escort_fach_name', r.id), items, charId) then
        Law.Warn('Eskorte #%s: Ware konnte nicht ins Abholfach gelegt werden (Admin pruefen): %s', tostring(r.id), tostring(r.cargo))
        Law.Audit(nil, 'escort.goods_error', charId, { id = r.id, cargo = r.cargo })
    end
    return true
end

--- Abholung einer Lieferung: atomar delivered -> claimed, erst dann Ware + Geld
function ES.ClaimDelivered(src, ctx, r)
    local affected = MySQL.update.await("UPDATE ara_law_escorts SET status = 'claimed', claimed_at = ?, status_reason = ? WHERE id = ? AND status = 'delivered'",
        { Law.Now(), 'claim:' .. ctx.charId, r.id })
    if affected ~= 1 then return Law.Result(false, 'already_done') end

    local items = ES.CargoList(r)
    if #items > 0 and not ES.PutItems(ES.FachId(r.id), L('escort_fach_name', r.id), items, ctx.charId) then
        -- Nichts ausgegeben -> Status zuruecksetzen, damit nichts verloren geht
        MySQL.update.await("UPDATE ara_law_escorts SET status = 'delivered', claimed_at = NULL, status_reason = 'delivered' WHERE id = ? AND status = 'claimed'", { r.id })
        return Law.Result(false, 'failed')
    end
    local money = tonumber(r.cargo_money) or 0
    local gold = tonumber(r.cargo_gold) or 0
    if money > 0 then Law.Money.GiveCharId(ctx.charId, money, 0, 'escort_claim') end
    if gold > 0 then Law.Money.GiveCharId(ctx.charId, gold, 1, 'escort_claim') end

    local client = tonumber(r.client_charid)
    if client and client ~= ctx.charId then ES.NotifyChar(client, L('escort_client_claimed', r.id, ctx.name), 'info') end
    Law.Audit(ctx, 'escort.claim', client, { id = r.id, money = money, gold = gold, items = #items })
    if #items > 0 then ES.OpenInv(src, ES.FachId(r.id), L('escort_fach_name', r.id), items) end
    return Law.Result(true, { opened = #items > 0, money = money, gold = gold }, L('escort_claimed', r.id))
end

--- Beute nach einem Ueberfall (Status ist schon atomar auf robbed)
function ES.GiveLoot(src, ctx, r)
    local items = ES.CargoList(r)
    if #items > 0 and not ES.PutItems(ES.LootId(r.id), L('escort_loot_name', r.id), items, ctx.charId) then
        Law.Warn('Eskorte #%s: Beute konnte nicht ins Beutefach gelegt werden (Admin pruefen): %s', tostring(r.id), tostring(r.cargo))
        Law.Audit(ctx, 'escort.goods_error', nil, { id = r.id, cargo = r.cargo, loot = true })
    end
    local money = tonumber(r.cargo_money) or 0
    local gold = tonumber(r.cargo_gold) or 0
    if money > 0 then Law.Money.GiveCharId(ctx.charId, money, 0, 'escort_loot') end
    if gold > 0 then Law.Money.GiveCharId(ctx.charId, gold, 1, 'escort_loot') end
    if #items > 0 then ES.OpenInv(src, ES.LootId(r.id), L('escort_loot_name', r.id), items) end
    return #items > 0, money, gold
end

--------------------------------------------------------------------------
-- Panzerwagen
--------------------------------------------------------------------------
--- Koordinaten einer gespeicherten Wagen-NetId - nur, wenn dahinter noch ein
--- Panzerwagen steckt (NetIds werden nach dem Loeschen wiederverwendet).
function ES.WagonCoords(netId)
    if not netId then return nil, 0 end
    local coords, ent = Law.EntityCoords(netId)
    if not coords or not Law.ModelMatches(ent, ECfg.WagonModel) then return nil, 0 end
    return coords, ent
end

--- Nur beim Start gepruefte Wagen (eigenes Entity des Leiters) werden geloescht,
--- und nur, wenn das Modell noch passt.
function ES.DeleteWagon(netId)
    local _, ent = ES.WagonCoords(netId)
    if ent and ent ~= 0 then DeleteEntity(ent) end
end

--- Wagen soll nicht verschwinden, wenn der Besitzer-Client kurz weg ist
function ES.KeepWagon(netId)
    local _, ent = ES.WagonCoords(netId)
    if ent and ent ~= 0 and SetEntityOrphanMode then
        pcall(SetEntityOrphanMode, ent, 2)  -- 2 = KeepEntity (OneSync)
    end
end

--- Gehoert diese Wagen-NetId schon zu einem Auftrag (aktiv oder ueberfallen)?
function ES.FindByWagon(netId)
    if not netId then return nil end
    for id, a in pairs(ES.Active or {}) do
        if a.wagonNetId == netId then return id, a end
    end
    return nil
end

function ES.RemoveInventories()
    for invId in pairs(registered) do
        pcall(function() Law.Inv:removeInventory(invId) end)
    end
    registered = {}
end
