--[[
    ArA-LawSystem - kleine Helfer (geteilt, Client + Server)

    Jede Eingabe, die vom Client kommt, laeuft durch ToInt/ToMoney/ToStr/ToBool.
    Das ist Vertrag (docs/01_CONTRACT.md, Abschnitt 11).
]]

Law = Law or {}

local PREFIX = '[ArA-Law] '

local function fmt(message, ...)
    if select('#', ...) > 0 then
        local ok, out = pcall(string.format, message, ...)
        if ok then return out end
    end
    return tostring(message)
end

--- Nur bei Config.General.Debug.
function Law.Log(message, ...)
    if not (Config.General and Config.General.Debug) then return end
    print(PREFIX .. fmt(message, ...))
end

--- Immer. Fuer echte Probleme.
function Law.Warn(message, ...)
    print('^3' .. PREFIX .. fmt(message, ...) .. '^7')
end

--- Ganze Zahl im Bereich oder nil. Nimmt auch Zahlen als Text an (NUI-Formulare).
function Law.ToInt(value, min, max)
    if type(value) == 'string' then value = tonumber(value) end
    if type(value) ~= 'number' then return nil end
    if value ~= value or value == math.huge or value == -math.huge then return nil end
    local n = math.floor(value)
    if min and n < min then return nil end
    if max and n > max then return nil end
    return n
end

--- Geldbetrag (2 Nachkommastellen) im Bereich oder nil.
function Law.ToMoney(value, min, max)
    if type(value) == 'string' then value = tonumber(value) end
    if type(value) ~= 'number' then return nil end
    if value ~= value or value == math.huge or value == -math.huge then return nil end
    local n = math.floor(value * 100 + 0.5) / 100
    if min and n < min then return nil end
    if max and n > max then return nil end
    return n
end

--- Bereinigter Text oder nil.
--- Entfernt Steuerzeichen und spitze Klammern (NUI-Injection), schneidet
--- UTF-8-sicher auf maxLen Zeichen. multiline = Zeilenumbrueche behalten
--- (Notizen, Berichte).
function Law.ToStr(value, maxLen, allowEmpty, multiline)
    if type(value) == 'number' then value = tostring(value) end
    if type(value) ~= 'string' then return nil end
    if not utf8.len(value) then return nil end -- kaputtes UTF-8
    if multiline then
        value = value:gsub('\r', ''):gsub('[%z\1-\9\11-\31\127]', ' '):gsub('\n\n\n+', '\n\n')
        value = value:gsub('[ \t][ \t]+', ' ')
    else
        value = value:gsub('%c', ' '):gsub('%s%s+', ' ')
    end
    value = value:gsub('[<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if value == '' and not allowEmpty then return nil end
    maxLen = maxLen or 255
    if utf8.len(value) > maxLen then
        local cut = utf8.offset(value, maxLen + 1)
        value = value:sub(1, cut - 1)
    end
    return value
end

function Law.ToBool(value)
    return value == true or value == 1 or value == 'true' or value == '1'
end

function Law.Round(n, decimals)
    local m = 10 ^ (decimals or 0)
    return math.floor((tonumber(n) or 0) * m + 0.5) / m
end

--- Zeitspanne kurz und lesbar (Sekunden -> "1h 5m").
function Law.Duration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    if seconds >= 86400 then
        local d, h = math.floor(seconds / 86400), math.floor((seconds % 86400) / 3600)
        return h > 0 and ('%dd %dh'):format(d, h) or ('%dd'):format(d)
    end
    if seconds >= 3600 then
        local h, m = math.floor(seconds / 3600), math.floor((seconds % 3600) / 60)
        return m > 0 and ('%dh %dm'):format(h, m) or ('%dh'):format(h)
    end
    if seconds >= 60 then
        local m, s = math.floor(seconds / 60), seconds % 60
        return s > 0 and ('%dm %ds'):format(m, s) or ('%dm'):format(m)
    end
    return ('%ds'):format(seconds)
end

function Law.Contains(list, value)
    for _, entry in ipairs(list or {}) do
        if entry == value then return true end
    end
    return false
end

--- {x,y,z} / vector3 / vector4 -> vector3
function Law.Vec(t)
    if t == nil then return nil end
    local tt = type(t)
    if tt == 'vector3' then return t end
    if tt == 'vector4' then return vector3(t.x, t.y, t.z) end
    if tt == 'table' and t.x and t.y and t.z then
        return vector3(tonumber(t.x) + 0.0, tonumber(t.y) + 0.0, tonumber(t.z) + 0.0)
    end
    return nil
end

function Law.Dist(a, b)
    a, b = Law.Vec(a), Law.Vec(b)
    if not a or not b then return math.huge end
    return #(a - b)
end

--- vector3 -> {x,y,z} fuer JSON/NUI
function Law.VecToTable(v)
    v = Law.Vec(v)
    if not v then return nil end
    return { x = Law.Round(v.x, 2), y = Law.Round(v.y, 2), z = Law.Round(v.z, 2) }
end

--- Flache Kopie
function Law.Copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end

--- Anzahl Eintraege einer Hash-Tabelle
function Law.Count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end
