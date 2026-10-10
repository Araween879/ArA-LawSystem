# Agent B – Abschlussbericht (Ermittlung & Schutz)

Stand: 2026-09-26 · Bereich B1–B7 aus `docs/bereiche/B_ERMITTLUNG_SCHUTZ.md` vollständig umgesetzt.
Keine Datei außerhalb der eigenen Liste geändert, keine eigene Tabelle, keine eigenen
`playerDropped`/`vorp:SelectedCharacter`/`onResourceStop`-Handler (nur `Law.Modules.Register`).

## 1. Dateien

| Datei | Inhalt |
|---|---|
| `config/investigation.lua` | `Config.Evidence`, `Config.Weapons`, `Config.Scent`, `Config.K9` |
| `config/escort.lua` | `Config.Escort` |
| `server/investigation/evidence.lua` | Welt-Spuren (Speicher), Schüsse/Blut, Spurensuche, Sichern, Asservatenkammer, Labor, Dienstbuch-Tab, Schmauchtest, `Law.Evidence.*` |
| `server/investigation/weapons.lua` | Waffenregister, Schalter, Dienstbuch-Tab, Feldkontrolle, Waffenfeile, Waffenschein, `Law.Weapons.*` |
| `server/investigation/scent.lua` | Geruchsspur-Ringpuffer je charId, `Law.Scent.*`, Geruchsprobe |
| `server/investigation/k9.lua` | Bluthund (holen/abgeben/Tod), Umgebung absuchen, Spurverfolgung `scent:start/next/stop` |
| `server/escort/cargo.lua` | Treuhand-Ware, Abhol-/Beutefach (vorp-Custom-Inventare), Panzerwagen-Hilfen |
| `server/escort/contracts.lua` | Preise, Schalter-/Dienstbuch-Callbacks, Zustandsautomat, Start/Abgabe, Auszahlung, Verfall |
| `server/escort/incidents.lua` | Server-Tick, VIP-Tod (`Law.Escort.OnPlayerDeath`), Überfall, Versicherung, NPC-Hinterhalt, Beutefach |
| `client/investigation/evidence.lua` | Spurensuche-Modus (Marker, Prompt), Labor-Stationspunkt, Schmauchtest |
| `client/investigation/shots.lua` | Schuss- und Verletzungsmeldung (nur eigener Charakter) |
| `client/investigation/weapons.lua` | Feldkontrolle, Waffenfeile (Answer + Fortschritt), Waffenschein-Dokument |
| `client/investigation/k9.lua` | Zwinger, Hund spawnen, Befehle, Spurverfolgung, Geruchsprobe, HUD `k9` |
| `client/escort/escort.lua` | Eskort-Büro-Punkt, Start Personenschutz/-transport, Beutefach, HUD `escort` |
| `client/escort/wagon.lua` | Panzerwagen spawnen, Wagen-Blip nur für Begleiter |
| `client/escort/incidents.lua` | Überfall-Prompt + Fortschritt (HUD `robbery`), NPC-Hinterhalt |
| `locales/de_investigation.lua`, `locales/en_investigation.lua` | alle Texte Spuren/Waffen/Geruch/K9 inkl. `err_*` |
| `locales/de_escort.lua`, `locales/en_escort.lua` | alle Texte Eskorte inkl. `err_*`, `payout_reason_escort_*` |

## 2. Querverweis-APIs (Vertrag 4.1) – überschreiben die Stubs mit exakter Signatur

| Funktion | Datei | Verhalten |
|---|---|---|
| `Law.Evidence.CreateTrace(kind, coords, data)` → id | evidence.lua | `casing`/`blood`/`cloth`; Blutgruppe wird bei Bedarf nachgeladen |
| `Law.Evidence.LastShotAt(charId)` → unix\|nil | evidence.lua | letzter gemeldeter eigener Schuss |
| `Law.Weapons.RegisterIssued(serial, weaponName, charId, dept)` → bool | weapons.lua | Upsert, Status `issued` |
| `Law.Weapons.GetByOwner(charId)` → `[{ serial, weapon, weaponLabel, status, statusLabel }]` | weapons.lua | |
| `Law.Weapons.Lookup(serial)` → WeaponInfo\|nil | weapons.lua | auch unregistrierte Waffen (aus `loadout`); `ABGEFEILT` → nil |
| `Law.Scent.HasTrail(charId)` → bool | scent.lua | |
| `Law.Escort.OnPlayerDeath(src)` | incidents.lua | VIP von Personenschutz/-transport → nach 1,5 s Gesundheit **serverseitig** prüfen → `failed` |

Zusätzliche (interne, nicht im Vertrag) Helfer: `Law.Evidence.U32/IsFirearm/WeaponLabel/TypeLabel/ZoneOf/FormatTime/SealOf/ItemByType/TypeByItem`,
`Law.Weapons.CurrentHolder(serial)`, `Law.Scent.GetTrail(charId)` (nie an Clients), `Law.Scent.Strength(t)`, `Law.Escort.*` (ES-Interna).

## 3. Callbacks (`Law.Cb.Register`) – Name · Recht · Args → `data`

Alle liefern `Result { ok, err?, msg?, data? }`.

### Vertrag 10.5 – Dienstbuch
| Callback | Recht | Args | data |
|---|---|---|---|
| `evidence:list` | evidence | `filter` = `nil` \| Status \| Typ \| Nummer \| `{ status?, type?, id? }`; `'all'` inkl. vernichtet | `[Evidence]` (max. 100) |
| `evidence:get` | evidence | `id` | `Evidence` |
| `evidence:destroy` | evidence_analyze | `id` | – (msg) |
| `weapons:lookup` | weapons_registry | `serial` | `WeaponInfo` |
| `weapons:setStatus` | weapons_registry | `serial, status, note` (`registered/stolen/confiscated/destroyed`) | `WeaponInfo` |
| `escort:listOpen` | escort_contracts (+ Behörde in `AllowedDepts`) | – | `[Escort]` (open/accepted) |
| `escort:listMine` | escort_contracts | – | `[Escort]` (eigene Begleitungen, aktiv + 7 Tage) |
| `escort:accept` | escort_contracts | `id` | `Escort` (erster mit `escort_lead` wird Leiter) |
| `escort:leave` | – (nur Mitglied; auch Entlassene) | `id` | – |
| `escort:insuranceList` **(neu, Abschnitt „Versicherungsfälle")** | boss_funds + Behörde `Config.Escort.Department` (oder Recht `all`) | – | `[{ id, clientName, recipientName?, robbedByName?, pickupLabel, destinationLabel, cargoSummary, insuredValue, amount, robbedAt, state, stateLabel, reasonLabel?, decidedBy?, decidedAt?, canDecide }]` (pending zuerst, max. 50) |
| `escort:insuranceDecide` **(neu)** | wie oben | `id, approve` | `{ amount }` bei Freigabe; Fehler `escort_ins_self` (Kunde/Empfänger/Räuber inkl. Zweitchar), `society_empty` (Fall bleibt `pending`), `already_done` |

`Evidence` = Vertragsform + Zusatz `department, analyzedByName, analyzedAt, subjectName` (nur `scent`).
`weaponLabel/serial/bloodType/analysis` erst ab Status `analyzed` (sonst wäre das Labor überflüssig).

### Vertrag 10.5 – Schalter
| Callback | Args | data |
|---|---|---|
| `weapons:mine` | – | `[{ id?, serial, weapon, weaponLabel, registered, status, statusLabel, filed, foreign?, inInventory, missing? }]` – `missing=true` (id=nil): auf mich registriert, aber nicht mehr bei mir → nur „gestohlen melden" anbieten |
| `weapons:register` | `weaponId` (am `counter`) | `{ serial }`; fremd registriert → `weapons_foreign` (Akteneintrag beim Besitzer + Hinweis an `weapons_registry`) |
| `weapons:reportStolen` | `serial` (am `counter`, eingetragener Besitzer – Besitz nicht nötig) | – |
| `weapons:transfer` **(neu)** | `weaponId, targetSrc` (Verkäufer am `counter`, Käufer ≤ 3 m) | `{ serial }` – Umschreiben/Verkaufen, siehe unten. Aufgerufen vom Client über die NUI-Aktion `action { app:'counter', name:'transferWeapon', payload:{ weaponId, serial } }` (Handler `Law.UI.OnAction('counter','transferWeapon')` wählt den Käufer per Menü) |

**Waffe umschreiben (`weapons:transfer`):** Waffe im Inventar des Verkäufers (ID + Seriennummer), nicht abgefeilt, Register `registered` und auf ihn eingetragen;
Käufer online, ≤ 3 m (Server-Position), nicht gefesselt/in Haft/tot, kein Zweitcharakter (`Law.IsSelfOrAlt`), kann die Waffe tragen →
`Law.Ask(käufer, 'weapons:confirmTransfer', { weaponLabel, serial, sellerName }, 12000)` (Client-Answer: Menü Annehmen/Ablehnen, schließt sich nach 11,5 s) →
**alles erneut prüfen** → atomar `UPDATE … WHERE serial=? AND owner_charid=<Verkäufer> AND status='registered'` → Waffe übergeben (`giveWeapon(käufer, weaponId, verkäufer)`, siehe Befund 10.5);
schlägt das fehl, wird der Register-Eintrag zurückgeschrieben. Danach Waffenschein für den Käufer (der alte Schein zeigt automatisch „UNGÜLTIG"), Akteneinträge für beide, Audit `weapons.transfer`.
Fehlercodes: `weapons_not_found`, `weapons_filed`, `weapons_no_serial`, `weapons_not_registered`, `no_target`, `too_far`, `weapons_buyer_unable`, `weapons_self`, `weapons_buyer_full`, `weapons_transfer_busy`, `declined`, `failed`.
| `escort:options` | `station` (muss der aktuelle Standort sein) | siehe unten |
| `escort:quote` | `values` | `{ price, premium, total, goldTotal, cargoValue, km, deadlineMinutes, breakdown:[{label,amount}], insured, insuredValue, uninsuredValue, coverageAmount, insuranceNote }` |
| `escort:book` | `values` | `{ id, total, gold }` |
| `escort:mine` | – | `[Escort]` (Kunde oder Empfänger) |
| `escort:cancel` | `id` (nur `open`, nur am Abholbüro) | `{ opened }` |
| `escort:claim` | `id` (am `counter` oder `escort`-Punkt des Abholorts) | `{ opened, money?, gold? }` |

`escort:options` data (für Agent C):
```
{ station, stationLabel,
  types: [{ value, key, label, desc, durations?, minEscorts, maxEscorts, needsDestination, needsDuration,
            allowsCargo, allowsInsurance, base, perMinute?, perKm?, valuePercent? }],
  destinations: [{ value: stationKey, label, km }],
  cargoItems: [{ value: itemName, name, label, unitValue, owned }],
  insurance: { available, premiumPercent, coverage, coversCash: false, manualReview: true, note },
  perExtraEscort, maxMoney, maxGold, maxCargoValue, maxCargoEntries, goldValue, myMoney, myGold }
```
`values` = `{ type, destination?, durationMin?, escorts, insurance, recipientName?, cargo:[{ name|value, amount|count }], money, gold }`
(leere Felder `""` gelten als nicht angegeben). `total` = Preis + Prämie + Bargeld (Dollar), Gold separat in `goldTotal`.

`Escort` = Vertragsform + Zusatz `premium, insuredValue, reasonLabel, startedAt, finishedAt, claimOffice, claimOfficeLabel, joined, full, isLeader,
insuranceState ('none'|'pending'|'paid'|'denied'|'expired'), insuranceStateLabel, insuranceAmount, insuranceReasonLabel?` (auch in `escort:mine`).
`canClaim` = Abholfach/Lieferung an `claimOfficeLabel` verfügbar.

**Versicherung (K1, Design Head Designer):** versichert ist nur der Warenwert (`insured_value` = Items, nie Bargeld/Gold; Prämie nur darauf).
Ein Überfall zahlt nichts aus: atomar `active → robbed` setzt `robbed_by`, `robbed_by_identifier`, `insurance_state` und `insurance_amount = Coverage × insured_value`.
Automatisch `denied` (Grund in `status_reason`: `ins_no_escort` / `ins_same_player` / `ins_limit`), wenn beim letzten Tick vor dem Überfall kein Begleiter (im Dienst) im `ParticipationRadius` war,
der Räuber derselbe Spieler wie Kunde/Empfänger/Begleiter ist (`Law.SamePlayer`), oder der Kunde (Steam-ID) in 7 Tagen schon `MaxClaimsPerWeek` Fälle `pending/paid` hatte. Sonst `pending` →
Freigabe/Ablehnung im Dienstbuch (`escort:insuranceDecide`), Verfall nach `ExpireDays`.

### Eigene Callbacks (Erweiterung, Modul-Präfix)
| Callback | Recht | Zweck |
|---|---|---|
| `evidence:scan` | evidence | Spuren ≤ `ScanRadius` um den Officer: `[{ id, kind, coords, ageClass }]` (keine Seriennummer/Besitzer) |
| `evidence:collect` | evidence | Spur sichern (Beutel, DB-Zeile, Item) |
| `evidence:myItems` | evidence | auswertbare Beweis-Items im Inventar |
| `evidence:analyze` | evidence_analyze (am `evidence`-Punkt) | Laborstart → `{ seconds }`; Ergebnis per Client-Event |
| `evidence:gsr` | evidence | Schmauchtest `targetSrc` → `{ positive, name }` |
| `weapons:inspect` | weapons_registry **oder** search | Feldkontrolle `targetSrc` → `{ name, weapons:[…] }` |
| `scent:sample` | scent_sample | Geruchsprobe am gefesselten/bewusstlosen Ziel |
| `k9:request` | k9 (am `kennel`) | Hund freigeben → `{ model, spawn }` |
| `k9:search` | k9 | nächster Nicht-Gesetz-Spieler ≤ 25 m um den **Hund** → `{ found, serverId?, coords? }` |
| `k9:scentItems` | k9 | Geruchsträger im Inventar |
| `k9:attack` | k9 (nur `AllowAttack`) | Ziel ≤ 30 m am Hund |
| `scent:start` | k9 | `itemId` → `{ sessionId, points, strength }` oder `err='scent_none'` |
| `scent:next` | k9 | `sessionId` → `{ points, strength }` \| `{ wait }` \| `{ found, serverId }` \| `{ lost, reason }` |
| `escort:here` | – (am `escort`-Punkt) | mögliche Aktionen `[{ action: start/deliver/claim, id, label, desc }]` |
| `escort:start` | escort_lead | Start (`cargo` → `{ spawnWagon, model, spawn }`) |
| `escort:deliver` | escort_lead | Abgabe im Zielbüro |
| `escort:canRob` / `escort:robStart` / `escort:robFinish` | – | Überfall (Start/Ende-Muster, Zeit misst der Server) |
| `escort:openLoot` | – | Beutefach erneut öffnen (nur Räuber) |

## 4. Net-Events Client → Server (`Law.Net.On`)
`evidence:shot(weaponHash)`, `evidence:bleed(isMelee)`, `evidence:openLocker`, `weapons:fileFinish(cancelled)`,
`k9:spawned(netId)`, `k9:dismiss(silent)`, `k9:died`, `scent:stop(sessionId)`, `escort:wagonSpawned(id, netId)`, `escort:robAbort(netId)`.

## 5. Events Server → Client (`ara_law:cl:*`)
`evidence:document(def)`, `weapons:document(def)`, `weapons:fileStart(seconds)`, `k9:spawn({model})`, `k9:removed(reason, netId?)` (`reason='rejected'` = Spawn abgelehnt, Client räumt auf),
`escort:wagonRejected(id, netId)` **(neu)** – Server hat den Panzerwagen nicht angenommen, Client löscht seinen lokal erzeugten Wagen,
`k9:sessionEnded(reason)`, `escort:sync(list)`, `escort:hud(data)`, `escort:ended(id, text)`, `escort:wagon(id, netId)` (nur Begleiter),
`escort:closeUi`, `escort:lootList(ids)`, `escort:ambush(data)` (nur an Leiter/Begleiter am Wagen).
`Law.Ask`: `weapons:chooseFile` (Client antwortet mit Waffen-ID aus `Law.UI.Menu`), `weapons:confirmTransfer` **(neu)** (Käufer antwortet `true` = annehmen).
NUI-Aktion (Client-Handler): `counter:transferWeapon` **(neu)** → Rückgabe = Result von `weapons:transfer`.

## 6. Interaktionen, Stationspunkte, HUDs
- Stationspunkte: `evidence` (Asservatenkammer + Labor), `kennel` (Hund holen/abgeben), `escort` (Eskort-Büro für alle: Start/Abgabe für Leiter, Abholfach für Kunden/Empfänger).
- Interaktionen (F6): `evidence_mode`, `evidence_gsr` (Ziel), `weapons_inspect` (Ziel), `scent_sample` (Ziel), `k9_follow`, `k9_stay`, `k9_search`, `k9_scent`, `k9_stop`, `k9_home`, `k9_attack` (Ziel, nur `AllowAttack`), `escort_start`, `escort_loot`.
- Benutzbare Items: `law_gunfile` (jeder), `law_weaponpermit` (Dokument aus DB), `law_whistle` (Recht `k9`).
- HUDs: `evidence { active, count }`, `k9 { state, strength, text }`, `escort { id, typeLabel, statusLabel, destinationLabel, timeLeft, escortsNear, escortsTotal }`, `robbery { progress, text }`.
- Dokumente: `evidence` (Laborbericht), `permit` (Waffenschein).

## 7. Sicherheit / Dupe-Schutz (Kurzfassung)
- Spuren nur Speicher, nur an Gesetz im Dienst mit Recht, nur Umkreis, nur auf Anfrage. Sichern entfernt die Spur sofort (kein Doppel-Sichern); Fehlerpfad gibt Beutel zurück und löscht die DB-Zeile.
- Schuss: Server nimmt eigene Position; Seriennummer nur von der **ausgerüsteten** Waffe mit passendem Hash aus dem eigenen Inventar; Bögen/Wurfwaffen/Unbekanntes → keine Hülse.
- Waffen-IDs werden immer gegen `getUserInventoryWeapons(src)` geprüft (vorp `getUserWeapon`/`setWeaponSerialNumber` prüfen den Besitzer nicht).
- Bluthund: echter Geruchsträger (DB-Besitzer über `evidence_id`), Abklingzeit auch ohne Treffer (kein Ortungs-Orakel), stückweise Spur, vor jedem Stück Hund ≤ `Tolerance` am letzten Punkt, Hundeführer ≤ `HandlerMaxDistance`, Mindestzeit je Stück (`MaxDogSpeed`, kein Teleport).
- Eskorte: jeder Statuswechsel atomar (`WHERE id=? AND status=?`, `affectedRows == 1`), Geld/Ware erst danach. Buchung: erst alle Mengen prüfen, dann abziehen, bei Teilfehlschlag Rückgabe. Jeder Endzustand (`delivered/completed/failed/robbed`) nur aus `active` – exklusiv. Ware verschwindet nie: Rückgabe/Abholung über Fach mit charId des Berechtigten; Fehlschlag beim Einlegen setzt den Status zurück (Abholung) bzw. wird geloggt (Rückgabe). Preis-Rest, Anteil und Prämie gehen in die Kasse. Sperre je Auftrag (`ES.WithLock`) gegen Doppelklicks.
- Überfall: Räuber ≠ Kunde/Empfänger/Begleiter, auch per Steam-ID; Item, Nähe zur **Server**-Position, Zeit ≥ `Seconds` serverseitig, Abklingzeit; Alarm sofort beim Start; entfernt sich der Räuber im Tick > `Distance + 2` m, ist der Aufbruch abgebrochen.
- Entities: Der Server löscht **nie** ein Entity auf Grund einer Client-NetId. Beim Spawn (Hund, Panzerwagen) prüft er per `Law.EntityCoordsWait` + `Law.IsEntityOwner` + `Law.ModelMatches` (+ Nähe, + NetId keinem anderen Auftrag zugeordnet) und lehnt sonst nur ab (Client räumt auf). Gespeicherte NetIds werden vor jeder Nutzung/Löschung auf das Modell geprüft (NetIds werden wiederverwendet).
- Alle `.await`-Schreibzugriffe nach einem Abzug (Buchung, Sichern, Registrierung, Geruchsprobe, Überfall, Versicherung) laufen über `Law.DB.Try` mit vollständiger Rückabwicklung.

## 8. Config-Schlüssel
- `Config.Evidence`: `Enabled, Lifetime{casing,blood,cloth}, ScanRadius, ScanCooldown, DrawDistance, CollectDistance, PromptDistance, MaxWorld, MaxPerOwner (neu, 40), ShotRateMs, CasingMerge, CasingScatter, BleedRateMs, BleedMinDamage, MeleeClothChance, AnalysisSeconds, RevealCurrentHolder, Gsr{Minutes,Distance}, CasingHasScent, LockerLimit, Colors`
- `Config.Weapons`: `RegisterFee, FeeDepartment, PermitItem, FiledSerial, File{Seconds,Chance,BreakChance}, InspectRequiresCuffs, InspectDistance, Labels`
- `Config.Scent`: `RecordInterval, MinStep, JumpReset (neu, 150), MaxAge, SniffRadius, Chunk, Tolerance, FoundDistance, Cooldown, UsesPerItem, MaxDogSpeed, SampleDistance, SampleCooldown, SourceItems, Strength{fresh,medium}, FollowLive, SessionTimeout`
- `Config.K9`: `Model, HandlerMaxDistance, SummonDistance, FromKennel, FromWhistle, DeathCooldown, Search{Radius,Cooldown}, AllowAttack, Invincible, Blip, PointReach, Speed{walk,run}`
- `Config.Escort`: `Enabled, Department, AllowedDepts, DepartmentCut, Types{bodyguard,transport,cargo}, PerExtraEscort, CargoItems, GoldValue, MaxCargoEntries, MaxCargoValue, MaxMoney, MaxGold, Insurance{PremiumPercent,Coverage,MaxClaimsPerWeek,ExpireDays,RevealRobber}, WagonModel, TickSeconds, ParticipationRadius, StartDistance, DeliverMargin, WagonLostGrace, LeaderLostGrace, RefundOnFail, OpenExpireHours, ClaimExpireDays, Robbery{Item,Seconds,Distance,Cooldown,WagonDeleteAfter}, Ambush{Enabled,Chance,Count,Models,Weapons,Progress,SpawnAhead,Spread,DespawnAfter}`

## 9. Items / SQL / server.cfg
- Keine neuen Items über `sql/items.sql` hinaus. Ware-Whitelist nutzt vorhandene Items `goldbar`, `goldnugget` (vorp_mining; Vertrag nannte `gold_nugget`), `diamond` – fehlende werden beim Start mit Warnung ausgeblendet.
- Keine eigenen SQL-Änderungen, keine `server.cfg`-Änderung. Genutzt werden die vom Kern ergänzten Spalten `ara_law_escorts.insurance_state/insurance_amount/insurance_by/insurance_at/robbed_by/robbed_by_identifier`.
- Neustart: `restart ArA-LawSystem` reicht, **sofern** `sql/items.sql` bereits eingespielt ist. Sind die `law_*`-Items neu in der DB → kompletter Server-Neustart (vorp_inventory liest Items nur beim Start).

## 10. Befunde im vorp-Code (wichtig auch für Agent A / Head Dev)
1. **`AddCharIdPermissionTakeFromCustom` / `AddCharIdPermissionMoveToCustom` sind in dieser vorp_inventory-Version wirkungslos**: `canContinue()` liefert bei aktivierten Rechten + charId `true`, der Export kehrt dann sofort zurück (`if canContinue(...) then return end`). Agent A nutzt das laut Auftrag für `ara_law_property_<charId>` → dort vermutlich darf **jeder** nehmen, der das Fach öffnen kann. Umgehung (von mir benutzt): nicht geteiltes Inventar (`shared=false`, Items liegen unter der charId) bzw. Rechte direkt über `Law.Inv:updateCustomInventoryData(invId, { CharIdPermissionTakeFrom = { [charId] = true } })`.
2. `getUserWeapon(src, cb, weaponId)` und `setWeaponSerialNumber(src, weaponId, serial)` prüfen den Besitzer nicht (globale Waffentabelle) – immer vorher gegen `getUserInventoryWeapons(src)` abgleichen.
3. `addItemsToCustomInventory(invId, items, charId, cb, identifier)` schreibt synchron in die DB, aktualisiert den Cache eines **nicht geteilten** Fachs aber nur mit dem 5. Argument `identifier` (sonst Konsolenmeldung „you didnt pass identifier" und ein bereits geöffnetes Fach bleibt bis zum Neustart leer). Ich übergebe immer `Law.IdentifierOf(charId)` und öffne das Fach erst, wenn `getCustomInventoryItemCount` die erwartete Menge zeigt (max. 5 s). Achtung: bei einem Fach, das schon Items **dieses Namens** hat, stürzt vorp ohne identifier in `updateItemAmount` ab (Index auf nil) – meine Fächer werden je Auftrag nur einmal befüllt.
4. oxmysql: `nil` mitten in Parameterlisten wird zu `NULL`, ein `nil` als **letzter** Parameter führt zu einer verschobenen Liste – in meinen Queries ist der letzte Parameter nie `nil`.
5. **`giveWeapon(source, weaponId, target)` hat vertauschte Rollen**: vorp gibt die Waffe **an `source`** (Kapazitätsprüfung des Empfängers, Meldung „erhalten", `receiveWeapon`) und nimmt sie **von `target`** (`subWeapon`). Richtig ist also `Law.Inv:giveWeapon(empfänger, weaponId, geber)`. Der Rückgabewert `true` kommt vor dem asynchronen DB-Update.

## 11. Offene Punkte / Annahmen (nicht im Spiel getestet)
- Natives ungeprüft im Spiel: `TaskFollowToOffsetOfEntity` (13 Parameter wie bcc-pets), `TaskGoToCoordAnyMeans(ped,x,y,z,speed,0,false,0,0.5)` (wie spooni_spooner), `TaskGoToEntity(ped,target,dur,dist,speed,0,0)` (wie vorp_fishing), `IsPedInMeleeCombat`, `GetWeapontypeGroup`/`IsPedShooting` (wie vorp_inventory), Blip `0x23F74C2FDA6E7C61` (BlipAddForEntity) mit Style `-1749618580` bzw. `BLIP_STYLE_FRIENDLY_ON_RADAR`, Blip-Name `0x9CB1A1623062F402`, Szenarien `WORLD_ANIMAL_DOG_*`, `WORLD_HUMAN_CROUCH_INSPECT`, `WORLD_HUMAN_INSPECT` (Namen aus spooni_spooner-Liste).
- Server-Natives: Tod des VIP über `Law.IsPedDead` (Kern), `SetEntityOrphanMode` nur wenn vorhanden (sonst übersprungen), `DeleteEntity` serverseitig nur für beim Spawn geprüfte Hunde/Wagen mit passendem Modell.
- Client-Natives neu: `AddRelationshipGroup('ara_law_ambush')` (Rückgabe bool + Hash, Fallback `joaat`), `ClearRelationshipBetweenGroups`/`RemoveRelationshipGroup` nur wenn vorhanden (sonst Beziehung auf neutral 3).
- Geruchsspur-Sprung (N5): statt die alte Spur zu verwerfen, wird der erste Punkt nach einem Sprung > `JumpReset` als `gap` markiert; der Hund folgt nie über eine Lücke (Stück endet dort → „Spur verloren"). So bleibt der Abschnitt bis zum Tatort/Ausloggpunkt erhalten, ein Respawn/Knast-Teleport kann ihn nicht löschen.
- Waffen-Besitzerwechsel (H2): eine auf jemand anderen registrierte Waffe kann am Schalter nicht mehr umgeschrieben werden. Der legale Weg ist jetzt `weapons:transfer` (Verkäufer und Käufer gemeinsam am Schalter, Käufer bestätigt). Kein Preis/Geldfluss im System – den handeln die Spieler selbst aus.
- `RevealRobber = true`: der Versicherungs-Entscheider sieht den Räubernamen (vom Head Designer als optionales Feld vorgesehen). Das verrät dem Gesetz den Täter ohne Ermittlung – ggf. auf `false` stellen.
- Wagen wird clientseitig gespawnt (wie Kern-Garage). Bei `sv_entityLockdown strict` müsste der Kern das Spawnen übernehmen.
- Personenschutz: nach Resource-Neustart startet ein aktiver Schutz neu (bereits geleistete Zeit zählt nicht). Personentransport: Tod der Person → `failed` mit `RefundOnFail` (Auftrag nannte nur Personenschutz).
- `ClaimExpireDays`: Lieferungen verfallen nie; nach Ablauf darf zusätzlich der Auftraggeber abholen. Rückgaben (failed/cancelled/expired) liegen unbefristet im Abholfach am Abholbüro.
- Cargo-Items mit Metadaten verlieren diese beim Transport (Treuhand speichert nur Name + Menge).
- Überfall: Preis + Prämie gehen in die Kasse (Dienst wurde erbracht/gebucht); aus ihr zahlt eine spätere Versicherungsfreigabe.

## 13. Fix-Runde 1 (Sicherheits-Review) – Änderungen
| Punkt | Datei:Zeile (ca.) | Änderung |
|---|---|---|
| K1.1 | `server/escort/contracts.lua` 344–356, 369, 434–436, 455–460, 527 | `insured_value` = nur Warenwert; Prämie nur darauf; Angebot/Optionen weisen `insuredValue/uninsuredValue/coverageAmount/insuranceNote` aus |
| K1.2 | `server/escort/incidents.lua` 260–300, 314–318, 350–395 | keine Auszahlung beim Überfall; `robbed_by(_identifier)`, `insurance_state/amount`, Auto-Ablehnung (a/b/c) |
| K1.3 | `server/escort/contracts.lua` 1030–1136, 199–212 | `escort:insuranceList`, `escort:insuranceDecide` (atomar pending→paid → Kasse → Auszahlung, sonst zurück auf pending), Verfall, Stand in `escort:mine` |
| H1/N2 | `server/investigation/k9.lua` 111–133; `server/escort/contracts.lua` 909–941 | kein Server-Löschen von Client-NetIds; Besitzer + Modell + Nähe + NetId frei; sonst Reject-Event |
| H2 | `server/investigation/weapons.lua` 190–205, 158–175 | fremd registrierte Waffe → `weapons_foreign` + Akte beim Besitzer + Hinweis; `weapons:mine` zeigt fehlende eigene Waffen |
| H3 | `client/investigation/k9.lua` 61–125; `client/escort/wagon.lua` (neu geschrieben) | erst melden, wenn vernetzt (≤ 3 s) + 250 ms; Server `EntityCoordsWait(3000)`; Reject → lokal aufräumen, Zustand zurück |
| M1 | `server/investigation/k9.lua` 50, 170, 392 | Suche/Angriff nur mit Hund ≤ `SummonDistance` |
| M2 | `server/investigation/evidence.lua` 145–163 | `MaxPerOwner`: eigene älteste Spur fliegt zuerst |
| M3 | `server/investigation/evidence.lua` 642–655 | Vernichten nur am `evidence`-Punkt, nur eigene Behörde |
| M4 | `contracts.lua` 527; `evidence.lua` 327; `weapons.lua` 215–228; `scent.lua` 103; `incidents.lua` 357 | `Law.DB.Try` + Rückabwicklung |
| M5 | `server/escort/cargo.lua` 98–149 | `identifier` an vorp übergeben, vor dem Öffnen auf sichtbare Menge warten |
| N1 | `cargo.lua` 207–227; `k9.lua` 23–46, 404; `incidents.lua` 95, 243 | Modellprüfung vor Nutzung/Löschung gespeicherter NetIds |
| N3 | `server/escort/incidents.lua` 154–163 | Tick bricht Aufbruch ab, wenn Räuber > `Distance + 2` m |
| N4 | `incidents.lua` 139–152; `contracts.lua` 678 | Teilnahme nur im Dienst; `escort:leave` ohne Behörden-Pflicht |
| N5 | `server/investigation/scent.lua` 44–53; `k9.lua` 228–236, 350–355 | Sprung > 150 m = `gap`, Hund folgt nie über die Lücke |
| N6 | `server/investigation/k9.lua` 148–163 | toter Hund wird nach 20 s serverseitig entfernt (nur bei passendem Modell) |
| N7 | `client/escort/incidents.lua` 157–200 | eigene Relationship-Group `ara_law_ambush`, beim Aufräumen zurückgesetzt |
| N10 | `server/escort/contracts.lua` 267–280, 720 | Auftrag fällt auf `open` zurück → neuer Leitstellen-Hinweis |

## 12. Wünsche an den Kern
1. ~~`Law.Money.PayPending` zeigt Gold mit `$`~~ – vom Kern erledigt (`payout_received_gold`).
2. Optional `Law.Inv`-Wrapper für Custom-Inventar-Rechte (siehe Befund 10.1), damit A und B nicht einzeln umgehen müssen.
3. Optional serverseitiges Spawnen von Fahrzeugen/Peds (falls Entity-Lockdown aktiviert wird).
