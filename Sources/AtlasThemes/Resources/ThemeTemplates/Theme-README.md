# Eigene Themes für e2Atlas

Klicke in Einstellungen → Darstellung auf „Theme-Vorlage erstellen“. Die App legt eine neue JSON-Datei und diese Anleitung im Theme-Ordner an. Vorhandene Dateien werden nicht überschrieben.

Bearbeite die JSON-Datei mit einem Texteditor und speichere sie als reinen UTF-8-Text. Du kannst beliebig weitere Dateien mit der Endung `.json` in denselben Ordner legen. Die Theme-Auswahl aktualisiert sich, solange die Darstellungseinstellungen geöffnet sind. „Themes neu laden“ liest die Dateien auch sofort neu ein.

## Aufbau

- `version`: derzeit immer `1`.
- `id`: eindeutige Kennung mit 2 bis 48 Zeichen. Beginne mit einem Kleinbuchstaben; danach sind Kleinbuchstaben, Ziffern und Bindestriche erlaubt. `system`, `ocean`, `ivory` und `bronze` sind reserviert. Jede Datei braucht eine eigene Kennung.
- `name`: sichtbarer Name mit 1 bis 60 Zeichen.
- `light` und `dark`: Farbpaletten für die helle und dunkle Darstellung. Die macOS-Einstellung beziehungsweise die gewählte Darstellung entscheidet, welche Palette verwendet wird.

Jede Palette enthält sechs Pflichtfelder:

| Feld | Verwendung |
| --- | --- |
| `background` | Hintergrundfarbe beziehungsweise Beginn des Verlaufs |
| `surface` | Karten, Programmfelder und weitere Flächen |
| `accent` | Bedienelemente und aktive Markierungen |
| `text` | Haupttext |
| `secondary` | Ergänzende Texte |
| `selection` | Ausgewählte Programme |

Das optionale Feld `backgroundEnd` legt die zweite Farbe eines dezenten diagonalen Hintergrundverlaufs fest. Ohne dieses Feld bleibt der Hintergrund einfarbig. Farben werden als `#RRGGBB` angegeben, beispielsweise `#127CA6`. Transparenzwerte, Kommentare und zusätzliche Kommata sind in dieser JSON-Vorlage nicht zulässig.

Halte den Kontrast zwischen Text und Hintergrund ausreichend hoch und prüfe beide Darstellungen. Videos behalten ihren schwarzen Hintergrund; Systemfenster und Liquid Glass werden weiterhin von macOS gezeichnet.

## Mehrere Dateien und Fehler

Gültige Dateien erscheinen einzeln in der Theme-Auswahl. Mitgelieferte Themes haben Vorrang. Bei doppelten eigenen Kennungen gewinnt die erste Datei in alphabetischer Reihenfolge. Gib Kopien deshalb eine neue `id` und einen neuen `name`.

Die App überspringt ungültige Dateien, unbekannte Formatversionen und Dateien über 64 KiB. Sie zeigt die Zahl der übersprungenen Dateien an. Wird das ausgewählte Theme entfernt oder ungültig, wechselt die App in diesen Einstellungen auf System. Lege keine Passwörter, Receiver-Adressen oder anderen privaten Daten in Theme-Dateien ab.

Der Ordner wird pro App-Kanal über die macOS-Datenverzeichnisse ermittelt. Dev, Beta und Final haben getrennte Theme-Ordner. Über „Theme-Ordner öffnen“ erreichst du den richtigen Ordner, unabhängig davon, wo die App installiert ist.
