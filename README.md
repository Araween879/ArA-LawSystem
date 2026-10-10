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
| `jobs` | Welche Jobs an der ganzen Station arbeiten dürfen (`nil` = alle Behörden, z. B. `{ 'sheriff' }`) |
| `jailTo` | Gefängnis beim Einbuchen am Pult (`'sisika'` = Transport) |
| `blip` | Kartensymbol (an/aus, Name, Symbol, Farbe, Position – ohne Angabe am Schalter bzw. Dienst-Punkt) |
| `points` | Alle Punkte der Station (siehe unten) |
| `cells` | Zellen mit Türen: aufschließen, Häftling geht rein, abschließen, an der Tür einbuchen |
| `doors` | Weitere abschließbare Türen (z. B. Zellentrakt) |
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
- **Höhe:** Ein Punkt darf bis zu 2,5 m über/unter dem Spieler liegen (z. B. auf Tisch-, Schrank- oder
  Schildhöhe). Der Abstand zählt waagerecht. Einstellbar in `config/main.lua` → `Config.Points`.
- **Mehrere Punkte vom gleichen Typ?** → als Liste: `duty = { { coords = ... }, { coords = ... } }`
- **Nur bestimmte Jobs an einem Punkt?** → `jobs` in den Punkt schreiben:
  `armory = { coords = vector3(...), jobs = { 'sheriff', 'marshal' } }`.
  Dann sehen und benutzen **nur** diese Jobs den Punkt – auch bei Bürger-Punkten wie dem Schalter.
  `jobs` gibt keine Rechte: der Rang braucht trotzdem das passende Recht (`config/main.lua`).
  Jobs: `sheriff`, `marshal`, `police`, `pinkerton`, `prisonguard`, `judge`.
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

### Zellen mit Türen (realistisch)

Jede Stadt-Datei hat einen Block `cells` mit den echten Zellentüren der Station (Tür-Hash und
Position aus den Spieldaten sind schon eingetragen). So läuft eine Festnahme:

1. **Zellentür aufschließen**: Prompt an der Tür (Recht `jail`, im Dienst)
2. Der Gefesselte **geht selbst in die Zelle** – es wird **nicht** hineinteleportiert
3. **Tür abschließen**
4. An der Tür **„Häftling einbuchen“**: Strafkatalog, Zusatzminuten, Kaution, Notiz.
   Geht nur, wenn die Tür abgeschlossen ist und die Person wirklich in der Zelle steht.
5. **Haft vorbei** → der Häftling wird nach `release` (draußen) teleportiert, die Tür bleibt zu.

- **Ausbruch:** Wer mit einem Dietrich das Schloss knackt, öffnet die Tür (Alarm an die Leitstelle,
  Spur für den Bluthund). Verlässt der Häftling die Zelle, gilt das als **Flucht** (Haftbefehl, Kopfgeld).
- **Aufschließen einer belegten Zelle** fragt vorher nach.
- **Plätze:** `capacity` je Zelle (Valentine: 3). Ist die Zelle voll, lehnt das Einbuchen ab.
- **Hinter dem Gitter:** Eingebucht wird nur, wer wirklich in der Zelle steht – der Gang vor dem
  Gitter zählt nie, auch wenn `radius` hineinreicht (das Script kennt die Gitterseite über die Tür).
- **Eine Taste, ein Menü:** Liegen an einer Stelle mehrere Aktionen (z. B. Zellentür: Aufschließen +
  Einbuchen, oder Garage + Eskorte), gibt es einen Prompt; Halten öffnet ein Auswahlmenü.
- Zellen in `cells.list` **nicht löschen oder umsortieren**, solange Häftlinge sitzen
  (gespeichert wird die Nummer in der Liste) – zum Abschalten `enabled = false` setzen.
- **Tür zu = kein Ausbruch:** Steht ein Häftling bei abgeschlossener Tür knapp außerhalb der Zelle
  (Glitch, Radius zu klein), wird er zurück in die Zelle gesetzt – Flucht gibt es nur durch eine offene Tür.
- **Kopfgeld-Abgabe:** Gibt ein **Kopfgeldjäger** (oder Gesetz außer Dienst) an der Abgabestelle
  einer Station mit Zellen jemanden ab, wird der Gefangene **in eine freie Zelle teleportiert** und die
  Tür abgeschlossen. **Gesetz im Dienst** löst an der Abgabestelle nichts ein, sondern sperrt den
  Gefangenen **selbst** ein (Tür auf, rein, zu, an der Tür einbuchen) – das Kopfgeld wird beim
  Einbuchen erledigt (Treuhandgeld zurück in die Kasse). Sind alle Zellen voll → Sisika.
- **Einrichten:** In jeder Zelle in die Mitte stellen, `/lawcoords`, Wert bei `center` eintragen.
  Als Admin zeigt **`/lawcells`** alle Türen (grün = zu, rot = offen) und Zellen (blau) im Spiel;
  neben einer Tür erscheint ihr Name.
- Ohne `center` ist die Zelle **aus** (Warnung in der Konsole) – erst messen, dann eintragen.
- Wer bei einer Freilassung offline war und in einer abgeschlossenen Zelle wieder einloggt, wird nach `release` gesetzt.
- Diese Türen **nicht zusätzlich in `vorp_doorlocks`** eintragen. Stehen sie dort, warnt das Script beim Start.
- Einstellungen für alle Zellen (Dietrich, Reichweite, Türen nach Neustart zu): `config/justice.lua` → `Config.Jail.Cells`.
- **Sisika** bleibt ein Gefängnis mit Transport (Teleport) – Einbuchen dafür am Pult (`jail`-Punkt).

---

## Spuren am Körper: Blut & Kleidung

Wer getroffen wird, hinterlässt an **seiner** Stelle Spuren (sichtbar nur für Gesetz im
Spurensuche-Modus, F6 → Spurensuche):

| Situation | Spur | Einstellung |
|---|---|---|
| Schlägerei (Fäuste, Laterne, Fackel …) | Blut **kann** fallen (35 % je Treffer) | `Wounds.Fist` |
| Angeschossen (Revolver, Gewehr, Schrot, Bogen) | Blut | `Wounds.Shot` |
| Messer, Axt, Machete, Tomahawk … | Blut **und** Kleidungsfetzen | `Wounds.Sharp`, Liste `SharpWeapons` |
| Tierbiss | Blut | `Wounds.Animal` |
| Sturz, Feuer, Explosion | nichts | `Wounds.Other` |

- **Blut** nimmt man mit einem **sterilen Tuch** auf (`law_sterilecloth`, in der Waffenkammer).
  Die Blutprobe taugt **60 Minuten ab der Tat** als Geruchsträger für den Bluthund –
  der Hund findet den Spieler, wenn er an dessen Fährte angesetzt wird (bis 200 m von der Fährte).
- **Kleidungsfetzen** sichert man mit einem Beweismittelbeutel. Damit findet der Hund den
  Spieler **immer wieder** (keine Zeitgrenze, beliebig oft) – **bis der Spieler im Knast saß**.
- **Knast = Geruch weg:** Beim Einbuchen werden alle älteren Geruchsträger (Kleidung, Blut,
  Hülsen, Geruchsproben) für den Hund wertlos, die Fährte im Speicher verfliegt. Im Hunde-Menü
  steht dann „verflogen“. Das Labor (Blutgruppe/Akte) funktioniert weiter.
- Der Hund folgt immer der echten Fährte (die letzten 60 Minuten Weg des Spielers) –
  er ist kein GPS: Ist der Spieler nie in der Nähe gewesen, nimmt er keine Witterung auf.
- Alles einstellbar in `config/investigation.lua` (`Config.Evidence.Wounds`, `CollectWith`,
  `Config.Scent.ItemMinutes`, `Uses`, `ResetOnJail`, `MaxAge`).

---

## Dienstwagen-Menü

Am Garagen-Punkt (`garage`) jeder Station öffnet sich ein Menü:
**1. Kategorie** (Gefangenentransport, Personentransport, Streife, Material & Versorgung, Sonderfahrzeuge)
→ **2. Wagen**. Wagen, für die der Rang noch nicht reicht, stehen ausgegraut mit „Ab Rang: …“ da.

Eingestellt wird in `config/main.lua` → `Config.Garage`:

| Feld | Bedeutung |
|---|---|
| `Categories` | Kategorien im Menü (Name, Symbol, Beschreibung, Reihenfolge) |
| `Vehicles` | Alle Wagen: `category`, `model`, `label`, `desc` |
| `minGrade` | Ab welchem Rang: `0` = alle, oder je Job `{ sheriff = 2, police = 1 }` |
| `jobs` | Nur für bestimmte Jobs: `{ 'police' }` (leer = alle Behörden mit Garagen-Recht) |
| `stations` | Nur an bestimmten Stationen: `{ 'saintdenis' }` (leer = überall) |

Eine Liste gültiger Wagen-Modelle steht direkt unter `Vehicles` in der Config.

---

## Oberfläche anpassen (`/editlawinterface`)

Jeder Spieler kann seine Anzeigen selbst anordnen. `/editlawinterface` blendet **alle** Anzeigen mit
Beispieldaten ein: Dienst-Abzeichen (Job), Benachrichtigungen, Haftzeit, Handschellen, Überfall,
Bluthund, Eskorte, Spurensuche und Marke.

- **Ziehen** = verschieben · **Mausrad** = Größe · **Doppelklick** = zurück auf Standard
- **Pfeiltasten** = fein verschieben (Shift = 10 px) · **+ / −** = Größe · **Entf** = zurücksetzen
- **Speichern** übernimmt, **Esc / Abbrechen** verwirft, **Alles zurücksetzen** = Standard-Layout

Gespeichert wird **pro Spieler auf dem eigenen PC** (RedM-KVP), ohne Datenbank, und es bleibt nach
Neustarts erhalten. Positionen werden in Prozent gespeichert und passen deshalb auch bei anderer Auflösung.

Damit auch die Benachrichtigungen verschiebbar sind, laufen sie über die eigene Anzeige
(`config/main.lua` → `Config.General.NotifyStyle = 'nui'`). Mit `'vorp'` kommen wieder die
vorp-Meldungen an fester Position.

---

## Befehle

| Befehl | Wer | Zweck |
|---|---|---|
| `/dienstbuch` | Behörde | Dienstbuch (Akten, Haftbefehle, Kopfgelder, Einsätze, Behörde) |
| `F6` / `/lawmenu` | alle | Interaktionsmenü |
| `F12` / `/hund` | Hundeführer im Dienst | Bluthund-Menü: Bei Fuß, Bleib, Umgebung absuchen, Witterung aufnehmen, Verfolgung abbrechen, Nach Hause |
| `/marke` | Behörde | Marke zeigen |
| `/sheriff <Text>` | alle | Notruf |
| `/panik` | Behörde im Dienst | Panikknopf |
| `/einsatz <Nr>` | Behörde im Dienst | Einsatz annehmen |
| `/lawcoords` | Admin | eigene Position in F8 ausgeben |
| `/lawcells` | Admin | Zellentüren und Zellen im Spiel anzeigen (zum Einrichten) |
| `/editlawinterface` | alle | eigene Anzeigen verschieben und vergrößern (siehe unten) |

Die Namen der Befehle lassen sich in `config/main.lua` → `Config.Commands` ändern.
