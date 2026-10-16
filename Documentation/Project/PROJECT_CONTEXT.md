# Projektkontext – e2Atlas

Stand: 16. Oktober 2026. Quellcode und tatsächlich ausgeführte Prüfungen sind maßgeblich. Ein Downloadpaket kann älter sein als der aktuelle Branch.

## Produkt und Plattform

e2Atlas ist eine native SwiftUI-App für Live-TV von Enigma2-Receivern über OpenWebif. Unterstützt werden Apple Silicon und macOS 26 oder neuer. Entwicklung und bisherige Prüfungen liefen mit Xcode 27 auf macOS 27.0.1. Ein Lauf auf macOS 26 steht aus.

Die Gestaltung verbindet Kino und Regie mit einer eigenen Programmansicht. Liquid Glass wird für Bedienelemente verwendet. Automatische, helle und dunkle Darstellung sowie System- und Ocean-Theme sind vorhanden. Das Kino-App-Icon liegt als bearbeitbare Icon-Composer-Datei unter `Resources/AppIcon.icon` vor; Xcode kompiliert die Varianten.

## Implementierte Funktionen und Module

- `Sources/AtlasCore`: gemeinsame Modelle, validierte Einstellungen, atomare Speicherung, EPG-Zeitfenster.
- `Sources/AtlasReceiver`: OpenWebif-Verifikation, Bouquets, Sender, EPG, Picons und Stream-Adressen.
- `Sources/AtlasPlayback`: unabhängige Wiedergabeplätze; VLCKit für allgemeine und authentifizierte Streams, AVPlayer für nicht authentifizierte HLS-Streams.
- `Sources/AtlasThemes`: versionierte JSON-Themes mit Validierung und System-Theme als Rückfall.
- `Sources/e2Atlas`: SwiftUI-App, Einrichtung, Einstellungen, Fernsehen, Multiview und Programmführer.

Bis zu drei Receiver, Sendersuche und Senderlogos vom Receiver werden unterstützt. Multiview zeigt bis zu vier Bilder mit höchstens einer Tonquelle. Stummschaltung und Lautstärke bleiben bei Senderwechseln erhalten. Der Programmführer bietet 2-, 4- und 6-Stunden-Fenster, 20:15 und eigene Zeitkürzel. Aufnahme- und Timer-Verwaltung fehlen.

Benutzername und Passwort dürfen leer bleiben, wenn der Receiver keine Anmeldung verlangt. OpenWebif liefert Daten und Logos, der Streaming-Dienst Bild und Ton. Ob ein Anmeldeschutz aktiv ist, hängt von der Receiver-Konfiguration ab.

## Wiedergabe und behobene Fehler

Der Ladekreis verschwindet nach tatsächlicher Bildausgabe, auch wenn VLC noch Buffering meldet. Senderwechsel und Stoppen setzen den Zustand pro Wiedergabeplatz zurück.

„Nur Video“ zeigt einen ausgewählten Wiedergabeplatz ohne App-Bedienung. Escape, Doppelklick oder Kontextmenü führen zurück. Command–Shift–F aktiviert den Modus. Ein zuvor aktives natives App-Vollbild bleibt erhalten.

Der Schwarzbildfehler beim Wechsel in den Nur-Video-Modus ließ sich mit synthetischen VLC-Clips reproduzieren und wurde korrigiert. Die `VLCVideoView` bleibt pro Wiedergabeplatz bestehen. SwiftUI-Wrapper übernehmen sie ausschließlich in `makeNSView`, nicht erneut in `updateNSView`; alte Wrapper dürfen sie nicht vom neuen Container lösen. Ein Regressionstest prüft wiederholte Containerwechsel bei laufender Wiedergabe.

## Zugangsdaten und Netzwerk

Passwörter liegen im macOS-Schlüsselbund; erfolgreich gelesene Werte werden während der Sitzung im Speicher gehalten. Unveränderte Passwörter werden nicht erneut geschrieben. Abgewiesene Zugriffe ersetzen keine gespeicherten Zugangsdaten. Namen, Adressen, Benutzernamen und Anzeigeeinstellungen liegen in Application Support.

Der API-Client verwendet eine flüchtige URLSession, HTTP-Basic-Challenges für den konfigurierten Ursprung und lehnt fremde Weiterleitungsziele ab. HTTPS nutzt die normale System-Zertifikatsprüfung. HTTP bleibt für Receiver-Kompatibilität zulässig und ist unverschlüsselt. Die Netzwerklogik der Wiedergabe-Engines ist getrennt vom API-Client zu beurteilen.

Ad-hoc-Builds können erneut Schlüsselbund-Freigaben auslösen. Sitzungscache und `LAContext.interactionNotAllowed` sind kein belegter Ersatz für eine stabile Signieridentität. Die wiederkehrende Abfrage ist noch nicht vollständig behoben. `E2ATLAS_SIGNING_IDENTITY` kann ein bereits vorhandenes Zertifikat auswählen; ohne Vorgabe bleibt Ad-hoc. Zertifikate und Freigaben nicht eigenmächtig ändern.

## Build und Veröffentlichung

Alle Einstiegsskripte liegen in `Scripts/` und ermitteln den Projektordner aus ihrer eigenen Position. Xcode-Projekt und SwiftPM-Manifest beschreiben dieselben Module. `Scripts/generate-project.py` regeneriert das Xcode-Projekt; `Scripts/test.sh` verwendet Xcode, weil SwiftPM beim VLCKit-Testbundle eine Laufzeitladegrenze hat.

| Kanal | App | Bundle-ID | Ausgabe |
| --- | --- | --- | --- |
| Dev | e2Atlas Dev | io.github.schrotty74.e2atlas.dev | `Build/Dev/` |
| Beta | e2Atlas Beta | io.github.schrotty74.e2atlas.beta | `Build/Beta/` |
| Final | e2Atlas | io.github.schrotty74.e2atlas | `Build/Final/` |

Dev bleibt lokal. Beta verlangt einen getrennten Checkout auf `beta`, Final auf `main`. Der lokale Dev-Stand funktioniert auch ohne Git. Build und Paketierung veröffentlichen nichts automatisch.

VLCKit 3.7.3 wird projektgebunden von VideoLAN geladen und vor Extraktion gegen eine festgelegte SHA-256-Prüfsumme geprüft. Es wird als austauschbares dynamisches Framework unter LGPL eingebunden. Die App steht unter GPL v3.

`Scripts/package-beta.sh` erstellt ZIP, DMG und Prüfsummen aus einem sauberen Beta-Checkout. Es prüft Version, Kanal, Architektur und lokale Entwicklungspfade im eigenen Release-Programm. Release-Ausgaben werden nicht überschrieben.

`Scripts/check-public-tree.sh` prüft eine Positivliste. Der Pre-Push-Hook begrenzt Branches, Zielrepository und unterstützte Beta-Tags und prüft ausgehende Historie. Auf einem neuen Mac ist die repository-lokale Aktivierung mit `git config core.hooksPath Scripts/git-hooks` erforderlich. Vor jedem Push dessen tatsächliche Aktivierung prüfen. Final-Paketierung und Final-Tags sind noch nicht implementiert.

## Bisherige Prüfungen und Release-Stand

Die erste Beta `0.1.0-beta.1` wurde am 15. Oktober 2026 veröffentlicht. Der Tag `v0.1.0-beta.1` zeigt auf `e585abd77d2dfc9c2b1fb70da4edef417c0f4ed7`. Spätere Branch-Commits ändern dieses Paket nicht. Download: https://github.com/Schrotty74/e2Atlas/releases/tag/v0.1.0-beta.1

Alle 36 Xcode-Tests in sieben Suites bestanden für diese Beta. ZIP-Inhalt, App-Signatur und DMG wurden geprüft; veröffentlichte Dateigrößen und SHA-256-Digests stimmten mit den vorbereiteten Paketen überein. Die App ist ad-hoc signiert und nicht notarisiert.

Native Bedienungsprüfungen mit synthetischen Inhalten deckten Einrichtung, Multiview, EPG, Zeitkürzel, Tonsteuerung und Nur-Video-Wechsel ab. Live-TV wurde zusätzlich an einem realen Receiver bestätigt. Das ist kein vollständiger eigener Hardwaretest oder Nachweis für alle Images. macOS 26 und weitere Receiver-Images bleiben offen.

## Änderungsprotokoll

- 15. Oktober 2026, Beta 1: erste Veröffentlichung mit 36 erfolgreichen Xcode-Tests und geprüften Downloadpaketen.
- 15. Oktober 2026, Beta-Branch: englische und deutsche README sowie SECURITY, Icon und kompakte Bildvorschauen veröffentlicht. Receiver-Abbildung anonymisiert, PNG-Metadaten entfernt. Skripte nach `Scripts/` verschoben. Beta-Build aus frischer Projektkopie mit Leerzeichen im Ordnernamen erfolgreich. Downloadpaket unverändert.
- 15. Oktober 2026, Kontextpflege: vier bereinigte Kontextdateien unter `Documentation/Project/` zusammengeführt, Root-Einstieg für Codex ergänzt und Pflege nach jedem Build sowie Veröffentlichung nach beauftragten Beta-/Final-Releases festgelegt. Nur Dokumentation und Upload-Positivliste geändert; kein neuer App-Build.

## Öffentliche Theme-Dokumentation

`Documentation/Themes/README.md` und `README.de.md` erklären das Erstellen eigener Themes, alle Felder, getrennte Paletten, mehrere Dateien, Fehler und Kanalordner. `Documentation/Themes/theme-template.json` ist die herunterladbare Vorlage. Beide Startseiten verlinken die passende Sprache. Die Anleitung unterscheidet die manuelle JSON-Unterstützung in Beta 1 von den noch nicht veröffentlichten Erweiterungen für Vorlagen-Button, Verlauf und weitere mitgelieferte Themes. Beta-Quellcode und Downloadpaket wurden für diese Dokumentationsveröffentlichung nicht ersetzt.

- 16. Oktober 2026, Beta-Dokumentation: zweisprachige Theme-Anleitung und JSON-Vorlage für die Veröffentlichung vorbereitet; Links, JSON-Format und private Angaben geprüft. Sprachlich passende Humanizer angewendet. Kein neuer Beta-Build und keine Übernahme des lokalen Dev-Codes.
