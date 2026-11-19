# POLARIS

**Ein First-Person-Open-World-Survival-Abenteuer in einem nordischen Tal, abgeschnitten von der Welt.**
Gebaut mit Godot 4.7 (GDScript, Forward+, Jolt Physics).

Du bist mit deiner Schwester Mirja zum Markt nach Polaris gefahren. Auf der Rückfahrt sprengt die Armee den einzigen Tunnel. 31 Fahrgäste sitzen im Tal fest, und in der ersten Nacht geht Mirja zum See und kommt nicht zurück. Im Tal wartet etwas, das die Forschungsstation Polaris-7 aus 240 m Tiefe geholt hat: Eis, das kein Eis ist.

## Spielmodi

| Modus | Worum es geht |
|---|---|
| **Story** | Das normale Spiel: 10 Kapitel in zwei Teilen (Senke und Vorland), 5 Bosse, 3 Enden, Fraktionen, Händler, Nebenaufträge und Aushänge. |
| **Horror** | Dasselbe Tal im Nebel, mit eigener Handlung in 10 Kapiteln (H1–H10). Es gibt keine Jobs, dafür Jäger im Dunkeln, versteckte Überlebende und Rätsel. |
| **Creator** | Ein freier Testmodus zum Ausprobieren und Bauen. Mit **F** fliegst du. |

Story und Horror haben getrennte Spielstände. Im Titelmenü schaltest du zwischen Sommer und Winter um.

## Features

- **Überleben:** Kälte, Nässe, Ausdauer, Blutungen, Verletzungen und Gewicht
- **Kampf:** sechs Schusswaffen mit Ballistik, dazu Nahkampf mit Schwert, Axt, Eispickel und Messer
- **Bewegung mit Schwung:** Sprint-Momentum, Sprünge, Wall-Jumps und Klettern an Fels
- **Fahrzeuge:** Schneemobil, Pickup, Geländewagen und Kettenfahrzeug; dünnes Eis bricht
- **Lebendige Orte:** das Dorf Eisgrund, die Stadt Grauwasser, ein Bergwerk, eine Forschungsstation, ein Fort, ein Sägewerk, ein Flugfeld und mehr. Jedes Haus und jedes Zimmer ist begehbar.
- **Menschen:** 5 Fraktionen und 7 Händler. Alle Bewohner lassen sich angreifen; neue kommen nach einiger Zeit wieder.
- **Komfort:** 3 Speicherplätze plus Autosave, Schwierigkeitsgrade, Untertitel für Geräusche, ein Modus mit reduzierten Effekten und frei belegbare Tasten

## Starten

1. [Godot 4.7](https://godotengine.org/download) herunterladen (die Standard-Version reicht, .NET ist nicht nötig).
2. Dieses Repo klonen oder als ZIP laden.
3. In Godot **Importieren** wählen, `project.godot` öffnen und mit **F5** starten.

Beim ersten Öffnen importiert Godot die Modelle und Texturen. Das dauert ein paar Minuten.

## Steuerung

| Taste | Aktion |
|---|---|
| W A S D | Laufen |
| Shift | Sprinten |
| Leertaste | Springen; halten und vorwärts an Fels zum Klettern |
| Strg | Ducken |
| Alt | Ausweichen |
| E | Benutzen, reden, Türen öffnen |
| Linke / rechte Maustaste | Schießen / Zielen |
| R | Nachladen |
| 1–6, Mausrad | Waffe wählen |
| F | Taschenlampe (im Creator-Modus: fliegen) |
| Tab / I | Inventar |
| J / L / M | Tagebuch / Aufträge / Karte |
| F5 / F9 | Schnellspeichern / Schnellladen |
| Esc | Menü |

Controller werden ebenfalls unterstützt.

## Projektaufbau

```
ai/         Gegner, Bosse, Bewohner, Tiere
builders/   Modelle aus Code (Häuser, Einrichtung, Menschen, Requisiten)
combat/     Waffen, Treffer, Effekte, Sound-Synthese
core/       Spielstand, Aufträge, Handel, Einstellungen, Spielmodi
player/     Spieler, Inventar, Werte
ui/         HUD, Menüs, Story-Karten
vehicles/   Fahrzeuge
world/      Gelände, Orte, Wetter, Horror-Handlung, Tests
assets/     3D-Modelle und Texturen
docs/GDD.md Game Design Document (Deutsch)
```

Ein Großteil der Grafik und alle Töne entstehen im Code (prozedurale Meshes, Shader, Synth-Audio). Die übrigen Modelle liegen in `assets/`.

## Automatische Tests

Ein Testroboter prüft das Spiel ohne echtes Spielen:

```bash
godot --headless --path . -- --playtest --reachtest
godot --headless --path . -- --horror --playtest --reachtest
godot --headless --path . -- --playtest --doorwalk
godot --path . -- --storytest
```

`--reachtest` prüft für jeden Story-Schritt, ob ein Spieler das Ziel zu Fuß oder kletternd erreichen kann. Mit `--reachfrom=main_4 --reachto=main_5` testet er nur einen Kapitelbereich. Weitere Tests sind in `docs/GDD.md` beschrieben.

## Quellen

- 3D-Scans und Texturen: [Poly Haven](https://polyhaven.com) (CC0)
- Menschen: erstellt mit [MakeHuman / MPFB](https://static.makehumancommunity.org) (CC0)
- Häuser, Waffen und Möbel: selbst in Blender gebaut
- Engine: [Godot Engine](https://godotengine.org) (MIT)
