--[[
    ArA-LawSystem - Festnahme (Server, Agent A)

    Items:  handcuffs   (benutzbar) -> naechsten Spieler fesseln
            handcuffkey (benutzbar) -> naechsten Gefesselten loesen
            lockpick    NICHT registriert (gehoert vorp_doorlocks) - nur zaehlen/abziehen
    Net:    arrest:cuff(target) · arrest:uncuff(target) · arrest:escort(target)
            arrest:putInVehicle(target, netId) · arrest:takeOutVehicle(target) · arrest:search(target)
    Cb:     arrest:idcheck(target) · arrest:lockpickStart(target) · arrest:lockpickFinish()

    Wahrheit: Law.State.cuffed[target] = Fesselnder, Law.State.escortedBy[target] = Officer.
    Statebags law_cuffed / law_escorted nur zur Anzeige.
]]

Law.Justice = Law.Justice or {}

local cuffMeta  = {}  -- [target] = { by, byCharId, byName, item, at, attended, hunter }
local lockpicks = {}  -- [src] = { target, startedAt }

--------------------------------------------------------------------------
-- Helfer
--------------------------------------------------------------------------
local function online(src)
    return src and GetPlayerPing(src) > 0
end

local function setBag(src, key, value)
    if online(src) then Player(src).state:set(key, value, true) end
end

local function fail(src, code)
    Law.Notify(src, L('err_' .. code), 'error')
end

--- Naechster Spieler im Umkreis (optional gefiltert)
local function nearestPlayer(src, radius, filter)
    local coords = Law.GetCoords(src)
    if not coords then return nil end
    local best, bestD
    for _, t in ipairs(Law.GetPlayersInRadius(coords, radius)) do
        if t ~= src and (not filter or filter(t)) then
            local c = Law.GetCoords(t)
            local d = c and #(c - coords)
            if d and (not bestD or d < bestD) then best, bestD = t, d end
        end
    end
    return best
end

local function escortingTarget(officerSrc)
    for t, o in pairs(Law.State.escortedBy) do
        if o == officerSrc then return t end
    end
    return nil
end

--- Recht ODER derjenige, der gefesselt hat (Kopfgeldjaeger fuehren ihr Ziel selbst ab)
local function canHandle(ctx, target, perm)
    return Law.HasPerm(ctx, perm) or Law.State.cuffed[target] == ctx.src
end

--------------------------------------------------------------------------
-- Querverweise fuer andere Justiz-Dateien
--------------------------------------------------------------------------
function Law.Justice.StopEscort(target)
    local officer = Law.State.escortedBy[target]
    if not officer then return false end
    Law.State.escortedBy[target] = nil
    setBag(target, 'law_escorted', nil)
    if online(target) then TriggerClientEvent('ara_law:cl:arrest:setEscort', target, nil) end
    return true, officer
end

--- Fesseln loesen. returnToSrc bekommt die Handschellen zurueck (wenn sie
--- beim Fesseln verbraucht wurden). Beim Einbuchen gehen sie an den
--- Fesselnden zurueck. -> meta|nil, returned(bool|nil)
function Law.Justice.ReleaseCuffs(target, reason, returnToSrc)
    target = tonumber(target)
    if not target or not Law.State.cuffed[target] then return nil end
    Law.Justice.StopEscort(target)
    local meta = cuffMeta[target]
    cuffMeta[target] = nil
    Law.State.cuffed[target] = nil
    setBag(target, 'law_cuffed', nil)
    if online(target) then TriggerClientEvent('ara_law:cl:arrest:setCuffed', target, false) end
    for s, lp in pairs(lockpicks) do
        if lp.target == target then lockpicks[s] = nil end
    end

    local returned
    local to = returnToSrc or (reason == 'jail' and meta and meta.by) or nil
    if meta and meta.item and online(to) then
        returned = Law.Items.Give(to, Config.Items.Cuffs, 1)
        if not returned then Law.Notify(to, L('arrest_cuffs_not_returned'), 'info') end
    end
    return meta, returned
end

--------------------------------------------------------------------------
-- Fesseln / Loesen
--------------------------------------------------------------------------
local function canCuff(ctx, tctx)
    if Law.HasPerm(ctx, 'cuff') then return true, false end
    if Config.Arrest.AllowHuntersToCuff and Law.Bounty.CanHunt(ctx.src) and #Law.Bounty.GetActive(tctx.charId) > 0 then
        return true, true
    end
    return false, false
end

--- -> nil bei Erfolg, sonst Fehlercode
local function doCuff(src, ctx, target)
    if not target or target == src then return 'no_target' end
    local tctx = Law.Ctx(target)
    if not tctx then return 'no_target' end
    if Law.State.jailed[target] then return 'target_jailed' end
    if tctx.isDead then return 'target_dead' end
    if not Law.IsNear(src, target, (Config.Arrest.CuffDistance or 2.0) + 0.5) then return 'too_far' end
    local ok, hunter = canCuff(ctx, tctx)
    if not ok then return 'no_permission' end
    -- nach den DB-Abfragen erneut pruefen (zwei gleichzeitige Versuche)
    if Law.State.cuffed[target] then return 'already_cuffed' end
    if Law.Items.Count(src, Config.Items.Cuffs) < 1 then return 'no_cuffs' end
    if Config.Arrest.CuffDelete and not Law.Items.Take(src, Config.Items.Cuffs, 1) then return 'no_cuffs' end

    local now = Law.Now()
    Law.State.cuffed[target] = src
    cuffMeta[target] = {
        by = src, byCharId = ctx.charId, byName = ctx.name, item = Config.Arrest.CuffDelete == true,
        at = now, attended = now, hunter = hunter,
    }
    setBag(target, 'law_cuffed', true)
    TriggerClientEvent('ara_law:cl:arrest:setCuffed', target, true, ctx.name)
    TriggerClientEvent('ara_law:cl:arrest:anim', src)
    Law.Notify(src, L('arrest_cuffed', tctx.name), 'success')

    if Config.Arrest.RecordOnCuff then
        Law.Records.Add(tctx.charId, 'arrest', hunter and L('record_arrest_hunter', ctx.name) or L('record_arrest'), nil, (not hunter) and ctx or nil)
    end
    Law.Audit(ctx, 'arrest.cuff', tctx.charId, { hunter = hunter })
    return nil
end

local function doUncuff(src, ctx, target)
    if not target or not Law.State.cuffed[target] then return 'target_not_cuffed' end
    if not Law.IsNear(src, target, (Config.Arrest.CuffDistance or 2.0) + 1.0) then return 'too_far' end
    local isCuffer = Law.State.cuffed[target] == src
    if not isCuffer and not Law.HasPerm(ctx, 'cuff') then return 'no_permission' end
    local tctx = Law.Ctx(target)
    Law.Justice.ReleaseCuffs(target, 'uncuff', src)
    TriggerClientEvent('ara_law:cl:arrest:anim', src)
    Law.Notify(src, L('arrest_uncuffed', tctx and tctx.name or '?'), 'success')
    if online(target) then Law.Notify(target, L('arrest_uncuffed_you'), 'success') end
    Law.Audit(ctx, 'arrest.uncuff', tctx and tctx.charId or nil, {})
    return nil
end

Law.Items.RegisterUsable(Config.Items.Cuffs, function(src, ctx)
    local target = nearestPlayer(src, Config.Arrest.CuffDistance or 2.0, function(t) return not Law.State.cuffed[t] end)
    if not target then return fail(src, 'no_target') end
    local err = doCuff(src, ctx, target)
    if err then fail(src, err) end
end, { notCuffed = true, alive = true, rate = 1500 })

Law.Items.RegisterUsable(Config.Items.CuffKey, function(src, ctx)
    local target = nearestPlayer(src, (Config.Arrest.CuffDistance or 2.0) + 0.5, function(t) return Law.State.cuffed[t] ~= nil end)
    if not target then return fail(src, 'no_target') end
    local err = doUncuff(src, ctx, target)
    if err then fail(src, err) end
end, { notCuffed = true, alive = true, rate = 1500 })

Law.Net.On('arrest:cuff', { rate = 1500, notCuffed = true, notJailed = true, alive = true }, function(src, ctx, target)
    local err = doCuff(src, ctx, Law.ToInt(target, 1))
    if err then fail(src, err) end
end)

Law.Net.On('arrest:uncuff', { rate = 1500, notCuffed = true, alive = true }, function(src, ctx, target)
    local err = doUncuff(src, ctx, Law.ToInt(target, 1))
    if err then fail(src, err) end
end)

--------------------------------------------------------------------------
-- Abfuehren
--------------------------------------------------------------------------
Law.Net.On('arrest:escort', { rate = 1000, notCuffed = true, notJailed = true, alive = true }, function(src, ctx, target)
    target = Law.ToInt(target, 1)
    if not target or target == src or not Law.Ctx(target) then return fail(src, 'no_target') end
    if not canHandle(ctx, target, 'escort') then return fail(src, 'no_permission') end

    if Law.State.escortedBy[target] == src then
        Law.Justice.StopEscort(target)
        Law.Notify(src, L('arrest_escort_stopped'), 'info')
        return
    end
    if not Law.State.cuffed[target] then return fail(src, 'target_not_cuffed') end
    if Law.State.escortedBy[target] then return fail(src, 'already_escorted') end
    if escortingTarget(src) then return fail(src, 'already_escorting') end
    if not Law.IsNear(src, target, Config.Arrest.EscortDistance or 2.5) then return fail(src, 'too_far') end
    local ped = GetPlayerPed(target)
    if ped and ped ~= 0 and GetVehiclePedIsIn(ped, false) ~= 0 then return fail(src, 'target_in_vehicle') end

    Law.State.escortedBy[target] = src
    setBag(target, 'law_escorted', src)
    TriggerClientEvent('ara_law:cl:arrest:setEscort', target, src)
    Law.Notify(src, L('arrest_escort_started'), 'info')
    Law.Audit(ctx, 'arrest.escort', Law.Players[target] and Law.Players[target].charId or nil, {})
end)

--------------------------------------------------------------------------
-- In den Wagen setzen / herausholen
--------------------------------------------------------------------------
Law.Net.On('arrest:putInVehicle', { rate = 1500, notCuffed = true, notJailed = true, alive = true }, function(src, ctx, target, netId)
    target = Law.ToInt(target, 1)
    netId = Law.ToInt(netId, 0)
    if not target or target == src or not Law.Ctx(target) then return fail(src, 'no_target') end
    if not canHandle(ctx, target, 'escort') then return fail(src, 'no_permission') end
    if not Law.State.cuffed[target] then return fail(src, 'target_not_cuffed') end

    -- eigener Dienstwagen zuerst, sonst das vom Client gemeldete naechste Fahrzeug
    local candidates = {}
    local own = Law.Garage.GetNetId(src)
    if own then candidates[#candidates + 1] = own end
    if netId and netId > 0 then candidates[#candidates + 1] = netId end
    local maxD = Config.Arrest.VehicleDistance or 6.0
    local chosen
    for _, id in ipairs(candidates) do
        local c, ent = Law.EntityCoords(id)
        if c and ent ~= 0 and GetEntityType(ent) == 2 and Law.IsNearCoords(src, c, maxD) and Law.IsNearCoords(target, c, maxD) then
            chosen = id
            break
        end
    end
    if not chosen then return fail(src, 'no_vehicle') end

    Law.Justice.StopEscort(target)
    TriggerClientEvent('ara_law:cl:arrest:putInVehicle', target, chosen)
    Law.Notify(src, L('arrest_put_in_vehicle'), 'info')
    Law.Audit(ctx, 'arrest.vehicle_in', Law.Players[target] and Law.Players[target].charId or nil, { netId = chosen })
end)

Law.Net.On('arrest:takeOutVehicle', { rate = 1500, notCuffed = true, notJailed = true, alive = true }, function(src, ctx, target)
    target = Law.ToInt(target, 1)
    if not target or target == src or not Law.Ctx(target) then return fail(src, 'no_target') end
    if not canHandle(ctx, target, 'escort') then return fail(src, 'no_permission') end
    if not Law.State.cuffed[target] then return fail(src, 'target_not_cuffed') end
    local ped = GetPlayerPed(target)
    local veh = (ped and ped ~= 0) and GetVehiclePedIsIn(ped, false) or 0
    if not veh or veh == 0 then return fail(src, 'not_in_vehicle') end
    if not Law.IsNearCoords(src, GetEntityCoords(veh), Config.Arrest.VehicleDistance or 6.0) then return fail(src, 'too_far') end
    TriggerClientEvent('ara_law:cl:arrest:takeOut', target, src)
    Law.Notify(src, L('arrest_taken_out'), 'info')
    Law.Audit(ctx, 'arrest.vehicle_out', Law.Players[target] and Law.Players[target].charId or nil, {})
end)

--------------------------------------------------------------------------
-- Durchsuchen, Akte im Feld
--------------------------------------------------------------------------
Law.Net.On('arrest:search', { perm = 'search', rate = 2000, notCuffed = true, alive = true }, function(src, ctx, target)
    target = Law.ToInt(target, 1)
    if not target or target == src then return fail(src, 'no_target') end
    local tctx = Law.Ctx(target)
    if not tctx then return fail(src, 'no_target') end
    if not Law.IsNear(src, target, Config.Arrest.SearchDistance or 2.5) then return fail(src, 'too_far') end
    local allowed = tctx.isDead or Law.State.cuffed[target] ~= nil or not Config.Arrest.SearchRequiresCuffs
    if not allowed then return fail(src, 'target_not_cuffed') end
    -- vorp macht den Transfer selbst (inkl. eigener Pruefungen)
    Law.Inv:openPlayerInventory({ source = src, target = target, title = L('arrest_search_title', tctx.name) })
    Law.Notify(target, L('arrest_searched_you'), 'info')
    Law.Audit(ctx, 'arrest.search', tctx.charId, {})
end)

Law.Cb.Register('arrest:idcheck', { perm = 'idcheck', rate = 1500, notCuffed = true }, function(src, ctx, target)
    target = Law.ToInt(target, 1)
    if not target or target == src then return Law.Result(false, 'no_target') end
    local tctx = Law.Ctx(target)
    if not tctx then return Law.Result(false, 'no_target') end
    if not Law.IsNear(src, target, Config.Arrest.IdCheckDistance or 3.0) then return Law.Result(false, 'too_far') end
    Law.Audit(ctx, 'arrest.idcheck', tctx.charId, {})
    if Law.HasPerm(ctx, 'records_view') then
        return Law.Result(true, { full = true, charId = tctx.charId, name = tctx.name })
    end
    local wanted = #Law.Warrants.GetActive(tctx.charId) > 0 or #Law.Bounty.GetActive(tctx.charId) > 0
    return Law.Result(true, { full = false, name = tctx.name, wanted = wanted })
end)

--------------------------------------------------------------------------
-- Handschellen knacken (jeder Nicht-Gefesselte mit Dietrich)
-- Start merkt die Zeit, Ende prueft Dauer, Naehe, Item und wuerfelt.
--------------------------------------------------------------------------
Law.Cb.Register('arrest:lockpickStart', { rate = 1000, notCuffed = true, notJailed = true, alive = true }, function(src, ctx, target)
    local cfg = Config.Arrest.Lockpick
    target = Law.ToInt(target, 1)
    if not target or target == src or not Law.Ctx(target) then return Law.Result(false, 'no_target') end
    if not Law.State.cuffed[target] then return Law.Result(false, 'target_not_cuffed') end
    if not Law.IsNear(src, target, cfg.Distance or 2.0) then return Law.Result(false, 'too_far') end
    if Law.Items.Count(src, Config.Items.Lockpick) < 1 then return Law.Result(false, 'no_lockpick') end
    local lp = lockpicks[src]
    if lp and GetGameTimer() - lp.startedAt < (cfg.Seconds or 8) * 3000 then return Law.Result(false, 'work_busy') end
    if not Law.RateLimit(src, 'arrest:lockpick:cooldown', (cfg.Cooldown or 30) * 1000) then return Law.Result(false, 'cooldown') end
    lockpicks[src] = { target = target, startedAt = GetGameTimer() }
    Law.Notify(target, L('arrest_lockpick_notice'), 'info')
    return Law.Result(true, { seconds = cfg.Seconds or 8 })
end)

Law.Cb.Register('arrest:lockpickFinish', { rate = 1000, notCuffed = true, notJailed = true, alive = true }, function(src, ctx)
    local cfg = Config.Arrest.Lockpick
    local lp = lockpicks[src]
    if not lp then return Law.Result(false, 'invalid') end
    lockpicks[src] = nil
    if GetGameTimer() - lp.startedAt < (cfg.Seconds or 8) * 1000 - 500 then return Law.Result(false, 'too_early') end
    local target = lp.target
    if not Law.State.cuffed[target] then return Law.Result(false, 'target_not_cuffed') end
    if not Law.IsNear(src, target, (cfg.Distance or 2.0) + 1.0) then return Law.Result(false, 'too_far') end
    if Law.Items.Count(src, Config.Items.Lockpick) < 1 then return Law.Result(false, 'no_lockpick') end
    local tctx = Law.Ctx(target)
    local tname = tctx and tctx.name or '?'

    if math.random(1, 100) <= (cfg.Chance or 35) then
        -- Erfolg: frei, Handschellen gehen verloren
        local meta = Law.Justice.ReleaseCuffs(target, 'lockpick', nil)
        local coords = Law.GetCoords(src)
        if coords then
            Law.Dispatch.Create({
                kind = 'escape', coords = coords, priority = 2, fuzz = 40,
                title = L('dispatch_title_cuff_escape'), text = L('arrest_lockpick_dispatch', tname),
            })
            -- Stofffetzen des Knackers (Spur fuer Labor und Bluthund)
            Law.Evidence.CreateTrace('cloth', coords, { ownerCharId = ctx.charId })
        end
        if tctx then
            Law.Records.Add(tctx.charId, 'escape', L('record_cuff_escape'), nil, nil)
            Law.Notify(target, L('arrest_lockpick_freed_you'), 'success')
        end
        if meta and meta.by and meta.by ~= src and online(meta.by) then
            Law.Notify(meta.by, L('arrest_lockpick_officer', tname), 'objective', 8000)
        end
        Law.Audit(ctx, 'arrest.lockpick', tctx and tctx.charId or nil, { success = true })
        return Law.Result(true, { success = true }, L('arrest_lockpick_success'))
    end

    local broke = false
    if math.random(1, 100) <= (cfg.BreakChance or 50) then
        broke = Law.Items.Take(src, Config.Items.Lockpick, 1)
    end
    Law.Audit(ctx, 'arrest.lockpick', tctx and tctx.charId or nil, { success = false, broke = broke })
    return Law.Result(true, { success = false, broke = broke }, broke and L('arrest_lockpick_broke') or L('arrest_lockpick_failed'))
end)

--------------------------------------------------------------------------
-- Auto-Loesen: niemand kuemmert sich um den Gefesselten
--------------------------------------------------------------------------
local function autoUncuff()
    local now = Law.Now()
    local limit = (Config.Arrest.AutoUncuffMinutes or 15) * 60
    local radius = Config.Arrest.AttendRadius or 30.0
    local list = {}
    for t, meta in pairs(cuffMeta) do list[#list + 1] = { t = t, meta = meta } end
    for _, e in ipairs(list) do
        local t, meta = e.t, e.meta
        -- M4: Fesselung durch Kopfgeldjaeger endet nach HunterMaxMinutes oder
        -- sobald auf das Ziel kein aktives Kopfgeld mehr ausgesetzt ist
        if meta.hunter and cuffMeta[t] == meta and Law.State.cuffed[t] then
            local expired = now - (meta.at or now) >= (Config.Arrest.HunterMaxMinutes or 20) * 60
            local charId = Law.Players[t] and Law.Players[t].charId
            local stillWanted = true
            if not expired and charId then
                local okQ, n = Law.DB.Try(MySQL.scalar.await, "SELECT COUNT(*) FROM ara_law_bounties WHERE charid = ? AND status = 'active'", { charId })
                stillWanted = not okQ or (tonumber(n) or 0) > 0  -- DB-Fehler: lieber nicht loesen
            end
            if (expired or not stillWanted) and cuffMeta[t] == meta and Law.State.cuffed[t] then
                Law.Justice.ReleaseCuffs(t, 'hunter_end', online(meta.by) and meta.by or nil)
                if online(t) then Law.Notify(t, L('arrest_hunter_released_you'), 'info') end
                if online(meta.by) then Law.Notify(meta.by, L(expired and 'arrest_hunter_timeout' or 'arrest_hunter_no_bounty'), 'info', 8000) end
                Law.Audit(nil, 'arrest.hunter_end', charId, { expired = expired })
            end
        end
        if cuffMeta[t] == meta and Law.State.cuffed[t] then
            local attended = Law.State.escortedBy[t] ~= nil
            if not attended and online(meta.by) and Law.IsNear(meta.by, t, radius) then attended = true end
            if not attended then
                for s in pairs(Law.GetOnDuty()) do
                    if s ~= t and Law.IsNear(s, t, radius) then attended = true break end
                end
            end
            if attended then
                meta.attended = now
            elseif now - (meta.attended or meta.at) >= limit then
                Law.Justice.ReleaseCuffs(t, 'auto', online(meta.by) and meta.by or nil)
                if online(t) then Law.Notify(t, L('arrest_auto_uncuffed'), 'info') end
                Law.Audit(nil, 'arrest.auto_uncuff', Law.Players[t] and Law.Players[t].charId or nil, {})
            end
        end
    end
end

--------------------------------------------------------------------------
-- Abfuehren serverseitig ueberwachen: Das Attach macht der Client des
-- Gefangenen - reisst er sich los (oder manipuliert den Client), steht er
-- ploetzlich weit weg. Dann Abfuehren beenden und Alarm.
-- Eigener, kurzer Takt (5 s), weil der Auto-Loesen-Takt (60 s) DB-Abfragen
-- macht und fuer diese Pruefung zu traege waere.
--------------------------------------------------------------------------
-- Angehaengt (Attach) = sicher beim Officer. Ob OneSync die Position eines
-- angehaengten Peds serverseitig aktualisiert, ist nicht garantiert - deshalb
-- zaehlt ein bestehender Attach immer als "bei ihm", und ein Alarm braucht
-- zwei Messungen in Folge (kein Fehlalarm durch einen einzelnen Sync-Ruckler).
local escortStrikes = {}

local function isAttachedTo(t, o)
    local ok, attached = pcall(GetEntityAttachedTo, GetPlayerPed(t))
    return ok and attached ~= nil and attached ~= 0 and attached == GetPlayerPed(o)
end

local function escortCheck()
    local maxD = Config.Arrest.EscortBreakDistance or 10.0
    local list = {}
    for t, o in pairs(Law.State.escortedBy) do list[#list + 1] = { t = t, o = o } end
    for t in pairs(escortStrikes) do
        if not Law.State.escortedBy[t] then escortStrikes[t] = nil end
    end
    for _, e in ipairs(list) do
        local t, o = e.t, e.o
        if Law.State.escortedBy[t] == o and online(t) and online(o) then
            local a, b = Law.GetCoords(o), Law.GetCoords(t)
            local far = a and b and #(a - b) > maxD and not isAttachedTo(t, o)
            escortStrikes[t] = far and (escortStrikes[t] or 0) + 1 or nil
            if far and escortStrikes[t] >= 2 then
                escortStrikes[t] = nil
                Law.Justice.StopEscort(t)
                local name = Law.Players[t] and Law.Players[t].name or '?'
                Law.Notify(o, L('arrest_escort_escaped_officer', name), 'objective', 8000)
                Law.Dispatch.Create({
                    kind = 'escape', coords = b, priority = 2, fuzz = 20,
                    title = L('dispatch_title_prisoner_escaped'), text = L('arrest_escort_escape_dispatch', name),
                })
                Law.Audit(nil, 'arrest.escort_break', Law.Players[t] and Law.Players[t].charId or nil,
                    { officer = Law.Players[o] and Law.Players[o].charId or nil, distance = math.floor(#(a - b)) })
            end
        end
    end
end

--------------------------------------------------------------------------
-- Lebenszyklus
--------------------------------------------------------------------------
Law.Modules.Register('arrest', {
    init = function()
        Law.Every(60000, autoUncuff)
        Law.Every((Config.Arrest.EscortCheckSeconds or 5) * 1000, escortCheck)
    end,

    playerLoaded = function(src)
        -- Charakterwechsel/Neusync: Client-Zustand angleichen
        if Law.State.cuffed[src] then
            local meta = cuffMeta[src]
            TriggerClientEvent('ara_law:cl:arrest:setCuffed', src, true, meta and meta.byName or nil)
        end
    end,

    playerDropped = function(src, cache)
        lockpicks[src] = nil
        for s, lp in pairs(lockpicks) do
            if lp.target == src then lockpicks[s] = nil end
        end
        -- Officer weg -> seine Abgefuehrten loslassen (gefesselt bleiben sie)
        for t, o in pairs(Law.State.escortedBy) do
            if o == src and t ~= src then Law.Justice.StopEscort(t) end
        end
        -- Gefesselt ausgeloggt -> Combat-Log: Haft beim naechsten Login
        if Law.State.cuffed[src] then
            local meta = cuffMeta[src]
            cuffMeta[src] = nil
            Law.State.cuffed[src] = nil
            Law.State.escortedBy[src] = nil
            local minutes = Config.Arrest.CombatLogJailMinutes or 0
            -- Handschellen gehen IMMER an den Fesselnden zurueck (auch wenn
            -- gerade eingebucht wird oder keine Combat-Log-Strafe konfiguriert ist)
            if meta and meta.item and online(meta.by) then
                Law.Items.Give(meta.by, Config.Items.Cuffs, 1)
                meta.item = false
            end
            -- Laeuft gerade die Einbuchung, gibt es keine Combat-Log-Strafe
            -- obendrauf (die Haftzeile steht schon, Rest beim naechsten Login)
            local sentencing = cache and cache.charId and Law.Justice.IsSentencing(cache.charId)
            if cache and cache.charId and minutes > 0 and not sentencing then
                local officerCtx = (meta and online(meta.by)) and Law.Ctx(meta.by) or nil
                if officerCtx and not officerCtx.dept then officerCtx = nil end
                local charId, name = cache.charId, cache.name
                CreateThread(function()
                    Law.Justice.SentenceOffline(charId, minutes, L('jail_reason_combatlog'), officerCtx, name)
                    Law.Audit(officerCtx, 'arrest.combatlog', charId, { minutes = minutes })
                end)
                if meta and online(meta.by) then
                    if meta.item then Law.Items.Give(meta.by, Config.Items.Cuffs, 1) end
                    Law.Notify(meta.by, L('arrest_combatlog_officer', name or '?', minutes), 'objective', 8000)
                end
            end
        end
    end,

    -- N2: Respawn (Krankenhaus) beendet Fesseln und Abfuehren
    playerRespawned = function(src)
        lockpicks[src] = nil
        for t, o in pairs(Law.State.escortedBy) do
            if o == src then Law.Justice.StopEscort(t) end
        end
        if Law.State.cuffed[src] then
            local meta = cuffMeta[src]
            Law.Justice.ReleaseCuffs(src, 'respawn', (meta and online(meta.by)) and meta.by or nil)
            Law.Audit(nil, 'arrest.respawn_uncuff', Law.Players[src] and Law.Players[src].charId or nil, {})
        end
    end,

    playerDied = function(src)
        lockpicks[src] = nil
        -- Tod beendet das Abfuehren (gefesselt bleibt man)
        if Law.State.escortedBy[src] then Law.Justice.StopEscort(src) end
        for t, o in pairs(Law.State.escortedBy) do
            if o == src then Law.Justice.StopEscort(t) end
        end
    end,

    stop = function()
        -- Statebags leert der Kern, Clients raeumen im eigenen onStop auf
        cuffMeta, lockpicks = {}, {}
    end,
})
