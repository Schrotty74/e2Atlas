# Projektkontext – e2Atlas

## Aktueller Stand – 26. Oktober 2026

- Auf ausdrücklichen Nutzerauftrag wird Final direkt aus dem aktuellen Dev-Build-55-Quellstand erstellt und als reguläres GitHub-Release veröffentlicht. Diese Quellenwahl ersetzt für diesen Auftrag die sonst vorgesehene Übernahme aus Beta. Dev bleibt lokal; seine Historie wird nicht veröffentlicht.
- Ziel: 1.0.0-final, Build 1, App e2Atlas, Bundle-ID io.github.schrotty74.e2atlas, Release-Konfiguration auf main. Der zusätzliche lokale Final-Checkout liegt unter `Local/Channels/Final`; fertige App unter `Build/Final/e2Atlas.app`. Build, Start- und Paketprüfung bestanden; 1.0.0-final ist mit Tag v1.0.0-final, ZIP, DMG und SHA256SUMS als reguläres GitHub-Release veröffentlicht. Der Tag verweist auf 5d53575; nachfolgende Kontextpflege ergänzt nur Dokumentation.
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
- Final-Testprodukt besitzt die vorgesehenen Namen, Kennungen und Versionswerte. Quellen, Tests und Ressourcen entsprechen Dev 55 bytegleich. Beide Sprachen im Textkatalog vollständig. Final-App-Build und Paketprüfung bestanden nach der Signaturkorrektur.
- Dev 55: ein erfolgreicher Build mit Signaturprüfung, statische Abdeckung aller Button-Hilfen sowie native Demo-Prüfung von Symbolanzeige und hinterlegten Hilfetexten einschließlich Ton-Zustandswechsel. Dev 54 bestätigte TV-/Vierfach-Multiview-Leiste, Video-Vollbild und Escape. Nutzer bestätigt neuen Aufbau und Tooltips. Keine neue Behauptung eines vollständigen Hover- oder Fenstergrößentests.
- Frühere Nutzerbestätigungen: grundsätzlicher Dev-Betrieb, schneller EPG, AutoTimer-Bedienung, Erinnerungszustellung bei offener und geschlossener App, Export, Now/Next ohne erneutes Laden bei Ansichtwechsel sowie senderweises Nachladen nach Sendungsende. Offene Validierungen stehen in NEXT_STEPS.md.

## Zukünftige Option

Ein Dateibereich für Transfers zwischen Mac und Receiver und später ein Texteditor für Konfigurationsdateien sind auf Nutzerwunsch vorgemerkt. Sicherung vor Änderungen und Erkennung zwischenzeitlicher Änderungen wären erforderlich. Protokoll (SFTP, FTP oder SMB) und Umgang mit von Enigma2 verwalteten Dateien sind offen. Es besteht kein Umsetzungsauftrag für diese Option.


### Startfehler des ersten Final-Builds

- Der erste Final-Build 1 bestand Build, Metadaten-, Signatur-, ZIP-, DMG- und Prüfsummenprüfung, brach aber vor dem App-Start im dynamischen Lader ab. Der Nutzer meldete ebenfalls den Startfehler. Der Absturzbericht benennt VLCKit und Library Validation mit fehlender gemeinsamer Team-ID. Dev/Beta waren Debug-Builds ohne diese aktive Release-Laufzeitprüfung. Es wurde noch nichts gepusht oder veröffentlicht.
- Korrektur: Hardened Runtime bleibt aktiv. Ausschließlich ad-hoc signierte Final-Builds erhalten die für die austauschbare Medienbibliothek erforderliche Ausnahme com.apple.security.cs.disable-library-validation. Build und Paketierung müssen sie beide erhalten. Bei ausdrücklich vorgegebener Zertifikat-Signierung wird sie im Build nicht gesetzt. Keine Zertifikate, Schlüsselbunddaten oder Systemeinstellungen ändern. Unveröffentlichte fehlerhafte Pakete verworfen; erneuter Final-Build und tatsächlicher App-Start erforderlich.
- Grundlage: eigener DYLD-Absturzbericht und [Apple-Dokumentation](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.cs.disable-library-validation). Die UI-Schnittstelle lief beim Zugriff auf die bereits abgestürzte App zweimal in ein Timeout; dies war kein bestandener Starttest.


## Final 1.0.0-final, Build 1 – Abschlussprüfung

- 26. Oktober 2026: Zwei Final-Compilerläufe in Release-Konfiguration: erster Lauf mit Startfehler, zweiter nach gezielter Signaturkorrektur erfolgreich. Abschließende Pakete ohne weiteren Compilerlauf neu signiert und erstellt, damit das runtime-Flag ausdrücklich erhalten bleibt. Debugger-Berechtigung entfernt; automatische Debugger-Entitlement-Injektion für Final abgeschaltet. Keine fachliche Änderung am Dev-55-Quellstand.
- Build, Version 1.0.0-final/1, App-Name e2Atlas, Final-Kennung/Kanal, arm64, macOS-26-Mindestversion und beide Sprachen geprüft. 34 gezielte Release-Tests in drei Suites bestanden; nach reinen Signaturkorrekturen nicht unnötig wiederholt. Kein vollständiger neuer Gesamttest.
- Nutzer bestätigt Start nach der Korrektur. Eigenständiger nativer Start der endgültig paketierten App mit aktivem Hardened Runtime erfolgreich; Demo-Hauptfenster und Aktionshilfen sichtbar. Keine eigene Receiver-Änderung oder reale Streamprüfung. Danach App und Bedienungszugriff beendet; keine verbleibenden Prozesse des geprüften Pakets.
- Finale Signatur enthält ausschließlich com.apple.security.cs.disable-library-validation, keine get-task-allow-Berechtigung. ZIP-CRC und enthaltene Programmdatei/Metadaten, vollständige Dateigleichheit des gemounteten DMG, Signatur und SHA256SUMS bestanden. Compiler-/Paketlog: `Build/Logs/Final/run-20261026T051706411884Z-4daae4b9.log`; abschließende Paketierung: `Build/Logs/Final/run-20261026T052012816177Z-f32060c3.log`.
- Positivliste und Hook-Grenzen geprüft: main und gültige Final-Tags erlaubt; Dev, falsche Branchzuordnung und falsches Tagformat abgelehnt. Keine Dev-/Beta-Historie übernommen. Beta bleibt f98575f. Ein Sub-Agent mit GPT-6 Luna Medium unterstützte den Dokumentationsabgleich; passende Humanizer für Englisch und Deutsch verwendet.


### Veröffentlichung abgeschlossen – 26. Oktober 2026

- [e2Atlas 1.0.0-final](https://github.com/Schrotty74/e2Atlas/releases/tag/v1.0.0-final) ist als reguläres, aktuelles GitHub-Release veröffentlicht, kein Vorabrelease und kein Entwurf. Tag v1.0.0-final verweist auf 5d53575. ZIP, DMG und SHA256SUMS sind vollständig hochgeladen; alle drei serverseitigen Größen und SHA-256-Digests stimmen mit den geprüften lokalen Dateien überein.
- main enthält jetzt den freigegebenen Dev-55-Funktionsstand mit Final-Metadaten und -Dokumentation. Beta bleibt f98575f, Dev bleibt lokal auf App-Build 55. Final-App lokal unter `Build/Final/e2Atlas.app`; Release-Ausgaben im Final-Checkout unter `dist/releases/final/1.0.0-final`. Kein weiterer Build-, Release- oder Final-Auftrag offen. Weitere main-Änderungen nur mit passendem Auftrag.
- Erforderliche Build-/Paketlogs und die bereinigte Startdiagnose bleiben lokal als Nachweise. Eigene temporäre Release-Notes, Konsolenkopien und Arbeitsordner nach Abschluss entfernt.


## Neue öffentliche Screenshots – 26. Oktober 2026

- Auf ausdrücklichen Nutzerauftrag fünf bereitgestellte Screenshots für Fernsehen, Multiview, Jetzt und danach, Programmführer und Aufnahmen auf main und beta ersetzt beziehungsweise neu zugeordnet. Die bisherigen Bilder von Receiver-Einstellungen und Ersteinrichtung aus der aktuellen Galerie entfernt. App-Icon unverändert.
- Vollauflösende PNG-Bilddaten unverändert übernommen; nicht darstellungsrelevante Metadaten entfernt. Vorschauen mit 640 Pixeln Breite und erhaltenem Seitenverhältnis erstellt. Deutsche und englische README-Galerien verlinken die fünf neuen Ansichten. Auf beta ist der gezeigte Final-Stand mit möglichen Abweichungen der Bedienelemente ausdrücklich bezeichnet.
- Ausschließlich Bilder, README-Galerien und dieser Kontext geändert. Keine App-Builds, Versions-, Tag- oder Downloadänderungen. Veröffentlichung auf beiden Branches durch diesen Screenshot-Auftrag ausdrücklich freigegeben.
