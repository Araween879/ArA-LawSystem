# ArA-LawSystem – Masterplan (A–Z)

Head Developer & Head Designer: Claude · Auftraggeber: Araween · Stand: 2026-09-26
Server: `VORPCore_AEFF02.base` (vorp_core 3.3, vorp_inventory mit Seriennummern, oxmysql, Lua 5.4, OneSync, **sv_maxclients 5**)

---

## 1. Ziel

Ein einziges Enterprise-Script für **alle Gesetzeshüter** in RedM/VORP:
Sheriff, Deputy, US Marshals, Saint Denis Police, Pinkerton-Detektei, Sisika-Wärter, Richter –
plus **Kopfgeldjäger** (Lizenz statt Job). Alles serverautoritativ, dupe-sicher, konfigurierbar,
deutsch lokalisiert, mit eigener Western-NUI („Dienstbuch", „Schalter", „Steckbriefbrett").

**Warum PvE-Inhalte Pflicht sind:** Der Server hat nur 5 Slots. Ein reines Spieler-gegen-Spieler-
Gesetzessystem hätte meistens nichts zu tun. Deshalb gehören NPC-Kopfgelder, NPC-Streifeneinsätze
und NPC-Überfälle auf Werttransporte fest dazu.

---

## 2. Umfang – alle Module

| # | Modul | Inhalt | Besitzer |
|---|-------|--------|----------|
| 1 | **Kern** | Behörden/Ränge/Rechte, Dienst an/aus, Dienstzeit, Marke zeigen, Lager, Waffenkammer, Dienstwagen, Kassen (Society), Chef-Verwaltung (einstellen/entlassen/befördern/Geld), Audit-Log, Webhooks, Lohn aus Kasse (optional) | Head Dev |
| 2 | **Leitstelle (Dispatch)** | Bürger-Notruf (`/sheriff`), Panikknopf, „Schüsse gemeldet" durch NPC-Zeugen in Städten, Einsätze annehmen/abschließen, Blips, Wegpunkt | Head Dev |
| 3 | **Festnahme** | Handschellen (Item `handcuffs`/`handcuffkey`), abführen, in/aus Gefangenenwagen, durchsuchen (vorp-Inventar), Ausweis/Akte im Feld, Handschellen knacken (Dritte mit `lockpick`), Hände hoch, Combat-Log-Schutz | Agent A |
| 4 | **Bußgeld** | Strafkatalog, Bußgeldbescheid (Item mit Beleg), Zahlung am Schalter oder vor Ort mit Zustimmung, Fälligkeit, Mahnung → automatischer Haftbefehl, Provision | Agent A |
| 5 | **Knast** | Lokale Zellen + Sisika, Haftzeit serverseitig (DB), Flucht-Erkennung → Haftbefehl + Kopfgeld + Alarm, Knastarbeit (Zeit abarbeiten), Kaution, Habseligkeiten-Schließfach, Tod/Relog im Knast | Agent A |
| 6 | **Akten & Haftbefehle** | Bürgerakte (Einträge, Blutgruppe, Gefährlich-Flag, Notizen), Haftbefehle mit Freigabe-Workflow, Ablauf, automatische Erledigung bei Inhaftierung | Agent A |
| 7 | **Kopfgeld** | Offizielle Kopfgelder (Kasse/Staat), private Kopfgelder (Geld treuhänderisch hinterlegt, Freigabe durch Gesetz), Kopfgeldjäger-Lizenz, Abliefern „tot oder lebendig" an Abgabestelle, Anti-Absprache-Regeln | Agent A |
| 8 | **NPC-Einsätze** | NPC-Kopfgeldaufträge am Brett, NPC-Streifeneinsätze (Banditen, Flüchtiger) über die Leitstelle | Agent A |
| 9 | **Spuren** | Patronenhülsen (mit Waffe + Seriennummer), Blut (mit Blutgruppe + Geruch), Stofffetzen (Geruch), Spurensuche-Modus nur für Gesetz, Sichern mit Beweisbeutel, Labor-Auswertung, Schmauchspurentest, Asservatenkammer | Agent B |
| 10 | **Waffenregister** | Seriennummern aus vorp_inventory (`loadout.serial_number`), Registrierung am Schalter (Waffenschein), gestohlen melden, Abfrage, Feldkontrolle, Seriennummer abfeilen (Feile), ausgegebene Dienstwaffen | Agent B |
| 11 | **Geruch & Bluthund (K9)** | Server zeichnet von **jedem** Spieler eine Geruchsspur (30 Min.) auf. Hund schnüffelt an Geruchsträger → Spur des Besitzers im **200-m-Radius** der letzten **25–30 Min.** → Hund läuft hin und folgt der Spur bis zum Ende bzw. bis zur Person. Befehle: Folgen, Bleiben, Umgebung absuchen, Heimschicken | Agent B |
| 12 | **Eskorte & Schutz** | Mietbar für Spieler: **Personenschutz** (Zeit), **Personentransport** (A→B), **Werttransport** (Gold/Geld/Items im Panzerwagen). Preis serverseitig, Ware treuhänderisch in DB, Übergabe am Zielbüro, Überfall durch Spieler möglich (Beute + Alarm + Versicherung aus Marshal-Kasse), NPC-Hinterhalte | Agent B |
| 13 | **NUI** | Dienstbuch (Gesetz), Schalter (Bürger), Steckbriefbrett, Marke, Dokumente, generische Menüs/Formulare, HUDs (Haft, K9, Eskorte, Spurensuche, Handschellen), Leitstellen-Toasts | Agent C |

### Behörden (Standard-Config, frei erweiterbar)

| Job-Key | Behörde | Ränge (0 → höchster) |
|---|---|---|
| `sheriff` | County Sheriff | Anwärter · Deputy · Senior Deputy · Undersheriff · Sheriff |
| `marshal` | US Marshals | Anwärter · Deputy Marshal · Marshal · Chief Marshal |
| `police` | Saint Denis Police | Kadett · Officer · Sergeant · Captain |
| `pinkerton` | Pinkerton-Detektei | Anwärter · Agent · Senior Agent · Direktor |
| `prisonguard` | Sisika-Gefängnis | Wärter · Oberwärter · Direktor |
| `judge` | Gericht | Richter · Oberrichter |

Kopfgeldjäger sind **kein Job**: Wer eine gültige Lizenz (DB, Item `bountylicns` als Nachweis) hat, darf
Personen mit aktivem Kopfgeld fesseln und abliefern. Alle Behörden handeln im ganzen Land
(bewusst keine Zuständigkeitsgrenzen in v1 – erspart Streit auf einem 5-Slot-Server).

---

## 3. Architektur

```
ArA-LawSystem/
  fxmanifest.lua                 Head Dev
  config/main.lua                Head Dev  (Behoerden, Stationen, Items, Kern, Leitstelle)
  config/justice.lua             Agent A
  config/investigation.lua       Agent B
  config/escort.lua              Agent B
  config/server_only.lua         Head Dev  (Webhooks - NUR Server!)
  shared/                        Head Dev  (Law-Namespace, Helfer, Locale, Rechte)
  locales/de_core.lua ...        je Besitzer eine Datei pro Modul
  server/core/*.lua              Head Dev  (Kern-API, DB-Schema ALLER Tabellen, Net-Wrapper, Stubs)
  server/justice/*.lua           Agent A
  server/investigation/*.lua     Agent B
  server/escort/*.lua            Agent B
  server/zz_boot.lua             Head Dev  (Start-Reihenfolge)
  client/core/*.lua              Head Dev  (UI-Bruecke, Prompts, Stationen, Interaktionsmenue)
  client/justice/*.lua           Agent A
  client/investigation/*.lua     Agent B
  client/escort/*.lua            Agent B
  client/zz_boot.lua             Head Dev
  html/                          Agent C
  sql/install.sql, sql/items.sql Head Dev
  docs/                          Head Dev
```

**Grundprinzipien**

1. **Ein Vertrag, drei Werkstätten.** `docs/01_CONTRACT.md` legt jedes Event, jeden Callback, jede
   Tabelle, jedes Item, jede NUI-Nachricht fest. Niemand erfindet eigene Namen.
2. **Kern zuerst.** Der Kern (Head Dev) steht, bevor die Agenten starten. Module bauen nur auf der
   Kern-API auf (`Law.Net.On`, `Law.Cb.Register`, `Law.Ctx`, `Law.Items`, `Law.Money`, `Law.Society` …).
3. **Server ist die Autorität.** Client schickt nur Absichten. Preise, Beträge, Distanzen, Rechte,
   Zeiten, Zustände – alles serverseitig. Statebags sind nur Anzeige (Client kann sie selbst setzen!).
4. **Dupe-Schutz durch Zustandsautomaten.** Jede Auszahlung/Warenübergabe hängt an einem atomaren
   `UPDATE … SET status = 'x' WHERE id = ? AND status = 'y'` mit Prüfung `affectedRows == 1`.
5. **Ein Proximity-Loop, eine UI-Brücke, ein Interaktionsmenü** – Module registrieren sich nur.
6. **Lebenszyklus zentral.** Der Kern besitzt `vorp:SelectedCharacter`, `playerDropped`,
   `onResourceStart/Stop` und ruft Modul-Hooks auf. Module registrieren diese Events **nicht** selbst.

---

## 4. Kernabläufe

### 4.1 Festnahme bis Knast
1. Officer (im Dienst, Recht `cuff`) benutzt `handcuffs` → nächster Spieler ≤ 2 m → Server prüft →
   `Law.State.cuffed[target] = officer` → Ziel-Client sperrt Steuerung.
2. Abführen (`escort`) → Ziel hängt am Officer. In Gefangenenwagen setzen (Wagen-NetId, Distanz serverseitig).
3. Durchsuchen (`search`, Ziel gefesselt) → vorp `openPlayerInventory` (vorp macht den Transfer).
4. Akte im Feld (`idcheck`) → offene Bußgelder, Haftbefehle, Kopfgelder.
5. Am Einbuchungspunkt (`jail`-Punkt) → Formular Haftstrafe (Strafkatalog) → `Law.Jail.Sentence`:
   Waffen/Items laut Config ins Habseligkeiten-Fach, Blut- & Geruchsprobe in die Akte,
   aktive Haftbefehle → `served`, Kopfgelder des Ziels → geschlossen, Akteneintrag, Teleport.
6. Haft: Server zählt jede Minute (online), Knastarbeit verkürzt, Kaution möglich,
   Flucht (Zone verlassen ohne kürzlichen Tod) → Haftbefehl + Kopfgeld + Leitstellen-Alarm.
7. Entlassung → Freilassungspunkt, Habseligkeiten am Schalter abholen.

### 4.2 Kopfgeld
- Offiziell: Haftbefehl + Betrag aus Kasse (oder „Staat" = Geld wird erzeugt, Config).
- Privat: Bürger hinterlegt Betrag + Gebühr am Schalter → Status `pending` → Gesetz gibt frei → `active`.
- Jäger bringt Ziel gefesselt (lebend) oder tot (nur wenn „tot oder lebendig") in die Abgabezone →
  Server prüft Zone, Zustand, Lizenz, Anti-Absprache (gleiche Steam-ID, Mindestalter des Kopfgelds,
  Paar-Limit 24 h) → atomar `active → claimed` → Auszahlung → lebend: automatisch Knast.

### 4.3 Spuren → Labor → Bluthund
1. Schuss (Client meldet nur „ich habe geschossen", Server nimmt eigene Position + Seriennummer der
   ausgerüsteten Waffe aus dem vorp-Inventar) → Hülse in der Welt (nur im Server-Speicher).
   Verletzung → Blutspur mit Blutgruppe. Nahkampf/Flucht → Stofffetzen. Alles trägt den Geruch des Besitzers.
2. Officer im Spurensuche-Modus sieht Spuren ≤ 30 m (Server schickt nur ihm), sichert mit Beweisbeutel →
   Item mit `evidence_id` (Fakten stehen in der DB, Item ist nur Verweis → kopieren bringt nichts).
3. Labor: Hülse → Waffe + Seriennummer → Waffenregister → registrierter Besitzer.
   Blut → Blutgruppe → Abgleich mit Proben in Akten.
4. Bluthund: Hundeführer lässt den Hund am Geruchsträger schnüffeln → Server sucht in der Spur des
   Besitzers den **neuesten Punkt ≤ 200 m** vom Hund, **nicht älter als 30 Min.** → schickt die Spur
   stückweise (15 Punkte) → Hund läuft hin und folgt. Server prüft bei jedem Stück, dass der Hund
   wirklich dort ist (Anti-Ortungs-Missbrauch). Ist die Person online, verlängert sich die Spur live
   bis der Hund ≤ 5 m an ihr steht („Gefunden"). Offline → Spur endet am Ausloggpunkt.

### 4.4 Werttransport
1. Kunde bucht am Marshal-Schalter: Ziel, Ware (Whitelist), Geld/Gold, Versicherung, Anzahl Begleiter.
   Server rechnet Preis → Kunde bestätigt → Preis + Prämie + Ware werden abgezogen und in
   `ara_law_escorts` treuhänderisch gespeichert (Status `open`).
2. Marshals nehmen an (Dienstbuch), Leiter spawnt Panzerwagen am Abholbüro → `active`.
3. Unterwegs: Server-Tick prüft Wagen + Begleiter, würfelt NPC-Hinterhalt.
4. Ankunft → Leiter liefert ab → atomar `active → delivered` → Begleiter/Kasse bezahlt →
   Empfänger holt am Zielbüro ab (atomar `delivered → claimed`, Ware via Abholfach).
5. Überfall: Nicht-Beteiligter knackt Kiste (Item, Zeit, Nähe) → Alarm → atomar `active → robbed` →
   Beute ins Beutefach des Räubers → Versicherung aus Marshal-Kasse an Kunden.
6. Scheitern (Wagen weg, Leiter weg, Frist) → `failed` → Ware zurück ans Abholbüro, Teilerstattung.

---

## 5. Lückenanalyse – erkannt und im Plan gelöst

| # | Lücke / Risiko | Lösung |
|---|---|---|
| 1 | `vorp_police` läuft parallel (Handschellen, /jail, Dienst) | `ensure vorp_police` auskommentieren – Pflicht vor Start |
| 2 | Statebags können vom Client selbst gesetzt werden | Wahrheit nur in Server-Tabellen (`Law.State`), Statebags nur Anzeige |
| 3 | `getUsedCharacter` ist ein Schnappschuss | Geld/Job immer frisch über `Law.Ctx(src)` lesen, nie zwischenspeichern |
| 4 | Client meldet Schüsse/Verletzungen | Kann nur **sich selbst** belasten; Position + Seriennummer vom Server; Rate-Limit |
| 5 | Manipulierte Event-Argumente | Jeder Wert über `Law.ToInt/ToMoney/ToStr` + Wertebereich |
| 6 | Doppelte Auszahlung (Kopfgeld, Eskorte, Bußgeld, Kaution) | Atomare Statuswechsel + `affectedRows == 1` vor jeder Auszahlung |
| 7 | Gefesselter loggt aus (Combat-Log) | Beim nächsten Login automatische Haft (Config-Minuten) + Akteneintrag |
| 8 | Officer loggt aus, Ziel bleibt ewig gefesselt | Auto-Lösen nach Config-Minuten, jeder Officer kann lösen |
| 9 | Resource-Neustart | Haft/Eskorten/Kopfgelder in DB; aktive Transporte → zurück auf `accepted` (Wagen neu spawnen); Clients räumen auf |
| 10 | Tod im Knast → Respawn im Krankenhaus = „Flucht" | Kürzlich tot (60 s) → zurückteleportieren statt Fluchtalarm |
| 11 | Selbstbedienung (sich selbst Kopfgeld/Bußgeld/Knast) | Ziel ≠ Täter, gleiche Steam-ID gesperrt |
| 12 | Kopfgeld-Absprache unter Freunden | Private Kopfgelder mit Freigabe, Mindestalter, Paar-Limit, Gebühr |
| 13 | Kasse geht ins Minus | `UPDATE … SET balance = balance - ? WHERE balance >= ?` |
| 14 | Spuren als Wallhack für Kriminelle | Spuren nur an Gesetz im Dienst mit Recht, nur Umkreis, nur auf Anfrage |
| 15 | Bluthund als Ortungswerkzeug | Nur mit echtem Geruchsträger aus dem Inventar, stückweise Spur, Hundeposition wird geprüft, Abklingzeit |
| 16 | NPC-Aufträge farmen | Modell + Position + Mindestdauer serverseitig, Stundenlimit, Abklingzeit |
| 17 | Zeitzonen DB vs. Lua | Alle Zeitfelder als Unix-Sekunden (`INT UNSIGNED`) |
| 18 | Items fehlen in DB | `sql/items.sql` + Startprüfung mit Warnung in der Konsole |
| 19 | Item `lockpick` gehört vorp_doorlocks | Kein zweites `registerUsableItem` – Knacken läuft über Prompt + Item-Zähler |
| 20 | NUI-Fokus hängt | ESC schließt immer, `onResourceStop` gibt Fokus frei |
| 21 | Client-Callback hängt ewig | Eigenes `Law.Ask` mit Timeout |
| 22 | Offline-Ziele (Bußgeld/Haftbefehl) | Über Aktensuche per charId, Benachrichtigung beim Login |
| 23 | Umlaute in Spiel-Texten | Spiel-Texte ASCII (ae/oe/ue) wie im Hausstil, NUI-Texte UTF-8 erlaubt |
| 24 | Job existiert für vorp nicht | `Core.RegisterJobs` für alle Behörden beim Start |
| 25 | Hund greift Spieler an = Griefing | „Stellen" (bellen, blockieren) statt Angriff; Angriff per Config aus |
| 26 | Leerer Server | NPC-Kopfgelder, NPC-Streifen, NPC-Hinterhalte |

---

## 6. Phasen & Arbeitsteilung

| Phase | Wer | Ergebnis |
|---|---|---|
| 0 | Head Dev | Analyse, Masterplan, Vertrag, **Kern-Code**, Bereichs-Anweisungen |
| 1 | Agent A · Agent B · Agent C **parallel** | Justiz · Ermittlung & Schutz · NUI – jeder nur in seinen Dateien |
| 2 | Head Dev | Zusammenführen: Vertragsabgleich (jedes Event hat Sender+Empfänger, jeder Callback existiert, jede NUI-Aktion hat Handler), fxmanifest, Querverweise |
| 3 | redm-reviewer | Sicherheits-/Dupe-/Performance-Prüfung |
| 4 | Head Dev | Fixes, Installationsanleitung, Testplan |

## 7. Installation (Kurzfassung – Details in `docs/INSTALL.md`)
1. `sql/items.sql` einspielen (Tabellen legt das Script selbst an).
2. `server.cfg`: `#ensure vorp_police` · `ensure ArA-LawSystem` **nach** `vorp_inventory`.
3. Webhooks in `config/server_only.lua`.
4. Voller Server-Neustart (neue Items).
