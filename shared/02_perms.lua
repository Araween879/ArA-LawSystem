--[[
    ArA-LawSystem - Behoerden, Raenge, Rechte (geteilt)

    Der Client nutzt das nur, um Menuepunkte ein-/auszublenden. Entscheiden
    tut IMMER der Server (Law.HasPerm in server/core/02_player.lua).
]]

Law = Law or {}

-- Vertrag, Abschnitt 6. Unbekannte Rechte in der Config werden beim Start gemeldet.
Law.Perms = {
    'all', 'duty', 'badge', 'storage', 'armory', 'garage', 'dispatch',
    'cuff', 'escort', 'search', 'idcheck', 'fine', 'fine_cancel', 'jail', 'jail_release',
    'records_view', 'records_edit', 'warrant_create', 'warrant_approve', 'bounty_manage',
    'license_manage', 'npc_calls',
    'evidence', 'evidence_analyze', 'weapons_registry', 'k9', 'scent_sample',
    'escort_contracts', 'escort_lead',
    'boss_hire', 'boss_fire', 'boss_promote', 'boss_funds', 'boss_logs',
}

local KNOWN = {}
for _, p in ipairs(Law.Perms) do KNOWN[p] = true end

-- [job][grade] = { perm = true } - beim Laden einmal aufgebaut
local permCache = {}

local function sortedGrades(dept)
    local list = {}
    for g in pairs(dept.grades or {}) do list[#list + 1] = g end
    table.sort(list)
    return list
end

local function build()
    permCache = {}
    for job, dept in pairs(Config.Departments or {}) do
        permCache[job] = {}
        local acc = {}
        for _, g in ipairs(sortedGrades(dept)) do
            local own = {}
            if dept.inherit then
                for p in pairs(acc) do own[p] = true end
            end
            for _, p in ipairs(dept.grades[g].perms or {}) do
                if not KNOWN[p] then
                    print(('^3[ArA-Law] Unbekanntes Recht "%s" bei %s Rang %s^7'):format(tostring(p), job, tostring(g)))
                end
                own[p] = true
                acc[p] = true
            end
            permCache[job][g] = own
        end
    end
end
build()

function Law.GetDept(job)
    if not job then return nil end
    return (Config.Departments or {})[job]
end

--- Rang-Config. Ist der exakte Rang nicht definiert, gilt der naechstniedrigere.
function Law.GetGrade(job, grade)
    local dept = Law.GetDept(job)
    if not dept then return nil end
    grade = tonumber(grade) or 0
    if dept.grades[grade] then return dept.grades[grade], grade end
    local best
    for g in pairs(dept.grades) do
        if g <= grade and (not best or g > best) then best = g end
    end
    if best then return dept.grades[best], best end
    return nil
end

function Law.GradePerms(job, grade)
    local _, g = Law.GetGrade(job, grade)
    if g == nil then return {} end
    return (permCache[job] or {})[g] or {}
end

function Law.GradeHasPerm(job, grade, perm)
    local perms = Law.GradePerms(job, grade)
    return perms.all == true or perms[perm] == true
end

--- Hoechster definierter Rang einer Behoerde
function Law.MaxGrade(job)
    local dept = Law.GetDept(job)
    if not dept then return nil end
    local max
    for g in pairs(dept.grades) do
        if not max or g > max then max = g end
    end
    return max
end

--- Liste { {grade, label}, ... } sortiert
function Law.GradeList(job)
    local dept = Law.GetDept(job)
    if not dept then return {} end
    local out = {}
    for _, g in ipairs(sortedGrades(dept)) do
        out[#out + 1] = { grade = g, label = dept.grades[g].label }
    end
    return out
end

--- Dienstnummer, z.B. "SO-0042"
function Law.BadgeNumber(job, charId)
    local dept = Law.GetDept(job)
    local prefix = dept and dept.badgePrefix or 'LAW'
    return ('%s-%04d'):format(prefix, (tonumber(charId) or 0) % 10000)
end
