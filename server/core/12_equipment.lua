--[[
    ArA-LawSystem - Dienstlager, Waffenkammer, Dienstwagen (Server)

    Lager:        vorp-Custom-Inventar je Behoerde (ara_law_storage_<dept>)
    Waffenkammer: Ausruestung aus Config.Armory, bezahlt aus der Kasse.
                  Waffen bekommen eine eigene Seriennummer und landen im
                  Waffenregister als "Dienstwaffe" (Law.Weapons.RegisterIssued).
    Garage:       Server gibt frei, Client spawnt, meldet die NetId zurueck.
]]

--------------------------------------------------------------------------
-- Lager
--------------------------------------------------------------------------
local function storageId(dept)
    return 'ara_law_storage_' .. dept
end

local function ensureStorage(dept)
    local id = storageId(dept)
    if not Law.Inv:isCustomInventoryRegistered(id) then
        Law.Inv:registerInventory({
            id = id,
            name = (Law.GetDept(dept).short or dept) .. ' - Lager',
            limit = (Config.Storage and Config.Storage.Limit) or 1000,
            acceptWeapons = true,
            shared = true,
            ignoreItemStackLimit = true,
            whitelistItems = false,
            UsePermissions = false,
            UseBlackList = false,
            whitelistWeapons = false,
        })
    end
    return id
end

Law.Net.On('storage:open', { perm = 'storage', rate = 1500, notCuffed = true }, function(src, ctx)
    local stationKey = Law.Stations.NearPoint(src, 'storage')
    if not stationKey or not Law.Stations.AllowsDept(stationKey, ctx.dept) then
        return Law.Notify(src, L('err_not_at_point'), 'error')
    end
    Law.Inv:openInventory(src, ensureStorage(ctx.dept))
    Law.Audit(ctx, 'storage.open', nil, { station = stationKey })
end)

--------------------------------------------------------------------------
-- Waffenkammer
--------------------------------------------------------------------------
local function armorySet(ctx)
    local key = ctx.deptCfg and ctx.deptCfg.armory
    return key and Config.Armory.Sets[key] or nil
end

local function entryAllowed(ctx, entry)
    if (entry.minGrade or 0) > ctx.grade and not Law.GradeHasPerm(ctx.job, ctx.grade, 'all') then return false end
    if entry.perm and not Law.HasPerm(ctx, entry.perm) then return false end
    return true
end

Law.Cb.Register('armory:list', { perm = 'armory', rate = 1000 }, function(src, ctx)
    local stationKey = Law.Stations.NearPoint(src, 'armory')
    if not stationKey or not Law.Stations.AllowsDept(stationKey, ctx.dept) then
        return Law.Result(false, 'not_at_point')
    end
    local set = armorySet(ctx)
    if not set then return Law.Result(false, 'no_armory') end
    local items = {}
    for i, e in ipairs(set) do
        items[#items + 1] = {
            index = i, kind = e.kind, name = e.name, label = e.label, price = e.price or 0,
            amount = e.amount or 1, allowed = entryAllowed(ctx, e),
        }
    end
    return Law.Result(true, { items = items, balance = Law.Society.Get(ctx.dept) })
end)

-- Zeitstempel + Zufall: praktisch kollisionsfrei (Register-PK ist die Seriennummer)
local function newSerial(ctx)
    return ('%s-%d-%04d'):format(ctx.deptCfg.badgePrefix or 'LAW', os.time(), math.random(0, 9999))
end

Law.Cb.Register('armory:take', { perm = 'armory', rate = 1000, notCuffed = true }, function(src, ctx, index)
    index = Law.ToInt(index, 1)
    local set = armorySet(ctx)
    local entry = set and index and set[index]
    if not entry then return Law.Result(false, 'invalid') end
    if not entryAllowed(ctx, entry) then return Law.Result(false, 'no_permission') end
    local stationKey = Law.Stations.NearPoint(src, 'armory')
    if not stationKey or not Law.Stations.AllowsDept(stationKey, ctx.dept) then
        return Law.Result(false, 'not_at_point')
    end
    if not Law.RateLimit(src, 'armory:cooldown', (Config.Armory.Cooldown or 20) * 1000) then
        return Law.Result(false, 'cooldown')
    end

    local price = entry.price or 0
    if entry.kind == 'weapon' then
        if not Law.Inv:canCarryWeapons(src, 1, nil, entry.name) then return Law.Result(false, 'cant_carry') end
        if not Law.Society.Remove(ctx.dept, price, 'armory', ctx) then return Law.Result(false, 'society_empty') end
        local serial = newSerial(ctx)
        local ok = Law.Inv:createWeapon(src, entry.name, {}, {}, {}, nil, nil, serial)
        if not ok then
            Law.Society.Add(ctx.dept, price, 'armory_refund', ctx)
            return Law.Result(false, 'failed')
        end
        Law.Weapons.RegisterIssued(serial, entry.name, ctx.charId, ctx.dept)
        Law.Audit(ctx, 'armory.weapon', nil, { weapon = entry.name, serial = serial, price = price })
    else
        local amount = entry.amount or 1
        if not Law.Inv:canCarryItem(src, entry.name, amount) then return Law.Result(false, 'cant_carry') end
        if not Law.Society.Remove(ctx.dept, price, 'armory', ctx) then return Law.Result(false, 'society_empty') end
        if not Law.Items.Give(src, entry.name, amount) then
            Law.Society.Add(ctx.dept, price, 'armory_refund', ctx)
            return Law.Result(false, 'cant_carry')
        end
        Law.Audit(ctx, 'armory.item', nil, { item = entry.name, amount = amount, price = price })
    end
    return Law.Result(true, nil, L('armory_taken', entry.label))
end)

--------------------------------------------------------------------------
-- Dienstwagen
--------------------------------------------------------------------------
Law.Garage = Law.Garage or { active = {} }  -- [src] = { netId, model, station }

local function garageSet(ctx)
    local key = ctx.deptCfg and ctx.deptCfg.garage
    return key and Config.Garage.Sets[key] or nil
end

Law.Cb.Register('garage:list', { perm = 'garage', rate = 1000 }, function(src, ctx)
    local stationKey = Law.Stations.NearPoint(src, 'garage')
    if not stationKey or not Law.Stations.AllowsDept(stationKey, ctx.dept) then
        return Law.Result(false, 'not_at_point')
    end
    local set = garageSet(ctx) or {}
    local list = {}
    for i, v in ipairs(set) do
        list[#list + 1] = { index = i, model = v.model, label = v.label, allowed = (v.minGrade or 0) <= ctx.grade }
    end
    return Law.Result(true, { vehicles = list, hasActive = Law.Garage.active[src] ~= nil })
end)

--- Freigabe zum Ausparken. Client spawnt und meldet NetId per garage:spawned.
Law.Cb.Register('garage:request', { perm = 'garage', rate = 1000, notCuffed = true }, function(src, ctx, index)
    index = Law.ToInt(index, 1)
    local set = garageSet(ctx)
    local v = set and index and set[index]
    if not v or (v.minGrade or 0) > ctx.grade then return Law.Result(false, 'invalid') end
    local stationKey, point = Law.Stations.NearPoint(src, 'garage')
    if not stationKey or not point or not point.spawn then return Law.Result(false, 'not_at_point') end
    local current = Law.Garage.active[src]
    if current and current.pending and Law.Now() - current.pending > 30 then
        Law.Garage.active[src] = nil -- Spawn nie gemeldet (Client abgestuerzt o.ae.)
        current = nil
    end
    if current then return Law.Result(false, 'garage_has_active') end
    if not Law.RateLimit(src, 'garage:cooldown', (Config.Garage.Cooldown or 60) * 1000) then
        return Law.Result(false, 'cooldown')
    end
    Law.Garage.active[src] = { netId = nil, model = v.model, station = stationKey, pending = Law.Now() }
    local s = point.spawn
    return Law.Result(true, { model = v.model, spawn = { x = s.x, y = s.y, z = s.z, w = s.w } })
end)

Law.Net.On('garage:spawned', { perm = 'garage', rate = 1000 }, function(src, ctx, netId)
    netId = Law.ToInt(netId, 1)
    local a = Law.Garage.active[src]
    if not a or a.netId or not netId then return end
    local coords, ent = Law.EntityCoordsWait(netId, 3000)
    -- Waehrend des Wartens kann ein zweites garage:spawned denselben Eintrag
    -- bearbeitet haben -> nur weitermachen, wenn es noch UNSER Eintrag ist
    if Law.Garage.active[src] ~= a or a.netId then return end
    -- Nur ein EIGENES, passendes, nahes Fahrzeug wird angenommen. Fremde
    -- Entities werden nie geloescht (Client koennte beliebige NetIds schicken).
    local valid = coords and Law.ModelMatches(ent, a.model) and Law.IsEntityOwner(ent, src)
        and Law.IsNearCoords(src, coords, 40.0)
    if not valid then
        Law.Garage.active[src] = nil
        TriggerClientEvent('ara_law:cl:garage:rejected', src, netId)
        return
    end
    a.netId = netId
    a.pending = nil
    Law.Audit(ctx, 'garage.spawn', nil, { model = a.model, station = a.station })
end)

function Law.Garage.Remove(src)
    local a = Law.Garage.active[src]
    if not a then return end
    Law.Garage.active[src] = nil
    if a.netId then
        local _, ent = Law.EntityCoords(a.netId)
        -- NetIds werden wiederverwendet: nur loeschen, wenn es noch unser Wagen ist
        if ent and ent ~= 0 and Law.ModelMatches(ent, a.model) then DeleteEntity(ent) end
    end
end

Law.Net.On('garage:store', { law = true, duty = false, rate = 1000 }, function(src, ctx)
    local a = Law.Garage.active[src]
    if not a then return Law.Notify(src, L('garage_none'), 'error') end
    if a.netId then
        local coords = Law.EntityCoords(a.netId)
        local near = coords and Law.IsNearCoords(src, coords, 15.0)
        local atGarage = Law.Stations.NearPoint(src, 'garage', 25.0)
        if coords and not near and not atGarage then
            return Law.Notify(src, L('garage_too_far'), 'error')
        end
    end
    Law.Garage.Remove(src)
    Law.Notify(src, L('garage_stored'), 'success')
end)

--- NetId des eigenen Dienstwagens (fuer Agent A: Gefangene einsetzen)
function Law.Garage.GetNetId(src)
    local a = Law.Garage.active[tonumber(src)]
    return a and a.netId or nil
end

Law.Modules.Register('equipment', {
    dutyChanged = function(src, _, onDuty)
        if not onDuty and Config.Garage.DespawnOnDutyOff then Law.Garage.Remove(src) end
    end,
    playerDropped = function(src)
        Law.Garage.Remove(src)
    end,
    stop = function()
        for src in pairs(Law.Garage.active) do Law.Garage.Remove(src) end
        for dept in pairs(Config.Departments) do
            pcall(function() Law.Inv:removeInventory(storageId(dept)) end)
        end
    end,
})
