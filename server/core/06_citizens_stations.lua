--[[
    ArA-LawSystem - Buerger-Stammdaten und Stationen (Server)

    Buerger (ara_law_citizens): Blutgruppe, Probe in der Akte, Gefaehrlich-
    Flag, Notizen. Gehoert dem Kern, weil Justiz (Akte) UND Ermittlung
    (Blutspuren) es brauchen.
]]

Law.Citizens = Law.Citizens or {}
Law.Stations = Law.Stations or {}

--------------------------------------------------------------------------
-- Blutgruppen: Verteilung grob nach Haeufigkeit
--------------------------------------------------------------------------
local BLOOD = {
    { 'O+', 35 }, { 'A+', 30 }, { 'B+', 9 }, { 'AB+', 4 },
    { 'O-', 7 },  { 'A-', 8 },  { 'B-', 5 }, { 'AB-', 2 },
}

local function rollBlood()
    local r = math.random(1, 100)
    local acc = 0
    for _, b in ipairs(BLOOD) do
        acc = acc + b[2]
        if r <= acc then return b[1] end
    end
    return 'O+'
end

local cache = {}  -- [charId] = row

local function toRow(r)
    return {
        charId    = tonumber(r.charid),
        bloodType = r.blood_type ~= '' and r.blood_type or nil,
        hasSample = tonumber(r.has_sample) == 1,
        dangerous = tonumber(r.dangerous) == 1,
        notes     = r.notes,
    }
end

function Law.Citizens.Get(charId)
    charId = tonumber(charId)
    if not charId then return nil end
    if cache[charId] then return cache[charId] end

    local r = MySQL.single.await('SELECT * FROM ara_law_citizens WHERE charid = ?', { charId })
    if not r then
        local blood = rollBlood()
        MySQL.insert.await('INSERT IGNORE INTO ara_law_citizens (charid, blood_type, has_sample, dangerous, notes, updated_at) VALUES (?, ?, 0, 0, NULL, ?)',
            { charId, blood, Law.Now() })
        r = MySQL.single.await('SELECT * FROM ara_law_citizens WHERE charid = ?', { charId })
    elseif (r.blood_type or '') == '' then
        r.blood_type = rollBlood()
        MySQL.update.await('UPDATE ara_law_citizens SET blood_type = ?, updated_at = ? WHERE charid = ?', { r.blood_type, Law.Now(), charId })
    end
    if not r then return nil end
    cache[charId] = toRow(r)
    return cache[charId]
end

local function set(charId, column, value)
    charId = tonumber(charId)
    if not charId then return false end
    Law.Citizens.Get(charId) -- Zeile sicher anlegen
    -- column kommt nur aus dieser Datei (feste Liste unten), nie aus Eingaben
    MySQL.update.await(('UPDATE ara_law_citizens SET `%s` = ?, updated_at = ? WHERE charid = ?'):format(column), { value, Law.Now(), charId })
    cache[charId] = nil
    return true
end

function Law.Citizens.SetSample(charId, flag)    return set(charId, 'has_sample', flag and 1 or 0) end
function Law.Citizens.SetDangerous(charId, flag) return set(charId, 'dangerous', flag and 1 or 0) end
function Law.Citizens.SetNotes(charId, text)     return set(charId, 'notes', text) end

--------------------------------------------------------------------------
-- Stationen
--------------------------------------------------------------------------
function Law.Stations.Get(key)
    return Config.Stations[key]
end

local function pointList(p)
    if not p then return {} end
    if p.coords then return { p } end
    return p
end

--- Steht der Spieler an einem Punkt dieses Typs? -> stationKey, point
--- maxDist: Default = point.radius oder 3.0 (waagerecht gemessen)
--- Hoehe: Punkt darf bis Config.Points.HeightTolerance ueber/unter dem Spieler
--- liegen (bei Zonen mit groesserem radius bis zum radius) - wie im Client.
--- Punkte mit `jobs` zaehlen nur fuer Spieler mit einem dieser Jobs.
function Law.Stations.NearPoint(src, pointType, maxDist)
    local coords = Law.GetCoords(src)
    if not coords then return nil end
    local bestKey, bestPoint, bestDist
    local dept, deptKnown = nil, false
    local maxDz = (Config.Points and Config.Points.HeightTolerance) or 2.5
    for key, st in pairs(Config.Stations) do
        for _, p in ipairs(pointList(st.points and st.points[pointType])) do
            local limit = maxDist or p.radius or 3.0
            local c = Law.Vec(p.coords)
            local dx, dy = coords.x - c.x, coords.y - c.y
            local d = math.sqrt(dx * dx + dy * dy)
            local dz = math.abs(coords.z - c.z)
            if d <= limit and dz <= math.max(maxDz, limit) and (not bestDist or d < bestDist) then
                local ok = true
                if p.jobs then
                    if not deptKnown then
                        local ctx = Law.Ctx(src)
                        dept, deptKnown = ctx and ctx.dept or nil, true
                    end
                    ok = Law.Contains(p.jobs, dept)
                end
                if ok then bestKey, bestPoint, bestDist = key, p, d end
            end
        end
    end
    return bestKey, bestPoint
end

--- Darf diese Behoerde die Behoerden-Punkte der Station nutzen?
function Law.Stations.AllowsDept(stationKey, dept)
    local st = Config.Stations[stationKey]
    if not st then return false end
    if not st.depts then return true end
    return Law.Contains(st.depts, dept)
end
