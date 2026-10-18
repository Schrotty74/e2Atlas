<p align="center"><img src="Documentation/Images/AppIcon.png" width="128" height="128" alt="App-Icon von e2Atlas für macOS"></p>
<p align="center"><a href="README.md">English</a> · <strong>Deutsch</strong></p>

# e2Atlas — Enigma2-TV-Player für macOS

Mit e2Atlas siehst du Live-TV von deinem Enigma2-Receiver auf dem Mac. Die Verbindung läuft über OpenWebif. Du kannst einen Sender ansehen, bis zu vier Programme im Multiview verfolgen oder im elektronischen Programmführer stöbern, während das Fernsehbild sichtbar bleibt. Die native SwiftUI-Oberfläche nutzt Liquid Glass für Bedienelemente und folgt der hellen oder dunklen Darstellung deines Mac.

**Voraussetzungen: ein Mac mit Apple Silicon (M1 oder neuer), macOS 26 oder neuer und ein Enigma2-Receiver mit erreichbarem OpenWebif und Streaming-Dienst.** Die aktuelle Version ist **0.3.0-beta**. Intel-Macs werden nicht unterstützt.

[Beta herunterladen](https://github.com/Schrotty74/e2Atlas/releases/tag/v0.3.0-beta) · [Changelog auf Englisch](CHANGELOG.md) · [Sicherheitsrichtlinie](SECURITY.de.md)

## Funktionen

- Deutsche und englische Oberfläche mit Sprachwahl im Menü Sprache und in den Darstellungseinstellungen. Native macOS-Menüs übernehmen die Wahl nach erneutem Öffnen.
- Receiver-Aufnahmetimer aus dem Programmführer anlegen, auflisten, unterstützte Einzelaufnahmen bearbeiten und nach Bestätigung löschen.
- Multiview-Belegungen je Receiver samt Toneinstellungen speichern. Beim Laden starten die Streams schrittweise.
- Geladene Sendungstitel und Beschreibungen durchsuchen, den Sendungsfortschritt ansehen und weitere geladene Ausstrahlungen derselben Sendung finden.
- Aufnahmeordner, Dauerbegrenzung und Stopp bei wenig Speicherplatz sowie ein Sleep-Timer, der die Wiedergabe beendet und lokale Aufnahmen weiterlaufen lässt.
- Wahlweise beim Start automatisch verbinden, einstellbar unter Einstellungen → Receiver. Begrenzte Wiederholungen bei nicht erreichbaren Diensten und unabhängige Wiederverbindung der Wiedergabeplätze.
- Schließen des Hauptfensters beendet die App vollständig.
- Live-TV mit Bouquets, Sendersuche und Senderlogos direkt vom Receiver.
- Multiview mit zwei, drei oder vier Bildern und einer ausgewählten Tonquelle. Ein kleines Bild lässt sich mit dem Hauptbild tauschen; Audio und Lautstärke bleiben beim jeweiligen Player.
- Stummschaltung und Lautstärkeregler sowie reines Video-Vollbild mit Rückkehr per Escape oder Doppelklick.
- Elektronischer Programmführer (EPG) mit 2-, 4- und 6-Stunden-Ansicht, Sprung zu 20:15 Uhr und eigenen Zeitkürzeln.
- Receiver-Info mit gemeldeten Hardware- und Systemdaten. Die Ansicht zeigt bestätigte Tunernutzung und zählt Streams ohne verwendbare Tuner-Zuordnung separat. Die gesamte Belegung kann unbekannt bleiben, auch bei FBC-Receivern.
- Den Originalstream des Receivers als lokale `.ts`-Datei aufnehmen. Die Aufnahme lässt sich im Player und in kleinen Multiview-Bildern starten, in der App stoppen und anschließend im Finder anzeigen.
- Bis zu drei gespeicherte Receiver. Benutzername und Passwort sind optional, wenn der Receiver keinen Zugangsschutz verlangt. Passwörter liegen im macOS-Schlüsselbund.
- Neben dem System-Theme gibt es Ocean, Elfenbein und Bronze mit jeweils heller und dunkler Palette. Du kannst automatisch der macOS-Darstellung folgen oder Hell und Dunkel manuell wählen. In den Darstellungseinstellungen lässt sich eine JSON-Vorlage erstellen.
- Der About-Tab verlinkt auf die Homepage und das GitHub-Repository.
- Die Wiedergabe fordert VideoToolbox an, wenn Codec und Mac dies unterstützen. Die Wiedergabebibliothek kann auf Software-Decodierung zurückfallen. Hardware-Nutzung und CPU-Auswirkung wurden nicht gemessen.

## Eigene Themes

[Erstelle dein eigenes Theme](Documentation/Themes/README.de.md) mit der [JSON-Vorlage](Documentation/Themes/theme-template.json?raw=true). Die Anleitung behandelt helle und dunkle Paletten, Verläufe, mehrere Theme-Dateien und den Button zum Erstellen einer Vorlage.

## Screenshots

Ein Klick auf eine Vorschau öffnet das Bild in voller Auflösung. Die Bilder zeigen die aktuelle deutsche Oberfläche; die Receiver-Adresse wurde anonymisiert.

<table>
<tr>
<td align="center"><a href="Documentation/Screenshots/full/live-tv.png?raw=true"><img src="Documentation/Screenshots/previews/live-tv.png" width="320" alt="Live-TV mit e2Atlas auf macOS, Senderlogos vom Receiver und Lautstärkeregler"></a><br>Live-TV</td>
<td align="center"><a href="Documentation/Screenshots/full/multiview.png?raw=true"><img src="Documentation/Screenshots/previews/multiview.png" width="320" alt="Enigma2-Multiview in e2Atlas mit vier TV-Streams und einer aktiven Tonquelle"></a><br>Multiview mit vier Sendern</td>
</tr>
<tr>
<td align="center"><a href="Documentation/Screenshots/full/programme-guide.png?raw=true"><img src="Documentation/Screenshots/previews/programme-guide.png" width="320" alt="Elektronischer Programmführer von e2Atlas mit Zwei-Stunden-Ansicht und Live-TV-Vorschau"></a><br>Elektronischer Programmführer</td>
<td align="center"><a href="Documentation/Screenshots/full/receivers.png?raw=true"><img src="Documentation/Screenshots/previews/receivers.png" width="320" alt="Receiver-Einstellungen von e2Atlas mit anonymisierter Adresse und Platz für drei Geräte"></a><br>Receiver-Einstellungen</td>
</tr>
<tr>
<td colspan="2" align="center"><a href="Documentation/Screenshots/full/welcome.png?raw=true"><img src="Documentation/Screenshots/previews/welcome.png" width="320" alt="Willkommensfenster von e2Atlas zum Verbinden eines Enigma2-Receivers über OpenWebif"></a><br>Ersteinrichtung</td>
</tr>
</table>

## Beta installieren und öffnen

Lade das DMG oder ZIP aus dem [offiziellen GitHub-Release](https://github.com/Schrotty74/e2Atlas/releases/tag/v0.3.0-beta). Öffne das DMG und ziehe **e2Atlas Beta** nach **Programme**. Beim ZIP entpackst du zuerst die Datei und verschiebst die App anschließend dorthin.

### Erster Start: Gatekeeper

e2Atlas Beta ist ad-hoc signiert. Die App hat kein Apple-Developer-ID-Zertifikat und ist nicht notarisiert. Deshalb kann macOS den ersten Start blockieren. Wenn du dem offiziellen Download vertraust:

1. Versuche einmal, **e2Atlas Beta** zu öffnen.
2. Öffne **Systemeinstellungen → Datenschutz & Sicherheit** und scrolle zum Bereich **Sicherheit**.
3. Klicke bei e2Atlas Beta auf **Dennoch öffnen**.
4. Bestätige mit **Öffnen** und authentifiziere dich, falls macOS danach fragt.

Damit legst du eine Ausnahme für diese App an. [Apples Gatekeeper-Anleitung](https://support.apple.com/de-de/102445) beschreibt den Ablauf. Meldet macOS Schadsoftware oder eine beschädigte App, brich ab und prüfe den Download, statt diese Warnung zu umgehen.

## Receiver verbinden

Gib beim ersten Start einen Namen und die IP-Adresse oder den Hostnamen des Receivers ein. Benutzername und Passwort können leer bleiben, wenn der Receiver keinen Zugangsschutz verwendet. Ein geschützter Receiver kann gültige Zugangsdaten für Verbindung oder Stream verlangen. Nach dem Verbinden wählst du Bouquet und Sender. Weitere Receiver fügst du in den Einstellungen hinzu. Dev und Beta verwenden getrennte Einstellungen, Theme-Ordner und Caches. Ein Dev-Profil musst du daher in der Beta erneut eingeben.

Verwende den Receiver in einem vertrauenswürdigen lokalen Netzwerk. Bei einer einfachen HTTP-Verbindung werden Passwort und TV-Stream nicht verschlüsselt. Die Kompatibilität eines Receiver-Images hängt von dessen OpenWebif- und Streaming-Diensten ab.

## Stand der Beta

Die lokale Aufnahme speichert den Originalstream als `.ts`-Datei. Receiver-Aufnahmetimer werden getrennt verwaltet; unbekannte und spezielle Timertypen bleiben schreibgeschützt. Das Anlegen wurde im Dev-Stand mit einem realen Receiver bestätigt; tatsächliche Aufnahmeausführung und weitere Images bleiben zu prüfen. Schlüsselbund-Abfragen nach einem Neubuild werden weiterhin untersucht; geschützte Receiver benötigen möglicherweise Zugriff auf gespeicherte Zugangsdaten. Die Wiedergabe fordert VideoToolbox an, wenn sie unterstützt wird. Hardware-Decodierung und CPU-Auswirkung wurden nicht gemessen. Wiedergabeprüfungen und automatische Tests liefen auf macOS 27; Tests auf macOS 26 und mit weiteren Receiver-Images stehen aus. Einzelheiten findest du im [englischen Changelog](CHANGELOG.md).

<details>
<summary>e2Atlas aus dem Quellcode bauen</summary>

Installiere Xcode 27 und wähle dessen Kommandozeilenwerkzeuge aus. Danach:

```sh
git clone --branch beta https://github.com/Schrotty74/e2Atlas.git
cd e2Atlas
./Scripts/build_beta_app.sh
```

Die App entsteht unter `Build/Beta/e2Atlas Beta.app`. Die Skripte ermitteln den Projektordner aus ihrer eigenen Position. Du kannst den Checkout daher an einem beliebigen Ort speichern, auch in einem Pfad mit Leerzeichen. Der Build lädt VLCKit 3.7.3 von VideoLAN und prüft dessen SHA-256-Prüfsumme. Ein persönliches Signierzertifikat ist nicht erforderlich.

Zur Entwicklung öffnest du `e2Atlas.xcodeproj`. `Scripts/generate-project.py` erzeugt das Projekt neu; `Scripts/test.sh` führt die Tests über Xcode aus. Das SwiftPM-Manifest beschreibt die Module. Wegen des Ladens der VLCKit-Bibliothek ist Xcode der unterstützte Testweg.

Alle Build-Einstiege liegen in `Scripts/`. Beta-Builds verlangen einen Checkout auf `beta`, Final-Builds auf `main`. Dev bleibt lokal. `Scripts/package-beta.sh 0.3.0-beta` erstellt aus einem sauberen, committed Beta-Checkout ZIP und DMG samt Prüfsummen. Die Build- und Paketierungsskripte veröffentlichen keine Releases.

</details>

## Lizenz

e2Atlas steht unter der [GNU GPL v3](LICENSE). VLCKit wird als austauschbare dynamische Bibliothek unter LGPL-2.1-or-later eingebunden. Lizenz und Quellcode-Links liegen in `Resources` und in der App.
