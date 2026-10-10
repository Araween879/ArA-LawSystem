--[[
    ArA-LawSystem - Querverweis-Stubs (Vertrag Abschnitt 4.1)

    Diese Funktionen gehoeren Agent A (Justiz) bzw. Agent B (Ermittlung &
    Schutz). Der Kern legt sie hier als harmlose Platzhalter an, damit jeder
    Aufrufer sie OHNE Existenzpruefung aufrufen kann - auch wenn ein Modul
    fehlt oder abgeschaltet ist. Die Module laden NACH dem Kern und
    ueberschreiben sie mit exakt dieser Signatur.
]]

Law.Jail     = Law.Jail or {}
Law.Records  = Law.Records or {}
Law.Warrants = Law.Warrants or {}
Law.Bounty   = Law.Bounty or {}
Law.Evidence = Law.Evidence or {}
Law.Weapons  = Law.Weapons or {}
Law.Scent    = Law.Scent or {}
Law.Escort   = Law.Escort or {}

local warned = {}
local function stub(name, ...)
    local ret = table.pack(...)
    return function()
        if not warned[name] then
            warned[name] = true
            Law.Log('Stub aufgerufen (Modul fehlt?): %s', name)
        end
        return table.unpack(ret, 1, ret.n)
    end
end

-- Agent A
Law.Jail.IsJailed          = stub('Jail.IsJailed', false)
Law.Jail.Sentence          = stub('Jail.Sentence', false, 'module_missing')
Law.Records.Add            = stub('Records.Add', nil)
Law.Warrants.CreateAuto    = stub('Warrants.CreateAuto', nil)
Law.Warrants.GetActive     = stub('Warrants.GetActive', {})
Law.Bounty.GetActive       = stub('Bounty.GetActive', {})
Law.Bounty.CanHunt         = stub('Bounty.CanHunt', false)

-- Agent B
Law.Evidence.CreateTrace   = stub('Evidence.CreateTrace', nil)
Law.Evidence.LastShotAt    = stub('Evidence.LastShotAt', nil)
Law.Weapons.RegisterIssued = stub('Weapons.RegisterIssued', false)
Law.Weapons.GetByOwner     = stub('Weapons.GetByOwner', {})
Law.Weapons.Lookup         = stub('Weapons.Lookup', nil)
Law.Scent.HasTrail         = stub('Scent.HasTrail', false)
Law.Escort.OnPlayerDeath   = stub('Escort.OnPlayerDeath')
