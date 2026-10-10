# ArA-LawSystem – Installation

## Voraussetzungen
- vorp_core 3.3+, vorp_inventory (mit Seriennummern), oxmysql, OneSync (bei VORP Standard)
- optional: vorp_progressbar (Fortschrittsbalken), vorp_lib (Schrift „Crock" in der NUI)
- **`sv_entityLockdown` NICHT auf `strict`** (Standard ist aus): Dienstwagen, Panzerwagen, Bluthund und
  NPCs werden – wie bei VORP üblich – vom Client gespawnt und vom Server über ihre NetId geprüft.
  Deine aktuelle `server.cfg` setzt keinen Lockdown → passt.

## Schritte
1. Ordner `ArA-LawSystem` nach `resources/[tests]/` (oder einen eigenen Ordner) auf den Server kopieren.
2. **`sql/items.sql`** in die Datenbank einspielen (HeidiSQL / phpMyAdmin).
   Tabellen legt das Script beim ersten Start selbst an (`server/core/01_db.lua`).
3. **`server.cfg`**:
   ```cfg
   #ensure vorp_police          # PFLICHT: auskommentieren (gleiche Items/Befehle)
   ensure ArA-LawSystem         # NACH vorp_core, vorp_inventory, oxmysql
   ```
   Liegt der Ordner in `[tests]`, reicht das vorhandene `ensure [tests]` – dann trotzdem `vorp_police` deaktivieren.
4. Webhooks (optional) in `config/server_only.lua` eintragen.
5. **Kompletter Server-Neustart** (neue Items werden nur beim Start von vorp_inventory gelesen).
6. Im Spiel als Admin `/lawcoords` an jeder Station benutzen und die mit `ANPASSEN` markierten
   Koordinaten prüfen. Jede Stadt hat ihre eigene Datei in `config/stations/<stadt>.lua`
   (alle Punkte, Blip, Zellen, Schüsse-Alarm). Neue Station: `config/stations/_vorlage.lua` kopieren.
   Nach dem Start stehen in der Server-Konsole die aktiven Stationen und ggf. Hinweise auf Tippfehler.

## Neustart-Umfang
| Änderung | Neustart |
|---|---|
| Lua-Code, Config, Locales, NUI | `restart ArA-LawSystem` |
| `sql/items.sql` / neue Items | voller Server-Neustart |
| neue DB-Spalte im Kern-Schema | `restart ArA-LawSystem` (Spalte wird automatisch ergänzt) |
| `server.cfg` | voller Server-Neustart |

## Erste Einrichtung im Spiel
1. Admin setzt den ersten Sheriff per vorp_admin (Job `sheriff`, Rang `4`).
2. Sheriff stempelt am Dienstpult ein (Prompt „Dienst beginnen"), holt Marke und Handschellen in der Waffenkammer.
3. Weitere Mitglieder per Dienstbuch (`/dienstbuch` → Behörde → Einstellen, Person muss daneben stehen).
4. Kassen starten mit `Config.Society.StartBalance` (einmalig).

## Befehle
| Befehl | Wer | Zweck |
|---|---|---|
| `/dienstbuch` | Behörde | Dienstbuch (Akten, Haftbefehle, Kopfgelder, Einsätze, Behörde) |
| `F6` / `/lawmenu` | alle | Interaktionsmenü (Person in der Nähe / eigene Aktionen) |
| `/marke` | Behörde | Marke zeigen (Item nötig) |
| `/sheriff <Text>` | alle | Notruf an die Leitstelle |
| `/panik` | Behörde im Dienst | Panikknopf |
| `/einsatz <Nr>` | Behörde im Dienst | Einsatz annehmen + Route |
| `F12` / `/hund` | Hundeführer im Dienst | Bluthund-Menü (Taste in `config/main.lua` → `Config.Keys.K9Menu`) |
| `/lawcoords` | Admin | Position als vector3/vector4 in F8 |
| `/editlawinterface` | alle | eigene Anzeigen (Job, Hinweise, Haft …) verschieben/vergrößern, pro Spieler gespeichert |
