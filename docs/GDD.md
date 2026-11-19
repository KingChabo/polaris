# POLARIS — Game Design Document

Stand: 2026-11-11 · Engine: Godot 4.7.2 (GDScript, Forward+, Jolt Physics)

Alle Grafiken und Töne entstehen im Code (prozedurale Meshes, Shader, Rausch-Texturen, Synth-Audio). Es gibt keine heruntergeladenen Assets und keine Szenen-Dateien außer `main.tscn`.

---

## 1. Kurzbeschreibung

Realistisches First-Person-Open-World-Abenteuer in einem arktischen Tal, der **Senke**. Die Sonne bleibt den ganzen Winter hinter den Bergen; es herrscht dauerhafte Dämmerung mit Polarlicht. Ein Weihnachtsdorf ist von der Außenwelt abgeschnitten, seit die Armee den einzigen Tunnel gesprengt hat.

Säulen des Spiels:

- **Überleben:** Kälte, Nässe, Ausdauer, Verletzungen, Gewicht.
- **Kampf:** realistische Schusswaffen mit Ballistik und Nahkampf mit Schwert, Axt, Eispickel und Messer.
- **Fahrzeuge:** Schneemobil, Pickup, Geländewagen, Kettenfahrzeug; dünnes Eis bricht.
- **Erkunden:** 11 Orte, 15 Dokumente, versteckte Räume, Kletterrouten, verschlossene Wege.
- **Menschen:** 5 Fraktionen, 7 Händler, Handwerk, 12 Nebenaufträge mit Entscheidungen, Endlos-Aushänge.
- **Story:** 10 Kapitel (Teil 1: Senke, Teil 2: Vorland), 5 Bosse, 3 Enden; Horror-Modus mit eigenen 10 Kapiteln (H1–H10).
- **Zwei Modi:** **Story** (das normale Spiel) und **Horror** (dasselbe Tal im Nebel, mit Jägern im Dunkeln, versteckten Menschen und Rätseln). Beide Modi haben getrennte Spielstände.

## 2. Die Geschichte

**Ausgangslage:** Du bist mit deiner Schwester **Mirja** im Dezember mit dem Bus zum Weihnachtsmarkt nach Polaris gefahren. Auf der Rückfahrt hielten Soldaten den Bus am Tunnel an, dann stürzte die Decke hinter ihm ein. Die 31 Fahrgäste liefen zurück ins Dorf. In der ersten Nacht ging Mirja mit ihrem roten Schal zum See und kam nicht zurück.

**Hintergrund (aus den Dokumenten):** Die Forschungsstation **Polaris-7** hat über das Bergwerk Nordstern **Kern 31** aus 240 m Tiefe geholt: „Eis, das kein Eis ist“. Es wuchs im Tank C, brach aus und ging zum See zurück. Daraus wurde **das Weiße**, die Eisbestie. Gleichzeitig begann die Abbaumaschine **K-9** im Bergwerk von selbst, Richtung See zu graben. Major Voss ließ den Tunnel sprengen (Befehl 44) und verschanzte sich im **Fort Nordwacht**. Ein Teil der Soldaten wurde unter **Oberst Falk** zu den Raidern der „Red Flags“.

| Kapitel | Titel | Ziel | Ort |
|---|---|---|---|
| 1 | The Last Bus | nach Eisgrund gehen, Tove nach Mirja fragen (Tove gibt den Minenschlüssel) | Dorf → Eisgrund |
| 2 | Something Digs Below | Bergwerk finden, Boss **K-9** besiegen, Tove berichten | Bergwerk Nordstern |
| 3 | Order 44 | Befehl 44 im Tunnel-Dienstraum lesen, Bunker B-2 und Fort erreichen, Boss **Oberst Falk** besiegen | Tunnel, B-2, Fort Nordwacht |
| 4 | Polaris-7 | über die Eisklamm zur Station, Halvorsens Logbuch und die Feldnotizen lesen, Pater Aurel berichten | Forschungsstation |
| 5 | The White One | Boss **das Weiße** auf dem See besiegen, über das **Herz von Kern 31** entscheiden | See |

Ab Kapitel 5 sitzt Mirja in Toves Haus in Eisgrund und spricht mit dir.

**Teil 1 endet mit der Entscheidung über das Herz von Kern 31** (Zwischenkarte, kein Abspann):

- **Pater Aurel → „The Lights Go Out“:** Das Herz verbrennt im Kapellenofen. Ruf im Dorf +20.
- **Tove → „The Lake Keeps Its Secret“:** Das Herz wird im tiefen Eisloch versenkt. Ruf in Eisgrund +20.
- **Pavel → „Bought and Sold“:** 1500 Kronen; das Herz liegt unter Pavels Stand. Ruf bei Dorf und Eisgrund −20.

In allen drei Fällen ist der Tunnel weiter zu. Mirja bringt Arvids letzte **Sprengladung**.

**Teil 2: das Vorland** (zweites Tal südlich des Tunnels)

| Kapitel | Titel | Ziel | Ort |
|---|---|---|---|
| 6 | The Way Out | Einsturz im Polaris-Tunnel sprengen, durch die Schlucht zur Armeesperre, Sperrbefehl lesen | Tunnel, Talausfahrt, Sperre Süd |
| 7 | Grauwasser | Stadt erreichen, Dr. Edda Brandt sprechen, Boss **Hauptmann Reiss** im Sägewerk besiegen, Bürgermeister Ragnar Halden berichten | Grauwasser, Sägewerk Halden |
| 8 | The Dead Line | Triage-Notizen im Feldlazarett lesen, Lars am Funkmast Relaissicherung + Benzin bringen, Pilotin Jorun Brandt fragen | Feldlazarett, Hochfunk, Flugfeld |
| 9 | The Grey Mother | Boss **die Graue Mutter** im Steinbruch töten, Jorun Rotornabe + 2 Kanister bringen | Steinbruch, Flugfeld |
| 10 | Last Flight | über das leere **Flugmanifest** entscheiden | Flugfeld, Grauwasser |

**Die drei Enden** (wem man das Manifest gibt):

- **Jorun Brandt → „Last Flight“:** Du fliegst mit Mirja aus. Ruf in Grauwasser −15, im Dorf −10.
- **Dr. Edda Brandt → „Six Seats“:** Die sechs schwersten Kranken fliegen, du bleibst. Ruf in Grauwasser +30.
- **Ragnar Halden → „The Lifeline“:** Kein letzter Flug – der Hubschrauber versorgt den Winter über beide Täler. Ruf überall +20.

Neue Nebenjobs im Vorland: Pelze für die Station (Sigrid), Brief zum Einödhof (Dr. Brandt), zwei Red-Flag-Lager räumen (Ragnar), das Vorland erkunden (Lars), drei Dokumente über die Asche (Dr. Brandt).

**Endlosspiel** (`core/jobs.gd`, `world/job_board.gd`): In Polaris, Eisgrund und Grauwasser steht je ein **Anschlagbrett**. Dort hängt immer genau ein Job; ist er erledigt, hängt der nächste da. Arten: Kopfgeld (Red-Flag-Marken), Wolfspelze, Vorräte liefern, ein Lager räumen, Kurierkiste ins andere Dorf, im Horror-Modus Hohlen-Asche. Lohn und Menge steigen mit der Zahl der erledigten Jobs; jeder dritte Job gibt Munition oder Medizin dazu. Alle 7 Minuten Spielzeit werden leere Räuberlager und Wolfsreviere neu besetzt (nie näher als 120 m), mit jeder Welle etwas stärker (bis Stufe 14). Jobs und Wellen werden gespeichert.

**Jeder Gegner gibt Beute:** Räuber eine Red-Flag-Marke (plus Waffe, Munition, Kronen), Wölfe einen Wolfspelz, Bosse ihre eigene Belohnung, Hohle lassen sich mit viel Feuerkraft töten und hinterlassen Hohlen-Asche. Sigrid in Grauwasser kauft Pelze, Marken und Asche zu guten Preisen.

Technik: Die Kapitel sind Quests mit `"main": true` in `core/quests.gd`. Jedes Kapitel startet das nächste über `"next"`. `"card"` zeigt eine Zwischenkarte (`Story.CARDS`), `"ending": true` den Epilog (`Story.ENDINGS`). Alte Spielstände, die nach Kapitel 5 endeten, bekommen Kapitel 6 automatisch (`Quests._resume`).

## 2b. Horror-Modus

Im Titelmenü wählt man unter „New game“ zwischen **STORY** und **HORROR**. Gleiches Tal, gleiche Orte – aber:

- **Stimmung:** dichter Nebel, rotes Polarlicht, großer fahler Mond, fast keine Fensterlichter, flackernde Lampen. Bild entsättigt, mit Korn, Vignette und Farbsäumen. Die Taschenlampe ist an.
- **Musik und Ton** (`core/horror_audio.gd`): tiefes Brummen, Atemrauschen, Tinnitus und Herzschlag, die mit der Angst steigen; dazu eine verstimmte Spieluhr-Melodie. Zufällige Schreckmomente: Flüstern, Klopfen, Stromausfall, ein Schatten am Waldrand, ein ferner Schrei, die Taschenlampe fällt für Sekunden aus, eine Tür in der Nähe geht von selbst auf, Schritte hinter dir (nur solange du gehst), alle Lampen gehen aus und etwas atmet. Die Abstände werden mit der Geschichte kürzer.
- **Die Hohlen** (`ai/hollow.gd`): gekrümmte, augenlose Gestalten mit einem breiten Zahnmaul. Sie bewegen sich nur, wenn man nicht hinsieht. Taschenlampe (1,6 s im Lichtkegel), Feuer oder Leuchtpistole vertreiben sie; viele Kugeln oder Hiebe töten sie (Beute: Hohlen-Asche). Ab Kapitel H3 sind es zwei, in Teil 2 bis zu drei, sie kommen paarweise aus verschiedenen Richtungen und sind 25 % schneller. Kommen sie an dich heran: Schaden und Gesicht direkt vor der Kamera.
- **Die Erfrorenen:** Raider sind bleich, weißhaarig, mit leuchtenden Augen und Eissplittern.
- **Versteckte Menschen:** Alle Dorfbewohner haben sich versteckt. Man findet sie erst durch die Rätsel.
- **Rätsel** (`world/horror.gd`, `world/puzzle_prop.gd`, `ui/keypad.gd`): Sicherungskasten mit 3 Sicherungen (Bahnhof, Kapelle, Weststraße), Zahlenschloss am Spielzeugladen (Code aus 4 bemalten Tafeln bei den Lautsprechern), 3 Spieluhren in der richtigen Reihenfolge (falsch = Stromausfall und ein Hohler), das Weinen in einer dunklen Hütte (Annika), 3 Feuerkörbe in Eisgrund mit Brennholz.

| Kapitel | Titel | Ziel |
|---|---|---|
| H1 | Nobody Home | Notiz am Platz finden |
| H2 | The Fuse Box | 3 Sicherungen holen, Strom einschalten |
| H3 | The Toymaker's Code | Code finden, Spielzeugladen öffnen |
| H4 | Three Music Boxes | Spieluhren in der richtigen Reihenfolge spielen |
| H5 | Someone Is Crying | dem Weinen folgen, Annika finden |
| H6 | Three Fires | die 3 Feuer in Eisgrund anzünden |
| H7 | The White One | das Weiße besiegen → Zwischenkarte „The Fog Moves On“ |
| H8 | The Siren | Tunnel sprengen, Notiz an der Sperre lesen, in Grauwasser 3 Kanister in den Generator füllen (Sirene), Ragnar finden |
| H9 | Dead Air | am Funkmast die Frequenz aus dem Funklog auf dem Schreibtisch ins Zahlenschloss des Funkgeräts tippen, Lars finden |
| H10 | The Nest | am Sägewerk die 4 Feuerkörbe bei den Ölfässern anzünden (jedes Feuer weckt mehr Hohle) → Ende „Ash“ |

Solange die Sirene läuft, kommen die Hohlen nicht auf den Platz von Grauwasser.

**Nur Horror:** Im Horror-Modus gibt es keine Nebenaufträge, keine Aushänge und keine Passanten – nur die Horror-Handlung H1–H10. Mehr Schreckmomente (alle 11–28 s, später 8–20 s): eine große Gestalt mit zu langen Armen steht am Rand des Blickfelds und ist weg, sobald man hinsieht; eine Gestalt direkt hinter dir (dreht man sich rechtzeitig um: Schrei, rotes Bild); frische Blutschrift an der Wand neben dir („TURN AROUND“, „IT WEARS THEIR FACES“ …); eine offene Tür knallt zu; ein Funkgerät rauscht hinter dir und sagt deinen Namen; eine Blutspur über den Boden. Ab Angst 0,4 hört man den eigenen Herzschlag, der mit der Angst schneller wird.

Technik: `core/game_mode.gd` (Modus, Speicherpfad `user://polaris_horror.json`), Kapitel `h_1`–`h_10` mit `"mode": "horror"` in `core/quests.gd`, Schritt-Art `"flag"` für Rätsel.

## 3. Welt

- **Größe:** Die Karte ist 2 km breit und 3 km lang (vorher 2 × 2 km): im Norden die **Senke** mit Polaris, im Süden das **Vorland**. Dazwischen liegt der Bergkamm mit dem Polaris-Tunnel und der Schlucht „Talausfahrt“.
- **Vorland** (`builders/site_south.gd`): Armeesperre Süd, Stadt **Grauwasser** (24 betretbare Häuser, Hotel, Kaufhaus, Gasthaus, Bahnhof, Kapelle, Denkmal, Sirene, Generatorhütte), Sägewerk Halden, verlassenes Feldlazarett mit Hubschrauberwrack, Funkmast Hochfunk (38 m), Flugfeld mit Hangar und Hubschrauber, Steinbruch mit Wolfshöhle, Einödhof mit roter Scheune, 2 Red-Flag-Lager, 3 Wolfsrudel. Sechs neue Bewohner (Dr. Edda Brandt, Ragnar Halden, Sigrid, Lars, Jorun Brandt, Oda), zwei neue Händler (Kaufhaus Halden, Hangar-Lager), neue Fraktion „Grauwasser“.
- **Senke** (nördlicher Teil der 2 × 3 km großen Karte): 2 km × 2 km, Bergring mit Graten, Rinnen und Felsbändern, Gletschereis. See (Radius 230 m) mit dünnem Eis in der Mitte und einem offenen Loch zum Schwimmen.
- **Wald:** rund 10 500 Bäume in 4 Arten, 1500 Felsen (kletterbar), junge Fichten, umgefallene Stämme.
- **Polaris (Stadt):** geräumte Straßen, bemalte Holzhäuser in nordischen Farben, Hotel, Spielzeugladen, Gasthaus, Seilbahnstation, Kapelle, Markt, großer Baum mit ca. 1350 Lichtern, Spielzeugeisenbahn, Pyramide, Karussell, Nussknacker, Straßenlaternen, Masten, Schilder, Bushaltestelle, geparkte Autos. 20 Häuser mit Einrichtung.
- **Orte:** Eisgrund (Fischerweiler mit Steg), Aussichtsturm Seeblick, Stollenkopf-Aussicht, Bergwerk Nordstern (Stollen, Kammer, Büro, Geheimraum), Polaris-Tunnel (Dienstraum), Schutzräume B-2 und B-5, Eisklamm-Brücke mit Notsteg (Hebel), Fort Nordwacht, Forschungsstation Polaris-7, Gipfel Gipfelblick (Kletterroute), 6 Waldhütten, 3 Raiderlager, Eisfischer.
- **Straßen:** 6 Straßen mit Schneestangen und 11 Wracks (einige mit Beute), Bus und Lastwagen.
- **Jahreszeit:** Standard ist **Sommer** (`GameMode.season = "summer"`): helle Sonne (`PhysicalSkyMaterial`), grüne Wiesen, Waldboden und Almrasen, offener See (nur um den „Weißen“ bleibt eine Eisscholle gefroren, `Lake.FLOE_C`/`FLOE_R`, damit der Bosskampf auf dem Eis bleibt), Schotterhaufen statt Schneewehe am Fort, Asphaltstraßen, Regen statt Schnee, Gras und Wiesenblumen (Margeriten, Glockenblumen, Hahnenfuß, Lichtnelken; `world/grass.gd`, im Umkreis von ca. 40 m um die Kamera, im Wind wiegend). Schnee liegt nur noch hoch oben auf den Bergen (Schneegrenze ca. 185 m, `terrain.gdshader`). Winter bleibt mit `--winter` möglich; der Horror-Modus spielt immer im Winter. Schnee- und Eisflächen aus Code-Modellen fallen im Sommer weg (`MeshKit.winter`).
- **Häuser:** 7 Haustypen aus Blender (`assets/models/houses/*.glb`): Wohnhaus, kleines Wohnhaus, Hotel, Gasthaus, Spielzeugladen, Bahnhof, Hütte. `builders/house_scan.gd` setzt die Hülle mit Material und Kollision auf das Haus, Räume, Treppen und Einrichtung baut weiter der Code.
- **Wetter:** Schneefall (Sommer: Regen), Stürme, volumetrischer Nebel, Wind-Ton, Fußspuren.
- **Verschlossene Wege:** Mikkel gibt die Brechstange → Tunnel-Dienstür → Bunkerschlüssel → B-2 → Waffenkammerschlüssel → Fort (Tor rammen ab 1500 kg, Bolzenschneider oder Schneewehe) → Labor-Schlüsselkarte → Labor der Station.

## 4. Spielsysteme

**Überleben** (`player/stats.gd`): Gesundheit, Ausdauer, Wärme, Nässe, Blutung, Verstauchung und Gewicht. Beheizte Häuser wärmen, Stürme kühlen aus. Kleidung hat Vor- und Nachteile: Wärme und Panzerung gegen Gewicht und Beweglichkeit.

**Gegenstände** (`core/items.gd`):

- Kleidung für 7 Plätze.
- Verbrauchsgüter: Essen, Tee, Handwärmer, Verband, Erste-Hilfe-Set, Schiene, Schmerzmittel.
- Material, Werkzeuge, Schlüssel, Fahrzeug-Upgrades, Waffen, Munitionsarten, Aufsätze.
- Seltenheit ergibt sich aus dem Wert.

**Kampf:**

- **Schusswaffen:** Pistole, Revolver, MP, Sturmgewehr, Pumpgun, DMR, Scharfschützengewehr und Leuchtpistole. Die Kugeln haben echte Flugbahn, Fall, Luftwiderstand und Durchschlag.
- **Aufsätze:** Zielfernrohr, Rotpunkt, Schalldämpfer, Griff, Magazin und Mündungsbremse.
- **Nahkampf:** Messer, Säbel, Axt und Eispickel. Es gibt leichte und schwere Schläge, Ketten, Blocken, Parieren mit Konter und Ausweichen.
- **Rückmeldung:** Trefferanzeigen, Blut und Funken, Hit-Stop und Herzschlag. Kopfschuss-Kills: kurze Zeitlupe und „HEADSHOT“.
- **Unter Beschuss:** Kugeln, die knapp vorbeigehen, zischen, die Kamera zuckt und der Bildrand verschwimmt kurz. Schüsse hallen über einen Echo-Bus (zwei späte Echos und Hall) von den Bergen zurück.
- **Schwer verletzt** (unter 30 %): Farben verblassen, der Rand wird weich im Takt des Herzschlags.
- **Granaten** (`combat/grenade.gd`, `combat/blast.gd`): Manche Raider tragen eine Splittergranate und werfen sie, wenn du dich versteckst. Rotes Blinklicht, das schneller wird. Deckung schwächt die Explosion auf 30 %.

**Gegner:**

- 7 Raider und 2 Wolfsrudel; Wachen im Fort.
- **K-9:** Teile mit eigenen Trefferpunkten und 3 Phasen; Fässer explodieren. **Spezialfähigkeiten:** Magnet in der Trommel zieht dich zu den Zähnen, **Minen-Drohnen** rollen piepend auf dich zu (ein Treffer zündet sie), **Dampfstoß** beim Überhitzen wirft dich zurück.
- **Das Weiße:** Eisplatten schützen; das Hinterteil ist der Schwachpunkt; Leuchtpistole stoppt den Ansturm; die Bestie bricht das Eis. **Spezialfähigkeiten:** **Frostatem** (Kegel, kühlt aus, Eis wächst über das Bild; währenddessen ist der Hals offen: 1,4× Schaden), ab Phase 2 **Eisspitzen** (eine Linie aus Speeren, vorher leuchtet das Eis blau), ab Phase 3 **Blizzard-Heulen** (alles wird weiß, Nebel, dann Ansturm).
- **Oberst Falk:** wechselt die Waffe nach Entfernung, sucht Deckung und ruft Verstärkung. **Spezialfähigkeiten:** Splitter- und Rauchgranaten (Rauch deckt seinen Weg in die Deckung), unter 25 % **letztes Gefecht**: „Für Nordwacht!“, schneller, genauer, keine Deckung mehr.
- **Phasenwechsel:** Die Welt hält kurz an, roter Blitz, „PHASE 2/3“ groß unter dem Bossbalken.

**Fahrzeuge** (`vehicles/`): Grip hängt vom Untergrund ab. Es gibt Treibstoff, Schaden, Reparatur mit Schrott, Upgrades (Schneeketten, Panzerplatten, Zusatztank, Seilwinde), Licht und Seilwinde. Dünnes Eis bricht unter schweren Fahrzeugen.

**Klettern:** gegen steilen Fels drücken und Sprung halten. Der Eispickel macht es schneller; ein Seil fängt Stürze ab und erlaubt Abseilen.

**Fraktionen** (`core/factions.gd`): Dorf, Eisgrund, Raider („Red Flags“), Nordwacht und Grauwasser. Der Ruf reicht von −100 bis 100 in 5 Stufen; Gebiete werden im HUD angezeigt. Falks Tod macht Nordwacht neutral.

**Wirtschaft:** 7 Händler, Kronen als Geld. Munition wird beim Verkauf billiger, je mehr der Händler schon hat. Ruf für getötete Räuber gibt es nur für die ursprünglichen Lagerbewohner, nicht für nachrückende Wellen. Die Preise hängen von Ruf, Knappheit und Vorlieben ab; das Angebot wechselt alle 8 Minuten. Dazu kommen 2 Werkbänke für Rezepte.

**Nebenaufträge (12, Auswahl):**

- Lieferung („A Parcel for Eisgrund“)
- Säubern („Otto's Station“)
- Sammeln („A New Heart for the Pickup“)
- Erkunden („Eyes on the Senke“)
- Nachforschen („What Happened at Polaris-7“)
- Jagd („The Pack in the South Wood“)
- Entscheidung („The Antibiotics“: Dorf, Eisgrund oder verkaufen)

**Bewegung** (`player/player.gd`): Wer geradeaus sprintet, baut Schwung auf (bis +32 %), harte Kurven kosten ihn. Sprungsprints schieben nach vorn, kurz nach der Landung erneut springen (0,16 s) hält den Schwung. Coyote-Zeit und Sprungpuffer, Rutschen mit Strg aus vollem Sprint (aus dem Rutschen springen geht). **Wandsprung:** in der Luft an einer Wand Sprung drücken – stößt von der Wand ab, zwei pro Sprung, kostet Ausdauer. Kanten bis 48 cm (Stufen, Schwellen, Treppenkanten, auch abgeschrägte) steigt man ohne Springen hinauf; die Kamera gleitet weich nach.

**Leute in der Stadt** (`ai/npc.gd`, `ai/people.gd`): Jeder kann getötet werden. Tote lassen einen Beutel fallen (Kronen, 1–3 Taschendinge; eine Waffe mit Munition nur, wenn sie eine trugen). Der Ruf beim Dorf sinkt stark, Leute in der Nähe erschrecken. Nach 6–9 Minuten kommt jemand nach – aber nur, wenn man weit weg ist und die Leiche nicht sieht; deshalb lohnt sich Farmen nicht. Dazu laufen 8 Passanten mit zufälligem Aussehen durch die Stadt.

**Speichern:** F5 speichert in den zuletzt benutzten Slot, F9 lädt den neuesten Stand (Slot oder Autosave). Im Pausenmenü „Save / load“: 3 Slots pro Modus plus Autosave (bei jedem Kapitelende und alle 5 Minuten Spielzeit). Geschrieben wird erst in eine .tmp-Datei, die nur ersetzt, wenn sie sich wieder lesen lässt; die alte Datei bleibt als .bak, die beim Laden einspringt, wenn die Hauptdatei kaputt ist. Versionsfeld mit Migration (aktuell 2). Gespeichert wird JSON mit allem: Position, Werte, Inventar, Truhen, tote Gegner, Fahrzeuge, Eislöcher, Türen und Hebel, Ruf, Händler, Quests und Story.

## 5. Bedienung

| Aktion | Tastatur / Maus | Controller |
|---|---|---|
| Bewegen | W A S D | linker Stick |
| Umsehen | Maus | rechter Stick |
| Sprinten / Springen / Ducken | Shift / Leertaste / Strg | L3 / A / B |
| Ausweichen | Alt | R3 |
| Benutzen / Reden / Ein- und Aussteigen | E | X |
| Feuern bzw. Schlagen / Zielen bzw. Blocken | LMB (halten = schwer) / RMB | RT / LT |
| Nachladen / Munitionsart / Holstern | R / B / H | Steuerkreuz rechts / links / unten |
| Waffe wählen | 1–6, Mausrad | RB / LB |
| Taschenlampe bzw. Autolicht | F | Steuerkreuz oben |
| Seilwinde / Kamera im Auto | G / V | — |
| Inventar / Tagebuch / Aufträge / Karte | Tab / J / L / M | Y / — / — / Back |
| Pause | Esc | Start |
| Rutschen (aus dem Sprint) | Strg | B |
| Wandsprung | Sprung in der Luft an einer Wand | A |
| Creator: Fliegen / Panel | F / P | — |

Alle Tasten sind im Spiel umbelegbar (Pause → Settings → Rebind…).

## 6. Menüs und Optionen

- **Titel:** „Story mode“ und „HORROR MODE“ stehen direkt im Titelmenü (Horror rot und pulsierend), dazu „Compare the two modes“ mit den zwei Karten. Im Pausemenü wechselt „Switch to HORROR/STORY mode“ den Modus; vorher wird gespeichert.
- **Inventar:** Item-Bilder sind fotografierte 3D-Modelle; im Ausrüstungsfenster steht die eigene Figur in der getragenen Kleidung. Die Waffenleiste im HUD zeigt Waffenbilder statt Wörtern.

- **Creator-Modus** (`world/creator.gd`, Titel: „CREATOR MODE“): das Tal als Werkstatt ohne Gegner, Story, Schaden, Hunger oder Kälte. **F** fliegt (WASD, Leertaste hoch, Strg runter, Shift schnell), **P** öffnet das Panel: zu jedem Ort springen, Häuser jeder Art, Raider oder Wolf vor sich hinstellen und wieder wegräumen, alle Waffen, Wetter, Sommer/Winter, Gras an/aus, Bild nach `shots/creator_*.png`. Eigener Spielstand `user://polaris_creator.json`.
- **Titelmenü:** Continue (zeigt Story oder Horror, je nach letztem Spielstand), Story mode, HORROR MODE, Compare the two modes, Settings, Quit.
- **Gespräche:** wie im Film: schwarze Balken oben und unten, die Kamera dreht sich zur Person und rückt näher, Namensschild mit Fraktionsfarbe, Text wird getippt (E überspringt), Antworten als Karten mit Ziffern 1–9, Markierungen „NEW JOB“, „JOB“, „TRADE“. Maus geht auch: zeigen und klicken.
- **Handel, Werkbank, Aufträge:** gleiche Panels mit Schatten und Eckmarken, Gegenstands-Bilder in jeder Zeile, Seltenheitsfarbe, Maus und Mausrad. Notizen liegen als altes, vergilbtes Papier mit Flecken und Kaffeerand vor dir.
- **Pausenmenü (Esc):** Resume, Save, Load, Map, Settings, Moduswechsel, Main menu, Quit.
- **Einstellungen** (`core/settings.gd`, gespeichert in `user://settings.cfg`):
  - 3 Profile
  - Mausempfindlichkeit, Invertieren
  - Stick-Geschwindigkeit, Totzone, Vibration
  - Sichtfeld, Grafikqualität (Low / Medium / High / Ultra), Vollbild, V-Sync
  - Lautstärke
  - Tastenbelegung für Tastatur/Maus und Controller getrennt, mit Konfliktauflösung
- **Grafikqualität:**
  - **Low:** Renderauflösung 67 % mit FSR, kleiner Schattenatlas, kurze Schattenweite, kein SSAO/SSR/Nebel/Glow.
  - **Ultra:** volle Auflösung, MSAA 2×, SSR, SSIL (Licht prallt von Schnee und Wänden in die Schatten), weite Schatten.
- **Bild:** AgX-Tonemapping (helle Lampen und Schnee brennen nicht weiß aus), leichte Farbkorrektur, Nachbearbeitung in `world/post.gdshader` (Korn, Vignette, Farbsäume, Frost, Whiteout, Blitze).
- **Oberflächen** (`world/surface.gdshader`): echtes Relief aus Bildschirm-Ableitungen: Fugen, Bretter, Ziegel und Wellblech werfen Licht und Schatten. Haut mit Subsurface Scattering, Fell mit Strähnen, Winterjacken mit gesteppten Kammern (`<farbe>_coat`). Gesichter mit Brauenbogen, Wangenknochen, Nasenflügeln, Lippen, Iris und Lidern; Bärte aus Büscheln.
- **Karte (M):** Reliefkarte aus dem Gelände mit Straßen, See, Stadt, entdeckten Orten, Spielerpfeil und Ziel des aktuellen Auftrags. Mit Mausrad zoomen, ziehen oder mit WASD verschieben.
- **Lenkrad:** Godot kennt nur allgemeine Joystick-Achsen. Ein Lenkrad funktioniert wie ein Controller, aber Kraftrückmeldung gibt es nicht.

## 7. Technik und Aufbau

- `world/main.gd` baut beim Start alles im Code, in dieser Reihenfolge: Gelände → Orte und Dorf planen → Gelände-Mesh → See → Wald → Dorf → Wildnis → Orte → Spieler → HUD und Fenster → Fraktionen, Handel, Quests → Gegner und Bosse → Leute → Fahrzeuge → Wetter → Karte, Story, Menü.
- **Modelle** entstehen mit `MeshKit` (`builders/kit.gd`), **Materialien** mit `Mats` und `world/surface.gdshader`.
- **Item-Bilder:** `builders/item_mesh.gd` hat für jedes Item ein 3D-Modell; `ui/item_icons.gd` fotografiert jedes einmal beim Start unter Studiolicht (ein Bild pro Frame) und legt es in `ItemIcons.tex` ab. Rucksack, Händler und Waffenleiste zeichnen diese Bilder. Dieselbe Klasse fotografiert die Figur im Ausrüstungsfenster in der getragenen Kleidung (`shoot_figure`). Kontrollbogen: `-- --iconsheet` → `shots/300_icons.png`.
- **Oberflächen:** `surface.gdshader` hat für Waffen und Werkzeug sauberes Metall (Art 17), Kunststoff (18) und geöltes Schaftholz (19): Materialnamen `gunmetal`, `steel_clean`, `worn`, `tin`, `polymer`, `walnut`. Art 4 (`metal`, `steel`) rostet und ist nur für Bauten gedacht.
- **Türen:** `world/door.gd` baut vier Arten: `house` (Füllungstür mit Fenster), `plank` (Brettertür), `steel` (Blechtür), `container` (Frachttür mit Verschlussstangen). `Places.leaf()` setzt eine einzelne Tür, `Places.cargo_doors()` die zwei Flügel eines begehbaren Containers. Alle Türen ohne Schloss gehen auf; fünf Türen brauchen weiter einen Schlüssel (Mine, Bunker, Waffenkammer, Labor), weil die Story daran hängt.
- **Tests:** `-- --doortest` zählt alle Türen, öffnet jede unverschlossene und macht Bilder (220–225). `godot --path . -- --<test>`. Es gibt `walktest`, `survtest`, `combattest`, `drivetest`, `climbtest`, `placestest`, `econtest`, `bosstest`, `storytest` und `looktest --only=…` (Bilder nach `shots/`). Horror: `godot --path . -- --horror --horrortest`. `--horror` startet das Spiel direkt im Horror-Modus.
- **Blender-Grafik (Branch `blender-graphics`):** `core/model_lib.gd` (`ModelLib`) lädt fertige Modelle aus `assets/models/*.glb` und Scan-Texturen aus `assets/textures/<name>/`. Fehlt eine Datei, baut das Spiel wie vorher im Code. Alle Vorlagen sind CC0 von Poly Haven bzw. MakeHuman, in Blender bereinigt, reduziert und exportiert.
  - Requisiten: Mülltonne, Müllsack, Fass, Kiste, Bank, Hydrant (`builders/props.gd` über `MeshKit.model()`), Baumstümpfe, tote Stämme, Felsen (`world/forest.gd`).
  - Waffen: Pistole (`service_pistol`) und Zielfernrohr-Gewehr (`bolt_action_rifle_7_62`) über `WeaponMesh.SCANS`; die übrigen Waffen bleiben Code-Modelle.
  - Menschen: sechs MakeHuman-Körper (`assets/models/people/`, Männer/Frauen, jung/alt, verschiedene Herkunft) mit Parka, Hose, Stiefelschaft und Handschuhen aus der Haut geschnitten. `builders/scan_person.gd` behält die Gelenke der Code-Figur (die KI bewegt sie weiter), versteckt deren Meshes und dreht jedes Frame die Knochen des Skeletts mit. Mütze, Kapuze, Schal, Rucksack und Weste kommen weiter aus dem Code. Wer welchen Körper hat: `People.BODIES`. Die „Frozen“ und Figuren mit leuchtenden Augen bleiben Code-Figuren.
  - Gelände und Häuser: Schnee, Fels und Asphalt im Gelände-Shader, Bretter, Putz, Ziegel, Schiefer, Blech, Beton und Rost an den Häusern sind Scan-Texturen (`Mats.PBR`, `Mats.PBR_NAMES`).
  - Leistung: Scans sind schwer (Tanne ~21 000 Dreiecke, Mensch ~17 000). `Forest.spread()` verteilt sie in kleinen Zellen mit Entfernungsstufen (Felsen: Scan bis 42 m, dann Code-Modell; Tannen: Code-Baum bis 110 m, dann Fern-Modell); Requisiten erscheinen bis 75 m, Menschen bis 140 m. Texturen müssen VRAM-komprimiert mit Mipmaps importiert sein – ohne lief das Gelände mit 4 statt 37 fps. Messen: `-- --climbtest --perf`, Vergleich ohne Scans mit `--noscan --noscan=all` oder `--skip=<id,id>`.
  - Bilder: `-- --scanshot` (shots/s1–s8: Menschen, Zielen, Requisiten, Wald).
- **Spieltest mit echten Tasten** (`world/playtest.gd`, `-- --playtest`): ein Roboter spielt die Hauptgeschichte über die echten Eingaben (W, Sprint, E, Zifferntasten im Gespräch, Feuern), läuft zu jedem Ziel, öffnet Türen, redet, kämpft, liest Notizen und meldet, wo er stecken bleibt (`PLAY …`, Bilder `shots/play_*`). `--horror --playtest` spielt den Horror-Modus. `--playtest --doorwalk` geht durch jede Tür ohne zu springen (2026-11-18: 83 von 83, 5 Story-Schlösser). `--playtest --roomtest` prüft auf einem 10-cm-Raster jedes Stockwerk jedes Hauses: Kommt der Körper von der Haustür bzw. vom Flur überall hin, auch zum Treppenfuß? (2026-11-18: 91 Stockwerke, 0 Fehler.) `--roommap=<art>:<stock>` druckt die Karte.
- **Zimmer und Möbel:** Zimmertüren oben sind 1,0 m breit; Betten lassen immer einen 1,35 m breiten Gang von der Tür frei (in schmalen Zimmern ein Einzelbett ohne Nachttisch). Nichts hängt in Türöffnungen (früher hing im Restaurant ein Bild im Durchgang zur Treppe).
- **Bäume:** Die Poly-Haven-Tannen (`fir_tree_01`, `fir_sapling`) haben beim Export ihre Nadeln verloren und werden nicht mehr benutzt; Tannen sind in jeder Entfernung Code-Bäume. Felsen sitzen tiefer im Hang.
- **Blut** (`combat/fx.gd`): Sprühnebel, Tropfen, Spritzer in Flugrichtung, Decals an der Wand hinter dem Treffer und am Boden, wachsende Blutlachen unter Toten, Tropfspuren bei Blutenden; Blut trocknet in 2 Minuten dunkel ein.
- Nach dem Anlegen neuer `class_name`-Skripte einmal `godot --headless --path . --import` laufen lassen.
- **Partikel:** Godot 4.7 zeichnet bei `CPUParticles3D` mit Vertex-Farbe noch nicht geborene Partikel als schwarzen Fleck am Emitter. Der Granatenrauch nutzt deshalb `combat/smoke.gdshader`: Er blendet diese Partikel aus, macht die Ränder klumpig und lässt den Rauch weich in Boden und Wände übergehen. Neue lange Partikel-Effekte mit Vertex-Farbe brauchen denselben Shader oder `preprocess`.

## 8. Bekannte Grenzen

- Gegner, Bosse und die Gate-Kette sind über Skript-Tests und Bilder geprüft. Von Hand gespielt wurde noch wenig; Schwierigkeit und Balance sind ungeprüft.
- Alle Stockwerke sind begehbar: Jedes Haus mit mehr als einem Stock hat eine Treppe im Flur an der Rückwand (`Chalet.stair_plan`), mit Geländer, Treppenloch und eingerichteten Zimmern oben (`Interior.upper`: Schlaf-, Gäste-, Kinder-, Arbeitszimmer, Bad, Abstellraum). Die sichtbaren Stufen sind Schmuck; gelaufen wird auf einer glatten unsichtbaren Rampe (StaticBody `steps`). `-- --buildtest` prüft, dass jedes Obergeschoss über die Treppe erreichbar ist (`--stairsonly` ohne Türtest).
- Gebäudeprüfung: `-- --buildtest` prüft bei jedem Haus Boden und Dach auf Löcher, Schnee im Boden und läuft durch jede unverschlossene Tür.
- Der Hubschrauber fliegt nur in den Endtexten; selbst fliegen kann man nicht. Nachgewachsene Gegner werden nicht einzeln gespeichert – nach dem Laden sind leere Lager entsprechend der Welle neu besetzt.
- Figuren unterscheiden sich: `Humanoid.vary()` wählt Hautton, Haarfarbe, Größe und Breite je Person (bei Dorfbewohnern immer gleich, bei Räubern zufällig), `Humanoid.fit()` skaliert das Modell. Räuber haben 8 Kleidungen und zufällig Bart. Händler- und Werkbankliste zeigen 36-px-Gegenstandsbilder.
- Relief kommt bei Code-Modellen aus Ableitungen im Shader. Auf dem Branch `blender-graphics` sind Menschen, Bäume, Felsen, viele Requisiten, zwei Waffen, Gelände und Hauswände echte Scans; alle sechs Schusswaffen sind in Blender gebaut (Walnuss-Schaft, brünierter Stahl, `assets/models/guns/`), viele Möbel sind Scans (Stühle, Sessel, Sofa, Schränke, Kachelofen, Uhren, Pflanzen, Nachttisch, Ofen; `assets/models/furniture/`). Hausformen, Fahrzeuge, Teile der Einrichtung, Wölfe und Bosse sind weiter Code-Modelle. Die Menschen tragen aus der Haut geschnittene, geglättete Kleidung (kein echter Stoff mit Falten) und haben keine Bärte; die Animation ist Gelenk-Animation, kein Motion-Capture. Dorfbewohner bewegen sich aber natürlicher: Schrittfrequenz und Schrittlänge passen zur Geschwindigkeit (`Humanoid.gait`), sie beschleunigen und bremsen weich, drehen sich erst und gehen dann, treten beim Drehen auf der Stelle, folgen dir mit Kopf und Schultern und haben Gesten im Stand (reden mit den Händen, Arme verschränken, Hände reiben, Füße stampfen, Standbein).
- Higgsfield (KI-Bilder/Videos) wurde nicht benutzt: Es gibt dort kein Gratis-Kontingent, und Credits sollten nicht ausgegeben werden.
- Fässer und zerstörte Bossteile kommen nach dem Laden zurück.
- Die Spielsprache ist Englisch; Schilder und Ämter im Tal sind deutsch.


## Analyse-Report v1 – behoben (2026-11-18)

- **Sommer ist das Setting:** Titel „A short summer, a long shadow“, Einleitung im August mit Sommerfest (statt Dezember/Weihnachtsmarkt), Notizen werden im Sommer passend erzählt (`GameMode.season_text`). Kälte im Sommer nur durch Regen/Sturm und Wasser (`Stats.tick`). Horror bleibt Winter.
- **Laden füllt keine Lager mehr neben dir** (`Jobs.from_dict` → 120-m-Regel).
- **Speichern** sicher, mit Backup, Autosave und 3 Slots (siehe oben).
- **Tod:** Bosse heilen sich voll, wenn du stirbst; du verlierst 10 % deiner Kronen (höchstens 50) und wachst am nächsten entdeckten Ort auf, der nicht in Reichweite eines Bosses liegt.
- **Hohle:** greifen nur auf gleicher Höhe und ohne Wand dazwischen an; Wände und geschlossene Türen halten sie auf, sie laufen darum herum.
- **Blutung** gerinnt langsam von selbst (kleine Wunden schneller); Verband bleibt der schnelle Weg.
- **Farming:** Ruf nur für ursprüngliche Lagerbewohner, Munitionspreise sinken mit dem Händlerbestand.
- **Texte:** Funk-Hinweis zeigt auf das Funklog, Manifest „Six seats“, Mirjas Zeitachse (Tove: „letzte Nacht“).
- **Aushänge:** zweimal E am Brett gibt einen Job ab (−2 Ruf beim Brett).
- **Toter Code** entfernt (`Enemies._loading`, Horror-Jobart „ash“).
- **Effekte:** rote Schmerzanzeige nur noch an den Rändern; Option „Reduced effects“ (weniger Rot, Korn, Farbsäume).
- **Traglast** 32 kg statt 25 kg.
- **Grauwasser** dichter: Straßenbäume, Baumring am Platz, Hecken, Blumenkübel, Mülleimer, Kisten, Fahrräder, Briefkästen.
- **Jahreszeit wählbar:** Im Titelmenü „Season: Summer / Winter“ (gespeichert in den Einstellungen); Sommer ist Standard, Horror bleibt immer Winter.
- **Schwierigkeit** in den Einstellungen: Easy (60 % Schaden, 135 % eigener Schaden), Normal, Hard (140 % / 80 %).
- **Einstieg:** Nach den Startkarten erscheinen in den ersten ~2 Minuten sechs kurze Hinweise mit den echten Tasten (Bewegen, Kompass-Marker und Karte, E, Rucksack, Leisten unten links, Taschenlampe und Speichern).
- **Leute im Sommer:** Wintersätze (Schneeketten, Glühwein, „vor dem ersten Schnee“) werden im Sommer passend ersetzt.
- **Schnelltest der ganzen Story** (`-- --playtest --reachtest`, ohne Fenster mit `--headless`): prüft für jeden Schritt jedes Kapitels, ob man vom vorigen Ziel zu Fuß (oder kletternd) hinkommt. Kapitelbereiche mit `--reachfrom=main_4 --reachto=main_5` laufen parallel; Ergebnisse werden in `user://reach_cache_*.json` gespeichert und beim nächsten Lauf übernommen, solange sich kein Spielskript geändert hat.
- **Offen:** Steam-App-ID ist noch 480 (Test-ID von Valve) – die echte ID gibt es erst nach der Anmeldung bei Steamworks. Die deutsche Übersetzung ist noch nicht gebaut (Schwierigkeitsgrade und Geräusch-Untertitel sind inzwischen drin).
