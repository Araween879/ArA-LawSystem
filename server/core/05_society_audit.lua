--[[
    ArA-LawSystem - Kassen der Behoerden, Audit-Protokoll, Webhooks (Server)

    Kasse: jede Buchung ist atomar in SQL. Abbuchen nur mit
    "WHERE balance >= ?" -> die Kasse kann nie ins Minus laufen, auch wenn
    zwei Abbuchungen gleichzeitig kommen.
]]

Law.Society = Law.Society or {}

local function actorInfo(actorCtx)
    if type(actorCtx) == 'table' then
        return actorCtx.charId, actorCtx.name or ''
    end
    return nil, 'System'
end

function Law.Society.Get(dept)
    local row = MySQL.single.await('SELECT balance FROM ara_law_society WHERE department = ?', { dept })
    return row and tonumber(row.balance) or 0
end

local function log(dept, amount, reason, actorCtx)
    local charId, name = actorInfo(actorCtx)
    local balance = Law.Society.Get(dept)
    MySQL.insert('INSERT INTO ara_law_society_log (department, amount, balance_after, reason, actor_charid, actor_name, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { dept, amount, balance, (reason or ''):sub(1, 64), charId, name, Law.Now() })
end

function Law.Society.Add(dept, amount, reason, actorCtx)
    amount = Law.ToMoney(amount, 0)
    if not amount or not Law.GetDept(dept) then return false end
    if amount == 0 then return true end
    local affected = MySQL.update.await('UPDATE ara_law_society SET balance = balance + ?, updated_at = ? WHERE department = ?',
        { amount, Law.Now(), dept })
    if affected ~= 1 then return false end
    log(dept, amount, reason, actorCtx)
    return true
end

function Law.Society.Remove(dept, amount, reason, actorCtx)
    amount = Law.ToMoney(amount, 0)
    if not amount or not Law.GetDept(dept) then return false end
    if amount == 0 then return true end
    local affected = MySQL.update.await('UPDATE ara_law_society SET balance = balance - ?, updated_at = ? WHERE department = ? AND balance >= ?',
        { amount, Law.Now(), dept, amount })
    if affected ~= 1 then return false end
    log(dept, -amount, reason, actorCtx)
    return true
end

--------------------------------------------------------------------------
-- Webhooks (URLs nur aus config/server_only.lua)
--------------------------------------------------------------------------
function Law.Webhook(channel, title, description, color)
    local hooks = (ServerConfig and ServerConfig.Webhooks) or {}
    local url = hooks[channel]
    if not url or url == '' then url = hooks.default end
    if not url or url == '' then return end
    Law.VORP.AddWebhook(title, url, description, color or ServerConfig.WebhookColor,
        ServerConfig.WebhookName or 'ArA-LawSystem', '', '', ServerConfig.WebhookAvatar or '')
end

--------------------------------------------------------------------------
-- Audit
--------------------------------------------------------------------------
--- action: '<kanal>.<was>', z.B. 'jail.sentence'
function Law.Audit(actorCtx, action, targetCharId, data)
    local charId, name = actorInfo(actorCtx)
    local encoded = data ~= nil and json.encode(data) or nil
    MySQL.insert('INSERT INTO ara_law_audit (actor_charid, actor_name, action, target_charid, data, created_at) VALUES (?, ?, ?, ?, ?, ?)',
        { charId, name, action, tonumber(targetCharId), encoded, Law.Now() })

    local channel = action:match('^([^%.]+)') or 'default'
    local lines = { ('**%s** %s'):format(L('audit_actor'), name .. (charId and (' (#' .. charId .. ')') or '')) }
    if targetCharId then
        lines[#lines + 1] = ('**%s** %s (#%s)'):format(L('audit_target'), Law.GetCharName(targetCharId), tostring(targetCharId))
    end
    if type(data) == 'table' then
        for k, v in pairs(data) do
            if type(v) ~= 'table' then lines[#lines + 1] = ('**%s** %s'):format(tostring(k), tostring(v)) end
        end
    end
    Law.Webhook(channel, action, table.concat(lines, '\n'))
end
