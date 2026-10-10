# ArA-LawSystem – Schnittstellen-Vertrag (VERBINDLICH)

Dieser Vertrag ist das Gesetz des Projekts. Wer einen Namen, eine Signatur oder eine Datenform braucht,
die hier nicht steht, erfindet sie NICHT, sondern hält sich an die Regeln in Abschnitt 12
(„Erweiterungen") und dokumentiert sie in seinem Abschlussbericht.

---

## 1. Namen

| Was | Muster | Beispiel |
|---|---|---|
| Ressource | `ArA-LawSystem` | |
| Lua-Namespace | globale Tabelle `Law` (Server und Client getrennt), `Config`, `Locales`, `L` | `Law.Jail.Sentence` |
| Net-Event Client→Server | `ara_law:sv:<modul>:<aktion>` – **nur über** `Law.Net.On('<modul>:<aktion>', …)` | `ara_law:sv:arrest:cuff` |
| Net-Event Server→Client | `ara_law:cl:<modul>:<aktion>` | `ara_law:cl:arrest:setCuffed` |
| Callback | `ara_law:cb:<modul>:<aktion>` – **nur über** `Law.Cb.Register('<modul>:<aktion>', …)` | `ara_law:cb:fines:list` |
| Server→Client-Anfrage mit Antwort | `Law.Ask(src, '<modul>:<frage>', payload, timeoutMs)` ↔ Client `Law.Answer('<modul>:<frage>', fn)` | `fines:confirmPay` |
| DB-Tabellen | `ara_law_<name>` | `ara_law_fines` |
| Items | `law_<name>` + wiederverwendet: `handcuffs`, `handcuffkey`, `lockpick`, `bountylicns` | `law_evidence_bag` |
| Locale-Schlüssel | `<modul>_<text>`; NUI-Texte `ui_<...>` | `jail_escaped` |
| Statebags (nur Anzeige!) | `law_duty`, `law_cuffed`, `law_escorted`, `law_jailed` | |

**Modul-Schlüssel:** Kern: `core`, `duty`, `boss`, `storage`, `armory`, `garage`, `dispatch`, `citizens`
· Agent A: `arrest`, `fines`, `jail`, `records`, `warrants`, `bounty`, `npc`
· Agent B: `evidence`, `weapons`, `scent`, `k9`, `escort`.

---

## 2. Dateien & Besitz

Jeder schreibt **nur** in seine Dateien. Fremde Dateien werden gelesen, nie geändert.

| Besitzer | Dateien |
|---|---|
| Head Dev | `fxmanifest.lua`, `config/main.lua`, `config/stations/**`, `config/server_only.lua`, `shared/**`, `server/core/**`, `server/zz_boot.lua`, `client/core/**`, `client/zz_boot.lua`, `locales/de_core.lua`, `locales/en_core.lua`, `sql/**`, `docs/00_*`, `docs/01_*`, `docs/INSTALL.md` |
| Agent A | `config/justice.lua`, `server/justice/*.lua`, `client/justice/*.lua`, `locales/de_justice.lua`, `locales/en_justice.lua`, `docs/A_REPORT.md` |
| Agent B | `config/investigation.lua`, `config/escort.lua`, `server/investigation/*.lua`, `server/escort/*.lua`, `client/investigation/*.lua`, `client/escort/*.lua`, `locales/de_investigation.lua`, `locales/en_investigation.lua`, `locales/de_escort.lua`, `locales/en_escort.lua`, `docs/B_REPORT.md` |
| Agent C | `html/**`, `locales/de_ui.lua`, `locales/en_ui.lua`, `docs/C_REPORT.md` |

Ladereihenfolge (fxmanifest, fest): `config/main.lua` → `config/justice.lua` → `config/investigation.lua` →
`config/escort.lua` → `config/stations/*.lua` → `shared/*.lua` (darin `shared/03_stations.lua`: baut die Stationen) → `locales/*.lua` → Server: `server/core/*.lua` (nummeriert) →
`server/justice/*.lua` → `server/investigation/*.lua` → `server/escort/*.lua` → `server/zz_boot.lua`.
Client analog. **Modul-Dateien dürfen beim Laden nur definieren und registrieren** (Funktionen,
`Law.Net.On`, `Law.Cb.Register`, `Law.Modules.Register`, `Law.Items.RegisterUsable`,
`Law.Stations.RegisterPoint`, `Law.Interact.Register`). Alles, was DB oder Spieler braucht,
läuft im `init`-Hook.

Jede Config-Datei beginnt mit `Config = Config or {}` und definiert **nur** ihre eigenen Unterschlüssel.
Jede Locale-Datei benutzt `Law.LocaleAdd('de', { ... })`.

---

## 3. Kern-API – Shared (Client + Server)

```lua
Law.Log(fmt, ...)                 -- nur bei Config.General.Debug
Law.Warn(fmt, ...)                -- immer
Law.ToInt(v, min, max)            -- number|nil  (ganzzahlig, NaN/Bereich -> nil)
Law.ToMoney(v, min, max)          -- number|nil  (2 Nachkommastellen)
Law.ToStr(v, maxLen, allowEmpty)  -- string|nil  (getrimmt, Steuerzeichen und < > entfernt)
Law.ToBool(v)                     -- true|false
Law.Round(n, decimals)
Law.Duration(seconds)             -- "1h 5m"
Law.Contains(list, value)
Law.Dist(a, b)                    -- Distanz zweier vector3 (oder {x,y,z})
Law.Vec(t)                        -- {x,y,z}|vector3 -> vector3
Law.T(key, ...) / L(key, ...)     -- Locale, Fallback 'de', sonst Schluessel selbst
Law.LocaleAdd(lang, tbl)
Law.GetDept(jobName)              -- Config.Departments[jobName] | nil
Law.GetGrade(jobName, grade)      -- Grade-Config | nil (faellt auf naechstniedrigeren definierten Rang zurueck)
Law.GradeHasPerm(jobName, grade, perm) -- bool ('all' erlaubt alles)
Law.Perms                         -- Liste aller gueltigen Rechte (Abschnitt 6)
```

## 4. Kern-API – Server

```lua
Law.VORP                          -- exports.vorp_core:GetCore()
Law.Inv                           -- exports.vorp_inventory
Law.Now()                         -- os.time()

-- Spieler-Kontext (IMMER frisch, nie zwischenspeichern)
Law.Ctx(src)          -> ctx|nil
--   ctx = { src, user, char, charId, identifier, name, firstname, lastname,
--           job, grade, dept (=job wenn Behoerde, sonst nil), deptCfg, gradeCfg,
--           onDuty (bool), group, isDead (bool) }
Law.CtxByCharId(charId) -> ctx|nil   (nur online)
Law.SrcByCharId(charId) -> src|nil
Law.Players[src]      -- Kern-Cache { charId, name, identifier, dept } (auch nach Drop im playerDropped-Hook gueltig)
Law.GetCharName(charId) -> string   (DB, gecacht; fuer Offline-Charaktere)

-- Position (OneSync, serverseitig)
Law.GetCoords(src)                         -> vector3|nil
Law.IsNear(srcA, srcB, maxDist)            -> bool, dist
Law.IsNearCoords(src, coords, maxDist)     -> bool, dist
Law.GetPlayersInRadius(coords, radius)     -> { src, ... }
Law.EntityCoords(netId)                    -> vector3|nil, entity  (NetworkGetEntityFromNetworkId, prueft DoesEntityExist)

-- Rechte / Dienst
Law.HasPerm(srcOrCtx, perm, needDuty)      -> bool   (needDuty default = Config.General.RequireDuty)
Law.IsLaw(srcOrCtx)                        -> bool
Law.IsOnDuty(src)                          -> bool, dept
Law.GetOnDuty(perm?)                       -> { [src] = dept }   (optional nach Recht gefiltert)

-- Netz (Pflicht fuer JEDES Net-Event und JEDEN Callback)
Law.Net.On(name, opts, handler)            -- handler(src, ctx, ...)
Law.Cb.Register(name, opts, handler)       -- handler(src, ctx, ...) -> ergebnis (wird an Client geliefert)
--   opts = {
--     perm      = 'cuff' | nil,           -- Recht noetig
--     duty      = true|false,             -- Dienst noetig (Default: true wenn perm gesetzt)
--     law       = true|nil,               -- muss Behoerdenmitglied sein (ohne bestimmtes Recht)
--     rate      = 500,                    -- ms zwischen zwei Aufrufen je Spieler (Default 500)
--     notCuffed = true|nil,               -- Aufrufer darf nicht gefesselt sein
--     notJailed = true|nil,               -- Aufrufer darf nicht in Haft sein
--     alive     = true|nil,               -- Aufrufer darf nicht tot sein
--   }
--   Abgelehnt: Net.On -> Notify + return; Cb -> { ok=false, err='no_permission'|'rate_limited'|'not_loaded'|..., msg=... }
Law.RateLimit(src, key, ms)                -> bool (true = erlaubt)
Law.Ask(src, name, payload, timeoutMs)     -> result|nil  (blockierend im Thread; nil bei Timeout)
Law.Result(ok, errOrData, msg)             -- Hilfsfunktion fuer Rueckgaben:
--   Law.Result(true, data)          -> { ok=true, data=data }
--   Law.Result(false, 'code', msg?) -> { ok=false, err='code', msg=msg or L('err_'..code) }

-- Benachrichtigen
Law.Notify(src, text, kind, ms)            -- kind: 'info'|'success'|'error'|'objective'|'left'
Law.NotifyLaw(text, perm?, kind?)          -- alle im Dienst (optional mit Recht)
Law.SendLaw(eventName, perm?, ...)         -- TriggerClientEvent an alle im Dienst (optional mit Recht)

-- Geld (currency: 0 = Dollar, 1 = Gold)
Law.Money.Get(src, currency)               -> number
Law.Money.Take(src, amount, currency)      -> bool   (prueft + zieht ab, OHNE yield dazwischen)
Law.Money.Give(src, amount, currency)      -> bool
Law.Money.GiveCharId(charId, amount, currency, reason) -> bool
--   online: sofort; offline: Tabelle ara_law_payouts, Auszahlung beim naechsten Login (Kern).
--   reason = kurzer Schluessel, z.B. 'bounty_refund' -> Locale 'payout_reason_bounty_refund' (Besitzer legt ihn an).
--   NIE Geld offline direkt in `characters` schreiben (vorp ueberschreibt es beim Speichern).

-- Items
Law.Items.Count(src, name, metadata?)      -> number
Law.Items.Take(src, name, amount, metadata?) -> bool
Law.Items.Give(src, name, amount, metadata?) -> bool  (canCarryItem vorher)
Law.Items.TakeById(src, itemId, amount?)   -> bool
Law.Items.GetById(src, itemId)             -> item|nil  ({ id, name, label, metadata, count })
Law.Items.RegisterUsable(name, handler, opts) -- handler(src, ctx, item); schliesst Inventar, Rate-Limit, opts wie Net.On

-- Kassen
Law.Society.Get(dept)                               -> number
Law.Society.Add(dept, amount, reason, actorCtx?)    -> bool
Law.Society.Remove(dept, amount, reason, actorCtx?) -> bool   (atomar, nie ins Minus)

-- Protokoll
Law.Audit(actorCtxOrNil, action, targetCharId?, data?)  -- DB + Webhook-Kanal (ServerConfig.Webhooks)
Law.Webhook(channel, title, description, color?)

-- Buerger-Stammdaten (Tabelle ara_law_citizens, Kern)
Law.Citizens.Get(charId)                 -> { charId, bloodType, hasSample, dangerous, notes }  (legt Zeile + Blutgruppe bei Bedarf an; gecacht)
Law.Citizens.SetSample(charId, bool)     -- Blut-/Geruchsprobe liegt in der Akte
Law.Citizens.SetDangerous(charId, bool)
Law.Citizens.SetNotes(charId, text)

-- Stationen
Law.Stations.Get(key)                               -> stationCfg|nil
Law.Stations.NearPoint(src, pointType, maxDist?)    -> stationKey|nil, pointCfg   (serverseitige Naehe zu Config.Stations[*].points[pointType])

-- Leitstelle (Kern)
Law.Dispatch.Create(alert) -> id
--   alert = { kind='citizen'|'panic'|'shots'|'escape'|'robbery'|'npc'|'escort'|'bounty'|'system',
--             coords=vector3, title=string, text=string, priority=1..3, fuzz=meter?, perm='dispatch'?,
--             depts={...}?, callerSrc=src?, expires=sekunden?, blip={ style?, sprite?, color? }?,
--             onAccept=function(src, ctx, alert, firstResponder)?,  -- Server-Rueckruf bei Annahme
--             onClose=function(alert, reasonText)?,                 -- Server-Rueckruf beim Schliessen/Verfallen
--             data=table? }                                         -- freie Moduldaten, gehen nie an Clients
Law.Dispatch.ShotsFired(src, coords, weaponLabel) -- prueft Stadtzonen/Cooldown selbst
Law.Dispatch.Close(id, reasonText?)
Law.Dispatch.Get(id) -> alert|nil   (alert.responders = { [src]=true }, alert.data)

-- Laufzeit-Zustand (Wahrheit!) – Schreiben nur durch den Besitzer
Law.State.cuffed[src]      = officerSrc|true   -- Besitzer: Agent A
Law.State.escortedBy[src]  = officerSrc        -- Besitzer: Agent A
Law.State.jailed[src]      = charId            -- Besitzer: Agent A
Law.IsCuffed(src) / Law.IsJailed(src) / Law.IsEscorted(src)  -- Lese-Helfer (Kern)

-- Modul-Lebenszyklus
Law.Modules.Register(name, {
  init            = function() end,                    -- nach DB-Start, einmal
  playerLoaded    = function(src, ctx) end,            -- Charakter gewaehlt ODER Resource-Start mit Spieler online (einmal je charId)
  playerDropped   = function(src, cache, reason) end,  -- cache = Law.Players[src]-Kopie; Law.Ctx(src) kann hier schon nil sein!
  playerDied      = function(src, ctxOrNil) end,       -- vorp_core:Server:OnPlayerDeath (nur Signal, kein Beweis)
  playerRevived   = function(src) end,
  playerRespawned = function(src) end,                 -- Respawn (z.B. Krankenhaus)
  dutyChanged     = function(src, ctxOrNil, onDuty) end,
  jobChanged      = function(src, newJob, oldJob) end,
  stop            = function() end,                    -- onResourceStop
})
Law.Every(ms, fn)       -- Intervall-Thread (fehlerisoliert)
Law.DB.OnReady(fn)      -- falls ein Modul ausserhalb von init auf die DB wartet
Law.DB.Decode(text, fallback)  -- JSON sicher dekodieren
Law.DB.Like(text)              -- %, _ und \ fuer LIKE escapen

-- Weitere Kern-Helfer
Law.DB.Try(fn, ...)                  -- pcall um DB-await: ok, result (oxmysql .await WIRFT bei SQL-Fehler -> Rueckbuchung sonst nie erreicht)
Law.EntityCoordsWait(netId, ms)      -- wie EntityCoords, wartet bis der Server ein frisch gespawntes Entity kennt
Law.ModelMatches(ent, model)         -- Modellvergleich mit 32-Bit-Maske
Law.IsEntityOwner(ent, src)          -- NetworkGetEntityOwner == src. Server loescht NIE fremde Entities aufgrund einer Client-NetId
Law.IsPedDead(src)                   -- true|false|nil(unbekannt) aus Server-Ped-Gesundheit; ctx.isDead nutzt das bereits (Config.General.ValidateDeath)
Law.Dispatch.ListFor(src, ctx)       -- Einsaetze, die dieser Officer sehen darf
Law.IdentifierOf(charId)             -- Steam-ID eines (auch Offline-)Charakters, gecacht
Law.IsSelfOrAlt(ctx, charId)         -- charId ist der Handelnde selbst oder sein Zweitcharakter (gleiche Steam-ID)
Law.SamePlayer(charIdA, charIdB)     -- gleiche Steam-ID hinter zwei Charakteren
Law.IsAdmin(src)                     -- vorp-Gruppe in Config.General.AdminGroups
Law.DiedRecently(src, seconds)       -- true, wenn Tod/Respawn innerhalb seconds (Default 60)
Law.SyncPlayer(src)                  -- Client-Daten (Law.Me) neu schicken, z.B. nach Rangwechsel
Law.Duty.Set(src, on, reason)        -- Dienst an/aus (z.B. bei Inhaftierung eines Officers)
Law.Duty.active[src]                 -- { dept, grade, since, logId, charId } | nil
Law.Garage.GetNetId(src)             -- NetId des eigenen Dienstwagens | nil (fuer "in Wagen setzen")
Law.Items.SetMetadata(src, itemId, metadata)
Law.Dispatch.Public(alert, forSrc)   -- Alert in NUI-Form
Law.VecToTable(v) / Law.Copy(t) / Law.Count(t)
```

**Items-Regel:** Niemals `Law.Inv:subItem` / `subItemById` / `addItem` direkt aufrufen –
im vorp_inventory-Quelltext prüfen `subItem` (mit Metadaten) und `subItemById` NICHT, ob genug
Stück vorhanden sind. `Law.Items.*` zählt vorher. Waffen-Exports (`createWeapon`, `subWeapon`,
`getUserInventoryWeapons`, `setWeaponSerialNumber`, …) und Custom-Inventare (`registerInventory`,
`openInventory`, `addItemsToCustomInventory`, `addWeaponsToCustomInventory`, …) dürfen direkt über
`Law.Inv` benutzt werden – Signaturen stehen in
`resources/[VORP]/vorp_inventory/server/types/types.lua` (dort nachlesen, nicht raten).

### 4.1 Querverweis-APIs (Stubs im Kern, Besitzer überschreibt)

Der Kern definiert diese Funktionen als Stubs (warnen + neutrale Rückgabe). Der Besitzer ersetzt sie
**mit exakt dieser Signatur**. Aufrufer rufen sie ohne Existenzprüfung auf.

| Funktion | Besitzer | Rückgabe | Zweck |
|---|---|---|---|
| `Law.Jail.IsJailed(charId)` | A | bool | |
| `Law.Jail.Sentence(targetSrc, minutes, reason, officerCtx?, opts?)` | A | bool, errCode | opts = `{ location?, bail?, warrantIds?, codes?, noConfiscate?, dept? }` (`dept` = Kasse für Kaution ohne Officer) |
| `Law.Records.Add(charId, type, title, details?, officerCtx?, refId?)` | A | id | type: `note`,`arrest`,`fine`,`jail`,`release`,`escape`,`warrant`,`bounty`,`evidence`,`weapon`,`escort` |
| `Law.Warrants.CreateAuto(charId, reason, opts?)` | A | id | System-Haftbefehl, sofort `active`; opts = `{ codes?, jailMinutes?, bounty?, deadOrAlive?, dept? }` |
| `Law.Warrants.GetActive(charId)` | A | Liste Warrant | |
| `Law.Bounty.GetActive(charId)` | A | Liste Bounty | |
| `Law.Bounty.CanHunt(src)` | A | bool | gueltige Lizenz |
| `Law.Evidence.CreateTrace(kind, coords, data)` | B | id | kind: `casing`,`blood`,`cloth`; data = `{ ownerCharId?, weapon?, serial?, bloodType? }` |
| `Law.Evidence.LastShotAt(charId)` | B | unix\|nil | |
| `Law.Weapons.RegisterIssued(serial, weaponName, charId, dept)` | B | bool | Waffenkammer |
| `Law.Weapons.GetByOwner(charId)` | B | Liste `{ serial, weapon, weaponLabel, status }` | Akte |
| `Law.Weapons.Lookup(serial)` | B | WeaponInfo\|nil | |
| `Law.Scent.HasTrail(charId)` | B | bool | |
| `Law.Escort.OnPlayerDeath(src)` | B | – | Kern ruft bei Tod auf |

---

## 5. Kern-API – Client

```lua
Law.VORP                                -- exports.vorp_core:GetCore()
Law.Ready                               -- true nach Charakterwahl + Sync
Law.Me = { charId, name, job, grade, dept, deptLabel, gradeLabel, onDuty, perms = { [perm]=true } }
Law.HasPerm(perm)                       -- NUR Anzeige-Hilfe (Server entscheidet)
Law.Notify(text, kind, ms)
Law.Net.Send(name, ...)                 -- TriggerServerEvent('ara_law:sv:'..name, ...)
Law.Cb.Await(name, ...)                 -- -> Ergebnis vom Server-Callback (im Thread aufrufen)
Law.Answer(name, fn)                    -- fn(payload) -> result   (Antwort auf Law.Ask)
Law.On(name, fn)                        -- RegisterNetEvent('ara_law:cl:'..name) + Handler

-- NUI
Law.UI.Open(app, data)                  -- Fokus an
Law.UI.Update(app, data)
Law.UI.Close()                          -- alles Fokussierte zu
Law.UI.Hud(name, data|nil)              -- nil versteckt
Law.UI.Toast(title, text, kind, ms)
Law.UI.Menu(def)                        -- blockierend: gewaehlte id | nil
Law.UI.Form(def)                        -- blockierend: values-Tabelle | nil
Law.UI.Document(def)                    -- zeigt Dokument (Fokus bis Schliessen)
Law.UI.OnAction(app, name, fn)          -- fn(payload) -> result  (App-spezifische NUI-Aktionen; EIN Handler je app:name)
Law.UI.RegisterForm(formId, fn)         -- fn(payload) -> result; wird von der NUI-Aktion ledger:openForm {form=formId,...} aufgerufen
Law.UI.Show(app, data)                  -- ohne Fokus anzeigen (badge)
Law.UI.IsOpen()
Law.OpenLedger(tab, focusCharId)        -- Dienstbuch oeffnen (blockierend, im Thread)

-- Welt
Law.Stations.RegisterPoint(pointType, {
  label   = 'Text' | function(stationKey) return 'Text' end,
  law     = true|nil,        -- nur Behoerde (Anzeige)
  perm    = 'perm'|nil,      -- nur mit Recht (Anzeige)
  duty    = true|nil,
  canShow = function(stationKey, point) return true end,   -- optional
  onUse   = function(stationKey, point) end,
  hold    = 500,             -- ms Halten
})
Law.Interact.Register(id, {
  label  = 'Text', desc = 'Text'?, order = 10,
  target = true|false,       -- true: braucht Spieler in Reichweite, false: Selbst-Aktion
  perm   = 'perm'|nil, law = true|nil, duty = true|nil,
  canShow = function(targetSrc) return true end,
  onSelect = function(targetSrc) end,
})
Law.Util.GetClosestPlayer(maxDist)      -> serverId|nil, ped, dist
Law.Util.GetPlayersInRange(maxDist)     -> { { serverId, name?, dist }, ... }
Law.Util.LoadModel(model, timeoutMs)    -> bool
Law.Util.LoadAnimDict(dict, timeoutMs)  -> bool
Law.Util.PlayAnim(ped, dict, anim, flag, durationMs)
Law.Util.AddBlip(coords, sprite, name, color) -> blip
Law.Util.RemoveBlip(blip)
Law.Util.Progress(text, ms)             -> bool (vorp_progressbar, blockierend)
Law.Util.SetWaypoint(coords)
Law.Util.DeleteEntity(ent)
Law.Util.NetToEnt(netId, timeoutMs)     -> entity|0
Law.Util.RequestControl(ent, timeoutMs) -> bool
Law.Util.PlayerName(serverId)           -> Anzeigename aus vorp-Statebag "Character"
Law.Util.ClearWaypoint()
Law.Modules.Register(name, { init, onReady, onSync(me), onDuty(onDuty), onStop })
Law.State = { cuffed=false, escorted=false, jailed=false, dead=false }  -- vom Server gesetzt
Law.HasPermAnyDuty(perm)                -- Recht ohne Dienstpruefung (Anzeige)
```

Der Kern (Client) setzt `Law.State.cuffed/jailed` aus `core:sync`. Agent A setzt sie zusätzlich in
seinen eigenen Events (`arrest:setCuffed`, `jail:*`) – beide Quellen kommen vom Server und sind konsistent.

---

## 6. Rechte (Permission-Keys)

| Key | Bedeutung | Nutzer |
|---|---|---|
| `all` | alles | Kern |
| `duty` | Dienst an/aus | Kern |
| `badge` | Marke zeigen | Kern |
| `storage` | Dienstlager | Kern |
| `armory` | Waffenkammer | Kern |
| `garage` | Dienstwagen | Kern |
| `dispatch` | Notrufe empfangen/annehmen | Kern |
| `cuff` | fesseln/lösen | A |
| `escort` | abführen, in/aus Wagen | A |
| `search` | durchsuchen | A |
| `idcheck` | Akte im Feld | A |
| `fine` / `fine_cancel` | Bußgeld / stornieren | A |
| `jail` / `jail_release` | einsperren / freilassen, Zeit ändern, Kaution | A |
| `records_view` / `records_edit` | Akten lesen / schreiben | A |
| `warrant_create` / `warrant_approve` | Haftbefehl | A |
| `bounty_manage` | offizielle Kopfgelder, private freigeben/stornieren | A |
| `license_manage` | Lizenzen entziehen | A |
| `npc_calls` | NPC-Streifeneinsätze bekommen | A |
| `evidence` / `evidence_analyze` | Spuren sichern / Labor, Schmauchtest | B |
| `weapons_registry` | Waffenregister | B |
| `k9` / `scent_sample` | Bluthund / Geruchsprobe nehmen | B |
| `escort_contracts` / `escort_lead` | Eskorte annehmen / leiten | B |
| `boss_hire`, `boss_fire`, `boss_promote`, `boss_funds`, `boss_logs` | Chef | Kern |

---

## 7. Datenbank (Kern legt ALLE Tabellen an – Agenten legen KEINE Tabellen an)

Alle Zeiten `INT UNSIGNED` Unix-Sekunden (`Law.Now()`). Geld `DECIMAL`. JSON als `LONGTEXT`.

```
ara_law_society        department VARCHAR(32) PK, balance DECIMAL(14,2), updated_at INT
ara_law_society_log    id PK AI, department, amount DECIMAL(14,2), balance_after DECIMAL(14,2), reason VARCHAR(64),
                       actor_charid INT NULL, actor_name VARCHAR(100), created_at INT
ara_law_duty_log       id PK AI, charid INT, name, department, grade INT, started_at INT, ended_at INT NULL, seconds INT
ara_law_audit          id BIGINT PK AI, actor_charid INT NULL, actor_name, action VARCHAR(48), target_charid INT NULL,
                       data LONGTEXT NULL, created_at INT
ara_law_citizens       charid INT PK, blood_type VARCHAR(3), has_sample TINYINT, dangerous TINYINT, notes TEXT NULL, updated_at INT
ara_law_records        id PK AI, charid INT, type VARCHAR(16), title VARCHAR(128), details TEXT NULL, ref_id INT NULL,
                       officer_charid INT NULL, officer_name VARCHAR(100) NULL, department VARCHAR(32) NULL, created_at INT
ara_law_fines          id PK AI, charid INT, target_name, officer_charid INT NULL, officer_name, department,
                       reason VARCHAR(255), codes LONGTEXT NULL, amount DECIMAL(10,2),
                       status VARCHAR(12) ('open','paid','cancelled','overdue'), created_at INT, due_at INT,
                       paid_at INT NULL, paid_by_charid INT NULL
ara_law_warrants       id PK AI, charid INT, target_name, reason VARCHAR(255), codes LONGTEXT NULL, jail_minutes INT,
                       dead_or_alive TINYINT, department, created_by INT NULL, created_by_name, approved_by INT NULL,
                       approved_by_name NULL, status VARCHAR(12) ('pending','active','served','revoked','expired'),
                       created_at INT, expires_at INT NULL, closed_at INT NULL
ara_law_bounties       id PK AI, charid INT, target_name, kind VARCHAR(10) ('official','private'), warrant_id INT NULL,
                       amount DECIMAL(10,2), placed_by INT NULL, placed_by_name NULL, placed_by_identifier VARCHAR(64) NULL,
                       department VARCHAR(32) NULL, reason VARCHAR(255), dead_or_alive TINYINT,
                       status VARCHAR(12) ('pending','active','claimed','cancelled','expired'),
                       claimed_by INT NULL, claimed_by_name NULL, claimed_at INT NULL, created_at INT, expires_at INT NULL
ara_law_licenses       id PK AI, charid INT, type VARCHAR(16) ('bounty','weapon'), status VARCHAR(12) ('active','revoked','expired'),
                       issued_at INT, expires_at INT NULL, issued_by INT NULL
ara_law_jail           charid INT PK, name, location VARCHAR(32), sentence_seconds INT, served_seconds INT, reduced_seconds INT,
                       reason VARCHAR(255), officer_charid INT NULL, officer_name NULL, bail DECIMAL(10,2) NULL,
                       department VARCHAR(32) NULL, has_property TINYINT, jailed_at INT, updated_at INT
ara_law_payouts        id PK AI, charid INT, amount DECIMAL(12,2), currency TINYINT, reason VARCHAR(64), created_at INT
                       (nur ueber Law.Money.GiveCharId / Kern)
ara_law_evidence       id PK AI, type VARCHAR(12) ('casing','blood','cloth','scent'), weapon VARCHAR(64) NULL, serial VARCHAR(50) NULL,
                       owner_charid INT NULL, blood_type VARCHAR(3) NULL, x FLOAT, y FLOAT, z FLOAT, zone VARCHAR(64) NULL,
                       created_at INT, collected_by INT NULL, collected_by_name NULL, collected_at INT,
                       department VARCHAR(32) NULL, status VARCHAR(12) ('collected','analyzing','analyzed','destroyed'),
                       analysis LONGTEXT NULL, analyzed_by_name NULL, analyzed_at INT NULL
ara_law_weapons        serial VARCHAR(50) PK, weapon VARCHAR(64), owner_charid INT NULL, owner_name NULL,
                       status VARCHAR(12) ('registered','stolen','confiscated','issued','destroyed'), department VARCHAR(32) NULL,
                       registered_at INT, registered_by INT NULL, notes VARCHAR(255) NULL, updated_at INT
ara_law_escorts        id PK AI, type VARCHAR(16) ('bodyguard','transport','cargo'), client_charid INT, client_name,
                       client_identifier VARCHAR(64), recipient_charid INT NULL, recipient_name NULL,
                       pickup VARCHAR(32), destination VARCHAR(32) NULL, duration_min INT NULL, escorts_required INT,
                       price DECIMAL(10,2), insurance TINYINT, premium DECIMAL(10,2), insured_value DECIMAL(12,2),
                       cargo LONGTEXT NULL, cargo_money DECIMAL(12,2), cargo_gold DECIMAL(12,2), department VARCHAR(32),
                       leader_charid INT NULL, leader_name NULL, escorts LONGTEXT NULL,
                       status VARCHAR(12) ('open','accepted','active','delivered','claimed','completed','failed','robbed','cancelled','expired'),
                       status_reason VARCHAR(64) NULL, claim_office VARCHAR(32) NULL,
                       insurance_state VARCHAR(12) ('none','pending','paid','denied','expired'), insurance_amount DECIMAL(12,2),
                       insurance_by NULL, insurance_at INT NULL, robbed_by INT NULL, robbed_by_identifier VARCHAR(64) NULL,
                       created_at INT, accepted_at INT NULL, started_at INT NULL, finished_at INT NULL, deadline_at INT NULL, claimed_at INT NULL
```

Pflicht-Muster für Statuswechsel mit Geld/Items:
```lua
local affected = MySQL.update.await('UPDATE ara_law_bounties SET status = ?, claimed_by = ?, claimed_at = ? WHERE id = ? AND status = ?',
    { 'claimed', ctx.charId, Law.Now(), id, 'active' })
if affected ~= 1 then return Law.Result(false, 'already_done') end
-- ERST JETZT auszahlen
```

---

## 8. Items

| Item | Label | Besitzer | Nutzung |
|---|---|---|---|
| `handcuffs` (vorhanden) | Handschellen | A | benutzbar: nächsten Spieler fesseln |
| `handcuffkey` (vorhanden) | Handschellenschlüssel | A | benutzbar: lösen |
| `lockpick` (vorhanden, gehört vorp_doorlocks) | Dietrich | A/B | **NICHT** registrieren – nur `Law.Items.Count/Take` |
| `bountylicns` (vorhanden) | Kopfgeldjäger-Lizenz | A | benutzbar: Lizenz vorzeigen (Dokument). Gültigkeit steht in DB |
| `law_badge` | Dienstmarke | Kern | benutzbar: Marke zeigen |
| `law_fineticket` | Bußgeldbescheid | A | benutzbar: Dokument anzeigen, metadata `{ fine_id, description }` |
| `law_evidence_bag` | Beweismittelbeutel | B | Verbrauch beim Sichern |
| `law_casing` | Patronenhülse (Beweis) | B | metadata `{ evidence_id, description }` |
| `law_bloodsample` | Blutprobe (Beweis) | B | metadata `{ evidence_id, description }` |
| `law_clothscrap` | Stofffetzen (Beweis) | B | metadata `{ evidence_id, description }` |
| `law_scentcloth` | Geruchstuch | B | metadata `{ evidence_id, description, uses }` |
| `law_whistle` | Hundepfeife | B | benutzbar: Bluthund rufen/heimschicken |
| `law_gunfile` | Waffenfeile | B | benutzbar: Seriennummer abfeilen |
| `law_weaponpermit` | Waffenschein | B | benutzbar: Dokument, metadata `{ serial, weapon, owner, description }` |
| `law_strongbox_tool` | Brecheisen | B | Werttransport knacken (Verbrauch) |

---

## 9. Stationen & Punkt-Typen

Eine Datei je Station: `config/stations/<key>.lua` (Vorlage mit allen Feldern: `config/stations/_vorlage.lua`).

`Config.Stations[key] = { enabled, label, depts = { 'sheriff', ... } | nil (alle), jailTo = '<Knast-Ort>'?, blip = { enabled, name, sprite, style, color?, coords? }, points = { <typ> = { coords=vector3, heading?, radius?, spawn?, enabled? } | { {…},{…} } }, cells = { enabled, label, center, radius, spawn, release, work }?, shotsZone = { enabled, coords, radius, label? }? }`

`shared/03_stations.lua` (laedt nach allen Configs, Client + Server) baut daraus beim Start:
Stationen/Punkte mit `enabled = false` werden entfernt (der restliche Code sieht sie nie),
`cells` → `Config.Jail.Locations[key]`, `jailTo` → `Config.Jail.StationLocation[key]`,
`shotsZone` → Eintrag in `Config.Dispatch.ShotsFired.Zones`. `spawn` als vector3 wird zu vector4 (Richtung 0.0).
Fehlerhafte Eintraege werden mit Warnung uebersprungen.

| Punkt-Typ | Besitzer | Wer | Aktion |
|---|---|---|---|
| `duty` | Kern | Behörde | Dienst an/aus |
| `boss` | Kern | `boss_*` | Dienstbuch Tab „Behörde" |
| `storage` | Kern | `storage` | vorp-Lager `ara_law_storage_<dept>` |
| `armory` | Kern | `armory` | Menü Waffen/Ausrüstung (Kasse zahlt) |
| `garage` | Kern | `garage` | Gefangenenwagen/Pferd ausparken/einparken; `spawn = vector4` |
| `counter` | Kern öffnet (`core:counterOpen`), Tab-Daten A/B | alle | Schalter-NUI |
| `board` | Kern öffnet (`core:boardOpen`), Daten A (`bounty:board`, `npc:accept`) | alle | Steckbriefbrett-NUI |
| `jail` | A | `jail` | Einbuchen (Formular Haftstrafe) |
| `dropoff` | A | Jäger/Gesetz | Kopfgeld abliefern (Zone `radius`) |
| `evidence` | B | `evidence` | Asservatenkammer + Labor |
| `kennel` | B | `k9` | Bluthund holen/abgeben |
| `escort` | B | alle / `escort_lead` | Eskort-Büro: Wagen-Spawn `spawn = vector4`, Liefer-/Abholzone `radius` |

Knast-Orte stehen in `Config.Jail.Locations` (A), Eskort-Büros sind Stationen mit `escort`-Punkt (B nutzt `Config.Stations`).

---

## 10. NUI-Protokoll (Agent C baut, alle anderen senden)

### 10.1 Lua → JS (`SendNUIMessage`)
```js
{ type: 'init',   data: { locale: 'de', strings: { ui_*: '...' }, currency: '$', resource: 'ArA-LawSystem' } }
{ type: 'open',   app: '<app>', data: {...} }      // oeffnet App (Stapel: form/menu/document ueber ledger/counter/board)
{ type: 'update', app: '<app>', data: {...} }      // Daten einer offenen App ersetzen/ergaenzen
{ type: 'close' }                                  // alle fokussierten Apps schliessen
{ type: 'hud',    hud: '<name>', data: {...}|null }// HUD zeigen/aktualisieren/verstecken (ohne Fokus)
{ type: 'toast',  data: { title, text, kind: 'info'|'success'|'error'|'alert', ms } }
```

### 10.2 JS → Lua (`fetch('https://' + GetParentResourceName() + '/<endpoint>', { method:'POST', body: JSON })`)
| Endpoint | Body | Antwort |
|---|---|---|
| `ready` | `{}` | `{ ok:true }` – Lua schickt danach `init` |
| `close` | `{ seq }` | `{ ok:true }` – Lua nimmt Fokus weg, bricht offene Menu/Form ab. `seq` = höchste empfangene `open.seq`; ist Lua schon weiter, wird das close ignoriert (`{ ok:true, stale:true }`) |
| `cb` | `{ name: 'fines:list', args: [...] }` | Ergebnis des Server-Callbacks (1:1) |
| `action` | `{ app, name, payload }` | Ergebnis des Lua-Handlers `Law.UI.OnAction(app, name, fn)` |
| `menuSelect` | `{ id }` | `{ ok:true }` |
| `formSubmit` | `{ values }` | `{ ok:true }` |
| `formCancel` / `menuCancel` | `{}` | `{ ok:true }` |

### 10.3 Generische Apps
- **`menu`**: `{ title, subtitle?, items: [{ id, label, desc?, icon?, disabled?, badge? }] }` → `menuSelect{id}` / `menuCancel`
- **`form`**: `{ id, title, subtitle?, submitLabel?, fields: [Field], summary?: 'penalcode' }` → `formSubmit{values}` / `formCancel`
  - `Field = { name, type, label, required?, min?, max?, maxLength?, options?, default?, placeholder?, help? }`
  - `type`: `text` · `textarea` · `number` · `money` · `select` · `multiselect` · `checkbox` · `readonly` ·
    `penalcode` (options = `[{ value:id, label, category, fine, jail }]`, Wert = `[{ id, count }]`, zeigt Summe Bußgeld/Haft)
  - `options` sonst: `[{ value, label, desc? }]`
- **`document`**: `{ kind: 'ticket'|'warrant'|'poster'|'license'|'permit'|'report'|'evidence', title, subtitle?, fields: [{ label, value }], body?, footer?, seal?: deptKey, signature? }`
- **`badge`**: `{ name, deptLabel, gradeLabel, badgeNumber, seal: deptKey }` – ohne Fokus, blendet nach `ms` (Default 6000) aus

### 10.4 HUDs (`type:'hud'`)
| hud | data |
|---|---|
| `jail` | `{ remaining, total, reduced, work: { done, max } }` (Sekunden) |
| `cuffed` | `{ by: 'Name'? }` |
| `k9` | `{ state: 'idle'|'following'|'staying'|'sniffing'|'tracking'|'waiting'|'lost'|'found'|'searching', strength: 'fresh'|'medium'|'weak'|null, text }` |
| `escort` | `{ id, typeLabel, statusLabel, destinationLabel, timeLeft, escortsNear, escortsTotal }` |
| `evidence` | `{ active: bool, count }` |
| `duty` | `{ deptLabel, gradeLabel }` (kleines Abzeichen, optional per Config) |
| `robbery` | `{ progress: 0..1, text }` |

### 10.5 Fachliche Apps
**`ledger`** (Dienstbuch) – open data:
`{ officer: { name, dept, deptLabel, gradeLabel, badgeNumber, perms: [..] }, tab: 'overview'|..., focusCharId? }`
Tabs werden nach `perms` ein-/ausgeblendet. Buttons, die ein Formular brauchen, senden
`action { app:'ledger', name:'openForm', payload:{ form:'<form>', charId?, id? } }` – das Modul öffnet dann `form`.

| Tab | Recht | Callbacks (`cb`) | Aktionen (`action`) |
|---|---|---|---|
| overview | law | `core:ledgerOverview` → `{ onDuty:[Officer], alerts:[Alert], stats:{ openWarrants, activeBounties, inmates, openEscorts } }` · `dispatch:accept(id)` · `dispatch:close(id)` | `setWaypoint {x,y,z}` |
| people | `records_view` | `records:search(query)` → `[PersonHit]` · `records:getFile(charId)` → `File` · `records:addNote(charId, title, text)` · `records:setDangerous(charId, bool)` | `openForm fine/warrant/bounty_official/note {charId}` |
| warrants | `records_view` | `warrants:list(status)` → `[Warrant]` · `warrants:approve(id)` · `warrants:revoke(id)` | `openForm warrant` |
| bounties | `records_view` | `bounty:list(status)` → `[Bounty]` · `bounty:approve(id)` · `bounty:cancel(id)` | `openForm bounty_official` |
| fines | `records_view` | `fines:list(status)` → `[Fine]` · `fines:cancel(id)` | |
| jail | `records_view` | `jail:list()` → `[Inmate]` · `jail:release(charId)` · `jail:adjust(charId, minutesDelta)` · `jail:setBail(charId, amount)` | |
| evidence | `evidence` | `evidence:list(filter)` → `[Evidence]` · `evidence:get(id)` → `Evidence` · `evidence:destroy(id)` | |
| weapons | `weapons_registry` | `weapons:lookup(serial)` → `WeaponInfo` · `weapons:setStatus(serial, status, note)` | |
| escorts | `escort_contracts` | `escort:listOpen()` → `[Escort]` · `escort:listMine()` · `escort:accept(id)` · `escort:leave(id)` | |
| department | `boss_*` | `boss:overview()` → `{ dept, deptLabel, balance, myGrade, grades:[{grade,label}], members:[Member], log:[SocietyLog], can:{ hire, fire, promote, funds, logs } }` · `boss:fire(charId)` · `boss:setGrade(charId, grade)` · `boss:deposit(amount)` · `boss:withdraw(amount)` (beide → `{ balance }`) | `openForm hire` |

Zusätze (Kern, gebaut):
- `core:ledgerOpen()` → `{ officer: { name, dept, deptLabel, gradeLabel, badgeNumber, seal, onDuty, perms:[..] } }` (Lua öffnet damit `ledger`).
- `core:ledgerOverview()` → `{ onDuty:[{ name, dept, deptLabel, gradeLabel, since }], alerts:[Alert], stats:{ openWarrants, activeBounties, inmates, openEscorts, balance } }`.
- `dispatch:list()` → `[Alert]`.
- Lua schickt `{ type:'update', app:'ledger', data:{ alertsChanged:true } }`, wenn sich Einsätze ändern → die NUI lädt die Übersicht neu, falls sie gerade offen ist.
- `open` kann `nofocus: true` tragen (Marke) → App ohne Maus/Tastatur-Fokus anzeigen, nach `data.ms` selbst ausblenden.
- HUD `duty` data: `{ deptLabel, gradeLabel, badgeNumber }`.

**`counter`** (Schalter) – open data (von `core:counterOpen`): `{ station, stationLabel, citizen: { name, charId }, tabs: ['fines','bail','license','bounty','weapons','escort','property','report'] }` (`escort` nur an Stationen mit escort-Punkt)
| Tab | Callbacks |
|---|---|
| fines | `fines:mine()` → `[Fine]` · `fines:pay(id)` |
| bail | `jail:bailList()` → `[{ charId, name, bail }]` · `jail:payBail(charId)` |
| license | `bounty:licenseStatus()` → `{ active, expiresAt, price, days }` · `bounty:buyLicense()` |
| bounty | `bounty:searchTarget(name)` → `[{ charId, name }]` · `bounty:placePrivate({ charId, amount, reason, deadOrAlive })` · `bounty:minePlaced()` → `[Bounty]` · `bounty:cancelPrivate(id)` |
| weapons | `weapons:mine()` → `[{ id, serial, weapon, weaponLabel, registered, status, filed }]` · `weapons:register(weaponId)` · `weapons:reportStolen(serial)` |
| escort | `escort:options(station)` → `{ types:[...], destinations:[...], cargoItems:[...], insurance:{...} }` · `escort:quote(values)` → `{ price, premium, total, breakdown:[{label,amount}] }` · `escort:book(values)` · `escort:mine()` → `[Escort]` · `escort:cancel(id)` · `escort:claim(id)` |
| property | `jail:propertyStatus()` → `{ hasProperty }` · `jail:claimProperty()` |
| report | `dispatch:report(text)` |

**`board`** (Steckbriefbrett) – open data (von `core:boardOpen`): `{ station, stationLabel, canHunt }`
Callbacks: `bounty:board()` → `{ posters:[Poster], bounties:[Bounty], contracts:[NpcContract] }` · `npc:accept(id)`.

### 10.6 Datenformen
```
Result      { ok:bool, err?:string, msg?:string, data?:any }
Officer     { name, dept, deptLabel, gradeLabel }
Alert       { id, kind, title, text, coords:{x,y,z}, zone?, priority, createdAt, expiresAt, responders:[string], mine:bool }
PersonHit   { charId, name, age?, gender?, flags:{ warrant, bounty, jailed, dangerous } }
File        { charId, name, age?, gender?, bloodType?, dangerous, notes?, flags, records:[Record], fines:[Fine],
              warrants:[Warrant], bounties:[Bounty], jail:Inmate|null, weapons:[{serial,weapon,weaponLabel,status}],
              licenses:[{ type, status, expiresAt }] }
Record      { id, type, typeLabel, title, details?, officerName?, deptLabel?, createdAt }
Fine        { id, charId, targetName, officerName, deptLabel, reason, codes:[{id,label,count}], amount, status, statusLabel, createdAt, dueAt, paidAt? }
Warrant     { id, charId, targetName, reason, codes, jailMinutes, deadOrAlive, deptLabel, createdByName, approvedByName?, status, statusLabel, createdAt, expiresAt?, bounty? }
Bounty      { id, charId, targetName, kind, amount, reason, deadOrAlive, status, statusLabel, placedByName?, createdAt, expiresAt? }
Poster      { charId, name, reason, amount, deadOrAlive, crimes:[string], deptLabel, createdAt }
Inmate      { charId, name, location, locationLabel, sentence, served, remaining, reason, officerName?, bail?, online }
Evidence    { id, type, typeLabel, zone?, createdAt, collectedByName, collectedAt, status, statusLabel,
              weaponLabel?, serial?, bloodType?, analysis?:{ summary, lines:[string], match?:{ charId, name } } }
WeaponInfo  { serial, weapon, weaponLabel, status, statusLabel, ownerName?, ownerCharId?, registeredAt?, notes?,
              currentHolder?:{ name }, evidence:[{ id, type, typeLabel, zone?, createdAt }] }
Escort      { id, type, typeLabel, clientName, recipientName?, pickup, pickupLabel, destination?, destinationLabel?,
              durationMin?, escortsRequired, escorts:[string], leaderName?, price, payoutEstimate?, insurance,
              status, statusLabel, createdAt, deadlineAt?, cargoSummary?, canClaim?:bool }
NpcContract { id, name, description, areaLabel, reward, aliveBonus, gangSize, difficulty, expiresAt }
Member      { charId, name, grade, gradeLabel, online, onDuty, dutyHours7d }
SocietyLog  { id, amount, balanceAfter, reason, actorName?, createdAt }
```
Alle Zeitwerte an die NUI: Unix-Sekunden. Alle Geldwerte: Zahl (NUI formatiert).

### 10.7 Formulare (Form-IDs) – Besitzer baut die Felder und verarbeitet `values`
| Form-ID | Besitzer | Felder (Kern) |
|---|---|---|
| `fine` | A | target(readonly/player), codes(penalcode), note(text) |
| `jail` | A | target, codes(penalcode), minutes(number), bail(money), location(select), note |
| `warrant` | A | charId(readonly), codes(penalcode), reason, jailMinutes, deadOrAlive(checkbox), bounty(money) |
| `bounty_official` | A | charId, amount, reason, deadOrAlive |
| `note` | A | title, text(textarea) |
| `hire` | Kern | player(select Spieler in Nähe), grade(select) |
| `escort_book` | B | im Schalter-Tab integriert (keine eigene Form) |

---

## 11. Sicherheitsregeln (für jeden Handler)

1. Nur `Law.Net.On` / `Law.Cb.Register` – nie direkt `RegisterNetEvent` für `ara_law:sv:*`.
2. Jede Client-Zahl/-Zeichenkette durch `Law.ToInt/ToMoney/ToStr/ToBool`, Wertebereich aus Config.
3. Ziel-Spieler: `Law.Ctx(target)` muss existieren, `target ~= src`, Distanz via `Law.IsNear` (serverseitig).
4. Ortsgebundene Aktionen: `Law.Stations.NearPoint(src, typ)` bzw. `Law.IsNearCoords`.
5. Geld/Items nur über `Law.Money` / `Law.Items`. Prüfen und Abziehen ohne `await`/`Wait` dazwischen.
6. Auszahlungen nur nach atomarem Statuswechsel (Abschnitt 7).
7. SQL nur mit `?`-Platzhaltern. `LIKE`-Suche: `%`/`_` im Suchtext escapen, Mindestlänge 2, `LIMIT`.
8. Keine Webhooks/Secrets in `config/*.lua` außer `config/server_only.lua`.
9. Statebags nur schreiben, nie lesen für Entscheidungen.
10. Schleifen: weit weg `Wait(1000)`, nah `Wait(0)`; kein `while true do Wait(0)` ohne Abbruch.
11. `stop`-Hook räumt Entities, Blips, Prompts, NUI-Fokus, Attach, Steuerungssperren auf.
12. Spiel-Texte ASCII (ae/oe/ue/ss), NUI-Texte (`ui_*`) dürfen Umlaute haben.
13. Jede sensible Aktion → `Law.Audit(...)`.
14. Im `stop`-Hook (Server) **keine** `.await`-Aufrufe und kein `Wait` – die Ressource wird gerade beendet. Nur synchrone Aufräumarbeit (Entities löschen, Tabellen leeren, `MySQL.update` ohne await).
15. `Law.Audit`, `Law.GetCharName`, `Law.Society.*`, `Law.Citizens.*` benutzen DB-await → nur in Handlern/Threads aufrufen, nie auf Datei-Ebene beim Laden.
16. `Law.Ctx(src)` kann jederzeit `nil` sein (Spieler weg). Jeder Zugriff darauf wird geprüft.

## 12. Erweiterungen

Braucht ein Modul etwas Neues:
- **Eigener Callback/Event**: frei im eigenen Modul-Präfix, im Abschlussbericht auflisten.
- **Neue Config-Schlüssel**: nur in der eigenen Config-Datei.
- **Neue NUI-Datenfelder**: zusätzliche Felder in Datenformen sind erlaubt (NUI ignoriert Unbekanntes), bestehende nie umbenennen.
- **Neue Tabelle/Spalte**: NICHT selbst anlegen → im Bericht anfordern (Head Dev ergänzt `server/core/01_db.lua`).
- **Kern-Funktion fehlt**: NICHT im Kern ändern → lokal im Modul lösen und im Bericht melden.
