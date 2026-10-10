--[[
    ArA-LawSystem - Zellentueren (Server)

    Die Tueren kommen aus config/stations/<stadt>.lua (cells.list / doors) und
    werden von shared/03_stations.lua in Config.Jail.Doors gesammelt.

    Der Server ist die Wahrheit fuer "abgeschlossen ja/nein". Der Zustand geht
    ueber GlobalState.ara_law_doors an alle Clients (die setzen die echte Tuer
    im Spiel). Jede Aktion prueft der Server selbst: Recht, Dienst, Abstand
    zur Tuer.

      door:toggle      Gesetz (Recht 'jail', Dienst): auf-/abschliessen
      door:pickStart   alle ausser Gesetz im Dienst: Dietrich ansetzen
      door:pickFinish  nach Ablauf der Zeit: Erfolg/Fehlschlag (Server wuerfelt)
]]

Law.Doors = Law.Doors or {}

local Cfg   = Config.Jail.Cells or {}
local PCfg  = Cfg.Lockpick or {}
local DOORS = Config.Jail.Doors or {}

local state   = {}  -- [hash] = true (abgeschlossen) | false
local picking = {}  -- [src] = { hash, startedAt }

local function publish()
    local out = {}
    for hash, locked in pairs(state) do out[tostring(hash)] = locked end
    GlobalState.ara_law_doors = out
end

function Law.Doors.Get(hash)
    return DOORS[tonumber(hash)]
end

function Law.Doors.IsLocked(hash)
    return state[tonumber(hash)] == true
end

--- Tuer setzen (Server-API). actorCtx nur fuer das Protokoll.
function Law.Doors.SetLocked(hash, locked, actorCtx, reason)
    hash = tonumber(hash)
    local d = DOORS[hash]
    if not d then return false end
    locked = locked == true
    if state[hash] == locked then return true end
    state[hash] = locked
    publish()
    Law.Audit(actorCtx, locked and 'door.lock' or 'door.unlock', nil,
        { door = hash, label = d.label, station = d.station, reason = reason })
    return true
end

--- Steht der Spieler an der Tuer? Waagerecht wie die Stations-Punkte, Hoehe bis 3 m.
local function nearDoor(src, d, extra)
    local c = Law.GetCoords(src)
    if not c then return false end
    local dx, dy = c.x - d.coords.x, c.y - d.coords.y
    return math.sqrt(dx * dx + dy * dy) <= (Cfg.DoorReach or 2.0) + (extra or 1.0) and math.abs(c.z - d.coords.z) <= 3.0
end

--- Wer sitzt gerade (eingebucht) in der Zelle hinter dieser Tuer? -> Namen
local function inmatesInCell(d)
    local out = {}
    if not d.cell or not Law.Justice.InmatesInCell then return out end
    for _, name in ipairs(Law.Justice.InmatesInCell(d.station, d.cell)) do out[#out + 1] = name end
    return out
end

--------------------------------------------------------------------------
-- Auf-/abschliessen (Gesetz)
--------------------------------------------------------------------------
Law.Cb.Register('door:toggle', { perm = 'jail', rate = 800, notCuffed = true, notJailed = true, alive = true }, function(src, ctx, hash)
    hash = Law.ToInt(hash, 0)
    local d = hash and DOORS[hash]
    if not d then return Law.Result(false, 'door_unknown') end
    if not Law.Stations.AllowsDept(d.station, ctx.dept) then return Law.Result(false, 'no_permission') end
    if not nearDoor(src, d) then return Law.Result(false, 'too_far') end
    local lock = not Law.Doors.IsLocked(hash)
    Law.Doors.SetLocked(hash, lock, ctx, 'manual')
    return Law.Result(true, { locked = lock }, L(lock and 'cell_locked' or 'cell_unlocked', d.label))
end)

--- Belegung fuer die Rueckfrage beim Aufschliessen (Client fragt vorher)
Law.Cb.Register('door:info', { perm = 'jail', rate = 500 }, function(src, ctx, hash)
    local d = DOORS[Law.ToInt(hash, 0) or 0]
    if not d then return Law.Result(false, 'door_unknown') end
    return Law.Result(true, { locked = Law.Doors.IsLocked(d.hash), inmates = inmatesInCell(d), label = d.label })
end)

--------------------------------------------------------------------------
-- Dietrich (Ausbruch / Befreiung)
--------------------------------------------------------------------------
Law.Cb.Register('door:pickStart', { rate = 1500, notCuffed = true, alive = true }, function(src, ctx, hash)
    if PCfg.Enabled == false then return Law.Result(false, 'disabled') end
    hash = Law.ToInt(hash, 0)
    local d = hash and DOORS[hash]
    if not d then return Law.Result(false, 'door_unknown') end
    if ctx.dept and ctx.onDuty then return Law.Result(false, 'door_law_use_key') end
    if not Law.Doors.IsLocked(hash) then return Law.Result(false, 'door_already_open') end
    if not nearDoor(src, d) then return Law.Result(false, 'too_far') end
    if Law.Items.Count(src, PCfg.Item or 'lockpick') < 1 then return Law.Result(false, 'door_need_lockpick') end
    if not Law.RateLimit(src, 'door:pick:cd', (PCfg.Cooldown or 60) * 1000) then return Law.Result(false, 'cooldown') end
    picking[src] = { hash = hash, startedAt = GetGameTimer() }
    return Law.Result(true, { seconds = PCfg.Seconds or 20 })
end)

Law.Cb.Register('door:pickFinish', { rate = 1500, notCuffed = true, alive = true }, function(src, ctx, hash)
    hash = Law.ToInt(hash, 0)
    local p = picking[src]
    picking[src] = nil
    if not p or p.hash ~= hash then return Law.Result(false, 'invalid') end
    local d = DOORS[hash]
    if not d then return Law.Result(false, 'door_unknown') end
    -- Mindestzeit (etwas Spielraum fuer Ping), Abstand, Tuer noch zu, Dietrich noch da
    if GetGameTimer() - p.startedAt < ((PCfg.Seconds or 20) - 2) * 1000 then return Law.Result(false, 'invalid') end
    if not nearDoor(src, d) then return Law.Result(false, 'too_far') end
    if not Law.Doors.IsLocked(hash) then return Law.Result(false, 'door_already_open') end
    local item = PCfg.Item or 'lockpick'
    if Law.Items.Count(src, item) < 1 then return Law.Result(false, 'door_need_lockpick') end

    if math.random(1, 100) <= (PCfg.Chance or 20) then
        Law.Doors.SetLocked(hash, false, ctx, 'lockpick')
        -- Spur fuer den Bluthund + Alarm
        Law.Evidence.CreateTrace('cloth', d.coords, { ownerCharId = ctx.charId })
        if PCfg.Alarm ~= false then
            local st = Config.Stations[d.station]
            Law.Dispatch.Create({
                kind = 'escape', coords = d.coords, priority = 3, fuzz = 15,
                title = L('dispatch_title_cell_pick'),
                text = L('cell_pick_dispatch', st and st.label or d.station, d.label),
            })
        end
        return Law.Result(true, { opened = true }, L('cell_pick_ok'))
    end
    if math.random(1, 100) <= (PCfg.BreakChance or 50) then
        Law.Items.Take(src, item, 1)
        return Law.Result(true, { opened = false, broke = true }, L('cell_pick_broke'))
    end
    return Law.Result(true, { opened = false }, L('cell_pick_fail'))
end)

--------------------------------------------------------------------------
-- Admin-Hilfe: Tueren und Zellen im Spiel anzeigen
--------------------------------------------------------------------------
RegisterCommand(Config.Commands.Cells or 'lawcells', function(src)
    if src <= 0 or not Law.IsAdmin(src) then return end
    TriggerClientEvent('ara_law:cl:door:debug', src)
end, false)

--------------------------------------------------------------------------
-- Start
--------------------------------------------------------------------------
--- Stehen unsere Tueren auch in vorp_doorlocks? Dann setzen zwei Scripts die
--- gleiche Tuer -> Hinweis in der Konsole (Datei nur lesen, nichts aendern).
local function checkDoorlockConflicts()
    if GetResourceState('vorp_doorlocks') == 'missing' then return end
    local text
    for _, path in ipairs({ 'config.lua', 'shared/config.lua', 'config/config.lua', 'Config.lua', 'shared/doors.lua', 'config/doors.lua' }) do
        local t = LoadResourceFile('vorp_doorlocks', path)
        if t then text = (text or '') .. t end
    end
    if not text then return end
    for hash, d in pairs(DOORS) do
        if text:find('%f[%d]' .. tostring(hash) .. '%f[%D]') then
            Law.Warn('Tuer %s (%s, %s) steht auch in vorp_doorlocks - dort entfernen, sonst stellen zwei Scripts dieselbe Tuer',
                tostring(hash), d.label, d.station)
        end
    end
end

Law.Modules.Register('doors', {
    init = function()
        for hash, d in pairs(DOORS) do state[hash] = d.locked == true end
        publish()
        checkDoorlockConflicts()
        local n = 0
        for _ in pairs(DOORS) do n = n + 1 end
        if n > 0 then Law.Log('Zellentueren: %d', n) end
    end,
    playerDropped = function(src)
        picking[src] = nil
    end,
})
