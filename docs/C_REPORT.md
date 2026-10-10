# Agent C – Abschlussbericht NUI

Stand: 2026-09-26 · Besitzer: Agent C · Bereich: `html/**`, `locales/de_ui.lua`, `locales/en_ui.lua`, `docs/C_REPORT.md`

## 1. Dateien

| Datei | Inhalt |
|---|---|
| `html/index.html` | Gerüst: HUD-Ebene, Apps (ledger, counter, board, menu, form, document, badge), Dialog- und Toast-Ebene, Script-Reihenfolge |
| `html/css/base.css` | Schriften (Crock per `@font-face` aus `nui://vorp_lib/web/fonts/crock.ttf`), Farben, Ebenen, Bühne, Knöpfe, Felder, Listen, Dialog, Toasts, Debug-Raster |
| `html/css/apps.css` | Menü, Formular + Strafkatalog, Dokumente (Bescheid/Haftbefehl/Bericht/Beweis, WANTED-Plakat, Lizenz-Karte), Siegel, Marke |
| `html/css/ledger.css` · `counter.css` · `board.css` · `hud.css` | Dienstbuch, Schalter, Steckbriefbrett, HUDs |
| `html/css/dev.css` | Testleiste (nur Browser) |
| `html/js/core.js` | Router (Vertrag 10.1), `post()`, `cb()`, `action()`, `t()`, Formatierer, Stapel, ESC, Bestätigungs-/Eingabedialog, Toasts, Debug |
| `html/js/ui.js` | Icons (Inline-SVG), Siegel mit Textbogen, Marken, Listen-Bausteine, **alle Feldtypen aus 10.3 inkl. `penalcode`** |
| `html/js/apps.js` | `menu`, `form`, `document`, `badge` |
| `html/js/ledger.js` · `ledger_tabs.js` | Dienstbuch: Rahmen, `overview`, `people` / `warrants`, `bounties`, `fines`, `jail`, `evidence`, `weapons`, `escorts` (+ Versicherungsfälle), `department` |
| `html/js/counter.js` · `board.js` · `hud.js` | Schalter, Steckbriefbrett, 7 HUDs |
| `html/js/mock_data.js` · `mock.js` | Browser-Testmodus (Testdaten, Testantworten für jeden Callback, Testleiste) – im Spiel inaktiv |
| `html/img/*.svg` (21 Stück) | `paper` (Kachel), `ledger`, `counter`, `board`, `poster`, `doc`, `card`, `wallet`, `silhouette`, `badge_<sheriff\|marshal\|police\|pinkerton\|prison\|court>`, `seal_<…>` – alles selbst gezeichnet, keine Texte eingebacken |
| `locales/de_ui.lua` · `locales/en_ui.lua` | alle `ui_*`-Schlüssel (DE mit Umlauten, EN vollständig) |

Keine Datei außerhalb dieser Liste wurde geändert.

## 2. Protokoll (Vertrag 10)

**Lua → JS:** `init` (strings/currency/locale), `open` (Stapel; `nofocus` auf oberster Ebene **oder** in `data` → ohne Fokus), `update`, `close` (alles Fokussierte weg, **kein** Post zurück), `hud` (`data` fehlt/null → ausblenden), `toast`.

**JS → Lua:** `ready` (beim Laden), `close { seq }`, `cb { name, args }`, `action { app, name, payload }`, `menuSelect { id }`, `menuCancel`, `formSubmit { values }`, `formCancel`.
Alle Posts: `fetch('https://' + GetParentResourceName() + '/<endpoint>', { method:'POST', headers:{'Content-Type':'application/json; charset=UTF-8'}, body })`.

Jede `cb`-/`action`-Antwort wird als `Result` behandelt: `ok=false` → `msg` (oder `ui_err_<err>`, sonst `ui_err_generic`) als roter Hinweis; `err='cancelled'` bleibt still; `ok=true` mit `msg` → grüner Hinweis. Nach Mutationen wird die Liste neu geladen.

### 2.1 Stapelverhalten
- **Grund-Apps** `ledger`, `counter`, `board`: immer ganz unten, höchstens eine gleichzeitig (eine neue ersetzt die alte).
- **Ebenen** `menu`, `form`, `document`: legen sich oben drauf; dieselbe App wird ersetzt statt doppelt gestapelt.
- **ESC** schließt die oberste Ebene: `menu` → `menuCancel`, `form` → `formCancel`, sonst nur ausblenden. Offener Bestätigungsdialog wird zuerst geschlossen.
- Nach `menuSelect` / `formSubmit` wird die Ebene entfernt (erst **nach** der Antwort des Posts wird ggf. geschlossen).
- **Stapel leer → `close { seq }`**: `seq` = höchste empfangene `seq` einer fokussierten `open`-Nachricht (Protokoll-Update Head Dev). Zusätzlich 200 ms Gnadenfrist: öffnet Lua in dieser Zeit etwas Neues, wird gar kein `close` gesendet.
- `badge` (`nofocus`) gehört nie zum Stapel und blendet nach `data.ms` (Default 6000) aus.
- Dokumente, die das Dienstbuch selbst anzeigt („Dokument ansehen“, „Steckbrief ansehen“), sind reine NUI-Ebenen über dem Buch.

### 2.2 Benutzte `cb`-Namen (alle aus Vertrag 10.5 bzw. vom Head Dev nachgereicht)

| Bereich | Callbacks |
|---|---|
| Dienstbuch overview | `core:ledgerOverview`, `dispatch:accept(id)`, `dispatch:close(id)` |
| people | `records:search(query)`, `records:getFile(charId)`, `records:setDangerous(charId, bool)`, **`bounty:revokeLicense(charId)`** (Update 1, Recht `license_manage`) |
| warrants | `warrants:list(status)`, `warrants:approve(id)`, `warrants:revoke(id)` |
| bounties | `bounty:list(status)`, `bounty:approve(id)`, `bounty:cancel(id)` |
| fines | `fines:list(status)`, `fines:cancel(id)` |
| jail | `jail:list()`, `jail:release(charId)`, `jail:adjust(charId, minutesDelta)`, `jail:setBail(charId, amount)` |
| evidence | `evidence:list(filter)`, `evidence:get(id)`, `evidence:destroy(id)` |
| weapons | `weapons:lookup(serial)`, `weapons:setStatus(serial, status, note)` |
| escorts | `escort:listOpen()`, `escort:listMine()`, `escort:accept(id)`, `escort:leave(id)`, **`escort:insuranceList()`**, **`escort:insuranceDecide(id, bool)`** (Update 2, Recht `boss_funds`) |
| department | `boss:overview()`, `boss:fire(charId)`, `boss:setGrade(charId, grade)`, `boss:deposit(amount)`, `boss:withdraw(amount)` |
| Schalter | `fines:mine`, `fines:pay`, `jail:bailList`, `jail:payBail`, `bounty:licenseStatus`, `bounty:buyLicense`, `bounty:searchTarget`, `bounty:placePrivate({charId,amount,reason,deadOrAlive})`, `bounty:minePlaced`, `bounty:cancelPrivate`, `weapons:mine`, `weapons:register(weaponId)`, `weapons:reportStolen(serial)`, `escort:options(station)`, `escort:quote(values)`, `escort:book(values)`, `escort:mine`, `escort:cancel`, `escort:claim`, `jail:propertyStatus`, `jail:claimProperty`, `dispatch:report(text)` |
| Brett | `bounty:board()`, `npc:accept(id)` |

Nicht benutzt (existieren, aber laut Auftrag über Formulare gelöst): `records:addNote` (→ `openForm note`), `dispatch:list` (Übersicht liefert die Einsätze), `core:ledgerOpen/counterOpen/boardOpen` (ruft Lua vor dem `open`).

**Status-Filter** (Update 1): `warrants:list` `open|pending|active|served|all`, `bounty:list` `open|pending|active|claimed|all`, `fines:list` `unpaid|overdue|paid|cancelled|all`; Standard `open` bzw. `unpaid`. `evidence:list`: „Aktuell“ sendet `null` (Server-Standard = alles außer vernichtet), sonst `collected|analyzed|destroyed|all`.

### 2.3 Benutzte `action`-Namen
- `ledger:setWaypoint { x, y, z }` – nach „Annehmen“ (Koordinaten aus `dispatch:accept` → `data.coords`, sonst aus dem Alert) und über „Route“.
- `ledger:openForm { form, charId?, id? }` mit `form` = `fine`, `warrant`, `bounty_official`, `note` (Akte, mit `charId`), `warrant` / `bounty_official` (Tab-Knopf, ohne `charId`), `hire` (Behörde). Die Antwort kommt erst nach dem Formular → danach lädt der Tab neu.

### 2.4 Rechte → Reiter
`overview` immer · `people`/`warrants`/`bounties`/`fines`/`jail` = `records_view` · `evidence` = `evidence` · `weapons` = `weapons_registry` · `escorts` = `escort_contracts` · `department` = irgendein `boss_*`. `all` erlaubt alles. Knöpfe zusätzlich: `fine`, `warrant_create`, `warrant_approve`, `bounty_manage`, `records_edit`, `license_manage`, `fine_cancel`, `jail_release`, `evidence_analyze`, `weapons_registry`, `boss_funds` (Versicherungsfälle). Behörde-Knöpfe über `boss:overview().can`. Der Server prüft trotzdem alles.

### 2.5 Bestätigungsdialoge (eigene NUI-Dialoge)
Entlassen, Haftbefehl widerrufen, Beweis vernichten, Kopfgeld/Bußgeld/privates Kopfgeld/Eskorte stornieren, Kaution zahlen, Kopfgeld aussetzen, Freilassen, Lizenz entziehen, Versicherung auszahlen/ablehnen (rot). Nicht-rot bestätigt: Bußgeld bezahlen, Lizenz kaufen, Eskorte buchen (mit Gesamtpreis), Waffe gestohlen melden, Auftrag verlassen, NPC-Auftrag annehmen. Kleine Eingabedialoge: Kaution festsetzen (0 = entfernen), Haftzeit ± Minuten, Rang ändern, Ein-/Auszahlen, Waffenstatus.

## 3. Zusätzliche Datenfelder (Vertrag 12 – optional, NUI ignoriert Fehlendes)

| Wo | Feld | Wirkung |
|---|---|---|
| `document` | `reward` (Zahl), `deadOrAlive` (bool) | WANTED-Plakat: „REWARD $…“ und „DEAD OR ALIVE“ / „ALIVE ONLY“. **Bitte bei `kind='poster'` mitschicken.** |
| `document` | `sealLabel` | Text im oberen Siegelbogen (sonst ohne Text) |
| `form` Field `readonly` | `display` | Anzeigetext statt Rohwert (z. B. Name statt charId); gesendet wird weiter `default` |
| `form` | `cancelLabel` | Beschriftung „Abbrechen“ |
| `counter`/`board` open | `seal` | Stempel auf Lizenzkarte/Plakaten (Default `sheriff`) |
| `menu` Item `icon` | Name | `cuffs, key, lock, search, doc, money, gold, jail, gun, dog, eye, scale, wagon, box, pin, person, people, pen, clock, bell, warning, skull, check, cross, star, badge, shield, book, horse, flag` + Aliase (`handcuffs, fine, weapon, k9, evidence, escort, bounty, panic, waypoint, …`). Unbekannt → Raute. |

Kassenbuch-Gründe werden über `ui_reason_<reason>` übersetzt (deposit, withdraw, withdraw_refund, salary, payroll, fine, fine_payment, bail, armory, bounty_official, bounty_refund, license, bounty_license, weapon_register, escort, escort_cut, escort_insurance, start); unbekannte erscheinen roh.

## 4. Gestaltung & Maße (Skill redm-nui-png)

Alle großen Apps sind „Bühnen“ mit festem Seitenverhältnis (SVG-Hintergrund, `1em` = 1 % der Bühnenbreite, Breite per `min(vw, vh)`), Panels/HUDs skalieren mit `clamp(12px, 1.6vh, 32px)`. Referenz 1920×1080; 1280×720 und 2560×1440 skalieren proportional.

| Bild | Maße | Zweck |
|---|---|---|
| `ledger.svg` | 1600 × 1000 | Dienstbuch |
| `counter.svg` | 1600 × 1000 | Schalter |
| `board.svg` | 1600 × 1000 | Steckbriefbrett |
| `doc.svg` | 1000 × 1300 | Bescheid, Haftbefehl, Bericht, Beweis |
| `poster.svg` | 900 × 1250 | WANTED-Plakat (auch kleine Plakate am Brett) |
| `card.svg` | 1400 × 900 | Lizenz, Waffenschein |
| `wallet.svg` | 1000 × 560 | Marke |
| `badge_*.svg` / `seal_*.svg` | 400 × 400 / 200 × 200 | Marken / Tintenstempel je Behörde |

**Feld-Tabelle (left / top / width / height in %)**

| Element | left | top | width | height |
|---|---|---|---|---|
| Dienstbuch Reiter `#lg-tabs` | 6.5 | 0.6 | 87 | 6.4 |
| Dienstbuch Kopf links `#lg-head` | 7.5 | 9.5 | 40 | 9 |
| Dienstbuch Seite links `#lg-left` | 7.5 | 19.5 | 40 | 72 |
| Dienstbuch Kopf rechts | 52.5 | 9.5 | 40 | 9 |
| Dienstbuch Seite rechts `#lg-right` | 52.5 | 19.5 | 40 | 72 |
| Dienstbuch Schließen | 94.6 | 6.2 | 3.4 | 5.44 |
| Schalter Bürger | 5 | 4.2 | 26 | 5.5 |
| Schalter Messingschild | 33 | 2.2 | 34 | 8.6 |
| Schalter Reiter | 5.5 | 13.2 | 89 | 6.8 |
| Schalter Bogen `#ct-sheet` | 7 | 22.5 | 86 | 71 |
| Schalter/Brett Schließen | 94.2 | 2.8 | 3.6 | 5.76 |
| Brett Kopfschild | 32 | 2.2 | 36 | 8 |
| Brett Plakate | 4.5 | 13 | 57 | 82 |
| Brett Aushang | 64 | 13 | 31.5 | 82 |
| Dokument Kicker / Titel / Untertitel | 12 / 10 / 12 | 6.5 / 10 / 18.5 | 76 / 80 / 76 | 3 / 8 / 3.5 |
| Dokument Inhalt / Fuß | 11 / 11 | 24 / 77 | 78 / 78 | 52 / 4 |
| Dokument Siegel / Unterschrift | 9 / 52 | 80.5 / 84 | 21 / 38 | 16.2 / 11 |
| Plakat WANTED / DOA / Bild | 8 / 8 / 27 | 4.5 / 18 / 25 | 84 / 84 / 46 | 13 / 5.5 / 27 |
| Plakat Name / Grund / Delikte | 6 / 10 / 12 | 53.5 / 61 / 66 | 88 / 80 / 76 | 7 / 4.5 / 13 |
| Plakat REWARD / Fuß / Siegel | 8 / 10 / 77 | 79.5 / 89.5 / 24 | 84 / 80 / 17 | 9.5 / 3.5 / 12.2 |
| Karte Siegel / Symbol / Kicker / Titel | 5 / 7 / 25 / 25 | 9 / 42 / 8 / 13 | 17 / 13 / 70 / 70 | 26.4 / 20 / 5 / 10 |
| Karte Untertitel / Inhalt / Fuß / Unterschrift | 25 / 25 / 5 / 55 | 23.5 / 31 / 77 / 75 | 70 / 70 / 44 / 40 | 5 / 43 / 13 / 16 |
| Marke Abzeichen / Behörde / Name / Rang | 5 / 54 / 54 / 54 | 9 / 12 / 27 / 43 | 42 / 40 / 40 / 40 | 82 / 9 / 14 / 8 |
| Marke Nr.-Label / Nummer | 54 / 54 | 62 / 69 | 40 / 40 | 6 / 10 |

**Positionen nachjustieren:** `html/index.html?debug` im Browser öffnen → 5-%-Raster über jeder Bühne, alle Slots rot umrandet; ein Klick in die Bühne schreibt `left:…%; top:…%;` in die Konsole (F12). Werte in `index.html` (Grund-Apps) bzw. `html/js/apps.js` (Dokumente/Marke) eintragen.

**Schriften:** Überschriften `Crock` (vorp_lib) → `Rye` → Georgia; Fließtext `IM Fell English` → Georgia/Times; Formulare/Nummern `Special Elite` → Courier New. Google Fonts wird nicht blockierend geladen (offline greifen die lokalen Fallbacks). Optional offline: woff2-Dateien nach `html/fonts/` legen und die vorbereiteten `@font-face`-Zeilen in `css/base.css` einkommentieren (Dateien liegen nicht bei). Im Browser-Testmodus wird Crock nicht angefragt (sonst Konsolenfehler für `nui://`), dort erscheint Rye.

**Sicherheit:** Kein `innerHTML`/`insertAdjacentHTML` im gesamten `html/js` – alle Lua-Daten über `textContent`/`createElement`, Siegeltexte als SVG-Textknoten. Die Testdaten enthalten absichtlich `<img onerror>`/`<script>`-Namen zur Kontrolle.

## 5. Testmodus (Browser)

1. `html/index.html` direkt im Browser öffnen (Chrome/Edge; Doppelklick reicht). Ohne `GetParentResourceName` startet der Testmodus.
2. Oben links erscheint die **Testleiste** (Titel anklicken = einklappen):
   - **Apps:** Dienstbuch mit allen Rechten, als Deputy (Reiter ausgeblendet), direkt mit Akte (`focusCharId`), Behörde; Schalter; Brett mit/ohne Lizenz; Menü (Icons, Badge, deaktiviert, Beschreibung, XSS-Probe); Formular Bußgeld (Strafkatalog) und „alle Feldtypen“.
   - **Dokumente:** ticket, warrant, poster, license, permit, report, evidence.
   - **Marke:** je Behörde (sheriff, marshal, police, pinkerton, prison, court).
   - **HUD:** jail, cuffed, k9 (schaltet durch alle Zustände), escort, evidence, duty, robbery (+20 %).
   - **Nachrichten:** Toasts info/success/error/alert, „neuer Einsatz“ (Toast + `update {alertsChanged}` → Übersicht lädt neu), `close` wie von Lua.
3. Jeder Post erscheint in der Konsole als `[NUI → Lua] <endpoint> {body}`; `cb` wird mit ~160 ms Verzögerung aus `mock.js` beantwortet, der Zustand ändert sich im Speicher (bezahlen, freigeben, stornieren, Kasse …). `ledger:openForm` öffnet das passende Testformular und antwortet erst nach Absenden/Abbrechen – wie Lua.
4. `?debug` an die URL hängen für das Positions-Raster.
5. Im Spiel ist die Testleiste nicht vorhanden (`mock.js`/`mock_data.js` beenden sich sofort, wenn `GetParentResourceName` existiert).

## 6. Offene Punkte / Hinweise

1. **Nicht im Browser/Spiel ausgeführt:** In meiner Umgebung stand weder Browser noch Shell zur Verfügung. Der Code wurde zweimal gelesen und gegen Vertrag/Lua-Gegenseite geprüft, aber **nicht laufen gelassen**. Bitte einmal `html/index.html` im Browser öffnen (F12-Konsole beobachten) und jede Testleisten-Schaltfläche durchklicken; danach im Spiel `/dienstbuch`, Schalter, Brett, `/marke` prüfen.
2. **Poster-Dokumente:** Damit das Plakat „REWARD“ und „DEAD OR ALIVE“ zeigt, sollte Agent A bei `Law.UI.Document{ kind='poster' }` zusätzlich `reward` und `deadOrAlive` senden (Brett und Dienstbuch bauen es selbst korrekt).
3. **`readonly`-Felder:** Agent A kann `display = Name` mitsenden, sonst steht der Rohwert (z. B. charId) im Feld.
4. **Texte im Testmodus:** `mock_data.js` enthält eine Kopie der deutschen `ui_*`-Texte. Quelle der Wahrheit bleibt `locales/de_ui.lua`; bei Textänderungen im Spiel ist die Kopie egal.
5. **Menü-Icons:** Die Module senden bisher keine `icon`-Namen; unterstützte Namen siehe Abschnitt 3.
6. **Englisch:** `Config.General.Locale = 'en'` nutzt `en_ui.lua`; fehlende Schlüssel fallen auf Deutsch zurück (`Law.LocaleUi`).
7. **Leitstelle ohne Dienst:** `core:ledgerOverview` liefert Einsätze nur im Dienst; die NUI zeigt dann „Einsätze siehst du nur im Dienst.“
8. **Fokus bei vorp-Inventar:** Nach `jail:claimProperty` und `escort:claim` schließt die NUI den Schalter selbst (bzw. akzeptiert das `close` von Lua), damit das vorp-Inventar den Fokus bekommt.

## 7. Neustart

Nur `html/**` und neue Locale-Dateien (`locales/*_ui.lua`, werden über `locales/*.lua` im fxmanifest automatisch geladen) → **`restart ArA-LawSystem` reicht**, kein voller Server-Neustart nötig. Nach reinen HTML/CSS/JS-Änderungen ggf. den NUI-Cache mit einem Ressourcen-Neustart leeren.
