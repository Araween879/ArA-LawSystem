--[[
    ArA-LawSystem - Stationen zusammenbauen (Client + Server)

    Jede Stadt steht in ihrer eigenen Datei: config/stations/<stadt>.lua
    Diese Datei laedt NACH allen Config-Dateien (fxmanifest: erst config/,
    dann shared/) und macht daraus die Tabellen, die der restliche Code liest:

      1. Stationen / Punkte mit enabled = false fliegen raus
      2. Feld `prison`    -> Config.Jail.Locations[<stadt>]     (Gefaengnis mit Teleport, z.B. Sisika)
      3. Feld `cells`     -> Config.Jail.Locations[<stadt>]     (Zellen MIT Tueren, kein Teleport hinein)
                          -> Config.Jail.Doors[<tuer-hash>]      (abschliessbare Tueren)
                          -> Punkte celldoor / cellbook / cellpick an jeder Tuer (Prompts)
         Feld `doors`     -> weitere abschliessbare Tueren (z.B. Zellentrakt)
      4. Feld `jailTo`    -> Config.Jail.StationLocation[<stadt>] (Vorauswahl beim Einbuchen am Pult)
      5. Feld `shotsZone` -> Config.Dispatch.ShotsFired.Zones   (Schuesse-Alarm)
      6. Tippfehler werden beim Start in der Konsole gemeldet

    Hier muss man normalerweise NICHTS aendern - eingestellt wird in
    config/stations/*.lua.
]]

Config = Config or {}
Config.Stations = Config.Stations or {}
Config.Jail = Config.Jail or {}
Config.Jail.Locations = Config.Jail.Locations or {}
Config.Jail.StationLocation = Config.Jail.StationLocation or {}
Config.Jail.Doors = {}   -- [tuer-hash] = { hash, station, label, coords, cell = index|nil, locked }
Config.Dispatch = Config.Dispatch or {}
Config.Dispatch.ShotsFired = Config.Dispatch.ShotsFired or {}
Config.Dispatch.ShotsFired.Zones = Config.Dispatch.ShotsFired.Zones or {}

-- Alle Punkt-Typen, die der Code kennt (docs/01_CONTRACT.md Abschnitt 9)
local POINT_TYPES = {
    duty = true, boss = true, counter = true, jail = true,
    storage = true, armory = true, evidence = true,
    board = true, kennel = true, dropoff = true, garage = true, escort = true,
    -- automatisch aus cells/doors erzeugt (nicht selbst eintragen):
    celldoor = true, cellbook = true, cellpick = true,
}
local NEEDS_SPAWN = { garage = true, escort = true }

-- Meldungen nur einmal ausgeben (Client und Server laden diese Datei beide;
-- auf dem Client reicht die Debug-Ausgabe)
local function warn(msg, ...)
    if IsDuplicityVersion() then
        Law.Warn('Stationen: ' .. msg, ...)
    else
        Law.Log('Stationen: ' .. msg, ...)
    end
end

local function isVec3(v) return type(v) == 'vector3' end
local function isVec4(v) return type(v) == 'vector4' end

--- Gueltige Position? (vector3/vector4 und nicht der Platzhalter 0, 0, 0 aus der Vorlage)
local function isPos(v)
    if not (isVec3(v) or isVec4(v)) then return false end
    return not (v.x == 0.0 and v.y == 0.0 and v.z == 0.0)
end

--- vector3 oder vector4 -> vector4 (fehlende Richtung = 0.0)
local function toVec4(v)
    if isVec4(v) then return v end
    if isVec3(v) then return vector4(v.x, v.y, v.z, 0.0) end
    return nil
end

--- jobs-Angabe angleichen: 'sheriff' -> { 'sheriff' }, {} -> nil (= keine Einschraenkung).
--- Unbekannte Jobs (Tippfehler) werden gemeldet und entfernt.
local function cleanJobs(where, jobs)
    if jobs == nil then return nil end
    if type(jobs) == 'string' then jobs = { jobs } end
    if type(jobs) ~= 'table' then
        warn('%s.jobs muss eine Liste sein, z.B. { \'sheriff\', \'marshal\' } - wird ignoriert', where)
        return nil
    end
    local out = {}
    for _, j in ipairs(jobs) do
        if Config.Departments and Config.Departments[j] then
            out[#out + 1] = j
        else
            warn('%s.jobs: Job "%s" gibt es nicht in Config.Departments (Tippfehler?) - wird ignoriert', where, tostring(j))
        end
    end
    if #out == 0 then
        if #jobs > 0 then
            warn('%s.jobs enthaelt keinen gueltigen Job - Punkt ist fuer NIEMANDEN freigegeben', where)
            return { '__niemand__' }
        end
        return nil
    end
    return out
end

--- Ein Punkt oder eine Liste von Punkten -> Liste.
--- Liste nur, wenn die Tabelle Eintraege [1], [2] ... hat - so wird auch ein
--- einzelner Punkt mit vertipptem "coords" geprueft und gemeldet.
local function pointList(p)
    if type(p) ~= 'table' then return {} end
    if p.coords ~= nil or p[1] == nil then return { p } end
    return p
end

--- Einen Punkt pruefen und angleichen. Liefert den Punkt oder nil (aus).
local function cleanPoint(key, pType, p)
    if type(p) ~= 'table' or p.enabled == false then return nil end
    if not isPos(p.coords) then
        warn('%s.points.%s hat keine gueltigen coords (vector3, nicht 0/0/0) - Punkt ist aus', key, pType)
        return nil
    end
    if NEEDS_SPAWN[pType] then
        local s = toVec4(p.spawn)
        if not s or not isPos(s) then
            warn('%s.points.%s braucht spawn = vector4(x, y, z, richtung) - Punkt ist aus', key, pType)
            return nil
        end
        p.spawn = s
    elseif p.spawn ~= nil then
        -- optionaler Spawn (z.B. Hund am Zwinger): vector3/vector4, sonst ignorieren
        local s = toVec4(p.spawn)
        if s and isPos(s) then
            p.spawn = s
        else
            warn('%s.points.%s.spawn ist kein vector4(x, y, z, richtung) - wird ignoriert', key, pType)
            p.spawn = nil
        end
    end
    p.jobs = cleanJobs(('%s.points.%s'):format(key, pType), p.jobs)
    return p
end

--- Abschliessbare Tuer anmelden + Prompts an der Tuer (celldoor / cellbook / cellpick)
local function addDoor(st, key, hash, coords, label, cellIdx, locked)
    if Config.Jail.Doors[hash] then
        warn('Tuer %s steht doppelt (%s und %s) - der zweite Eintrag wird ignoriert', tostring(hash), Config.Jail.Doors[hash].station, key)
        return
    end
    local onStart = (Config.Jail.Cells and Config.Jail.Cells.LockedOnStart) ~= false
    Config.Jail.Doors[hash] = {
        hash = hash, station = key, label = label, coords = coords, cell = cellIdx,
        locked = (locked == nil) and onStart or (locked == true),
    }
    local function push(pType, p)
        local cur = st.points[pType]
        if cur == nil then st.points[pType] = { p }
        elseif cur.coords then st.points[pType] = { cur, p }
        else cur[#cur + 1] = p end
    end
    push('celldoor', { coords = coords, door = hash, label = label })
    if cellIdx then push('cellbook', { coords = coords, door = hash, cell = cellIdx, label = label }) end
    local lp = Config.Jail.Cells and Config.Jail.Cells.Lockpick
    if lp and lp.Enabled ~= false then push('cellpick', { coords = coords, door = hash, label = label }) end
end

local function buildStation(key, st)
    -- Jobs der ganzen Station (jobs, alter Name: depts)
    st.depts = cleanJobs(key, st.jobs ~= nil and st.jobs or st.depts)
    st.jobs = nil

    -- Blip
    if type(st.blip) ~= 'table' or st.blip.enabled == false then
        st.blip = nil
    end

    -- Punkte
    local points = {}
    for pType, p in pairs(st.points or {}) do
        if not POINT_TYPES[pType] then
            warn('%s.points.%s ist kein bekannter Punkt-Typ (Tippfehler?) - wird ignoriert', key, tostring(pType))
        elseif p ~= false and type(p) ~= 'table' then
            warn('%s.points.%s muss { coords = vector3(...) } sein (oder false) - Punkt ist aus', key, pType)
        elseif p ~= false then
            local list = {}
            for _, one in ipairs(pointList(p)) do
                local ok = cleanPoint(key, pType, one)
                if ok then list[#list + 1] = ok end
            end
            if #list == 1 then
                points[pType] = list[1]
            elseif #list > 1 then
                points[pType] = list
            end
        end
    end
    st.points = points

    -- Blip braucht eine Position: blip.coords, sonst Schalter, sonst Dienst-Punkt
    if st.blip and not isPos(st.blip.coords) then
        st.blip.coords = nil
        if not points.counter and not points.duty then
            warn('%s.blip hat keine Position (kein counter/duty-Punkt) - blip.coords setzen, sonst kein Kartensymbol', key)
        end
    end

    -- Gefaengnis mit Teleport (Sisika). Alte Form: cells mit center/spawn (ohne list).
    local prison = st.prison
    if prison == nil and type(st.cells) == 'table' and st.cells.list == nil then prison = st.cells end
    if type(prison) == 'table' then
        local complete = isPos(prison.center) and isPos(prison.spawn) and isPos(prison.release)
        if not complete then
            -- ausgeschaltete, unfertige Eintraege (Vorlage) still ueberspringen
            if prison.enabled ~= false then
                warn('%s.prison braucht center (vector3), spawn und release (vector4), nicht 0/0/0 - Gefaengnis ist aus', key)
            end
        else
            if Config.Jail.Locations[key] then
                warn('Knast-Ort "%s" steht doppelt (config/justice.lua und Station) - die Station gilt', key)
            end
            Config.Jail.Locations[key] = {
                mode    = 'prison',
                label   = prison.label or st.label or key,
                enabled = prison.enabled ~= false,
                center  = vector3(prison.center.x, prison.center.y, prison.center.z),
                radius  = (tonumber(prison.radius) or 8.0) + 0.0,
                spawn   = toVec4(prison.spawn),
                release = toVec4(prison.release),
                work    = prison.work or {},
            }
        end
    end

    -- Zellen mit Tueren (kein Teleport hinein)
    local cells = st.cells
    if type(cells) == 'table' and cells.list and cells.enabled ~= false then
        -- Schluessel = Position in cells.list (bleibt gleich, auch wenn eine Zelle
        -- abgeschaltet wird - die DB speichert diese Nummer)
        local list, order = {}, {}
        local defRadius = (Config.Jail.Cells and Config.Jail.Cells.Radius) or 1.6
        local defCap = (Config.Jail.Cells and Config.Jail.Cells.Capacity) or 2
        for i, c in ipairs(cells.list) do
            if type(c) == 'table' and c.enabled ~= false then
                local hash = tonumber(c.door)
                if not hash or not isPos(c.doorCoords) then
                    warn('%s.cells.list[%d]: door (Tuer-Hash) und doorCoords (vector3) fehlen - Zelle ist aus', key, i)
                elseif not isPos(c.center) then
                    -- ohne Mitte weiss das Script nicht, wo die Zelle ist (Einbuchen, Flucht, Teleport)
                    warn('%s.cells.list[%d] (%s): center fehlt - Zelle ist aus. In der Zelle /lawcoords messen und eintragen',
                        key, i, tostring(c.label or i))
                else
                    local center = c.center
                    order[#order + 1] = i
                    list[i] = {
                        label      = c.label or ('Zelle ' .. i),
                        door       = hash,
                        doorCoords = vector3(c.doorCoords.x, c.doorCoords.y, c.doorCoords.z),
                        center     = vector3(center.x, center.y, center.z),
                        radius     = (tonumber(c.radius) or defRadius) + 0.0,
                        heading    = (tonumber(c.heading) or 0.0) + 0.0,
                        capacity   = math.max(1, math.floor(tonumber(c.capacity) or defCap)),   -- Plaetze
                    }
                end
            end
        end
        if #order == 0 then
            warn('%s.cells: keine gueltige Zelle - Zellen sind aus', key)
        elseif not isPos(cells.release) then
            warn('%s.cells.release (vector4) fehlt - hier kommt der Haeftling nach der Haft raus. Zellen sind aus', key)
        else
            if Config.Jail.Locations[key] then
                warn('%s hat prison UND cells - es gelten die Zellen (Sisika-artiges Gefaengnis bitte als eigene Station)', key)
            end
            -- Mittelpunkt/Umkreis aller Zellen (nur fuer "nach Freilassung noch drin?")
            local cx, cy, cz = 0.0, 0.0, 0.0
            for _, i in ipairs(order) do local c = list[i]; cx, cy, cz = cx + c.center.x, cy + c.center.y, cz + c.center.z end
            local mid = vector3(cx / #order, cy / #order, cz / #order)
            local r = 0.0
            for _, i in ipairs(order) do local c = list[i]; r = math.max(r, #(vector3(c.center.x, c.center.y, mid.z) - mid) + c.radius) end
            local first = list[order[1]]
            Config.Jail.Locations[key] = {
                mode      = 'cells',
                label     = cells.label or ((st.label or key) .. ' (Zellen)'),
                enabled   = true,
                center    = mid,
                radius    = r,
                spawn     = vector4(first.center.x, first.center.y, first.center.z, first.heading),
                release   = toVec4(cells.release),
                work      = {},
                cells     = list,    -- [Nummer] = Zelle (kann Luecken haben -> cellOrder benutzen)
                cellOrder = order,   -- gueltige Nummern aufsteigend
            }
            for _, i in ipairs(order) do local c = list[i]; addDoor(st, key, c.door, c.doorCoords, c.label, i) end
        end
    end

    -- weitere abschliessbare Tueren (Zellentrakt o.ae.)
    for i, d in ipairs(type(st.doors) == 'table' and st.doors or {}) do
        if type(d) == 'table' and d.enabled ~= false then
            local hash = tonumber(d.door)
            if hash and isPos(d.doorCoords) then
                addDoor(st, key, hash, vector3(d.doorCoords.x, d.doorCoords.y, d.doorCoords.z), d.label or ('Tuer ' .. i), nil, d.locked)
            else
                warn('%s.doors[%d]: door (Tuer-Hash) und doorCoords (vector3) fehlen - Tuer ist aus', key, i)
            end
        end
    end

    -- Wohin wird an dieser Station eingebucht?
    if st.jailTo then
        Config.Jail.StationLocation[key] = st.jailTo
    end

    -- Schuesse-Alarm-Gebiet
    local z = st.shotsZone
    if type(z) == 'table' and z.enabled ~= false then
        if isPos(z.coords) then
            local zones = Config.Dispatch.ShotsFired.Zones
            local label = z.label or st.label or key
            -- Gleichnamiges Gebiet aus config/main.lua (z.B. "Van Horn") ersetzt die Station
            for i = #zones, 1, -1 do
                if zones[i].label == label then
                    table.remove(zones, i)
                    warn('Schuesse-Gebiet "%s" steht auch in config/main.lua - es gilt das aus %s.lua (dort loeschen)', label, key)
                end
            end
            zones[#zones + 1] = {
                label  = label,
                coords = vector3(z.coords.x, z.coords.y, z.coords.z),
                radius = (tonumber(z.radius) or 150.0) + 0.0,
            }
        else
            warn('%s.shotsZone.coords fehlt (oder 0/0/0) - kein Schuesse-Alarm fuer diese Stadt', key)
        end
    end
end

-- Feste Reihenfolge (alphabetisch), damit Client und Server gleich bauen
local keys = {}
for key in pairs(Config.Stations) do keys[#keys + 1] = key end
table.sort(keys)

local active = {}
for _, key in ipairs(keys) do
    local st = Config.Stations[key]
    if type(st) ~= 'table' or st.enabled == false then
        Config.Stations[key] = nil
    else
        buildStation(key, st)
        if next(st.points) == nil and not Config.Jail.Locations[key] then
            warn('%s hat keinen einzigen gueltigen Punkt', key)
        end
        active[#active + 1] = st.label or key
    end
end

-- Pruefen, ob jedes jailTo auf einen Knast-Ort zeigt, der an ist
for key, loc in pairs(Config.Jail.StationLocation) do
    local l = Config.Jail.Locations[loc]
    if not l or l.enabled == false then
        warn('%s.jailTo = "%s" - diesen Knast-Ort gibt es nicht oder er ist aus (es gilt %s)',
            key, tostring(loc), tostring(Config.Jail.DefaultLocation))
        Config.Jail.StationLocation[key] = nil
    elseif l.mode == 'cells' then
        warn('%s.jailTo = "%s" - das sind Zellen mit Tueren (dort wird an der Zellentuer eingebucht). Am Pult gilt %s',
            key, tostring(loc), tostring(Config.Jail.DefaultLocation))
        Config.Jail.StationLocation[key] = nil
    end
end

local def = Config.Jail.DefaultLocation and Config.Jail.Locations[Config.Jail.DefaultLocation]
if not def or def.enabled == false or def.mode == 'cells' then
    warn('Config.Jail.DefaultLocation = "%s" ist nicht vorhanden oder aus - bitte config/stations/sisika.lua pruefen',
        tostring(Config.Jail.DefaultLocation))
end

if IsDuplicityVersion() then
    print(('^2[ArA-Law] Stationen aktiv (%d): %s^7'):format(#active, table.concat(active, ', ')))
end

--------------------------------------------------------------------------
-- Zellen: steht eine Position wirklich IN der Zelle?
-- Kreis um die Zellenmitte (radius) UND auf der Zellenseite des Gitters.
-- Das Gitter liegt an der Tuer (doorCoords = Scharnier); die Richtung
-- Tuer -> Zellenmitte zeigt in die Zelle. So zaehlt der Gang vor dem
-- Gitter nie als Zelle, auch wenn der Kreis hineinreicht.
--------------------------------------------------------------------------
Law.Cells = Law.Cells or {}

local BOOK_DEPTH = 0.25   -- Einbuchen: mind. so weit hinter dem Gitter
local STAY_DEPTH = -0.6   -- Haft: erst so weit VOR dem Gitter gilt man als draussen (Toleranz Gitter-Schraege)

--- Meter hinter dem Gitter (negativ = im Gang davor), nil = Richtung unbekannt
function Law.Cells.Depth(cell, pos)
    local d = cell and cell.doorCoords
    if not d or not pos then return nil end
    local nx, ny = cell.center.x - d.x, cell.center.y - d.y
    local len = math.sqrt(nx * nx + ny * ny)
    if len < 0.3 then return nil end   -- Mitte nicht gemessen (liegt an der Tuer)
    return ((pos.x - d.x) * nx + (pos.y - d.y) * ny) / len
end

--- mode 'book' = zum Einbuchen (streng), sonst Haft-Pruefung (mit Toleranz)
function Law.Cells.Inside(cell, pos, mode)
    if not cell or not pos then return false end
    local dx, dy = pos.x - cell.center.x, pos.y - cell.center.y
    local extra = mode == 'book' and 0.3 or 0.0
    if math.sqrt(dx * dx + dy * dy) > cell.radius + extra then return false end
    if math.abs(pos.z - cell.center.z) > 3.0 then return false end
    local depth = Law.Cells.Depth(cell, pos)
    if depth == nil then return true end
    return depth >= (mode == 'book' and BOOK_DEPTH or STAY_DEPTH)
end
