# Agent A – Abschlussbericht Justiz

Stand: 2026-09-26 · Bereich A1–A9 vollständig umgesetzt, **Fix-Runde aus dem Sicherheits-Review eingearbeitet (Abschnitt 13)**.
Nicht im Spiel getestet (keine Laufzeitumgebung) – alle Dateien wurden auf Syntax, nil-Zugriffe, Argument-Reihenfolgen
und Locale-Schlüssel geprüft.

## 1. Dateien

| Datei | Inhalt |
|---|---|
| `config/justice.lua` | `Config.Arrest`, `Config.PenalCode` (34 Delikte), `Config.Fines`, `Config.Jail`, `Config.Warrants`, `Config.Bounty`, `Config.Npc` |
| `server/justice/records.lua` | `Law.Records.Add`, Aktensuche/-ansicht, gemeinsame Helfer (`Law.Justice.*`: Strafkatalog, Datenformen) |
| `server/justice/warrants.lua` | `Law.Warrants.CreateAuto/GetActive`, Haftbefehle, Ablauf |
| `server/justice/bounty.lua` | `Law.Bounty.GetActive/CanHunt`, Lizenz, offizielle/private Kopfgelder, Brett, Abgabe |
| `server/justice/fines.lua` | Bußgeld ausstellen/zahlen/kassieren/stornieren, Fälligkeit, Bescheid-Item |
| `server/justice/jail.lua` | `Law.Jail.IsJailed/Sentence`, Haft-Tick, Flucht, Knastarbeit, Kaution, Habseligkeiten |
| `server/justice/arrest.lua` | Handschellen, Schlüssel, Abführen, Wagen, Durchsuchen, Akte im Feld, Knacken, Combat-Log, Auto-Lösen |
| `server/justice/npc.lua` | NPC-Kopfgelder (Brett) und NPC-Streifen (Leitstelle) |
| `client/justice/arrest.lua` | Gefesselt-Zustand, Abführen (Attach), Wagen, alle Feld-Interaktionen, gemeinsame Client-Helfer |
| `client/justice/records.lua` | Formulare `note`, `warrant`; `Law.Justice.PenalOptions()`, `Law.Justice.CharName()` |
| `client/justice/fines.lua` | Formular `fine`, Interaktionen Bußgeld/Kassieren, `Law.Answer('fines:confirmPay')` |
| `client/justice/jail.lua` | Stationspunkt `jail` (Formular), Haft-HUD, Knastarbeit-Prompts, Teleports |
| `client/justice/bounty.lua` | Stationspunkt `dropoff`, Lizenz-Anzeige, Formular `bounty_official`, Dokumente |
| `client/justice/npc.lua` | Spawnen/Aufräumen der NPC-Ziele und Streifen-NPCs, Blips |
| `locales/de_justice.lua`, `locales/en_justice.lua` | alle Texte (identische Schlüssel) |

Keine Datei außerhalb dieser Liste wurde geändert. Keine eigenen Tabellen, keine eigenen
`playerDropped`/`vorp:SelectedCharacter`/`onResourceStop`-Handler (nur `Law.Modules.Register`).
`lockpick` ist **nicht** als benutzbar registriert (nur `Law.Items.Count/Take`).

## 2. Querverweis-APIs (Vertrag 4.1) – überschrieben mit exakter Signatur

| Funktion | Rückgabe | Hinweis |
|---|---|---|
| `Law.Jail.IsJailed(charId)` | bool | Speicher, sonst DB |
| `Law.Jail.Sentence(targetSrc, minutes, reason, officerCtx?, opts?)` | bool, errCode | opts `{ location?, bail?, warrantIds?, codes?, noConfiscate?, dept? }` – **`dept` ist Zusatz** (Kasse für Kaution, wenn kein Officer-Ctx) |
| `Law.Records.Add(charId, type, title, details?, officerCtx?, refId?)` | id | unbekannter Typ → `note` |
| `Law.Warrants.CreateAuto(charId, reason, opts?)` | id | sofort `active`; `opts.bounty` → offizielles Kopfgeld (Finanzierung laut Config) |
| `Law.Warrants.GetActive(charId)` | [Warrant] | |
| `Law.Bounty.GetActive(charId)` | [Bounty] | öffentliche Form (ohne Auftraggeber) |
| `Law.Bounty.CanHunt(src)` | bool | DB, Cache 60 s (`Config.Bounty.License.CacheSeconds`) |

## 3. Callbacks (`Law.Cb.Register`) – Name, Argumente, Rückgabe

Alle liefern `Result { ok, err?, msg?, data? }`. Lese-Callbacks im Dienstbuch haben `duty = false` (Akte auch außer Dienst lesbar).

### Vertrag 10.5 (NUI ruft diese Namen)
| Callback | Args | data | Recht |
|---|---|---|---|
| `records:search` | query (≥ 2 Zeichen) | `[PersonHit]` (max. 20, Flags) | records_view |
| `records:getFile` | charId | `File` | records_view |
| `records:addNote` | charId, title, text | `{ id }` | records_edit |
| `records:setDangerous` | charId, bool | `{ dangerous }` | records_edit |
| `warrants:list` | status (`open`\|pending\|active\|served\|revoked\|expired\|sonst alle) | `[Warrant]` | records_view |
| `warrants:approve` | id | `{ id }` | warrant_approve |
| `warrants:revoke` | id | `{ id }` | warrant_approve |
| `bounty:list` | status (`open`\|pending\|active\|claimed\|cancelled\|expired\|sonst alle) | `[Bounty]` | records_view |
| `bounty:approve` | id | `{ id }` | bounty_manage |
| `bounty:cancel` | id | `{ id }` (mit Erstattung) | bounty_manage |
| `fines:list` | status (`unpaid`\|open\|paid\|cancelled\|overdue\|sonst alle) | `[Fine]` | records_view |
| `fines:cancel` | id | `{ id }` | fine_cancel |
| `jail:list` | – | `[Inmate]` | records_view |
| `jail:release` | charId | `{ charId }` | jail_release |
| `jail:adjust` | charId, minutesDelta (±MaxMinutes) | `{ charId, sentence }` oder `{ charId, released=true }` | jail_release |
| `jail:setBail` | charId, amount (0 = keine) | `{ charId, bail? }` | jail_release |
| `fines:mine` | – | `[Fine]` (offen + letzte 14 Tage) | alle |
| `fines:pay` | id | `{ id, amount }` | alle, am `counter` |
| `jail:bailList` | – | `[{ charId, name, bail }]` | alle |
| `jail:payBail` | charId | `{ charId, amount }` | alle außer Häftling, am `counter` |
| `bounty:licenseStatus` | – | `{ active, expiresAt, price, days }` | alle |
| `bounty:buyLicense` | – | `{ active, expiresAt, price, days }` | alle, am `counter` |
| `bounty:searchTarget` | name | `[{ charId, name }]` (max. 10, ohne sich selbst) | alle, am `counter` |
| `bounty:placePrivate` | `{ charId, amount, reason, deadOrAlive }` | `{ id, status, fee }` | alle, am `counter` |
| `bounty:minePlaced` | – | `[Bounty]` | alle |
| `bounty:cancelPrivate` | id | `{ id, refund }` | alle, am `counter` |
| `jail:propertyStatus` | – | `{ hasProperty }` | alle |
| `jail:claimProperty` | – | – (öffnet vorp-Inventar) | alle, am `counter`, nicht in Haft |
| `bounty:board` | – | `{ posters:[Poster], bounties:[Bounty], contracts:[NpcContract] }` | alle, am `board` |
| `npc:accept` | id (Ziel-ID aus `contracts`) | `{ id, expiresAt }` | Lizenz (oder Gesetz im Dienst), am `board` |

### Zusätzliche Callbacks (Modul-Präfix, Vertrag 12)
| Callback | Args | data | Zweck |
|---|---|---|---|
| `records:brief` | charId | `{ charId, name }` | Name für Formular-Kopfzeilen (law) |
| `warrants:create` | charId, codes, reason, extraMinutes, deadOrAlive, bounty | `{ id, status }` | Formular `warrant` (warrant_create; bounty > 0 braucht bounty_manage) |
| `bounty:createOfficial` | charId, amount, reason, deadOrAlive | `{ id }` | Formular `bounty_official` (bounty_manage) |
| `bounty:revokeLicense` | charId | – | Lizenz entziehen (license_manage) – **noch kein NUI-Knopf** |
| `bounty:claim` | – | `{ amount, ids }` | Kopfgeld abliefern (`dropoff`) |
| `fines:issue` | targetSrc, codes, note | `{ id, amount }` | Bußgeld im Feld (fine) |
| `fines:issueByCharId` | charId, codes, note | `{ id, amount }` | Bußgeld aus der Akte (fine) |
| `fines:listFor` | targetSrc | `[Fine]` | offene Bußgelder des Ziels zum Kassieren (fine) |
| `fines:collect` | targetSrc, id | `{ id, amount }` | vor Ort kassieren, fragt Ziel per `Law.Ask` (12 s) |
| `jail:sentence` | targetSrc, codes, extraMinutes, bail, note, location? | `{ minutes, location }` | Einbuchen am `jail`-Punkt (jail) |
| `jail:workStart` | index | `{ seconds, scenario }` | Knastarbeit Start |
| `jail:workFinish` | – | `{ reduced, released? }` | Knastarbeit Ende |
| `jail:myStatus` | – | Enter-Payload oder nil | Client-Resync (Resource-Neustart) |
| `arrest:idcheck` | targetSrc | `{ full=true, charId, name }` oder `{ full=false, name, wanted }` | idcheck |
| `arrest:lockpickStart` | targetSrc | `{ seconds }` | Handschellen knacken (jeder mit Dietrich) |
| `arrest:lockpickFinish` | – | `{ success, broke? }` | |
| `npc:deliver` | – | `{ amount, alive }` bzw. `{ call }` | NPC-Ziel oder Streifen-Flüchtigen abliefern (`dropoff`) |
| `npc:abort` | – | – | NPC-Auftrag abbrechen |

## 4. Net-Events Client → Server (`Law.Net.On`)
`arrest:cuff(target)` · `arrest:uncuff(target)` · `arrest:escort(target)` (an/aus) · `arrest:putInVehicle(target, netId)` ·
`arrest:takeOutVehicle(target)` · `arrest:search(target)` · `npc:spawned(contractId, targetNet, gangNets)` · `npc:callSpawned(callId, nets)`

## 5. Client-Events Server → Client (`ara_law:cl:*`)
| Event | Payload |
|---|---|
| `arrest:setCuffed` | state(bool), byName? |
| `arrest:setEscort` | officerSrc \| nil |
| `arrest:anim` | – (Animation am Officer) |
| `arrest:putInVehicle` | netId |
| `arrest:takeOut` | officerSrc |
| `fines:showTicket` | Dokument `ticket` |
| `jail:enter` | `{ location, label, center, radius, spawn{x,y,z,w}, work[{index,coords,label,scenario}], workSeconds, workDistance, hud, teleport }` |
| `jail:hud` | HUD `jail` |
| `jail:teleport` | spawn `{x,y,z,w}` |
| `jail:leave` | `{ release?{x,y,z,w}, escaped? }` |
| `jail:closeUi` | – (vor dem Öffnen des vorp-Inventars) |
| `bounty:license` | bool |
| `bounty:showDocument` | Dokument `license` |
| `npc:contract` / `npc:cleanup` | Auftragsdaten / contractId |
| `npc:callSpawn` / `npc:callCleanup` | Streifendaten / callId |

`Law.Ask`/`Law.Answer`: `fines:confirmPay` (Payload `Fine`, Antwort bool).
HUDs: `cuffed { by }`, `jail { remaining, total, reduced, work:{ done, max } }`.

## 6. Interaktionen (F6) und Stationspunkte

| ID | Label | Bedingung (Anzeige) |
|---|---|---|
| `arrest_cuff` | Fesseln | Ziel nicht gefesselt, Recht cuff oder Lizenz |
| `arrest_uncuff` | Handschellen lösen | Ziel gefesselt |
| `arrest_escort` | Abführen / beenden | Ziel gefesselt, nicht im Wagen, Recht escort oder Lizenz |
| `arrest_vehicle_in` / `_out` | In Wagen setzen / herausholen | gefesselt, (nicht) im Wagen |
| `arrest_search` | Durchsuchen | Recht search, Ziel gefesselt oder tot |
| `arrest_idcheck` | Akte prüfen | Recht idcheck |
| `arrest_lockpick` | Handschellen knacken | Ziel gefesselt, selbst frei |
| `fines_issue` / `fines_collect` | Bußgeld ausstellen / kassieren | Recht fine |
| `npc_route` / `npc_abort` | Route / Auftrag abbrechen | eigener NPC-Auftrag aktiv (Selbst-Aktion) |

Stationspunkte: `jail` (perm jail, duty) → Formular Haftstrafe · `dropoff` (Lizenz, Gesetz im Dienst oder NPC-Auftrag; Reichweite 3 m, Zone = `radius` des Punkts).

Formulare (Vertrag 10.7): `fine`, `warrant`, `bounty_official`, `note` über `Law.UI.RegisterForm`; `jail` direkt am Stationspunkt.

## 7. Config-Schlüssel (config/justice.lua)
`Config.Arrest` (Distanzen, SearchRequiresCuffs, AllowHuntersToCuff, CuffDelete, AutoUncuffMinutes, AttendRadius, CombatLogJailMinutes, **HunterMaxMinutes, EscortBreakDistance, EscortCheckSeconds**, RecordOnCuff, Lockpick{}, EscortBone, EscortOffset, VehicleSeats, Anim, DisabledControls) ·
`Config.PenalCode` · `Config.Fines` (+ MaxCodes, MaxCodeCount, CheckMinutes, FallbackDepartment) ·
`Config.Jail` (Locations mit `enabled`, StationLocation, Work, Confiscate{Weapons, KeepWeapons, Items, Limit}, Bail, SentenceDistance, EscapeGraceSeconds, DiedRecentlySeconds, **MaxDeathReturns**, DisabledControls) ·
`Config.Warrants` (+ SystemDept, CheckMinutes) · `Config.Bounty` (License{…, Department, CacheSeconds}, Private{…, FeeDepartment, MaxPerPlacer}, Official{FundedBy, Max, ExpireDays, SystemDept}, Claim{…, **LawGetsPrivate**}, BoardDistance) ·
`Config.Npc` (Bounties{…, AllowLaw, MaxMinutes, OfferMinutes, SpawnDistance, SpawnCheckRadius, **SampleSeconds, MaxSpeed, MinSamples**, AreaRadius, Weapons, Blip, Targets[10]}, Calls{…, MinSeconds, CompleteRadius, SpawnDistance, Expires, CheckSeconds, Types, Locations[12]})

## 8. Datenbank-Konventionen (keine neuen Tabellen/Spalten)
- `ara_law_jail.has_property`: 0 leer · 1 Fach belegt · **2 = Nacharbeiten ausstehend** (Offline-Haft/Combat-Log ODER Einbuchung, bei der der Spieler zwischendurch weg war): beim nächsten Login werden Beschlagnahme, Probe, Haftbefehle und Kopfgelder nachgeholt. `Law.Jail.Sentence` legt die Zeile immer mit 2 an und setzt am Ende 0/1.
- `ara_law_bounties.placed_by_identifier` bei `kind='official'`: **`'society'` oder `'state'`** (Finanzierungsart, damit Erstattungen auch nach Config-Änderung stimmen).
- Auto-Haftbefehl zu Bußgeld: `codes = {"fine_id": X}` → beim Bezahlen/Stornieren wird er widerrufen.
- Habseligkeiten: vorp-Custom-Inventar `ara_law_property_<charId>`; Status wird über `character_inventories.inventory_type` / `loadout.curr_inv` gelesen (nur lesend).

## 9. Geld-/Item-Pfade (Prüfen → atomar → Auszahlung → Rückabwicklung)
Bußgeld zahlen/kassieren, Kaution, private Kopfgelder (setzen/stornieren/freigeben), offizielle Kopfgelder (Kasse → Treuhand → Erstattung),
Abliefern (`active → claimed` je Zeile), Lizenzkauf (Geld zurück bei DB-Fehler), Beschlagnahme (erst abziehen, dann einlagern, sonst zurückgeben;
**Waffen erst `deleteWeapon` (nur bei `true` weiter), dann einlagern, sonst `createWeapon` mit gleicher Seriennummer zurück**), NPC-Belohnung (Zustandswechsel im Speicher ohne yield vor der Auszahlung).
Alle DB-Schreibzugriffe zwischen Geldbewegung und Erfolg laufen über `Law.DB.Try`; Geld-/Kassenbuchungen über die Helfer
`Law.Justice.GiveBack / PayCharId / SocietyAdd / SocietyRemove` (records.lua), die Erfolg als bool melden. Scheitert eine Erstattung
nach einem Statuswechsel, wird der Status zurückgesetzt (kein Geldverlust, erneuter Versuch möglich).

## 10. Offene Punkte / ungeprüfte Annahmen
1. **vorp_inventory-Befunde (im Quelltext geprüft):**
   - `addWeaponsToCustomInventory` liest `serial_number` (types.lua nennt fälschlich `custom_serial`) – ich übergebe beides. Munition in der Waffe geht bei der Beschlagnahme verloren, Komponenten werden mitgenommen.
   - `AddCharIdPermissionTakeFromCustom` ist in dieser Version wirkungslos (invertierte `canContinue`-Prüfung). Workaround: zusätzlich `updateCustomInventoryData(inv, { CharIdPermissionTakeFrom = { [charId]=true }, PermissionMoveTo = { ara_law_nobody = 99 } })`. Das Fach wird außerdem nur für den Besitzer serverseitig geöffnet.
2. **Natives ungeprüft im Spiel:** `CuffPed/UncuffPed` (aus vorp_police übernommen), `AttachEntityToEntity` mit Knochen 0 + Versatz `Config.Arrest.EscortOffset` (vorp_police-Parameter sind verrutscht, deshalb eigene Werte), `BlipAddForRadius` (0x45F13B7E0A15C880, Stil -1282792512), `BlipAddForEntity` (0x23F74C2FDA6E7C61, `BLIP_STYLE_ENEMY`), `GiveWeaponToPed` (0x5E3BDDBCB83F3D84, Parameterliste), Szenarien der Knastarbeit, `GetGamePool('CVehicle')`, serverseitig `GetEntityHealth`/`GetVehiclePedIsIn`/`GetEntityType`.
3. **Koordinaten:** Sisika-Arbeitspunkte sind geschätzt (ANPASSEN). `valentine_cells` ist deaktiviert, bis die Zellen-Koordinaten geprüft sind. NPC-Gebiete stammen aus `ricx_bounty_quests` (erprobt), Z wird clientseitig per Bodenhöhe korrigiert.
4. **Ped-Modelle** der NPCs (g_m_m_unibanditos_01 u. a.) bitte im Spiel prüfen; ungültige Modelle werden übersprungen und in F8 gemeldet.
5. **Locale-Kollision:** Neue `err_*`-Codes (z. B. `err_target_not_cuffed`, `err_too_early`) könnten auch von Agent B definiert werden → bei abweichendem Text meldet `Law.LocaleAdd` „doppelt“ (harmlos, letzter gewinnt).
6. **Auto-Lösen:** löst nur, wenn sich `AutoUncuffMinutes` lang niemand kümmert (Fesselnder oder Gesetz im Dienst ≤ `AttendRadius`, oder abgeführt). So bleibt ein Transport nach Sisika möglich.
7. **Kopfgeld beim Einbuchen:** `Law.Jail.Sentence` storniert alle offenen Kopfgelder des Ziels mit Erstattung (auch wenn ein Jäger es gerade herbringt) – so im Auftrag verlangt.
8. **Jail-Formular:** Das Einbuchen stellt kein Bußgeld aus (Delikte bestimmen nur die Haftzeit); ggf. zusätzlich Bußgeld über die Interaktion.

## 11. Wünsche an den Kern
1. ~~Menü → Formular-Übergang~~ – **im Kern gelöst** (`open` trägt `seq`). Mein 200-ms-Warten (`Law.Justice.AfterMenu`) bleibt als harmlose Absicherung.
2. **`Law.Ask`-Timeout vs. `Law.Cb.Await` (fest 15 s):** Ich nutze 12 s für `fines:confirmPay`. Wunsch: Timeout von `Law.Cb.Await` konfigurierbar oder > AskTimeout.
3. **Webhook-Kanal `records`** in `config/server_only.lua` ergänzen (Audit `records.*` landet sonst in `default`).
4. **NUI-Knopf „Lizenz entziehen“** in der Akte (`bounty:revokeLicense(charId)`, Recht `license_manage`) – Callback existiert.
5. `core:sync` könnte `escorted` mitschicken (ich setze `Law.State.escorted` nur über eigene Events).
6. Optional: `Law.Jail.Sentence`-Option `dept` in den Vertrag aufnehmen (für Kopfgeld-Einlieferungen ohne Officer).

## 12. Installation / Neustart
- Keine eigenen SQL-Dateien; Items (`law_fineticket`, `handcuffs`, `handcuffkey`, `lockpick`, `bountylicns`) stehen in `sql/items.sql` des Kerns.
- `vorp_police` muss deaktiviert sein (gleiche Items `handcuffs`/`handcuffkey`).
- Erster Einsatz: **kompletter Server-Neustart** (neue Items). Spätere Änderungen an Justiz-Dateien/Config: `restart ArA-LawSystem` genügt.

## 13. Fix-Runde Sicherheits-Review

Benutzte neue Kern-APIs: `Law.DB.Try`, `Law.IsSelfOrAlt`, `Law.SamePlayer`, `Law.IdentifierOf` (keine eigene Variante gebaut).
`err_declined` aus meinen Locales entfernt (steht jetzt im Kern).

| Punkt | Umsetzung | Datei:Zeile |
|---|---|---|
| K1 | `bounty:claim` löst nur Ziele ein, die der Einlösende gefesselt ODER abgeführt hat (`err_target_not_yours`); Tote abgelehnt, wenn Fessel/Abführen einem anderen gehört. Gesetz im Dienst: offizielle Kopfgelder → Betrag zurück in die Kasse (`bounty_return`), private nur mit `Config.Bounty.Claim.LawGetsPrivate` (Default false, `err_law_private`). Scheitert die Kassen-Rückbuchung → Zeile bleibt `active`; scheitert die Jäger-Auszahlung → alle Einlösungen zurückgenommen | bounty.lua:529–639, eligible 501–527 |
| H1 | „kürzlich tot → zurück“ höchstens `Config.Jail.MaxDeathReturns` (3) Mal in Folge, danach Flucht; Zähler nur zurück, wenn sicher in der Zone und nicht frisch tot. Zurück-Teleport zusätzlich serverseitig `SetEntityCoords(GetPlayerPed(src), …)` (`teleportBack`, auch beim Respawn) | jail.lua:120, 734–770, 854 |
| H2 | Handschellen erst NACH der Beschlagnahme lösen; Waffe erst `deleteWeapon == true`, dann `addWeaponsToCustomInventory`, bei Fehler `createWeapon(src, name, nil, nil, comps, nil, nil, serial, custom_label, custom_desc)`; Item-Einlagern in `pcall` | jail.lua:222–290, 366–378 |
| M1 | `Law.DB.Try` + Rückbuchung: fines `settle` (117–121), Provision/Kasse (132–134); jail `payBail` (592–598), `releaseInmate` (159), `escape` (706); bounty `CreateOfficialBounty` (`GetCharName` vor der Abbuchung, 123–143), `buyLicense` (218–231), `placePrivate` (319–327), `cancelPrivate` (361–362), `CloseBounty` inkl. Status-Rücksetzung (80–92) | s. links |
| M2 | `Law.IsSelfOrAlt` in fines:cancel (fines.lua:228), fines:issue/issueByCharId (53), warrants:create/approve/revoke (warrants.lua:174/224/243), bounty:approve/cancel/createOfficial/placePrivate (bounty.lua:395–396/414/429/308), records:addNote/setDangerous (records.lua:316/327), jail:release/adjust/setBail/payBail (jail.lua:513/523/552/583). Provision nur, wenn Beamter und Betroffener nicht derselbe Spieler (`Law.SamePlayer`, fines.lua:131) | s. links |
| M3 | Offizielle Kopfgelder: Ersteller ≠ Ziel per Steam-ID beim Anlegen (bounty.lua:123, 429); in `eligible()` Ersteller-Steam-ID über `Law.IdentifierOf(placed_by)` gegen Jäger UND Ziel (bounty.lua:510–515) | bounty.lua |
| M4 | Jäger-Fesselung endet nach `Config.Arrest.HunterMaxMinutes` (20) oder wenn kein aktives Kopfgeld mehr (Auto-Lösen-Takt) | arrest.lua:359–374 |
| M7 | `Sentence` → `doSentence`: Zeile zuerst mit `has_property = 2`, nach jedem DB-Warten Ping-Prüfung (`return true`, Rest beim Login), `setupInmate` nur online, `inmateSrc` nur Ping > 0; `IsSentencing` verhindert zusätzliche Combat-Log-Strafe, `SentenceOffline` ergänzt nie eine bestehende Zeile | jail.lua:74–80, 106, 333–465; arrest.lua:460 |
| M9 | NPC-Ziel: Positionsprobe beim Spawn, alle `SampleSeconds` (5 s) und beim Abliefern; > `MaxSpeed` (40 m/s) → Auftrag ungültig ohne Lohn (`npc_invalid`); Abliefern erst ab `MinSamples` (6) Proben (`err_npc_not_verified`) | npc.lua:77–96, 221, 306–312, 470–499 |
| N2 | `playerRespawned` löst Fesseln (Handschellen an den Fesselnden zurück) und beendet eigenes Abführen | arrest.lua:477–487 |
| N6 | `ComputeCodes`: `#codes > MaxCodes * MaxCodeCount` → nil | records.lua:39 |
| N7 | Bestätigungsmenü schließt sich nach 12 s selbst (`fine_confirm_timeout`) | client/justice/fines.lua:75–95 |
| N10 | `bounty:searchTarget`: min. 3 Zeichen (`err_query_short3`), max. 5 Treffer, Rate 3000 ms | bounty.lua:280–290 |
| Zusatz | Abgeführtes Ziel > `EscortBreakDistance` (10 m) vom Officer → Abführen beenden, Notify an den Officer, Leitstelle `kind='escape'` „Gefangener entkommen“ (eigener 5-s-Takt, weil der 60-s-Auto-Lösen-Takt DB-Abfragen macht) | arrest.lua:402–431 |

Neue Locale-Schlüssel (de + en): `err_query_short3`, `err_target_not_yours`, `err_law_private`, `err_npc_invalid`, `err_npc_not_verified`,
`dispatch_title_prisoner_escaped`, `arrest_escort_escaped_officer`, `arrest_escort_escape_dispatch`, `arrest_hunter_released_you`,
`arrest_hunter_timeout`, `arrest_hunter_no_bounty`, `bounty_claim_law`, `npc_invalid`, `fine_confirm_timeout`; `err_self_target` nennt jetzt auch Zweitcharaktere.

Offen/Annahmen der Fix-Runde:
- Serverseitiges `SetEntityCoords` auf Spieler-Peds unter OneSync (RedM) ist nicht im Spiel geprüft – das Client-Event bleibt deshalb zusätzlich bestehen.
- `createWeapon` beim Zurückgeben: die Munition in der Waffe geht verloren; `comps` werden übernommen.
- Ein Beamter im Dienst, der ein Ziel mit ausschließlich privatem Kopfgeld herbringt, bekommt `err_law_private` – er bucht dann normal am `jail`-Punkt ein (dabei wird das private Kopfgeld erstattet).
