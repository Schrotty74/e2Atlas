# Eigene Themes für e2Atlas erstellen

[English](README.md) · [Zur Startseite](../../README.de.md) · [JSON-Vorlage herunterladen](theme-template.json?raw=true)

Mit einer JSON-Datei legst du die Farben von e2Atlas fest. Jedes Theme enthält eine helle und eine dunkle Palette. Wenn du in der App „Automatisch“ wählst, folgt die Darstellung der macOS-Einstellung; „Hell“ und „Dunkel“ verwenden die jeweilige Palette dauerhaft.

## Welche Version unterstützt was?

Die veröffentlichte **Beta 1 (0.1.0-beta.1)** liest eigene JSON-Themes bereits ein. Verwende dort „Theme-Ordner öffnen“ und danach „Themes neu laden“. Den optionalen Verlauf ignoriert Beta 1; die übrigen Farben der Vorlage funktionieren.

Der Button „Theme-Vorlage erstellen“, die automatische Aktualisierung der Liste und Hintergrundverläufe sind im lokalen Dev-Build implementiert. Sie sind für eine spätere Beta vorgesehen und noch nicht im veröffentlichten Beta-1-Download enthalten. Das gilt auch für die neuen mitgelieferten Themes Elfenbein und Bronze. Die verfügbaren Downloads findest du bei den [Releases](https://github.com/Schrotty74/e2Atlas/releases).

## Mit der Vorlage beginnen

1. Lade die [Vorlage](theme-template.json?raw=true) herunter. Du kannst den Link auch mit der rechten Maustaste als Datei speichern. Die Datei muss auf `.json` enden, nicht auf `.json.txt`.
2. Öffne in e2Atlas **Einstellungen → Darstellung → Theme-Ordner öffnen**.
3. Kopiere die Vorlage direkt in diesen Ordner, beispielsweise als `mein-meer.json`. Dateien in Unterordnern werden nicht eingelesen.
4. Öffne sie in einem Texteditor. Wenn du TextEdit verwendest, wähle **Format → In reinen Text umwandeln**. Speichere als UTF-8-Text.
5. Ändere `id`, `name` und die gewünschten Farben. Speichere die Datei.
6. Klicke in Beta 1 auf **Themes neu laden** und wähle dein Theme im Feld **Theme** aus. In der erweiterten Theme-Verwaltung aktualisiert sich die Liste alle zwei Sekunden, solange die Darstellungseinstellungen geöffnet sind.

Wenn deine App bereits den Button „Theme-Vorlage erstellen“ anbietet, kannst du die ersten drei Schritte damit ersetzen. Der Button erstellt eine neue JSON-Datei und eine Anleitung im richtigen Ordner. Bestehende Dateien bleiben erhalten; weitere Klicks erzeugen eigene Kennungen und Dateinamen.

## Aufbau der JSON-Datei

Die [vollständige Vorlage](theme-template.json) enthält alle nötigen Felder. Passe zunächst diese Angaben an:

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

Verwende nicht die Kennungen mitgelieferter Themes: `system`, `ocean` und im erweiterten Stand auch `ivory` und `bronze`. Der erweiterte Katalog schützt diese Kennungen; Beta 1 schützt nur `system` ausdrücklich. Gib jeder eigenen Datei eine neue Kennung. Der Dateiname allein reicht nicht zur Unterscheidung.

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

Das optionale Feld `backgroundEnd` gibt die zweite Farbe eines diagonalen Verlaufs an. Verwende zwei nahe beieinanderliegende Farbtöne für einen leichten Verlauf. Entferne dieses Feld aus beiden Paletten, wenn du einen einfarbigen Hintergrund möchtest. Beta 1 ignoriert dieses Feld; der Verlauf benötigt die erweiterte Theme-Version.

Wähle in `light` dunkle Schrift auf hellen Flächen und in `dark` helle Schrift auf dunklen Flächen. Prüfe beide Darstellungen sowie die Lesbarkeit ausgewählter Programme. Videos behalten ihren schwarzen Hintergrund. Native Fensterteile und Liquid Glass werden weiterhin von macOS gezeichnet; ein Theme ersetzt nicht jede Systemfarbe.

## Mehrere Themes verwenden

Lege mehrere `.json`-Dateien direkt in den Theme-Ordner und gib jeder Datei eine eigene `id` sowie einen erkennbaren `name`. Nach dem Neuladen erscheinen gültige Dateien einzeln in der Auswahl.

Im erweiterten Theme-Katalog haben mitgelieferte Kennungen Vorrang. Bei doppelten eigenen IDs gewinnt die alphabetisch erste Datei. Vermeide doppelte Kennungen auch in Beta 1; die Reihenfolge ersetzt keine eindeutige ID.

Dev, Beta und Final haben getrennte Theme-Ordner. Öffne den Ordner immer aus der App, in der du das Theme verwenden möchtest. Dafür brauchst du keinen festen Installationspfad.

## Wenn ein Theme nicht erscheint

- Prüfe Dateiendung, UTF-8-Format und gültige JSON-Syntax.
- Vergleiche alle Pflichtfelder mit der Vorlage und verwende `version: 1`.
- Prüfe Kennung, Namen und alle Farben. Die Datei darf höchstens 64 KiB groß sein.
- Vermeide reservierte oder doppelte Kennungen. Klicke auf „Themes neu laden“.

Ungültige Dateien werden übersprungen; die Einstellungen zeigen ihre Anzahl. Die erweiterte Verwaltung zählt auch doppelte Kennungen und wechselt auf System, wenn das ausgewählte Theme entfernt oder ungültig wird.

Theme-Dateien enthalten nur Darstellungsdaten. Trage darin keine Passwörter, Receiver-Adressen oder anderen privaten Daten ein.
