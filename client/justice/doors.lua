--[[
    ArA-LawSystem - Zellentueren (Client)

    Der Server haelt den Zustand (GlobalState.ara_law_doors). Hier wird er
    auf die echten Tueren im Spiel gesetzt (Door-System von RedM) und es
    gibt die Prompts an den Tueren:
      celldoor  Gesetz (Recht 'jail', Dienst): auf-/abschliessen
      cellpick  alle anderen: Schloss mit Dietrich knacken
    ("Haeftling einbuchen" an der Tuer steht in client/justice/jail.lua)

    Admin: /lawcells zeigt Tueren (gruen = zu, rot = offen) und Zellen (blau).
]]

Law.Doors = Law.Doors or {}

local Cfg   = Config.Jail.Cells or {}
local DOORS = Config.Jail.Doors or {}

local current = {}   -- [hash] = true (zu) | false (offen) - so wie zuletzt gesetzt

local function yes(v) return v == true or v == 1 end

--- Zustand laut Server (GlobalState), sonst Startwert aus der Config
local function serverLocked(hash, gs)
    gs = gs or GlobalState.ara_law_doors or {}
    local v = gs[tostring(hash)]
    if v == nil then return DOORS[hash] and DOORS[hash].locked == true end
    return v == true
end

function Law.Doors.IsLocked(hash)
    hash = tonumber(hash)
    if current[hash] ~= nil then return current[hash] end
    return serverLocked(hash)
end

function Law.Doors.Get(hash)
    return DOORS[tonumber(hash)]
end

--------------------------------------------------------------------------
-- Tuer im Spiel setzen
--------------------------------------------------------------------------
local function register(hash)
    if not yes(IsDoorRegisteredWithSystem(hash)) then
        Citizen.InvokeNative(0xD99229FE93B46286, hash, 1, 1, 0, 0, 0, 0)  -- AddDoorToSystemNew
    end
end

--- close = Tuer vorher zuziehen (nur beim Abschliessen einer offenen Tuer)
local function apply(hash, locked, close)
    register(hash)
    if locked and close then
        DoorSystemSetOpenRatio(hash, 0.0, false, true)
    end
    DoorSystemSetDoorState(hash, locked and 1 or 0, false, true)
end

local function sync(gs)
    for hash in pairs(DOORS) do
        local locked = serverLocked(hash, gs)
        if current[hash] ~= locked then
            local wasOpen = current[hash] == false
            current[hash] = locked
            apply(hash, locked, locked and wasOpen)
        end
    end
end

AddStateBagChangeHandler('ara_law_doors', 'global', function(_, _, value)
    sync(type(value) == 'table' and value or {})
end)

-- Tueren in der Naehe regelmaessig nachsetzen: RedM uebernimmt den Zustand
-- erst, wenn die Tuer geladen ist (Spieler kommt in die Naehe)
CreateThread(function()
    if next(DOORS) == nil then return end
    Wait(2000)
    sync(nil)
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for hash, d in pairs(DOORS) do
            if #(pos - d.coords) <= 80.0 then
                local locked = Law.Doors.IsLocked(hash)
                register(hash)
                DoorSystemSetDoorState(hash, locked and 1 or 0, false, false)
            end
        end
        Wait(3000)
    end
end)

--------------------------------------------------------------------------
-- Prompts an der Tuer
--------------------------------------------------------------------------
Law.Stations.RegisterPoint('celldoor', {
    perm = 'jail', duty = true,
    distance = Cfg.DoorReach or 2.0,
    label = function(_, point)
        return L(Law.Doors.IsLocked(point.door) and 'prompt_cell_unlock' or 'prompt_cell_lock', point.label or '')
    end,
    onUse = function(_, point)
        if Law.Doors.IsLocked(point.door) then
            -- Sitzt jemand drin? Dann erst nachfragen (laeuft er raus, ist es Flucht)
            local info = Law.Cb.Await('door:info', point.door)
            local names = info and info.ok and info.data and info.data.inmates or {}
            if #names > 0 then
                local choice = Law.UI.Menu({
                    title = L('cell_occupied_title'),
                    subtitle = L('cell_occupied_sub', point.label or '', table.concat(names, ', ')),
                    items = {
                        { id = 'yes', label = L('cell_confirm_unlock'), desc = L('cell_confirm_unlock_desc') },
                        { id = 'no', label = L('cell_confirm_cancel') },
                    },
                })
                if choice ~= 'yes' then return end
            end
        end
        local res = Law.Cb.Await('door:toggle', point.door)
        Law.Notify(res and res.msg or L('err_failed'), res and res.ok and 'success' or 'error')
    end,
})

Law.Stations.RegisterPoint('cellpick', {
    distance = Cfg.DoorReach or 2.0,
    label = L('prompt_cell_pick'),
    canShow = function(_, point)
        if not Law.Doors.IsLocked(point.door) then return false end
        -- Gesetz im Dienst hat den Schluessel
        return not (Law.Me.dept and Law.Me.onDuty)
    end,
    onUse = function(_, point)
        local res = Law.Cb.Await('door:pickStart', point.door)
        if not res or not res.ok then return Law.Notify(res and res.msg or L('err_failed'), 'error') end
        local ped = PlayerPedId()
        TaskStartScenarioInPlace(ped, joaat('WORLD_HUMAN_CROUCH_INSPECT'), -1, true, false, false, false)
        Law.Util.Progress(L('cell_pick_progress'), ((res.data and res.data.seconds) or 20) * 1000)
        ClearPedTasks(ped)
        local fin = Law.Cb.Await('door:pickFinish', point.door)
        local ok = fin and fin.ok and fin.data and fin.data.opened
        Law.Notify(fin and fin.msg or L('err_failed'), ok and 'success' or 'error')
    end,
})

--------------------------------------------------------------------------
-- Admin: /lawcells - Tueren und Zellen anzeigen (zum Einrichten)
--------------------------------------------------------------------------
local debugOn = false

local function marker(x, y, z, scale, height, r, g, b, a)
    -- DrawMarker (0x2A32FAA57B937173), Typ 0x94FDAE17 = flacher Zylinder am Boden
    Citizen.InvokeNative(0x2A32FAA57B937173, 0x94FDAE17, x, y, z,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, scale, scale, height, r, g, b, a, 0, 0, 2, 0, 0, 0, 0)
end

local function cellsOf(stationKey)
    local loc = Config.Jail.Locations[stationKey]
    return loc and loc.mode == 'cells' and loc.cells or {}
end

local function debugLoop()
    local lastNear
    print('[ArA-Law] Zellentueren (Stadt / Name / Tuer-Hash / Position):')
    for hash, d in pairs(DOORS) do
        print(('  %s / %s / %s / vector3(%.2f, %.2f, %.2f)'):format(d.station, d.label, tostring(hash), d.coords.x, d.coords.y, d.coords.z))
    end
    while debugOn do
        local pos = GetEntityCoords(PlayerPedId())
        local near, nearD
        for hash, d in pairs(DOORS) do
            local dist = #(pos - d.coords)
            if dist <= 40.0 then
                local locked = Law.Doors.IsLocked(hash)
                marker(d.coords.x, d.coords.y, d.coords.z + 0.05, 0.35, 2.2, locked and 60 or 220, locked and 200 or 60, 60, 170)
                if d.cell then
                    local c = cellsOf(d.station)[d.cell]
                    if c then marker(c.center.x, c.center.y, c.center.z - 0.95, c.radius * 2.0, 0.15, 60, 120, 230, 90) end
                end
                if not nearD or dist < nearD then near, nearD = d, dist end
            end
        end
        if near and near ~= lastNear and nearD <= 3.0 then
            lastNear = near
            local st = Config.Stations[near.station]
            Law.Notify(L('cells_debug_near', near.label, st and st.label or near.station, tostring(near.hash), ('%.1f'):format(nearD)), 'info', 4000)
        end
        Wait(0)
    end
end

Law.On('door:debug', function()
    debugOn = not debugOn
    Law.Notify(L(debugOn and 'cells_debug_on' or 'cells_debug_off'), 'info', 8000)
    if debugOn then CreateThread(debugLoop) end
end)

Law.Modules.Register('doors', {
    onStop = function()
        debugOn = false
    end,
})
