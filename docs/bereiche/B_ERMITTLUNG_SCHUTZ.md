# Bereich B – Ermittlung & Schutz (Spuren · Waffenregister · Geruch & Bluthund · Eskorten)

> Vollständiger Arbeitsauftrag, auch als Prompt für einen anderen Chat nutzbar.
> Projektordner: `C:\Users\chris\Desktop\Working Station\ArA-LawSystem`

## Rolle
Du bist **Agent B**, Senior-Entwickler für RedM/RDR3 mit VORP Core 3.3 (Lua 5.4, oxmysql, OneSync).
Team: Head Dev (Kern), Agent A (Justiz), Agent C (NUI). Du baust **nur deinen Teil**.

## Ziel
Ein realistisches Ermittlungssystem (Hülsen mit Seriennummer, Blut, Stoff, Labor, Waffenregister),
ein **echter** Bluthund, der Geruchsspuren von Spielern verfolgt, und ein mietbarer Eskort-Dienst
(Personenschutz, Personentransport, Werttransport) – serverautoritativ, dupe-sicher, ohne Nacharbeit lauffähig.

## Pflichtlektüre (vollständig, vor dem ersten Code)
1. `docs/01_CONTRACT.md` – verbindlich.
2. `docs/00_MASTERPLAN.md` – Abläufe 4.3 und 4.4, Lückenanalyse.
3. Kern (nur lesen): `shared/*.lua`, `server/core/*.lua`, `server/zz_boot.lua`, `client/core/*.lua`, `client/zz_boot.lua`, `config/main.lua`.
4. vorp_inventory: `D:\[0] Projekte\RedM Projekt\VORPCore_AEFF02.base\resources\[VORP]\vorp_inventory\server\types\types.lua`
   + Umsetzung `server/services/inventoryApiService.lua` (Waffen: `getUserInventoryWeapons` liefert `id, name, label, used, used2, serial_number …`; `setWeaponSerialNumber(src, weaponId, serial)`; Custom-Inventare).
   Seriennummern stehen in der Tabelle `loadout.serial_number` (Spalten: id, identifier, charidentifier, name, label, serial_number, curr_inv, dropped …).
5. Natives: https://alloc8or.re/rdr3/nativedb/ · https://github.com/femga/rdr3_discoveries (Hunde-Tasks, Relationship-Groups, Anims).

## Deine Dateien (nur diese!)
```
config/investigation.lua  config/escort.lua
server/investigation/evidence.lua  weapons.lua  scent.lua  k9.lua
server/escort/contracts.lua  cargo.lua  incidents.lua
client/investigation/evidence.lua  shots.lua  weapons.lua  k9.lua
client/escort/escort.lua  wagon.lua  incidents.lua
locales/de_investigation.lua  locales/en_investigation.lua  locales/de_escort.lua  locales/en_escort.lua
docs/B_REPORT.md
```

## Regeln (hart)
1. Nur `Law.Net.On` / `Law.Cb.Register` für Netz. Eingaben durch `Law.ToInt/ToMoney/ToStr/ToBool`.
2. **Positionen kommen vom Server** (`Law.GetCoords`, `Law.EntityCoords(netId)`), nie vom Client.
3. Client-Meldungen (Schuss, Verletzung) dürfen **nur den Meldenden selbst** belasten: Position = Server-Position des Meldenden, Seriennummer = aus SEINEM vorp-Inventar. Rate-Limit.
4. Geld/Items nur über `Law.Money.*` / `Law.Items.*` (vorp `subItem`/`subItemById` prüfen die Menge NICHT – nie direkt aufrufen). Offline-Geld nur `Law.Money.GiveCharId`.
5. Jede Auszahlung/Warenübergabe nach atomarem Statuswechsel (`UPDATE ara_law_escorts SET status=? WHERE id=? AND status=?` → `affected == 1`).
6. Keine eigenen Tabellen (alle im Kern). Lebenszyklus nur über `Law.Modules.Register`.
7. Spuren und Spurdaten nur an Gesetz im Dienst mit Recht und nur im Umkreis. Keine Rundsendungen von Wagen-Positionen an alle.
8. Spiel-Texte ASCII (ae/oe/ue/ss) in deinen Locale-Dateien. Keine Texte im Code.
9. Loops mit Distanz-Sleep, `onStop` räumt Hund, Wagen, NPCs, Blips, Marker, Prompts auf.
10. `Law.Audit` für: Spur gesichert/ausgewertet/vernichtet, Waffe registriert/gestohlen/abgefeilt/Status, Hund gerufen/Spur gestartet, Eskorte gebucht/angenommen/geliefert/abgeholt/überfallen/gescheitert.
11. Code englisch, Kommentare deutsch (erklären WARUM). Du kannst nicht im Spiel testen → jede Datei zweimal auf nil, Argument-Reihenfolge, Locale-Schlüssel prüfen.

## Aufgaben (TODO)

### B1 – Config
`config/investigation.lua`:
- `Config.Evidence = { Lifetime={ casing=2700, blood=3600, cloth=7200 }, ScanRadius=30.0, ScanCooldown=3, CollectDistance=2.0, MaxWorld=600, ShotRateMs=1500, CasingMerge=3.0, BleedRateMs=5000, ClothRateMs=60000, Wounds={...}, SharpWeapons={...}, CollectWith={...}, AnalysisSeconds=60, RevealCurrentHolder=true, Gsr={ Minutes=15, Distance=2.5 }, CasingHasScent=true }`
- `Config.Weapons = { RegisterFee=10, PermitItem=true, FiledSerial='ABGEFEILT', File={ Seconds=10, Chance=80, BreakChance=30 }, InspectRequiresCuffs=true, Labels={ WEAPON_REVOLVER_CATTLEMAN='Cattleman-Revolver', ... } }`
- `Config.Scent = { RecordInterval=5, MinStep=3.0, MaxAge=1800, SniffRadius=200.0, Chunk=15, Tolerance=15.0, FoundDistance=5.0, Cooldown=60, UsesPerItem=3, SourceItems={ law_casing=true, law_bloodsample=true, law_clothscrap=true, law_scentcloth=true }, Strength={ fresh=300, medium=900 }, FollowLive=true, SessionTimeout=600 }`
- `Config.K9 = { Model='A_C_DogBluetickCoonhound_01', HandlerMaxDistance=60.0, SummonDistance=10.0, FromKennel=true, FromWhistle=true, DeathCooldown=300, Search={ Radius=25.0, Cooldown=60 }, AllowAttack=false }`

`config/escort.lua`:
- `Config.Escort = { Department='marshal', AllowedDepts={ 'marshal','sheriff','pinkerton','police' }, DepartmentCut=0.25, Types={ bodyguard={ Base=50, PerMinute=1.5, Durations={30,60,90,120}, MinEscorts=1, MaxEscorts=4, VipRadius=75.0, DeathRefund=0.5 }, transport={ Base=30, PerKm=8, MinutesPerKm=6, MinMinutes=15 }, cargo={ Base=60, PerKm=10, ValuePercent=0.05, MinutesPerKm=6, MinMinutes=20 } }, PerExtraEscort=20, CargoItems={ goldbar={ value=500 }, gold_nugget={ value=15 }, … }, MaxCargoValue=50000, MaxMoney=20000, MaxGold=100, Insurance={ PremiumPercent=0.08, Coverage=0.8 }, WagonModel='wagonarmoured01x', TickSeconds=10, ParticipationRadius=75.0, WagonLostGrace=120, LeaderLostGrace=300, RefundOnFail=0.5, OpenExpireHours=24, ClaimExpireDays=14, Robbery={ Item='law_strongbox_tool', Seconds=60, Distance=3.0, Cooldown=300 }, Ambush={ Enabled=true, Chance=0.35, Count={3,6}, Models={...}, Weapons={...}, Progress={0.3,0.7}, SpawnAhead=120.0 } }`
- Eskort-Büros = alle `Config.Stations` mit `points.escort` (Kern-Config). Entfernung = Luftlinie zwischen den `escort`-Punkten in km.

### B2 – Spuren (`evidence.lua`, Client `shots.lua` + `evidence.lua`)
- **Welt-Spuren nur im Server-Speicher**: `{ id, kind, coords, createdAt, ownerCharId?, weapon?, serial?, bloodType?, zone? }`, Ablauf nach `Lifetime`, Obergrenze `MaxWorld` (älteste fliegen).
- `Law.Evidence.CreateTrace(kind, coords, data)` (Vertrag 4.1) – A ruft es bei Flucht/Knacken auf.
- Schüsse: Client-Loop nur wenn bewaffnet (Feuerwaffe, keine Bögen/Wurf/Nahkampf/Lasso), `IsPedShooting` → `evidence:shot(weaponHash)` (Client-seitig gedrosselt). Server: Rate-Limit `ShotRateMs`; Seriennummer = ausgerüstete Waffe (`used`/`used2`) des Spielers mit passendem Hash aus `Law.Inv:getUserInventoryWeapons(src)`; keine gefunden → `serial=nil`. Hülse an Server-Position (+ kleiner Zufallsversatz), bei gleicher Seriennummer im `CasingMerge`-Radius zusammenfassen (Zähler). Merkt `LastShotAt[charId]`. Ruft `Law.Dispatch.ShotsFired(src, coords, weaponLabel)`.
- Verletzungen: Client liest das Spiel-Ereignis `EVENT_ENTITY_DAMAGED` (eigener Ped getroffen) und meldet nur die Art → `evidence:wound(kind)` mit `kind = fist|shot|sharp|animal|other`. Server würfelt nach `Config.Evidence.Wounds` Blut (Blutgruppe aus `Law.Citizens`, Drossel `BleedRateMs`) und Kleidungsfetzen (Drossel `ClothRateMs`) an der Server-Position. Blut sichern verbraucht `law_sterilecloth` (`CollectWith`). Geruchsträger: Blut `Config.Scent.ItemMinutes` (60) ab Tat, Kleidung unbegrenzt (`Uses = 0`); nach Haft (`ResetOnJail`, `ara_law_citizens.scent_reset_at`) wertlos.
- Spurensuche: Interaktion (Selbst, Recht `evidence`) schaltet den Modus; Client fragt alle `ScanCooldown` s `evidence:scan()` → Server liefert nur Spuren ≤ `ScanRadius` um den Officer: `{ id, kind, coords, ageClass }` (KEINE Seriennummer/Besitzer). Client zeichnet Marker, Prompt „Spur sichern" ≤ 1.5 m → `evidence:collect(id)`: Nähe ≤ `CollectDistance`, 1× `law_evidence_bag` abziehen, DB-Zeile `ara_law_evidence`, Item (`law_casing`/`law_bloodsample`/`law_clothscrap`) mit `metadata = { evidence_id, description }`, Spur aus der Welt. HUD `evidence`.
- Labor am Stationspunkt `evidence` (`Law.Stations.RegisterPoint`): Menü „Asservatenkammer" (vorp-Custom-Inventar `ara_law_evidence_<dept>`) und „Beweis auswerten" → `evidence:myItems()` (Beweis-Items aus dem Inventar mit Beschreibung) → `evidence:analyze(itemId)` → Server-Timer `AnalysisSeconds` → Ergebnis: Hülse → Waffe + Seriennummer + Registerabgleich (+ aktueller Besitzer aus `loadout` wenn `RevealCurrentHolder`); Blut → Blutgruppe + Abgleich mit Akten (`ara_law_citizens.has_sample=1` gleicher Blutgruppe **und** Besitzer = Treffer); Stoff → Geruchsträger (+ Treffer wenn Probe in Akte). `status='analyzed'`, `analysis` JSON, Item-Metadaten aktualisieren, `Law.Records.Add` beim Treffer, Dokument `evidence` anzeigen.
- Dienstbuch: `evidence:list(filter)`, `evidence:get(id)`, `evidence:destroy(id)` (`evidence_analyze`).
- Schmauchspurentest: Interaktion am Ziel (`evidence`) → `evidence:gsr(targetSrc)` → positiv wenn `LastShotAt` ≤ `Gsr.Minutes`. `Law.Evidence.LastShotAt(charId)` (Vertrag 4.1).

### B3 – Waffenregister (`weapons.lua`)
- Schalter: `weapons:mine()` (eigene Waffen mit Seriennummer, registriert?, Status, abgefeilt?), `weapons:register(weaponId)` (Gebühr → Kasse `sheriff`; nicht abgefeilt/leer; nicht als gestohlen eines anderen gemeldet; Zeile `ara_law_weapons`; `law_weaponpermit` mit Metadaten), `weapons:reportStolen(serial)` (nur eigene registrierte).
- Dienstbuch: `weapons:lookup(serial)` → `WeaponInfo` (+ Beweise mit dieser Seriennummer, + aktueller Besitzer aus `loadout`), `weapons:setStatus(serial, status, note)` (`weapons_registry`).
- Feldkontrolle: Interaktion (`weapons_registry` oder `search`) → `weapons:inspect(targetSrc)` (Ziel gefesselt/tot wenn `InspectRequiresCuffs`) → Liste mit Status/abgefeilt → Menü-Anzeige.
- `law_gunfile` benutzbar (jeder): eigene Waffen wählen → Start/Ende-Muster mit `File.Seconds` → Würfel → `Law.Inv:setWeaponSerialNumber(src, weaponId, Config.Weapons.FiledSerial)`, bei Fehlschlag `BreakChance` → Feile weg. Registereintrag bleibt (Status unverändert).
- `law_weaponpermit` benutzbar → Dokument `permit`.
- `Law.Weapons.RegisterIssued/GetByOwner/Lookup` (Vertrag 4.1).

### B4 – Geruchsspur (`scent.lua`)
- `Law.Every(RecordInterval)`: für jeden geladenen Spieler Server-Position → nur wenn ≥ `MinStep` bewegt → Punkt `{ x, y, z, t }` in Ringpuffer **je charId** (bleibt nach Logout bis `MaxAge` bestehen). Alte Punkte löschen. Keine DB.
- `Law.Scent.HasTrail(charId)` (Vertrag 4.1).
- Geruchsprobe: Interaktion am gefesselten Ziel (`scent_sample`) → `scent:sample(targetSrc)` → Beweiszeile `type='scent'` + `law_scentcloth` mit `{ evidence_id, description, uses=UsesPerItem }`.

### B5 – Bluthund (`k9.lua`)
- Holen: Stationspunkt `kennel` und/oder `law_whistle` (Recht `k9`, im Dienst). Server gibt frei → Client spawnt Hund (vernetzt, Begleiter des Hundeführers, unverwundbar gegenüber Freund-Feuer optional) → `k9:spawned(netId)` → Server prüft Modell. Ein Hund pro Hundeführer, `DeathCooldown`.
- Befehle als Selbst-Interaktionen (nur wenn Hund da): Folgen, Bleiben, Umgebung absuchen (`k9:search` → nächster Nicht-Gesetz-Spieler ≤ `Search.Radius` um den **Hund** → Hund läuft hin und bellt), **Witterung aufnehmen** (Menü mit Geruchsträgern aus dem Inventar), Heimschicken.
- **Spurverfolgung (Kernfeature):**
  1. `scent:start(itemId)`: Item liegt im Inventar, ist in `SourceItems`, hat `evidence_id` → DB `owner_charid`; `uses` > 0; Hund-Entity existiert und ≤ 10 m vom Hundeführer; Cooldown.
  2. Server sucht in der Spur des Besitzers den **neuesten Punkt ≤ `SniffRadius` (200 m) vom Hund**, nicht älter als `MaxAge` (30 Min.). Keiner → `{ ok=false, err='no_scent' }` (Hund winselt).
  3. Sonst Sitzung `{ handler, target, index, startedAt }` → Rückgabe: erstes Stück (≤ `Chunk` Punkte ab diesem Punkt vorwärts in der Zeit) + `strength` (fresh/medium/weak nach Alter). `uses` −1 (Item-Metadaten).
  4. Client: Hund läuft zum ersten Punkt und folgt den Punkten (NavMesh-Task, Tempo passend), Hundeführer-Abstand > `HandlerMaxDistance` → Hund wartet. Am Stückende → `scent:next(sessionId)`: Server prüft **Hund-Position** (`Law.EntityCoords`) ≤ `Tolerance` vom letzten gesendeten Punkt und Hundeführer ≤ `HandlerMaxDistance` → nächstes Stück.
  5. Ende der gespeicherten Spur: Ziel online + `FollowLive` → neue Punkte anhängen, bis Hund ≤ `FoundDistance` an der Ziel-Person → `{ found=true }` (bellen, anzeigen). Ziel offline/Spur alt → `{ lost=true }`.
  6. Abbruch per Befehl, `SessionTimeout`, Hund tot, Dienstende.
- HUD `k9` (Zustände laut Vertrag 10.4).

### B6 – Eskorten (`contracts.lua`, `cargo.lua`, `incidents.lua` + Client)
- Schalter-Tab `escort`: `escort:options(station)`, `escort:quote(values)`, `escort:book(values)`, `escort:mine()`, `escort:cancel(id)` (nur `open`, volle Erstattung inkl. Ware), `escort:claim(id)`.
  `values = { type, destination?, durationMin?, escorts, insurance, recipientName?, cargo=[{ name, amount }], money, gold }`.
  Buchung: am `counter`/`escort`-Punkt des Abholbüros; Preis serverseitig; ERST alle Mengen prüfen, DANN Preis+Prämie+Ware+Geld abziehen (bei Teilfehlschlag bereits Abgezogenes zurückgeben); Zeile `open`; Leitstelle `kind='escort'` an berechtigte Behörden.
- Dienstbuch-Tab `escorts`: `escort:listOpen`, `escort:listMine`, `escort:accept(id)` (erster mit `escort_lead` wird Leiter), `escort:leave(id)`.
- Start: Leiter am Abholbüro (`escort`-Punkt) → Cargo: Panzerwagen spawnen (Client, NetId melden, Modellprüfung) → `active`, Frist setzen. Bodyguard/Transport: Start in ≤ 20 m zum Kunden.
- Server-Tick (`TickSeconds`): Wagen/VIP/Begleiter prüfen, Teilnahme-Ticks je Begleiter (≤ `ParticipationRadius`), Wagen weg > `WagonLostGrace` oder Leiter weg > `LeaderLostGrace` oder Frist → `failed` (Ware zurück an Abholbüro, `RefundOnFail`). Bodyguard: Dauer abgelaufen → `completed`; VIP tot (`Law.Escort.OnPlayerDeath`) → `failed` mit `DeathRefund`.
- Abliefern (Cargo): Leiter + Wagen in Zielzone → atomar `active → delivered` → Wagen löschen → Lohn an Begleiter nach Teilnahme (`Law.Money.GiveCharId`, Grund `escort_pay`), Anteil `DepartmentCut` an Kasse `Config.Escort.Department` → Empfänger benachrichtigen. Abholen: atomar `delivered → claimed` (nur Empfänger, nur am Zielbüro) → Ware in vorp-Custom-Inventar `ara_law_escort_<id>` (nur Empfänger darf nehmen) + Geld/Gold direkt → `openInventory`.
- Überfall (`incidents.lua`): Client erkennt nahen Panzerwagen (Modell) und fragt `escort:canRob(netId)` → Prompt. `escort:robStart(netId)` / `escort:robFinish(netId)`: Räuber ≠ Kunde/Empfänger/Begleiter (auch Steam-ID), Item `Robbery.Item`, Nähe `Robbery.Distance` zur **Server**-Position des Wagens, Dauer ≥ `Robbery.Seconds`, Cooldown. Start → sofort `Law.Dispatch.Create{ kind='robbery', priority=3 }`. Ende → atomar `active → robbed` → Beute in `ara_law_escort_loot_<id>` (nur Räuber) + Geld → Versicherung (`Insurance.Coverage` × versicherter Wert) aus Kasse `Config.Escort.Department` an Kunden über `Law.Money.GiveCharId(…,'escort_insurance')` (Kasse leer → so viel wie da ist, Rest verfällt, im Log vermerken).
- NPC-Hinterhalt: pro Cargo-Vertrag einmal würfeln (`Ambush.Chance`), bei Fortschritt zwischen `Progress[1..2]` schickt der Server dem Leiter den Befehl, `Count` Banditen `SpawnAhead` m vor dem Wagen zu spawnen (feindlich). Aufräumen bei Vertragsende.
- Neustart: `init` setzt `active` → `accepted` (Wagen weg, neu spawnen), abgelaufene `open` → `expired` mit Erstattung.
- HUD `escort`, `payout_reason_escort_pay`, `payout_reason_escort_insurance`, `payout_reason_escort_refund` in Locales.

### B7 – Texte & Bericht
- Locale-Dateien mit ALLEN benutzten Schlüsseln (inkl. neue `err_<code>`).
- `docs/B_REPORT.md`: Callbacks (Name/Args/Rückgabe), Events, Interaktionen, Stationspunkte, Config-Schlüssel, offene Punkte, Wünsche an den Kern.

## Abnahme (Definition of Done)
- Alle Callbacks aus Vertrag 10.5 (Tabs `evidence`, `weapons`, `escorts`) und 10.5 Schalter (`weapons`, `escort`) mit exakt diesen Namen/Formen.
- Alle Querverweis-Funktionen aus Vertrag 4.1 (Besitzer B) überschreiben die Stubs mit exakt der Signatur.
- Kein Pfad, auf dem Ware/Geld doppelt entsteht oder verschwindet (jeder Endzustand der Eskorte ist atomar und exklusiv).
- Keine Datei außerhalb deiner Liste geändert.
