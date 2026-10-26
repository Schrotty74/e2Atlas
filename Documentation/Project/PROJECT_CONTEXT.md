# Projektkontext – e2Atlas

## Aktueller Stand – 26. Oktober 2026

- Auf ausdrücklichen Nutzerauftrag wird Final direkt aus dem aktuellen Dev-Build-55-Quellstand erstellt und als reguläres GitHub-Release veröffentlicht. Diese Quellenwahl ersetzt für diesen Auftrag die sonst vorgesehene Übernahme aus Beta. Dev bleibt lokal; seine Historie wird nicht veröffentlicht.
- Ziel: 1.0.0-final, Build 1, App e2Atlas, Bundle-ID io.github.schrotty74.e2atlas, Release-Konfiguration auf main. Der zusätzliche lokale Final-Checkout liegt unter `Local/Channels/Final`; fertige App unter `Build/Final/e2Atlas.app`. Build, Paketprüfung und Veröffentlichung stehen noch aus.
- Beta 0.5.0-beta, Build 5, bleibt unverändert auf f98575f; Tag v0.5.0-beta verweist auf 9c728a1. main stand vor dem Final-Auftrag auf 1af31eb mit ursprünglicher README und LICENSE. Der Final-Auftrag erlaubt die erforderlichen main-Änderungen, keine sonstigen Branch-Eingriffe.

## Funktionen und Plattform

Native SwiftUI-App für Apple Silicon ab macOS 26. Entwicklung und bisherige Prüfungen auf macOS 27 mit Xcode 27. Funktionen: Live-TV, bis zu vier Multiview-Bilder mit einer Tonquelle, sieben Tage EPG mit Speicher-/Dateicache, Jetzt und danach mit Erhalt bei Ansichtswechseln und senderweisem Nachladen an Sendungsgrenzen, Favoriten, Receiver-Timer, unterstützte AutoTimer-Regeln, EPGRefresh, Receiver-Aufnahmenbibliothek und Speicheranzeige, lokale Streamaufnahme, Erinnerungen, Themes sowie Einstellungsexport/-import mit Vorschau.

Die Wiedergabebedienleiste liegt unter dem Bild. Video-Vollbild ist ein Symbol mit Tooltip und Accessibility-Namen; der native Fenstermodus ist getrennt benannt. Alle 111 app-eigenen Button-Definitionen tragen native Aktionshilfen auf Deutsch und Englisch. macOS darf Tooltips über den Fensterrand hinaus anzeigen; dieses native Verhalten wurde besprochen und bleibt erhalten. Der Nutzer bestätigt die Symbolanzeige und Hilfen im normalen Betrieb.

## Module und Daten

- AtlasCore: Modelle, Einstellungen, atomare Speicherung, Programm- und Zeitfensterlogik.
- AtlasReceiver: OpenWebif, Receiver-Informationen, Sender, EPG, Timer, AutoTimer, EPGRefresh und Aufnahmedaten.
- AtlasPlayback: unabhängige Wiedergabeplätze mit VLCKit beziehungsweise AVPlayer. Die VLCVideoView bleibt beim Wechsel in Video-Vollbild bestehen.
- AtlasRecording: lokale Aufnahme des Originalstreams. AtlasThemes: validierte, versionierte JSON-Themes. e2Atlas: SwiftUI-Oberfläche und App-Zustand.

Dev, Beta und Final behalten getrennte Einstellungen, Caches, Themes und Schlüsselbund-Services. Nur die Dev-Bundle-ID wird auf ihren älteren Dev-Speicher io.github.schrotty74.e2atlas.dev abgebildet. Final verwendet io.github.schrotty74.e2atlas ohne Umleitung. Keine automatischen Kopien von Nutzerprofilen oder Passwörtern. Bewusster Export/Import überträgt Einstellungen, Favoriten, Belegungen und gültige eigene Themes; Passwörter, Erinnerungen, Wiedergabepositionen, Aufnahmen, Ordnerfreigaben und EPG-Caches sind ausgeschlossen. Backups enthalten Adressen und Benutzernamen.

OpenWebif- und Streaming-Anmeldung hängen von der Receiver-Konfiguration ab. Der Nutzer bestätigt Live-Streams, Aufnahmeliste und SSD-Anzeige ohne Zugangsdaten; daraus folgt keine allgemeine Garantie für geschützte Receiver oder Aufnahme-Wiedergabe. API-Zugangsdaten gehen nur an den konfigurierten Ursprung, fremde Weiterleitungen werden abgelehnt. HTTPS nutzt System-Zertifikatsprüfung; HTTP bleibt unverschlüsselt unterstützt.

## Build und Veröffentlichung

Final-Xcode-Projekt und Generator verwenden e2Atlas, Final-Kennung, Version 1.0.0-final und Build 1; Start- und Standardkonfiguration sind Release. `Scripts/build_final_app.sh` baut ausschließlich Final; `Scripts/package-final.sh 1.0.0-final 1` baut und paketiert einen sauberen, committed main-Checkout als ZIP/DMG mit SHA256SUMS. Skripte veröffentlichen nicht selbst.

Final-Tags vX.Y.Z-final müssen beim Push auf den aktuellen main-Commit zeigen; Beta-/Beta-Bugfix-Tags bleiben an den Beta-Branch gebunden. Positivliste und ausgehende Historie werden vom aktivierten Pre-Push-Hook geprüft. Final ist ad-hoc signiert und nicht notarisiert; keine Zertifikate oder Zugriffsfreigaben wurden angelegt. Die Versionsbezeichnung ist kein Nachweis vollständiger Plattform-/Hardwarevalidierung.

## Belegte Prüfungen und Bestätigungen

- 26. Oktober: 34 gezielte Tests in drei Suites in der Release-Konfiguration bestanden (Einstellungen einschließlich Kanalidentität, Zugangsdaten-Sitzungsverhalten, Einstellungssicherung/-import). Log im lokalen Gesamtprojekt: `Build/Logs/Tests/run-20261026T051124642876Z-bfa98a2c.log`. Kein vollständiger Gesamttestlauf.
- Final-Testprodukt besitzt die vorgesehenen Namen, Kennungen und Versionswerte. Quellen, Tests und Ressourcen entsprechen Dev 55 bytegleich. Beide Sprachen im Textkatalog vollständig. Final-App-Build und Paketprüfung folgen noch.
- Dev 55: ein erfolgreicher Build mit Signaturprüfung, statische Abdeckung aller Button-Hilfen sowie native Demo-Prüfung von Symbolanzeige und hinterlegten Hilfetexten einschließlich Ton-Zustandswechsel. Dev 54 bestätigte TV-/Vierfach-Multiview-Leiste, Video-Vollbild und Escape. Nutzer bestätigt neuen Aufbau und Tooltips. Keine neue Behauptung eines vollständigen Hover- oder Fenstergrößentests.
- Frühere Nutzerbestätigungen: grundsätzlicher Dev-Betrieb, schneller EPG, AutoTimer-Bedienung, Erinnerungszustellung bei offener und geschlossener App, Export, Now/Next ohne erneutes Laden bei Ansichtwechsel sowie senderweises Nachladen nach Sendungsende. Offene Validierungen stehen in NEXT_STEPS.md.

## Zukünftige Option

Ein Dateibereich für Transfers zwischen Mac und Receiver und später ein Texteditor für Konfigurationsdateien sind auf Nutzerwunsch vorgemerkt. Sicherung vor Änderungen und Erkennung zwischenzeitlicher Änderungen wären erforderlich. Protokoll (SFTP, FTP oder SMB) und Umgang mit von Enigma2 verwalteten Dateien sind offen. Es besteht kein Umsetzungsauftrag für diese Option.
