# Projektkontext – e2Atlas

Stand: 18. Oktober 2026. Dieser Quellstand gehört zur Beta `0.3.0-beta`, Build 3. App und Tests sind geprüft; Commit, Downloadpakete und GitHub-Veröffentlichung werden im ausdrücklich beauftragten Release-Ablauf erstellt.

## Produkt und Plattform

e2Atlas ist eine native SwiftUI-App für Live-TV von Enigma2-Receivern über OpenWebif. Sie unterstützt Apple Silicon ab M1 und macOS 26 oder neuer. Entwicklung und Tests laufen mit Xcode 27 auf macOS 27. Die Gestaltung verbindet Kino und Regie; Fernsehen, Multiview und Programmführer bilden eigene Ansichten. Liquid Glass dient den Bedienelementen. Das bearbeitbare Kino-Icon liegt unter `Resources/E2AtlasIcon.icon`; Xcode kompiliert helle, dunkle und getönte Darstellungen. Keine statische Dock-Icon-Zuweisung zur Laufzeit.

## Funktionen und Module

- `AtlasCore`: gemeinsame Modelle, Einstellungen, atomare Speicherung und EPG-Zeitfenster.
- `AtlasReceiver`: OpenWebif-Verifikation, Bouquets, Sender, EPG, Logos, Stream-Adressen und Receiver-Hardwareinfos.
- `AtlasPlayback`: getrennte Wiedergabeplätze, Tonsteuerung und Multiview-Anordnung. VLCKit für allgemeine und authentifizierte Streams, AVPlayer für nicht authentifizierte HLS-Streams.
- `AtlasRecording`: Übertragung eines Originalstreams in eine neue lokale MPEG-TS-Datei.
- `AtlasThemes`: validierte JSON-Themes mit getrennten hellen und dunklen Paletten, optionalem Verlauf und System als Rückfall.
- `e2Atlas`: SwiftUI-Oberfläche, Einrichtung, Einstellungen und Koordination der Module.

Bis zu drei Receiver können gespeichert werden. Benutzername und Passwort sind optional, wenn die Dienste des Receivers keine Anmeldung verlangen. OpenWebif und Streaming können getrennt geschützt sein. Eine automatische Netzwerksuche ist nicht implementiert.

Multiview bietet bis zu vier Bilder mit einer Tonquelle. Ein kleines Bild kann mit dem Hauptbild tauschen; bestehende Player, Ton und Lautstärke bleiben erhalten. Anfragetokens verhindern, dass veraltete Senderanfragen nach einem Tausch oder Ausblenden Streams neu starten. „Nur Video“ blendet die App-Bedienung aus; Escape und Doppelklick führen zurück. VLC-Ausgabeflächen bleiben bei Containerwechseln erhalten. Der Ladekreis endet nach tatsächlicher Bildausgabe.

Der Programmführer bietet 2-, 4- und 6-Stunden-Fenster, den Sprung zu 20:15 und eigene Zeitkürzel. Senderlogos werden vom Receiver geladen.

Receiver-Info liest `/api/boxinfo` und bei geeigneten älteren Antworten `/api/about`. Hardware- und Systemfelder sowie bestätigte Tuner-Nutzung werden dargestellt, soweit vorhanden. Nicht zugeordnete Streams werden getrennt gezählt. Mehrere Streams können denselben Tuner teilen; ihre Anzahl ist keine Tunerbelegung. Bei fehlender Zuordnung bleibt die Gesamtbelegung unbekannt. Das Fenster aktualisiert alle fünf Sekunden. Rohantworten, Client-Adressen, Seriennummern und MAC-Adressen werden nicht gespeichert.

## Lokale Aufnahme

Der Aufnahme-Button liegt in der Player-Leiste und in kleinen Multiview-Bildern. Ein NSSavePanel wählt eine neue `.ts`-Datei. Eine Aufnahme kann gleichzeitig laufen, unabhängig von der sichtbaren Wiedergabe. Die App zeigt Laufzeit und Datenmenge, bietet Stoppen und anschließend die Anzeige im Finder. Vorhandene Dateien werden nicht überschrieben; ein exklusives Erstellen schützt auch gegen zwischenzeitliche Namenskollisionen. Bei Abbruch bleiben bereits gültig gespeicherte Streamdaten erhalten, leere Ausgabedateien werden entfernt. Receiver-Timer werden getrennt verwaltet; Transcoding ist nicht implementiert.

Die Aufnahme verwendet eine flüchtige URLSession ohne Cookie-, Credential- oder Disk-Cache. HTTP-Basic-Zugangsdaten werden nur für den konfigurierten Ursprung verwendet; Weiterleitungen werden abgelehnt. Dateizugriffe und Session-Callbacks sind seriell, Abbruchzustand ist gesperrt. Fortschrittsmeldungen sind auf vier pro Sekunde begrenzt.

VLCKit fordert VideoToolbox für unterstützte Codecs an und kann auf Software zurückfallen. Tatsächliche Hardware-Nutzung und CPU-Ersparnis sind nicht gemessen. Die Aufnahme kopiert Daten und benötigt keine Video-Neukodierung.

## Themes und Links

System, Ocean, Elfenbein und Bronze sind mitgeliefert. Farb-Themes haben helle und dunkle Paletten sowie dezente Verläufe. Automatisch folgt macOS. Eigene JSON-Dateien liegen im kanalgetrennten Theme-Ordner. Der Vorlagen-Button erstellt eine neue Datei und Anleitung ohne Überschreiben. Die Liste lädt während geöffneter Darstellungseinstellungen alle zwei Sekunden neu. Ungültige, doppelte oder über 64 KiB große Dateien werden gezählt und ausgelassen; mitgelieferte Kennungen haben Vorrang. Ein verlorenes ausgewähltes Theme führt zum System-Theme zurück.

Der About-Tab neben Receiver und Darstellung zeigt App-Icon, numerische Version, Build sowie Homepage- und GitHub-Links. Dieselben Links sind im Hilfe-Menü verfügbar. Öffentliche Theme-Anleitungen und JSON-Vorlage liegen unter `Documentation/Themes/`.

## Daten und Zugangsdaten

Passwörter liegen im macOS-Schlüsselbund und nach erfolgreichem Lesen im Sitzungsspeicher. Automatische Lesezugriffe verwenden `LAContext.interactionNotAllowed` und ergänzend `kSecUseAuthenticationUIFail`. Verweigerter Zugriff wird als `credentialsUnavailable` behandelt: automatische Verbindungen versuchen ohne Passwort, ohne diesen Ersatz zu speichern oder das vorhandene Secret zu überschreiben. Andere Speicherfehler bleiben sichtbar. Bearbeiten und Speichern bleiben strikt; geschützte Receiver können gültige Zugangsdaten benötigen. Wiederkehrende Systemdialoge sind auf dem Nutzergerät noch nicht abschließend ausgeschlossen.

Dev, Beta und Final haben getrennte Bundle-Kennungen, Einstellungen, Theme-Ordner, App-Caches und Schlüsselbund-Services. Nur die neue Dev-Kennung `io.github.schrotty74.e2atlas.development` wird auf seinen bisherigen `.dev`-Speicher abgebildet; Beta und Final bleiben unverändert. Namen, Adressen und Benutzernamen liegen in Application Support. Receiver-Daten und private Diagnosen gehören nicht ins Repository.

Der OpenWebif-API-Client verwendet eine flüchtige Session, Basic-Challenges nur vom eingerichteten Ursprung und keine fremden Weiterleitungsziele. HTTPS verwendet die System-Zertifikatsprüfung. HTTP ist für Receiver-Kompatibilität zulässig und unverschlüsselt. Wiedergabe-Engines haben eigene Netzwerklogik. Es gibt keine Telemetrie oder Cloud-Konten.

## Build und Release

Alle Einstiegsskripte liegen unter `Scripts/` und ermitteln Pfade aus ihrer Position. Xcode-Projekt und SwiftPM verwenden dieselben Module. `generate-project.py` erzeugt das Projekt; `test.sh` führt Swift-Testing-Tests über Xcode mit eingebundenem VLC aus. VLCKit 3.7.3 wird projektgebunden von VideoLAN geladen und gegen eine feste SHA-256-Prüfsumme geprüft. GPL v3 für die App, austauschbares dynamisches VLCKit unter LGPL; Hinweise und Quelllinks sind gebündelt.

| Kanal | Bundle-Kennung | App-Ausgabe im Gesamtprojekt |
| --- | --- | --- |
| Dev | `io.github.schrotty74.e2atlas.development` | `Build/Dev/Application/e2Atlas Dev.app` |
| Beta | `io.github.schrotty74.e2atlas.beta` | `Build/Beta/e2Atlas Beta.app` |
| Final | `io.github.schrotty74.e2atlas` | `Build/Final/e2Atlas.app` |

Zusätzliche lokale Quell-Checkouts liegen unter `Local/Channels/`. Der Beta-Aufruf im Hauptprojekt verwendet den Beta-Checkout und dessen eigenen Xcode-Build-Cache. `E2ATLAS_OUTPUT_DIRECTORY` ändert ausschließlich die fertige App-Ausgabe; relative Werte gelten ab dem bauenden Checkout. Eigenständige Checkouts benötigen keine lokale Gesamtstruktur. Beta verlangt Branch `beta`, Final `main`. Final-Paketierung und Final-Tags fehlen weiterhin.

Versionsschema: drei Zahlen für Final-Generation, Beta-Schritt und Bugfix mit `-final`, `-beta` oder `-bugfix`. App-Metadaten trennen numerische Version und vollständigen Release-Namen. Beta `0.3.0-beta` verwendet Build 3; die veröffentlichte `0.2.0-beta` verwendet Build 2. Dev bleibt lokal. Quellstände werden gezielt übernommen, keine Dev-Historie veröffentlicht. Positivliste und Pre-Push-Hook prüfen Zielrepository, Branches und alle ausgehenden Commits. Der Hook muss über `git config core.hooksPath Scripts/git-hooks` repository-lokal aktiviert sein.

`package-beta.sh` verlangt einen sauberen, geprüften Beta-Commit und erstellt ZIP, DMG und SHA256SUMS. Es prüft Metadaten, arm64 und private Entwicklungspfade im eigenen Release-Programm. Ausgaben werden nicht überschrieben. Apps sind ad-hoc signiert und nicht notarisiert. Gatekeeper kann eine einmalige Freigabe erfordern. Build und Paketierung veröffentlichen nichts automatisch.

## Prüfergebnisse und Grenzen

- 16. Oktober 2026: Beta-Build `0.2.0-beta`, Build 2, erfolgreich. Alle 66 Tests in neun Suites bestanden im Beta-Quellstand. App-Signatur erfolgreich geprüft. Native Demo-Prüfung bestätigt About mit Version 0.2.0 und Build 2, beide Links, System/Ocean/Elfenbein/Bronze in der Auswahl sowie die Aufnahme-Schaltfläche in der Player-Leiste. ZIP und DMG samt App-Signaturen, Metadaten, arm64 und privaten Entwicklungspfaden geprüft. Frischer Checkout mit Leerzeichen im Pfad erfolgreich gebaut, mit getrennter Prüfkennung und deaktivierter Debug-Bibliothek. GitHub-Vorabrelease unter `v0.2.0-beta` veröffentlicht.
- Frühere native Prüfungen im Dev-Stand bestätigten synthetische Wiedergabe, Vollbildwechsel, Multiview-Tausch, Tonsteuerung, Themes und About. Live-TV ist zusätzlich durch einen Nutzer an einem realen Receiver bestätigt. FBC-Auswertung wurde mit bereinigten realen Zählern geprüft. Das ist kein vollständiger Hardware- oder Image-Kompatibilitätstest.
- macOS 26, weitere Receiver-Images, tatsächliche Hardwaredekodierung, Aufnahmen bei realen Netzwerk-/Speicherfehlern und dauerhaft dialogfreier Schlüsselbund-Zugriff bleiben zu prüfen.
- Beim lokalen Dev-Dock-Problem zeigte dasselbe Paket am alten Pfad das weiße dunkle Icon und an einem neuen Pfad das richtige. Nutzer bestätigte den neuen Pfad auch nach Paketersatz. Die genaue macOS-Ursache ist offen; dies belegt keinen allgemeinen Cache-Fix für alle Rechner.

## Veröffentlichungshistorie

- 15. Oktober 2026: erste Beta unter historischem Tag `v0.1.0-beta.1` veröffentlicht, 36 erfolgreiche Tests. Bilinguale READMEs, bereinigte Screenshots, Sicherheits- und Theme-Dokumentation folgten als Branch-Änderungen.
- 16. Oktober 2026: Anzeigename dieses ersten Releases auf `e2Atlas 0.1.0-beta` geändert; historischer Tag und Download-Dateien erhalten.
- 16. Oktober 2026: neue Beta `0.2.0-beta` mit Receiver-Info, Multiview-Tausch, lokaler Aufnahme, neuen Themes, Vorlagen, About und optionalem Anmeldehinweis vorbereitet. Feature-Listen, englischer Changelog und alle vier Kontextdateien sind auf diesen Quellstand gebracht.

- Beta-Paketprüfung, 16. Oktober 2026: erster ZIP-Kandidat enthielt lokale Entwicklungspfade in einer zusätzlichen Xcode-Debug-Bibliothek. Nicht veröffentlicht und zur lokalen Diagnose aufbewahrt. Verteilte Builds deaktivieren künftig diese Bibliothek; die Paketierung strippt und prüft alle eigenen Mach-O-Dateien. Erneuter Build und Paketprüfung folgen.

- Abschließende Paketierung: Debug-Bibliothek für verteilte Builds deaktiviert. Neuer ZIP-/DMG-Kandidat besteht Signatur-, Metadaten-, Architektur- und vollständige Home-Pfad-Prüfung. SHA256SUMS erstellt; frischer Checkout erneut erfolgreich gebaut. Keine weiteren Tests gestartet.

- 16. Oktober 2026, Veröffentlichung: `0.2.0-beta`, Build 2, als GitHub-Vorabrelease mit ZIP, DMG und SHA256SUMS veröffentlicht. Release-Tag `v0.2.0-beta` liegt auf `2369b7a`; spätere Begleittextänderungen ersetzen keine App-Pakete. Beide Startseiten enthalten die neuen Funktionen. Changelog und Release-Notes verwenden das Beta-1-Muster Added, Fixed, Known limitations und Validation. Alle vier Kontextdateien aktualisiert. Künftige Abschlussprüfungen werden gebündelt; Wiederholungen nur bei konkretem Anlass.

- 16. Oktober 2026, Beta-1-Downloads: nach ausdrücklicher Nutzerfreigabe ZIP, DMG und SHA256SUMS des historischen Releases `v0.1.0-beta.1` durch lokal bereinigte Dateien ersetzt. Lokale Entwicklungspfade aus eigenen Mach-O-Dateien entfernt und Signaturen erneuert; App-Version, Build 1, Funktionen, Framework-Inhalte, Tag und Download-Dateinamen unverändert. Die vorbereiteten Dateien bestanden Signatur-, Paket- und Home-Pfad-Prüfung. Nach Upload alle drei veröffentlichten SHA-256-Digests mit den vorbereiteten Dateien abgeglichen. Keine neuen App-Builds oder wiederholten Funktionsprüfungen.


## Stand für die Fortsetzung

Stand: 16. Oktober 2026 nach Veröffentlichung und Bereinigung der Downloads.

- Der lokale Hauptordner enthält den Dev-Quellstand und ist kein eigenes Git-Repository. `dev` bezeichnet hier den lokalen Build-Kanal, keinen tatsächlich vorhandenen Branch. Dev bleibt ausschließlich lokal.
- Der getrennte Git-Checkout liegt unter `Local/Channels/Beta`, Branch `beta`, zuletzt veröffentlichter Commit `af58a07` (bereinigte Beta-1-Downloads dokumentiert). Release `0.2.0-beta`, Build 2, gehört zum Tag `v0.2.0-beta` auf `2369b7a`; danach wurden nur Begleittexte angepasst. Das historische Beta-1-Release behält seinen Tag `v0.1.0-beta.1` und enthält jetzt bereinigte ZIP-/DMG-Dateien mit neuen Prüfsummen.
- Der vorhandene Remote-Branch `origin/main` steht auf `48d096a` und enthält nur `README.md` und `LICENSE`. App-Quellen, Xcode-Projekt, Sicherheits- und Kontextdateien fehlen dort bewusst bis zur ersten beauftragten Final-Vorbereitung. Es gibt keinen lokalen Final-Checkout und keinen lokalen `main`-Branch im Beta-Checkout.
- Im Dev-Ordner und Beta-Checkout sind Root-`AGENTS.md`, die vier Dateien unter `Documentation/Project/`, englische/deutsche README und SECURITY, CHANGELOG sowie Theme-Anleitungen vorhanden. Die vollständigen Kontextdateien stehen nicht zusätzlich im Root. Globale Agentenregeln bleiben außerhalb des Projekts und werden nicht kopiert.
- Die Übergabe ändert ausschließlich lokale Kontextdateien. Dafür wurden keine Builds, Tests, Branch-Wechsel, Commits, Pushes oder Releases ausgeführt. Lokale Übergabeänderungen im Beta-Checkout sind nicht veröffentlicht.


## Beta 0.3.0-beta

- 18. Oktober 2026: Auf Nutzerauftrag den aktuellen Dev-Funktionsstand gezielt in den vorhandenen Beta-Checkout übernommen: deutsche/englische Oberfläche, Receiver-Timer, EPG-Suche und Fortschritt, gespeicherte Multiview-Belegungen, unabhängige begrenzte Wiederverbindung, Aufnahmeoptionen, Speicherplatzprüfung, Sleep-Timer, einstellbare Startverbindung sowie vollständiges Beenden beim Schließen des Hauptfensters. Quellen, Tests und Ressourcen stimmen bytegenau mit dem übernommenen Dev-Stand überein. Versionsvorgabe 0.3.0-beta und Build 3 bleiben im Beta-Build getrennt.
- Bestätigungen aus Dev: Anlegen eines echten Receiver-Timers; ungefähr zehn Minuten stabile Einzelwiedergabe; schrittweises Laden beseitigt die gemeldeten Multiview-Tonaussetzer; Sender und EPG laden nach Wiederherstellen; automatische Startverbindung, Einstellung im Receiver-Bereich und vollständiges Beenden über den roten Knopf funktionieren laut Nutzer. Diese Aussagen sind keine erneute Hardwareprüfung des Beta-Pakets.
- App-Build erfolgreich. Beta-Kennung und -Kanal, Version 0.3.0, Build 3, Apple Silicon, macOS-26-Mindestversion und beide Sprachressourcen geprüft. Eigenes Hauptprogramm gestript, absolute Suchpfade entfernt und auf private Entwicklungspfade geprüft; Ad-hoc-Signatur erneuert und streng geprüft. Keine Debug-Dylib im Paket. Getrennte Beta-Daten, Schlüsselbund-Services und Build-Caches erhalten; keine Dev-Nutzerdaten übernommen.
- Die drei vorbestehenden lokalen Kontextänderungen sind vor Übernahme getrennt unter Local/Backups gesichert. Neue Build-/Test-Logs werden über den übernommenen Logger begrenzt aufbewahrt. Keine zusätzliche Prüf-App oder Projektkopie erstellt, kein Branchwechsel, Commit, Push, Tag oder Release ausgeführt. Das Paketierungsskript verlangt weiterhin einen ausdrücklich beauftragten sauberen Commit für ZIP/DMG.

- Automatische Prüfung: 96 Testfunktionen im übernommenen Quellstand über Gesamtlauf und gezielte Nachprüfungen erfolgreich abgedeckt. Der erste gemeinsame Lauf wurde wegen einer VLC-Sperre beim Abbau eines synthetischen Players beendet. Fünf dadurch offene Funktionen anschließend in getrennten Aufrufen erfolgreich geprüft; bestandene Funktionen nicht erneut ausgeführt. Eine vorherige Methodenauswahl fand keine Tests und zählt nicht als Prüfnachweis. Nach dem abgebrochenen Lauf verbliebene eigene synthetische Mediendatei samt Ordner entfernt; Logs bleiben geordnet als Nachweise erhalten. Keine Änderung der App-Logik für diesen Prüfkonflikt.
- Englische/deutsche README, englischer Changelog und vier Kontextdateien auf den lokalen Kandidaten abgeglichen. Sprachlich passende Humanizer verwendet. Neue Funktionen und Ressourcen nur im vorhandenen Beta-Checkout übernommen; ein Sub-Agent mit GPT-6 Luna Medium unterstützte Dateiabgleich und Auswertung der noch offenen Tests. Beta wurde nicht gegen einen echten Receiver gestartet. ZIP/DMG und Veröffentlichung bleiben ohne Commit-/Veröffentlichungsauftrag ausstehend.


## Auftrag zur GitHub-Veröffentlichung

- 18. Oktober 2026: Nutzer stellt klar, dass „neue Beta erstellen“ auch das Hochladen und Veröffentlichen auf GitHub umfasst. Diese Auslegung gilt künftig als ausdrücklicher Release-Auftrag und ist in den Projektregeln ergänzt. Für 0.3.0-beta sind Quell-Commit und Push auf beta, Tag v0.3.0-beta sowie GitHub-Vorabrelease mit ZIP, DMG und SHA256SUMS beauftragt. Ältere Angaben zur rein lokalen Vorbereitung dokumentieren den Zustand vor dieser Klarstellung.
- Die 96 erfolgreich abgedeckten Testfunktionen bleiben maßgeblich; reine Release-Texte und Paketierung erfordern keine erneuten Funktionstests. Neue Prüfungen beschränken sich auf veröffentlichbaren Quellstand, Pakete, Signaturen und tatsächliche Upload-Dateien. Fortschritt und Ergebnis werden nach Paketierung und Veröffentlichung ergänzt.
