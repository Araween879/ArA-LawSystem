# ArA-LawSystem

Gesetzes-System für **RedM / VORP**: Sheriff, US Marshals, Saint Denis Police, Pinkerton, Sisika-Wärter
und Gericht – mit Dienst, Dienstbuch, Festnahme, Bußgeld, Knast, Haftbefehlen, Kopfgeld, Spuren,
Waffenregister, Bluthund und Eskorten.

---

## Installation (Kurzfassung)

1. Ordner `ArA-LawSystem` in `resources/` kopieren.
2. `sql/items.sql` in die Datenbank einspielen. Die Tabellen legt das Script beim ersten Start selbst an.
3. In der `server.cfg`:
   ```cfg
   #ensure vorp_police      # MUSS aus sein (gleiche Items/Befehle)
   ensure ArA-LawSystem     # nach vorp_core, vorp_inventory, oxmysql
   ```
4. Server **komplett** neu starten.

Ausführlich: [`docs/INSTALL.md`](docs/INSTALL.md)

**Voraussetzungen:** `vorp_core`, `vorp_inventory`, `oxmysql` (optional: `vorp_progressbar`)

---

## Ordner-Aufbau

```
ArA-LawSystem/
├── fxmanifest.lua
├── config/                  ← HIER wird alles eingestellt
│   ├── main.lua             Allgemein, Tasten, Befehle, Items, Behörden + Ränge + Rechte,
│   │                        Waffenkammer, Dienstwagen, Lohn, Kassen, Leitstelle
│   ├── stations/            EINE Datei pro Stadt (Police / Sheriff Station)
│   │   ├── _vorlage.lua     Vorlage mit Erklärung jedes Feldes – zum Kopieren
│   │   ├── annesburg.lua
│   │   ├── armadillo.lua
│   │   ├── blackwater.lua
│   │   ├── rhodes.lua
│   │   ├── saintdenis.lua
│   │   ├── sisika.lua       Sisika-Gefängnis (= Standard-Knast!)
│   │   ├── strawberry.lua
│   │   ├── tumbleweed.lua
│   │   └── valentine.lua
│   ├── justice.lua          Festnahme, Strafkatalog, Bußgeld, Knast, Haftbefehle, Kopfgeld, NPC-Einsätze
│   ├── investigation.lua    Spuren, Waffenregister, Geruch, Bluthund
│   ├── escort.lua           Personenschutz, Transporte, Werttransporte
│   └── server_only.lua      Discord-Webhooks (wird NIE an Spieler geschickt)
├── client/                  nur Client-Code   (core, justice, investigation, escort)
├── server/                  nur Server-Code   (core, justice, investigation, escort)
├── shared/                  Helfer für Client + Server
├── locales/                 Texte (de / en)
├── html/                    Oberfläche (Dienstbuch, Schalter, Steckbriefbrett …)
├── sql/                     Items für die Datenbank
└── docs/                    Entwickler-Doku
```

In `client/`, `server/`, `shared/`, `locales/` und `html/` musst du für die normale Einrichtung
**nichts** ändern.

---

## Eine Station einstellen

Jede Stadt hat ihre eigene Datei in `config/stations/`. Darin steht **alles**, was zu dieser
Station gehört:

| Feld | Bedeutung |
|---|---|
| `enabled` | `true` = Station an, `false` = komplett aus |
| `label` | Name der Station im Spiel |
| `depts` | Welche Behörden hier arbeiten dürfen (`nil` = alle, z. B. `{ 'sheriff' }`) |
| `jailTo` | Wohin hier eingebucht wird (`'sisika'` oder eigene Zellen) |
| `blip` | Kartensymbol (an/aus, Name, Symbol, Farbe, Position – ohne Angabe am Schalter bzw. Dienst-Punkt) |
| `points` | Alle Punkte der Station (siehe unten) |
| `cells` | Eigene Zellen in der Station (Standard: aus, alle kommen nach Sisika) |
| `shotsZone` | Gebiet für den Schüsse-Alarm der Stadt |

### Die Punkte

| Punkt | Wer | Was passiert dort |
|---|---|---|
| `duty` | Behörde | Dienst an/aus |
| `boss` | Chef | Einstellen, befördern, Kasse, Protokoll |
| `jail` | Behörde | Gefesselte Person einbuchen (Haftstrafe) |
| `storage` | Behörde | Dienstlager |
| `armory` | Behörde | Waffenkammer (Kasse der Behörde zahlt) |
| `evidence` | Behörde | Asservatenkammer + Labor |
| `kennel` | Behörde | Bluthund holen/abgeben (`heading` = Blickrichtung) |
| `counter` | **alle** | Schalter: Bußgeld, Kaution, Lizenzen, Kopfgeld, Waffen, Eskorte, Anzeige |
| `board` | **alle** | Steckbriefbrett: Kopfgelder und Aufträge |
| `dropoff` | **alle** | Abgabe-Zone für Gefangene (`radius` = Größe) |
| `garage` | Behörde | Dienstwagen (`spawn` = wo der Wagen erscheint) |
| `escort` | alle / Behörde | Eskort-Büro (`spawn` = Panzerwagen, `radius` = Lieferzone) |

- **Punkt nicht gewünscht?** → `enabled = false` in den Punkt schreiben (oder die Zeile löschen).
- **Mehrere Punkte vom gleichen Typ?** → als Liste: `duty = { { coords = ... }, { coords = ... } }`
- **Stadt nicht gewünscht?** → ganz oben `enabled = false`.

### Koordinaten holen

1. Im Spiel als Admin an die Stelle stellen.
2. `/lawcoords` eingeben → die Position steht in der **F8-Konsole** als `vector3(...)` und `vector4(...)`.
3. In die Stadt-Datei einfügen, speichern, in der Server-Konsole `restart ArA-LawSystem`.

`vector3(x, y, z)` ist eine Position, `vector4(x, y, z, richtung)` eine Position mit Blickrichtung
(für `spawn`, `release`).

Werte mit dem Kommentar **ANPASSEN** sind Startwerte und sollten einmal im Spiel geprüft werden.

### Neue Station anlegen (z. B. Van Horn)

1. `config/stations/_vorlage.lua` kopieren → `config/stations/vanhorn.lua`
2. In der Kopie `Config.Stations.vorlage` → `Config.Stations.vanhorn` ändern
   (Kleinbuchstaben, keine Leerzeichen, jeder Name nur einmal).
3. `enabled = true` setzen und die Punkte eintragen (nicht gebrauchte Punkte löschen).
4. Optional `shotsZone` (Schüsse-Alarm) und `cells` (eigene Zellen) ausfüllen und dort
   `enabled = true` setzen – in der Vorlage sind beide aus.
   Steht die Stadt schon in `config/main.lua` unter `ShotsFired.Zones` (z. B. Van Horn),
   gilt ab jetzt das Gebiet aus der Stadt-Datei – den alten Eintrag dort löschen.
5. `restart ArA-LawSystem`

In der Server-Konsole steht nach jedem Start `Stationen aktiv: …`. Tippfehler (falscher Punkt-Name,
fehlende Koordinaten, Platzhalter `0.0, 0.0, 0.0`, `jailTo` auf einen Knast, den es nicht gibt)
werden dort gelb gemeldet – der betroffene Punkt ist dann aus.

> Den Namen (Schlüssel) einer Station, die schon benutzt wurde, **nicht mehr ändern** –
> Eskort-Aufträge und Häftlinge in eigenen Zellen sind damit in der Datenbank gespeichert.
> Gleiches beim **Abschalten** einer benutzten Station (oder ihres `escort`-Punkts): offene
> Eskort-Aufträge und abholbereite Ware dort sind erst wieder erreichbar, wenn sie wieder an ist.

### Eigene Zellen statt Sisika

In der Stadt-Datei:
1. bei `cells` → `enabled = true`, `center`, `spawn` und `release` im Spiel prüfen
2. oben `jailTo = '<name der stadt>'` setzen (z. B. `jailTo = 'valentine'`)

Die Positionen der Zellentüren aus den Spieldaten stehen als Hilfe schon in jeder Stadt-Datei.

---

## Befehle

| Befehl | Wer | Zweck |
|---|---|---|
| `/dienstbuch` | Behörde | Dienstbuch (Akten, Haftbefehle, Kopfgelder, Einsätze, Behörde) |
| `F6` / `/lawmenu` | alle | Interaktionsmenü |
| `/marke` | Behörde | Marke zeigen |
| `/sheriff <Text>` | alle | Notruf |
| `/panik` | Behörde im Dienst | Panikknopf |
| `/einsatz <Nr>` | Behörde im Dienst | Einsatz annehmen |
| `/lawcoords` | Admin | eigene Position in F8 ausgeben |

Die Namen der Befehle lassen sich in `config/main.lua` → `Config.Commands` ändern.
