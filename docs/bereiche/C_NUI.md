# Bereich C – NUI (Dienstbuch · Schalter · Steckbriefbrett · Dokumente · Menüs · Formulare · HUDs)

> Vollständiger Arbeitsauftrag, auch als Prompt für einen anderen Chat nutzbar.
> Projektordner: `C:\Users\chris\Desktop\Working Station\ArA-LawSystem`

## Rolle
Du bist **Agent C**, Head of UI für RedM-NUIs im Western-Stil (HTML/CSS/Vanilla-JS, eigene SVG-Grafiken).
Team: Head Dev (Kern), Agent A (Justiz), Agent B (Ermittlung & Schutz). Du baust **nur** `html/**` und die UI-Texte.

## Ziel
Eine einzige, schnelle, schöne NUI im Stil 1899 (Pergament, Tinte, Siegel, Holz, Messing), die exakt das
Protokoll aus `docs/01_CONTRACT.md` Abschnitt 10 spricht, auf jeder Auflösung sauber skaliert und ohne
Spiel im Browser mit Testdaten vorgeführt werden kann.

## Pflichtlektüre
1. `docs/01_CONTRACT.md` – **Abschnitt 10 komplett** (Nachrichten, Endpoints, Apps, Datenformen, Formular-Feldtypen, HUDs). Abschnitt 6 (Rechte → Tabs).
2. `client/core/01_ui.lua` – so spricht Lua mit dir (Fokus-Regel, Stapel, `cb`/`action`-Endpoints).
3. `client/core/05_features.lua` – welche Apps der Kern öffnet und mit welchen Daten.
4. Dein Skill/Agent-Wissen zu PNG/SVG-Hintergründen mit prozentgenauer Platzierung (redm-nui-png).

## Deine Dateien (nur diese!)
```
html/index.html
html/css/*.css
html/js/*.js          (klassische <script>-Tags, KEINE ES-Module, KEIN Build-Schritt, KEINE externen JS-Bibliotheken)
html/img/*.svg        (eigene Grafiken: Pergament, Holzbrett, Siegel je Behörde, Stern/Schild-Marken, Poster-Rahmen)
locales/de_ui.lua  locales/en_ui.lua   (Law.LocaleAdd('de', { ui_... = '...' }) – ALLE sichtbaren NUI-Texte)
docs/C_REPORT.md
```

## Regeln (hart)
1. **Protokoll exakt** wie Vertrag 10: Nachrichten `init/open/update/close/hud/toast`; Endpoints `ready, close, cb, action, menuSelect, menuCancel, formSubmit, formCancel`. `fetch('https://' + GetParentResourceName() + '/<endpoint>', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify(body) })`.
2. **Stapel:** `menu`, `form`, `document` legen sich über `ledger`/`counter`/`board`. ESC schließt die oberste Ebene (menu → `menuCancel`, form → `formCancel`, sonst nur ausblenden). Wird der Stapel leer → `close` posten. Nach `menuSelect`/`formSubmit` die Ebene entfernen; wenn danach leer → zusätzlich `close`.
3. `open` mit `nofocus:true` (Marke) zählt NICHT zum Stapel, blendet nach `data.ms` aus.
4. **Nie** Daten als HTML einsetzen (`innerHTML` mit Spielertexten verboten) – immer `textContent`/`createElement`. Spieler können Namen/Notizen frei wählen → XSS/NUI-Injection.
5. Alle Texte über `t('ui_key')` aus `init.data.strings` (Fallback: Schlüssel selbst). Keine festen deutschen Texte im JS.
6. Zeiten kommen als Unix-Sekunden → `DD.MM.YYYY HH:mm`; Dauer → „1h 5m"; Geld → `currency + 12.50`.
7. Tabs im Dienstbuch nach `officer.perms` ein/aus (Vertrag 10.5 Spalte „Recht"; `all` = alles; `department` wenn irgendein `boss_*`).
8. Jede `cb`-Antwort ist `Result { ok, err?, msg?, data? }` → bei `ok=false` `msg` als Hinweis zeigen. Nach Mutationen (`approve`, `pay`, `fire` …) die Liste neu laden.
9. Gefährliche Aktionen (entlassen, widerrufen, vernichten, stornieren, Kaution zahlen, Kopfgeld setzen) mit eigenem Bestätigungsdialog in der NUI.
10. Skalierung: Referenz 1920×1080, Größen in `vh`/`clamp()`; auf 1280×720 und 2560×1440 ohne Überlappung.
11. Schriften: `@font-face` „Crock" von `nui://vorp_lib/web/fonts/crock.ttf` (vorhanden) für Überschriften; Google Fonts `Rye`, `IM Fell English`, `Special Elite` mit lokalen `serif`/`monospace`-Fallbacks (Offline darf nichts brechen).
12. Performance: kein Dauer-`requestAnimationFrame`, HUD-Updates nur bei `hud`-Nachricht, keine riesigen Bilder (SVG).
13. **Entwicklermodus:** Läuft die Seite außerhalb von RedM (`typeof GetParentResourceName === 'undefined'`), zeigt sie eine kleine Testleiste, mit der jede App/HUD mit Testdaten (`html/js/mock.js`) geöffnet werden kann, und `fetch` wird auf Testantworten für **jeden** Callback-Namen aus Vertrag 10.5 umgeleitet. Im Spiel ist die Leiste unsichtbar.

## Aufgaben (TODO)

### C1 – Gerüst
- `index.html` (lädt CSS/JS, Container je App + HUD-Ebene + Toast-Ebene), `js/core.js` (Nachrichten-Router, Stapel, `post()`, `t()`, Formatierer, ESC, Bestätigungsdialog), `js/mock.js` (Testdaten + Testleiste).
- `ready` beim Laden posten.

### C2 – Generische Apps
- **menu**: Liste mit `label/desc/icon/disabled/badge`, Tastatur (↑/↓/Enter) + Maus.
- **form**: alle Feldtypen aus Vertrag 10.3 (`text, textarea, number, money, select, multiselect, checkbox, readonly, penalcode`). `penalcode`: Suchfeld + Kategorien, je Delikt Anzahl (+/−, max 5), Live-Summe Bußgeld/Haftzeit, Wert = `[{ id, count }]`. Pflichtfelder/`min`/`max`/`maxLength` prüfen, bevor `formSubmit`.
- **document**: Vorlagen je `kind` (`ticket` Bußgeldbescheid, `warrant` Haftbefehl, `poster` WANTED-Plakat „DEAD OR ALIVE / REWARD", `license`, `permit`, `report`, `evidence`), Siegel nach `seal` (Behörden-Key), Unterschrift.
- **badge**: Marke je `seal` (Sheriff-Stern, Marshal-Stern im Kreis, Police-Schild, Pinkerton-Auge, Gefängnis, Gericht-Waage), Name, Rang, Dienstnummer – ohne Fokus, blendet aus.

### C3 – Dienstbuch `ledger`
Aufgeschlagenes Buch mit Register-Reitern. Tabs und Callbacks exakt nach Vertrag 10.5:
`overview` (Dienstliste, Einsätze mit „Annehmen" → `dispatch:accept` → `action setWaypoint` mit `data.coords`, „Abschließen" → `dispatch:close`, Kennzahlen; reagiert auf `update {alertsChanged}`),
`people` (Suche → Trefferliste mit Flags → Akte `File` mit Abschnitten; Buttons `openForm fine/warrant/bounty_official/note` mit `charId`, `records:setDangerous`), `warrants`, `bounties`, `fines`, `jail` (+ Kaution setzen/Zeit ändern/Freilassen per eigenem kleinen Dialog), `evidence`, `weapons` (Seriennummer-Suche), `escorts`, `department` (Mitglieder mit Rang ändern/Entlassen, Kasse ein-/auszahlen, Kassenbuch, „Einstellen" → `action openForm {form:'hire'}`). `focusCharId` im open → direkt Akte öffnen.

### C4 – Schalter `counter`
Behördentresen mit Reitern aus `data.tabs`: Bußgelder (bezahlen), Kaution (Liste, bezahlen), Kopfgeldjäger-Lizenz (Status, kaufen/verlängern), Kopfgeld aussetzen (Name suchen → Betrag/Grund/tot-oder-lebendig → `bounty:placePrivate`; eigene Aufträge + stornieren), Waffen (eigene Waffen registrieren, als gestohlen melden), Eskorte (Typ/Ziel/Dauer/Begleiter/Versicherung/Ware/Geld/Gold → `escort:quote` live → `escort:book`; eigene Aufträge, stornieren, abholen), Habseligkeiten (`jail:propertyStatus` / `jail:claimProperty`), Anzeige erstatten (`dispatch:report`).

### C5 – Steckbriefbrett `board`
Holzbrett mit angepinnten WANTED-Postern (`posters`, Klick → Dokument `poster`), Kopfgeldliste, NPC-Aufträge (nur `canHunt` → „Annehmen" `npc:accept`).

### C6 – HUDs & Toasts
`jail` (Restzeit groß, Arbeit x/y), `cuffed`, `k9` (Zustand + Duftstärke-Anzeige), `escort` (Ziel, Restzeit, Begleiter x/y), `evidence` (Modus aktiv + Anzahl), `duty` (kleines Abzeichen), `robbery` (Fortschritt). Toasts oben rechts, `alert` rot/pulsierend, stapelbar, Auto-Ausblendung nach `ms`.

### C7 – Texte & Bericht
- `locales/de_ui.lua` und `locales/en_ui.lua` mit **allen** `ui_*`-Schlüsseln, die das JS benutzt (deutsch mit echten Umlauten erlaubt).
- `docs/C_REPORT.md`: Liste der benutzten `cb`-Namen und `action`-Namen, Stapelverhalten, Testmodus-Anleitung, offene Punkte.

## Abnahme (Definition of Done)
- Im Browser (Testmodus) lässt sich jede App und jedes HUD mit Testdaten öffnen, bedienen und schließen, ohne JS-Fehler in der Konsole.
- Jeder `cb`-Name im JS existiert im Vertrag (Abschnitt 10.5) – keine erfundenen Namen.
- Kein `innerHTML` mit Daten aus Lua.
- Alle sichtbaren Texte aus `ui_*`-Schlüsseln.
