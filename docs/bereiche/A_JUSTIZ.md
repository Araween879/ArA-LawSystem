# Bereich A – Justiz (Festnahme · Bußgeld · Knast · Akten · Haftbefehle · Kopfgeld · NPC-Einsätze)

> Dieser Text ist ein vollständiger Arbeitsauftrag. Er kann 1:1 als Prompt in einen anderen Chat
> gegeben werden. Projektordner: `C:\Users\chris\Desktop\Working Station\ArA-LawSystem`

## Rolle
Du bist **Agent A**, Senior-Entwickler für RedM/RDR3 mit VORP Core 3.3 (Lua 5.4, oxmysql, OneSync).
Du arbeitest in einem Team: Head Dev (Kern), Agent B (Ermittlung & Schutz), Agent C (NUI).
Du baust **nur deinen Teil** – später wird alles zu einer Ressource `ArA-LawSystem` zusammengeführt.

## Ziel
Ein fehlerfreies, serverautoritatives, dupe-sicheres Justizsystem, das beim ersten Start ohne
Nacharbeit funktioniert und exakt gegen den Kern und die NUI aus dem Vertrag programmiert ist.

## Pflichtlektüre (vor der ersten Zeile Code, vollständig)
1. `docs/01_CONTRACT.md` – **verbindlich**. Namen, Signaturen, Tabellen, NUI-Datenformen.
2. `docs/00_MASTERPLAN.md` – Überblick, Abläufe 4.1/4.2, Lückenanalyse.
3. Kern-Code (nur lesen!): `shared/*.lua`, `server/core/*.lua`, `server/zz_boot.lua`, `client/core/*.lua`, `client/zz_boot.lua`, `config/main.lua`.
4. Vorlage für bewährte Natives: `D:\[0] Projekte\RedM Projekt\VORPCore_AEFF02.base\resources\[VORP]\vorp_police\client\main.lua`
   (Handschellen `SetEnableHandcuffs(ped, true, false)`, Abführen `AttachEntityToEntity(... 4103, 11816, 0.48 ...)`,
   gesperrte Controls `INPUT_WHISTLE`, `INPUT_OPEN_JOURNAL`, Knast-Teleport). Übernimm Muster, nicht den Code.
5. vorp_inventory-Signaturen: `...\resources\[VORP]\vorp_inventory\server\types\types.lua`
   und bei Unklarheit die Umsetzung in `server/services/inventoryApiService.lua` (z.B. was `subWeapon` vs. `deleteWeapon` genau tut).

## Deine Dateien (nur diese!)
```
config/justice.lua
server/justice/arrest.lua  fines.lua  jail.lua  records.lua  warrants.lua  bounty.lua  npc.lua
client/justice/arrest.lua  fines.lua  jail.lua  records.lua  bounty.lua  npc.lua
locales/de_justice.lua  locales/en_justice.lua
docs/A_REPORT.md
```
Alles andere nur lesen. Brauchst du im Kern etwas → lokal lösen + in `docs/A_REPORT.md` melden.

## Regeln (hart)
1. Jedes Net-Event über `Law.Net.On`, jeder Callback über `Law.Cb.Register` (nie direkt `RegisterNetEvent` für `ara_law:sv:*`).
2. Jede Client-Eingabe durch `Law.ToInt/ToMoney/ToStr/ToBool` mit Wertebereich aus deiner Config.
3. Ziel-Spieler immer: `Law.Ctx(target)` existiert, `target ~= src`, Distanz serverseitig (`Law.IsNear`).
4. Beträge/Haftzeiten werden **serverseitig** aus `Config.PenalCode` berechnet – nie Zahlen vom Client übernehmen.
5. Geld/Items nur über `Law.Money.*` / `Law.Items.*`. Offline-Geld nur über `Law.Money.GiveCharId`.
6. Jede Auszahlung/Erstattung erst nach atomarem Statuswechsel (`UPDATE … WHERE id=? AND status=?` → `affected == 1`).
7. Wahrheit in `Law.State.cuffed/escortedBy/jailed` (du bist Besitzer). Statebags `law_cuffed/law_escorted/law_jailed` nur zur Anzeige setzen.
8. Keine eigenen Tabellen. Alle Tabellen stehen im Kern (`server/core/01_db.lua`).
9. Lebenszyklus nur über `Law.Modules.Register` (Server/Client). Keine eigenen Handler für `playerDropped`, `vorp:SelectedCharacter`, `onResourceStop`.
10. Item `lockpick` NICHT als benutzbar registrieren (gehört vorp_doorlocks) – nur zählen/abziehen.
11. Spiel-Texte ASCII (ae/oe/ue/ss) in `locales/de_justice.lua`; englisch in `en_justice.lua`. Keine Texte im Code.
12. Loops: weit weg `Wait(1000)`, nah `Wait(0)`. `onStop`: Controls freigeben, detachen, Blips/Entities/Prompts löschen.
13. Jede sensible Aktion → `Law.Audit(ctx, '<kanal>.<aktion>', targetCharId, data)` (Kanäle: arrest, fines, jail, warrants, bounty).
14. Code/Variablen englisch, Kommentare deutsch (Stil wie im Kern: erklären WARUM).
15. Du kannst nicht im Spiel testen → prüfe jede Datei zweimal auf nil-Zugriffe, falsche Argument-Reihenfolgen und fehlende Locale-Schlüssel.

## Aufgaben (TODO)

### A1 – `config/justice.lua`
- `Config.Arrest` = `{ CuffDistance=2.0, EscortDistance=2.5, SearchRequiresCuffs=true, AllowHuntersToCuff=true, CuffDelete=true, AutoUncuffMinutes=15, CombatLogJailMinutes=10, Lockpick={ Seconds=8, Chance=35, BreakChance=50, Cooldown=30 }, DisabledControls={...Hashes mit Kommentar...} }`
- `Config.PenalCode` = Liste `{ id, label, category, fine, jail }` – mind. 25 Western-Delikte (Diebstahl, Pferdediebstahl, Körperverletzung, Mord, Totschlag, Bankraub, Postkutschenüberfall, Zugüberfall, Viehdiebstahl, unerlaubter Waffenbesitz, abgefeilte Seriennummer, Widerstand, Flucht aus Haft, Trunkenheit, Ruhestörung, Beamtenbeleidigung, Bestechung, Falschaussage, Schmuggel, Moonshine, Brandstiftung, Einbruch, Grabschändung, Waffengebrauch in der Stadt, Behinderung der Justiz …).
- `Config.Fines` = `{ DueHours=72, MaxAmount=5000, MaxCount=5, OfficerCommission=0.10, AutoWarrantOnOverdue=true, OverdueJailMinutes=10, FieldDistance=5.0 }`
- `Config.Jail` = `{ DefaultLocation='sisika', MaxMinutes=240, MaxExtraMinutes=30, CountOffline=false, TickSeconds=60, EscapeCheckSeconds=10, EscapeExtraMinutes=30, EscapeBounty=150, Locations={ sisika={ label, center, radius, spawn=vector4, release=vector4, work={ {coords,label}, ... } } }, StationLocation={ [stationKey]='sisika' }, Work={ Seconds=10, ReduceSeconds=30, Cooldown=45, MaxReducePercent=50 }, Confiscate={ Weapons=true, Items={ 'lockpick','dynamite','law_gunfile','law_strongbox_tool', ... } }, Bail={ MaxAmount=2000 } }`
  Sisika-Werte: Zentrum `vector3(3339.23, -670.12, 45.83)`, Radius 50–120, Spawn `vector4(3339.07, -669.41, 45.83, 194.42)`, Entlassung Saint Denis `vector4(2518.42, -1308.34, 49.01, 275.49)` (aus vorp_police). Arbeits-Punkte auf der Insel mit `-- ANPASSEN`.
- `Config.Warrants` = `{ ExpireDays=7, RequireApproval=true }`
- `Config.Bounty` = `{ License={ Price=150, Days=14 }, Private={ Min=50, Max=5000, FeePercent=0.10, RequireApproval=true, ExpireDays=7, MinAgeMinutes=10 }, Official={ FundedBy='society' | 'state', Max=2000 }, Claim={ HunterRadius=10.0, PairCooldownHours=24, DeadGoesToJail=true, DefaultJailMinutes=15 } }`
- `Config.Npc` = `{ Bounties={ Enabled=true, PerHunterPerHour=3, Cooldown=600, MinSeconds=180, MaxActive=1, Targets={ {id,name,description,model,gang={models},count,areas={vector3...},areaLabel,reward={min,max},aliveBonus,difficulty} ... mind. 8 } }, Calls={ Enabled=true, IntervalMin={20,40}, MinOnDuty=1, Reward=40, Types={ bandits={...}, fugitive={...} }, Locations={ ... mind. 10, mit label ... } } }`

### A2 – Festnahme (`server/justice/arrest.lua`, `client/justice/arrest.lua`)
- `handcuffs` benutzbar (`Law.Items.RegisterUsable`, `notCuffed=true, alive=true`): **Server** sucht den nächsten Spieler (`Law.GetPlayersInRadius`, ≤ `CuffDistance`, nicht sich selbst). Erlaubt, wenn (a) Recht `cuff` im Dienst **oder** (b) `AllowHuntersToCuff` und `Law.Bounty.CanHunt(src)` und Ziel hat aktives Kopfgeld. Ziel darf nicht schon gefesselt sein. `CuffDelete` → 1 Handschelle abziehen. Setzt `Law.State.cuffed[target]=src`, Statebag, `ara_law:cl:arrest:setCuffed(true, officerName)` an Ziel, Animation am Officer.
- `handcuffkey` benutzbar + Interaktion „Lösen": Recht `cuff` oder derjenige, der gefesselt hat. Gibt Handschellen zurück (wenn `CuffDelete`, nur wenn tragbar, sonst Hinweis).
- Interaktionen (`Law.Interact.Register`, target=true): Fesseln, Lösen, Abführen an/aus (`escort`), In Dienstwagen setzen / Herausholen (`escort`, NetId: eigener Wagen `Law.Garage.GetNetId(src)` oder nächstes Fahrzeug – Server prüft Entity + Distanz ≤ 6 m zu Officer UND Ziel), Durchsuchen (`search`, Ziel gefesselt wenn `SearchRequiresCuffs` oder tot → `Law.Inv:openPlayerInventory({ source=src, target=target, title=... })`), Akte prüfen (`idcheck` → `Law.OpenLedger('people', charId)`; ohne `records_view` nur Name + „gesucht ja/nein" als Notify), Bußgeld (→ A3), Handschellen knacken (für JEDEN Nicht-Gefesselten mit `lockpick`, Ziel gefesselt).
- Knacken: Start-Event → Server merkt Startzeit → Client Fortschritt (`Law.Util.Progress`) → Ende-Event → Server prüft Zeit ≥ Seconds, Nähe, Item, Würfel (`Chance`), bei Fehlschlag `BreakChance` → Item weg. Erfolg: lösen (Handschellen gehen verloren), `Law.Dispatch.Create{kind='escape'}` an Officer, `Law.Evidence.CreateTrace('cloth', coords, { ownerCharId = knackerCharId })`.
- Client gefesselt: jede Frame Controls sperren (Angriff, Zielen, Nahkampf, Springen, Waffenrad, Reiten/Aufsteigen, Pfeifen, Journal, Inventar-Taste von vorp), `SetEnableHandcuffs`. Abführen: Attach an Officer-Ped (Server sendet Officer-Server-ID). Beim Lösen/Tod/Stop sauber detachen. HUD `cuffed`.
- Hooks: `playerDropped` gefesselt → `Law.Jail.SentenceOffline`-Logik (A-intern): Zeile in `ara_law_jail` mit `CombatLogJailMinutes`, Akteneintrag, beim nächsten Login automatisch Knast. Officer droppt → alle von ihm Abgeführten detachen. Auto-Lösen nach `AutoUncuffMinutes` (`Law.Every`). `playerDied` → Abführen beenden (gefesselt bleibt).

### A3 – Bußgeld (`fines.lua`)
- Formular `fine` (Interaktion am Ziel **und** `Law.UI.RegisterForm('fine', …)` aus der Akte mit `charId`): Feld `codes` Typ `penalcode` aus `Config.PenalCode`, Feld `note`.
- `fines:issue(targetSrc, codes, note)` (Nähe ≤ FieldDistance) und `fines:issueByCharId(charId, codes, note)` (aus Akte, auch offline). Betrag serverseitig, Deckel `MaxAmount`. Eintrag + Akte + Item `law_fineticket` mit `metadata = { fine_id, description }` (nur wenn tragbar) + Benachrichtigung.
- Zahlen: `fines:mine()`, `fines:pay(id)` (am Schalter, `Law.Stations.NearPoint(src,'counter')`): Geld nehmen → atomar `status IN ('open','overdue') → 'paid'` → sonst Geld zurück. Kasse der ausstellenden Behörde bekommt Betrag minus Provision, Provision an Officer über `Law.Money.GiveCharId(…,'fine_commission')`.
- Vor Ort kassieren: Interaktion → `fines:collect(targetSrc, id)` → `Law.Ask(target,'fines:confirmPay', fine)` → Ziel bestätigt per `Law.UI.Menu` → gleiche Zahllogik mit dem Geld des Ziels.
- Fälligkeit (`Law.Every` 10 Min.): `open` + `due_at < now` → `overdue`; wenn `AutoWarrantOnOverdue` → `Law.Warrants.CreateAuto(charId, …, { jailMinutes=OverdueJailMinutes, codes={ fine_id=id } })`. Wird ein überfälliges Bußgeld bezahlt → zugehörigen Auto-Haftbefehl widerrufen.
- `fines:cancel(id)` (`fine_cancel`), `fines:list(status)` (`records_view`), Item `law_fineticket` benutzbar → `Law.UI.Document{ kind='ticket', … }` aus DB.

### A4 – Knast (`jail.lua`)
- Stationspunkt `jail` (Client `Law.Stations.RegisterPoint('jail', { perm='jail', duty=true, … })`): Formular `jail` mit gefesselten Spielern in Reichweite (Client filtert per Statebag `law_cuffed`), Strafkatalog, Extra-Minuten, Kaution, Ort. → `jail:sentence(targetSrc, codes, extraMinutes, bail, note)`. Server: Officer am `jail`-Punkt, Ziel gefesselt + ≤ 5 m, Minuten = Summe Katalog + extra (≤ `MaxExtraMinutes`), Deckel `MaxMinutes`, Ort aus `StationLocation[station]` oder `DefaultLocation`.
- `Law.Jail.Sentence(targetSrc, minutes, reason, officerCtx?, opts?)` (Vertrag 4.1!): lösen/detachen, Dienst beenden (falls Officer), Beschlagnahme laut `Config.Jail.Confiscate` in vorp-Custom-Inventar `ara_law_property_<charId>` (UsePermissions=true, nur `AddCharIdPermissionTakeFromCustom(inv, charId, true)`; Waffen: prüfe im vorp-Code, wie du sie mit gleicher Seriennummer umziehst – `addWeaponsToCustomInventory` mit `custom_serial` + passendes Entfernen beim Spieler), `Law.Citizens.SetSample(charId,true)`, aktive Haftbefehle → `served`, aktive Kopfgelder auf das Ziel → `cancelled` (private: Einsatz über `Law.Money.GiveCharId(placer, …, 'bounty_refund')` zurück), Akteneintrag, DB-Zeile (`department` = Behörde des Officers), `Law.State.jailed`, Teleport (Fade), HUD `jail`.
- Tick (`TickSeconds`): Online-Häftlinge `served += Tick`; fertig → entlassen. DB jede Runde aktualisieren. HUD-Update an den Client.
- Fluchtprüfung (`EscapeCheckSeconds`): außerhalb Radius → wenn `Law.DiedRecently(src, 90)` → zurück teleportieren; sonst Flucht: Zeile löschen, Akte `escape`, `Law.Warrants.CreateAuto(charId, …, { jailMinutes = rest + EscapeExtraMinutes, bounty = EscapeBounty })`, `Law.Dispatch.Create{ kind='escape', priority=3 }`, `Law.Evidence.CreateTrace('cloth', coords, { ownerCharId })` (Spur für den Bluthund!).
- Knastarbeit: Client zeigt nur in Haft eigene Prompts an `work`-Punkten; Start/Ende-Muster wie beim Knacken; Server kürzt `reduced_seconds` bis `MaxReducePercent`.
- Kaution: `jail:setBail(charId, amount)` (`jail_release`), `jail:bailList()`, `jail:payBail(charId)` am Schalter von jedem außer dem Häftling: Geld nehmen → atomar `DELETE … WHERE charid=? AND bail=?` → Kasse `department` → entlassen (online) – sonst Geld zurück.
- `jail:list()`, `jail:release(charId)`, `jail:adjust(charId, minutesDelta)` (`jail_release`), `jail:propertyStatus()`, `jail:claimProperty()` (am Schalter, nicht in Haft → `Law.Inv:openInventory(src, 'ara_law_property_'..charId)`).
- Hooks: `playerLoaded` mit Zeile → in Haft setzen + teleportieren; `playerRespawned` in Haft → zurück teleportieren; `playerDropped` → DB speichern.

### A5 – Akten (`records.lua`)
- `Law.Records.Add(...)` (Vertrag 4.1). `records:search(query)` (≥ 2 Zeichen, `Law.DB.Like`, `CONCAT(firstname,' ',lastname) LIKE ?`, LIMIT 20, Flags je Treffer), `records:getFile(charId)` (Form `File`, Waffen über `Law.Weapons.GetByOwner`, Lizenzen aus `ara_law_licenses`, Blutgruppe nur wenn `hasSample`), `records:addNote`, `records:setDangerous` (`records_edit`). Formular `note`.

### A6 – Haftbefehle (`warrants.lua`)
- Formular `warrant` (aus Akte): Strafkatalog → Grund/Haftminuten serverseitig, `deadOrAlive`, optional Kopfgeld (`bounty_manage`). `warrant_approve` oder `RequireApproval=false` → sofort `active`, sonst `pending`.
- `warrants:list/approve/revoke`, `Law.Warrants.CreateAuto`, `Law.Warrants.GetActive`, Ablauf (`ExpireDays`) per `Law.Every`. Bei `active` + Ziel online → Benachrichtigung „Du wirst gesucht".

### A7 – Kopfgeld (`bounty.lua`)
- Lizenz: `bounty:licenseStatus`, `bounty:buyLicense` (am Schalter, Geld → Kasse `sheriff`, Zeile in `ara_law_licenses`, Item `bountylicns` mit `metadata={ charId, expiresAt, description }` wenn tragbar), `bountylicns` benutzbar → Dokument `license`. `Law.Bounty.CanHunt(src)` (DB, 60 s Cache).
- Offiziell: Formular `bounty_official` → `bounty:createOfficial` (Betrag aus Kasse oder „state" laut Config).
- Privat: `bounty:searchTarget(name)` (nur Name+charId), `bounty:placePrivate{ charId, amount, reason, deadOrAlive }` (nicht auf sich selbst / gleiche Steam-ID; Betrag+Gebühr abziehen; `pending` wenn `RequireApproval`), `bounty:minePlaced`, `bounty:cancelPrivate(id)` (nur `pending`/`active`, Erstattung ohne Gebühr, atomar), `bounty:approve/cancel/list` (`bounty_manage`).
- Brett: `bounty:board()` → `{ posters, bounties, contracts }` (contracts aus A8).
- Abliefern: Stationspunkt `dropoff` (Client-Prompt für Jäger mit Lizenz + Gesetz im Dienst) → `bounty:claim()`: Jäger in Zone, Ziel in Zone + ≤ `HunterRadius` vom Jäger, Ziel gefesselt (Server-State) oder tot (`ctx.isDead`; tot nur wenn `dead_or_alive=1`), Lizenz oder Gesetz im Dienst, Jäger ≠ Ziel ≠ Auftraggeber (auch Steam-ID), Kopfgeld älter als `MinAgeMinutes`, Paar-Sperre. Atomar `active → claimed` → auszahlen → Ziel in Knast (`Law.Jail.Sentence`, tot vorher `Law.VORP.Player.Revive`), Dispatch-Info an Gesetz.

### A8 – NPC-Einsätze (`npc.lua`, Client `npc.lua`)
- NPC-Kopfgelder am Brett: `npc:accept(id)` (Lizenz, Limits) → Server speichert Auftrag + Zielgebiet → Client spawnt Ziel + Bande erst < 250 m (vernetzte Peds, `SetRandomOutfitVariation` `0x283978A15512B2FE`, feindlich, Waffen), meldet NetIds → `npc:spawned`. Abliefern am `dropoff` → `npc:deliver()`: Entity existiert, Modell passt, Koordinaten in Zone, Mindestdauer, Gesundheit (`GetEntityHealth`) → Belohnung (+ Lebend-Bonus) → `DeleteEntity`. Abbruch/Timeout räumt auf.
- NPC-Streifen: Server-Timer (nur wenn ≥ `MinOnDuty` mit `npc_calls` im Dienst) → `Law.Dispatch.Create{ kind='npc', perm='npc_calls', onAccept=…, onClose=…, data=… }` → bei Annahme spawnt der erste Annehmende die NPCs (Typ `bandits` = alle ausschalten; `fugitive` = Flüchtiger, tot oder gefesselt/abgeliefert) → Abschluss serverseitig geprüft (Mindestzeit, Officer ≤ 100 m am Ort, Entities tot/weg) → Belohnung an alle Annehmenden in der Nähe, `Law.Dispatch.Close`.

### A9 – Texte & Bericht
- `locales/de_justice.lua` + `en_justice.lua` mit **allen** Schlüsseln, die du benutzt (inkl. `err_<code>` für neue Fehlercodes, `payout_reason_<grund>`, `dispatch_title_*` falls neu).
- `docs/A_REPORT.md`: Liste aller Callbacks (Name, Args, Rückgabe), Net-Events, Client-Events, Interaktionen, Stationspunkte, Formulare, Config-Schlüssel, Locale-Dateien, offene Punkte, Wünsche an den Kern.

## Abnahme (Definition of Done)
- Jeder Callback aus Vertrag 10.5 / 10.7 mit Besitzer A existiert mit genau diesem Namen und Rückgabeform.
- Alle Querverweis-Funktionen aus Vertrag 4.1 (Besitzer A) überschreiben die Stubs mit exakt der Signatur.
- Keine Datei außerhalb deiner Liste geändert.
- Jeder Geld-/Item-Pfad hat Prüfung → atomaren Wechsel → Auszahlung, und bei Fehlschlag eine Rückabwicklung.
- Keine `nil`-Zugriffe auf Spieler, die offline sein können (`Law.Ctx` kann `nil` sein!).
