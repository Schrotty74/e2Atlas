# Eigene Themes für e2Atlas erstellen

[English](README.md) · [Zur Startseite](../../README.de.md) · [JSON-Vorlage herunterladen](theme-template.json?raw=true)

Ein e2Atlas-Theme ist eine JSON-Datei mit einer hellen und einer dunklen Farbpalette. Mit „Automatisch“ folgt die App der macOS-Darstellung. „Hell“ und „Dunkel“ verwenden die jeweilige Palette dauerhaft.

## Unterstützte Funktionen

Die [Version 0.2.0-beta](https://github.com/Schrotty74/e2Atlas/releases/tag/v0.2.0-beta) unterstützt eigene JSON-Themes, diagonale Hintergrundverläufe und mehrere Theme-Dateien. Wähle in **Einstellungen → Darstellung** den Button **Theme-Vorlage erstellen**. Die App legt eine JSON-Vorlage und eine Anleitung im Theme-Ordner an. Bestehende Dateien bleiben erhalten. Solange die Darstellungseinstellungen geöffnet sind, wird die Liste alle zwei Sekunden aktualisiert.

Mitgeliefert werden System, Ocean, Elfenbein und Bronze. Jedes Farb-Theme enthält eine helle und eine dunkle Palette. Ocean verwendet Blau- und Cyanverläufe; auch Elfenbein und Bronze haben eigene Verläufe.

Ab 0.5.0-beta können Einstellungs-Backups gültige eigene Themes enthalten.

## Eigenes Theme anlegen

1. Öffne in e2Atlas **Einstellungen → Darstellung → Theme-Vorlage erstellen**. Die App legt eine JSON-Datei und eine Anleitung im richtigen Ordner an. Alternativ kannst du die [Vorlage](theme-template.json?raw=true) herunterladen und **Einstellungen → Darstellung → Theme-Ordner öffnen** wählen.
2. Öffne die JSON-Datei in einem Texteditor. Wenn du TextEdit verwendest, wähle **Format → In reinen Text umwandeln** und speichere als UTF-8-Text.
3. Ändere `id`, `name` und die gewünschten Farben. Speichere die Datei mit der Endung `.json`. Dateien in Unterordnern werden nicht eingelesen.
4. Kehre zu den Darstellungseinstellungen zurück. Die Liste aktualisiert sich, solange der Bereich geöffnet ist. Wähle dort dein Theme aus.

Jeder Klick auf den Vorlagen-Button erzeugt einen neuen Dateinamen und eine neue Kennung. Vorhandene Dateien werden nicht überschrieben.

## Aufbau der JSON-Datei

Die [vollständige Vorlage](theme-template.json) enthält alle Pflichtfelder. Passe zunächst diese Angaben an:

```json
"version": 1,
"id": "mein-meer",
"name": "Mein Meer"
```

Dieser Ausschnitt zeigt nur die Kopfzeilen. Verwende für eine vollständige Datei die verlinkte Vorlage.

| Feld | Bedeutung |
| --- | --- |
| `version` | Formatversion, derzeit `1` |
| `id` | Eindeutige Kennung: 2 bis 48 Zeichen, beginnend mit einem Kleinbuchstaben; danach Kleinbuchstaben, Ziffern und Bindestriche |
| `name` | Anzeigename mit 1 bis 60 Zeichen |
| `light` | Palette für die helle Darstellung |
| `dark` | Palette für die dunkle Darstellung |

Verwende keine Kennungen der mitgelieferten Themes: `system`, `ocean`, `ivory` und `bronze`. Diese Kennungen haben Vorrang. Bei gleichen eigenen IDs wird die alphabetisch erste Datei verwendet. Gib jeder eigenen Datei eine eindeutige Kennung; unterschiedliche Dateinamen reichen nicht.

## Farben und Verlauf einstellen

Beide Paletten enthalten dieselben sechs Pflichtfelder:

| Feld | Verwendung |
| --- | --- |
| `background` | Hintergrundfarbe oder Beginn des Verlaufs |
| `surface` | Karten und Programmflächen |
| `accent` | Bedienelemente und aktive Markierungen |
| `text` | Haupttext |
| `secondary` | Ergänzende Texte |
| `selection` | Ausgewählte Programme |

Farben werden als sechsstelliger Hexwert mit `#` geschrieben, etwa `#127CA6`. Kurzformen wie `#FFF` und Transparenzwerte werden nicht unterstützt. JSON erlaubt keine Kommentare und kein Komma nach dem letzten Eintrag.

Das optionale Feld `backgroundEnd` gibt die zweite Farbe eines diagonalen Verlaufs an. Zwei ähnliche Farbtöne ergeben einen dezenten Übergang. Entferne das Feld aus beiden Paletten, wenn du einen einfarbigen Hintergrund möchtest.

Wähle in `light` dunkle Schrift auf hellen Flächen und in `dark` helle Schrift auf dunklen Flächen. Prüfe beide Darstellungen und die Lesbarkeit ausgewählter Programme. Videos behalten ihren schwarzen Hintergrund. Native Fensterteile und Liquid Glass werden weiterhin von macOS gezeichnet; ein Theme ersetzt nicht jede Systemfarbe.

## Mehrere Themes verwenden

Lege mehrere `.json`-Dateien direkt in den Theme-Ordner. Jede Datei braucht eine eigene `id` und einen erkennbaren `name`. Gültige Dateien erscheinen nach der Aktualisierung einzeln in der Auswahl.

Dev, Beta und Final haben getrennte Theme-Ordner und Caches. Öffne den Ordner aus der App, in der du das Theme verwenden möchtest.

## Wenn ein Theme nicht erscheint

- Prüfe Dateiendung, UTF-8-Format und gültige JSON-Syntax.
- Vergleiche alle Pflichtfelder mit der Vorlage und verwende `version: 1`.
- Prüfe Kennung, Namen und Farben. Die Datei darf höchstens 64 KiB groß sein.
- Vermeide reservierte oder doppelte Kennungen.

Ungültige Dateien werden übersprungen und in den Einstellungen gezählt. Der Katalog zählt auch doppelte Kennungen und wechselt auf System, wenn das ausgewählte Theme entfernt oder ungültig wird.

Theme-Dateien enthalten nur Darstellungsdaten. Trage darin keine Passwörter, Receiver-Adressen oder anderen privaten Daten ein.
