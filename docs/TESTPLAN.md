# ArA-LawSystem – Testplan (im Spiel)

Benötigt: 2 Spieler (A = Sheriff, B = Bürger), Admin-Rechte für A. F8-Konsole (Client) und
Server-Konsole während aller Tests offen lassen – jede rote Zeile notieren.
Vorher: `docs/INSTALL.md` Schritte 1–5 erledigt, `vorp_police` aus.

Beim Start muss in der Server-Konsole stehen: `[ArA-Law] gestartet - N Module` und **keine**
Meldung „Items fehlen in der Tabelle items“.

## 0. Koordinaten (einmalig)
- [ ] An jeder Station mit `/lawcoords` prüfen: Dienstpult, Lager, Eingang, Wagen-Spawn. Falsche Werte in `config/stations/<stadt>.lua` (Block `points`, Wagen-Spawn = `points.garage.spawn`) korrigieren → `restart ArA-LawSystem`.
- [ ] Sisika: Zentrum, Radius, Spawn, Arbeitspunkte (`config/stations/sisika.lua`, Block `cells`).
- [ ] Server-Konsole: `Stationen aktiv (9): …` und **keine** gelben „Stationen: …“-Hinweise.

## 1. Kern
| # | Schritt | Erwartet |
|---|---|---|
| 1.1 | Admin setzt A: Job `sheriff`, Rang 4 (vorp_admin) | Kein Fehler, Station-Blips sichtbar |
| 1.2 | A am Dienstpult: Prompt „Dienst beginnen“ | Meldung „Dienst begonnen“, Dienst-Abzeichen im HUD |
| 1.3 | A: Waffenkammer → Revolver, Handschellen, Marke, Beweisbeutel, Hundepfeife | Kasse sinkt, Waffe hat Seriennummer `SO-…` |
| 1.4 | A: `/marke` neben B | B sieht die Marke (Stern, Name, Dienstnummer) |
| 1.5 | A: `/dienstbuch` → alle Reiter durchklicken | Keine leeren Seiten, keine F8-Fehler |
| 1.6 | A: Behörde → Einstellen → B wählen, Rang 0 | **B bekommt Rückfrage**, nach „Annehmen“ ist B Anwärter |
| 1.7 | A: Rang von B ändern, dann entlassen | Rang-Anzeige bei B aktuell, danach arbeitslos |
| 1.8 | A: Kasse einzahlen / auszahlen | Kassenbuch zeigt beide Buchungen |
| 1.8b | Jeder: `/editlawinterface` → Anzeigen ziehen, Mausrad, Speichern; `restart ArA-LawSystem` | Alle 9 Rahmen sichtbar; nach Neustart stehen Job-Abzeichen/Hinweise an der gespeicherten Stelle; Esc verwirft |
| 1.9 | A: Dienstwagen ausparken, einparken | Menü zeigt Kategorien (Gefangene, Personen, Streife …), gesperrte Wagen mit „Ab Rang: …“; Wagen steht am Spawn, verschwindet beim Einparken |
| 1.10 | B: `/sheriff Hilfe` | A: Toast + Blip, `/einsatz <Nr>` setzt Route |
| 1.11 | A: `/panik` | Alarm an alle im Dienst |
| 1.12 | B schießt in Valentine in die Luft | Nach 5–15 s Einsatz „Schüsse gemeldet“ bei A |

## 2. Festnahme & Bußgeld
| # | Schritt | Erwartet |
|---|---|---|
| 2.1 | A benutzt Handschellen neben B | B gefesselt (Hände hinten, keine Waffen, kein Inventar, kein Sprinten) |
| 2.2 | A: F6 → Abführen, 50 m laufen | B folgt; entfernt B sich > 10 m (z. B. per Teleport) → Meldung „Gefangener entkommen“ |
| 2.3 | A: F6 → Durchsuchen | vorp-Inventar von B öffnet sich |
| 2.4 | A: F6 → In Dienstwagen setzen / herausholen | B sitzt im Gefangenenwagen / steigt aus |
| 2.5 | A: F6 → Bußgeld → 2× Diebstahl | B erhält Bescheid-Item, Summe stimmt mit Katalog |
| 2.6 | A: F6 → Bußgeld kassieren | B bekommt Rückfrage; nach Zustimmung Geld weg, Kasse +, Provision an A |
| 2.7 | B am Schalter → Bußgelder → bezahlen | Status „bezahlt“ |
| 2.8 | Dritter mit Dietrich knackt die Handschellen von B | Fortschritt, bei Erfolg B frei + Meldung an A |
| 2.9 | B loggt gefesselt aus und wieder ein | B landet im Knast (Combat-Log-Strafe) |

## 3. Knast
| # | Schritt | Erwartet |
|---|---|---|
| 3.1 | A bringt gefesselten B zum `jail`-Punkt, Formular Haft | B nach Sisika, HUD Haftzeit, Waffen/verbotene Items weg |
| 3.2 | B arbeitet an einem Arbeitspunkt | Haftzeit sinkt, Obergrenze greift |
| 3.3 | B schwimmt von der Insel | Fluchtalarm, Haftbefehl + Kopfgeld, Steckbrief am Brett |
| 3.4 | B stirbt im Knast und respawnt | zurück im Knast, **kein** Fluchtalarm |
| 3.5 | A setzt Kaution; Dritter zahlt am Schalter | B frei, Geld in der Kasse |
| 3.6 | B holt am Schalter „Habseligkeiten“ ab | Waffen mit **gleicher Seriennummer** zurück |

## 4. Akten, Haftbefehle, Kopfgeld
| # | Schritt | Erwartet |
|---|---|---|
| 4.1 | A: Dienstbuch → Personen → B suchen → Akte | Einträge, Bußgelder, Waffen, Blutgruppe (nach Haft) |
| 4.2 | A: Haftbefehl mit Kopfgeld auf B | Steckbrief am Brett |
| 4.3 | A versucht Haftbefehl/Kopfgeld/Bußgeld auf **sich selbst oder eigenen Zweitchar** | abgelehnt |
| 4.4 | C kauft Kopfgeldjäger-Lizenz am Schalter | Lizenz-Item, Status aktiv |
| 4.5 | C fesselt B (aktives Kopfgeld), bringt ihn zur Abgabezone, Prompt „Kopfgeld einfordern“ | C bekommt Geld, B im Knast |
| 4.6 | Ein **anderer** Jäger versucht, das von C gefesselte Ziel einzulösen | abgelehnt („nicht dein Gefangener“) |
| 4.7 | B setzt privates Kopfgeld auf C am Schalter | Status „wartet auf Freigabe“, A gibt frei |
| 4.8 | C nimmt am Brett einen NPC-Auftrag an, bringt Ziel zur Abgabe | Belohnung, NPC verschwindet |
| 4.9 | A im Dienst (Recht npc_calls) wartet 20–40 Min. | NPC-Streifeneinsatz erscheint, annehmen, erledigen, Belohnung |

## 5. Spuren, Waffenregister
| # | Schritt | Erwartet |
|---|---|---|
| 5.1 | B schießt 3× an einer Stelle | — |
| 5.2 | A: F6 → Spurensuche an derselben Stelle | Marker für Hülsen; B sieht **keine** Marker |
| 5.3 | A sichert eine Hülse (Beweisbeutel nötig) | Item „Patronenhülse“ mit Beschreibung |
| 5.4 | A am Labor: auswerten | Nach 60 s Bericht mit Waffe + Seriennummer + ggf. Besitzer |
| 5.5 | B am Schalter: Waffe registrieren | Waffenschein-Item, Register-Eintrag |
| 5.6 | Dritter hält B's registrierte Waffe und will sie registrieren | abgelehnt, Hinweis an Gesetz |
| 5.7 | B feilt mit Waffenfeile die Seriennummer ab | Seriennummer „ABGEFEILT“ |
| 5.8 | A: Schmauchspurentest an B direkt nach Schuss | positiv; nach 15 Min. negativ |
| 5.9 | B verkauft registrierte Waffe am Schalter an C („Verkaufen / umschreiben“) | C bekommt Rückfrage; nach Annahme Waffe + neuer Waffenschein bei C, Register zeigt C, alter Schein von B „UNGÜLTIG“ |

## 6. Bluthund
| # | Schritt | Erwartet |
|---|---|---|
| 6.1 | A (Recht k9): Hundepfeife | Bluthund erscheint und folgt |
| 6.2 | A nimmt Geruchsprobe von gefesseltem B (oder nutzt Blut/Stoff-Beweis von B) | Item Geruchstuch |
| 6.3 | B läuft 300 m weg und versteckt sich; A: Hund → „Witterung aufnehmen“ | Hund läuft los und folgt **B's Weg**, HUD „frisch“ |
| 6.4 | A bleibt > 60 m zurück | Hund wartet |
| 6.5 | Hund erreicht B | „Gefunden“, Hund bellt bei B |
| 6.6 | Probe von einer Person, die seit > 30 Min. nicht in 200 m war | „Keine Witterung“, Abklingzeit |

## 7. Eskorten
| # | Schritt | Erwartet |
|---|---|---|
| 7.1 | B bucht am Schalter Werttransport Valentine → Rhodes mit Goldbarren + Versicherung | Preis wie Voranschlag, Ware weg, Einsatz bei A |
| 7.2 | A (escort_lead) nimmt an, startet am Eskort-Büro | Panzerwagen spawnt, HUD Eskorte |
| 7.3 | A fährt nach Rhodes, liefert ab | A bekommt Lohn, B wird benachrichtigt |
| 7.4 | B holt am Zielbüro ab | Fach öffnet sich mit der Ware |
| 7.5 | Neuer Transport; Dritter (nicht beteiligt) knackt die Kiste mit Brecheisen | Alarm sofort, nach 60 s Beute-Fach für den Räuber |
| 7.6 | A (Marshal mit boss_funds): Dienstbuch → Eskorten → Versicherungsfälle | Fall „in Prüfung“, Auszahlen/Ablehnen funktioniert |
| 7.7 | B bucht Personenschutz 30 Min. | Begleiter bekommen Lohn nach Anwesenheit |

## 7b. Nur im Spiel prüfbar (vom Review markiert – bitte gezielt testen)
| # | Schritt | Erwartet | Wenn nicht |
|---|---|---|---|
| 7b.1 | B stirbt, C (Jäger) will ein „tot oder lebendig“-Kopfgeld auf B einlösen | Einlösung klappt | `Config.General.ValidateDeath = false` setzen (Server erkennt tote Peds dann nicht) |
| 7b.2 | A führt gefesselten B 30 m weit ab | **kein** „Gefangener entkommen“-Alarm | Meldung an Head Dev (OneSync-Position angehängter Peds) |
| 7b.3 | B verlässt Sisika nach Tod/Respawn | B landet wieder im Knast | Client-Rückteleport greift, Server-SetEntityCoords prüfen |
| 7b.4 | Gefesselter B nutzt normalen vorp-Respawn nach echtem Tod | Fesseln gelöst (Krankenhaus) | – |

## 8. Robustheit
| # | Schritt | Erwartet |
|---|---|---|
| 8.1 | `restart ArA-LawSystem` während B im Knast und ein Transport läuft | B bleibt im Knast; Transport zurück auf „angenommen“, Wagen neu spawnbar |
| 8.2 | ESC in jedem Fenster | Maus/Tastatur immer wieder frei (kein hängender Fokus) |
| 8.3 | Server-Konsole nach allen Tests | keine roten Fehler von ArA-LawSystem |
