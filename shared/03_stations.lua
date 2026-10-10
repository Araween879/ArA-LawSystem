--[[
    ArA-LawSystem - Stationen zusammenbauen (Client + Server)

    Jede Stadt steht in ihrer eigenen Datei: config/stations/<stadt>.lua
    Diese Datei laedt NACH allen Config-Dateien (fxmanifest: erst config/,
    dann shared/) und macht daraus die Tabellen, die der restliche Code liest:

      1. Stationen / Punkte mit enabled = false fliegen raus
      2. Feld `cells`     -> Config.Jail.Locations[<stadt>]     (Knast-Ort)
      3. Feld `jailTo`    -> Config.Jail.StationLocation[<stadt>] (Vorauswahl beim Einbuchen)
      4. Feld `shotsZone` -> Config.Dispatch.ShotsFired.Zones   (Schuesse-Alarm)
      5. Tippfehler werden beim Start in der Konsole gemeldet

    Hier muss man normalerweise NICHTS aendern - eingestellt wird in
    config/stations/*.lua.
]]

Config = Config or {}
Config.Stations = Config.Stations or {}
Config.Jail = Config.Jail or {}
Config.Jail.Locations = Config.Jail.Locations or {}
Config.Jail.StationLocation = Config.Jail.StationLocation or {}
Config.Dispatch = Config.Dispatch or {}
Config.Dispatch.ShotsFired = Config.Dispatch.ShotsFired or {}
Config.Dispatch.ShotsFired.Zones = Config.Dispatch.ShotsFired.Zones or {}

-- Alle Punkt-Typen, die der Code kennt (docs/01_CONTRACT.md Abschnitt 9)
local POINT_TYPES = {
    duty = true, boss = true, counter = true, jail = true,
    storage = true, armory = true, evidence = true,
    board = true, kennel = true, dropoff = true, garage = true, escort = true,
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
    end
    return p
end

local function buildStation(key, st)
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

    -- Eigene Zellen -> Knast-Ort mit dem Schluessel der Station
    local cells = st.cells
    if type(cells) == 'table' then
        local complete = isPos(cells.center) and isPos(cells.spawn) and isPos(cells.release)
        if not complete then
            -- ausgeschaltete, unfertige Zellen (Vorlage) still ueberspringen
            if cells.enabled ~= false then
                warn('%s.cells braucht center (vector3), spawn und release (vector4), nicht 0/0/0 - Zellen sind aus', key)
            end
        else
            if Config.Jail.Locations[key] then
                warn('Knast-Ort "%s" steht doppelt (config/justice.lua und Station) - die Station gilt', key)
            end
            Config.Jail.Locations[key] = {
                label   = cells.label or st.label or key,
                enabled = cells.enabled ~= false,
                center  = vector3(cells.center.x, cells.center.y, cells.center.z),
                radius  = (tonumber(cells.radius) or 8.0) + 0.0,
                spawn   = toVec4(cells.spawn),
                release = toVec4(cells.release),
                work    = cells.work or {},
            }
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
    end
end

local def = Config.Jail.DefaultLocation and Config.Jail.Locations[Config.Jail.DefaultLocation]
if not def or def.enabled == false then
    warn('Config.Jail.DefaultLocation = "%s" ist nicht vorhanden oder aus - bitte config/stations/sisika.lua pruefen',
        tostring(Config.Jail.DefaultLocation))
end

if IsDuplicityVersion() then
    print(('^2[ArA-Law] Stationen aktiv (%d): %s^7'):format(#active, table.concat(active, ', ')))
end
