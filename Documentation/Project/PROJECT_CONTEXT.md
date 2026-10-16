# Projektkontext – e2Atlas

Stand: 16. Oktober 2026. Dieser Quellstand gehört zur Beta `0.2.0-beta`, Build 2. ZIP, DMG und Prüfsummen sind für die Veröffentlichung erstellt und geprüft.

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

Der Aufnahme-Button liegt in der Player-Leiste und in kleinen Multiview-Bildern. Ein NSSavePanel wählt eine neue `.ts`-Datei. Eine Aufnahme kann gleichzeitig laufen, unabhängig von der sichtbaren Wiedergabe. Die App zeigt Laufzeit und Datenmenge, bietet Stoppen und anschließend die Anzeige im Finder. Vorhandene Dateien werden nicht überschrieben; ein exklusives Erstellen schützt auch gegen zwischenzeitliche Namenskollisionen. Bei Abbruch bleiben bereits gültig gespeicherte Streamdaten erhalten, leere Ausgabedateien werden entfernt. Receiver-Timer und Transcoding sind nicht implementiert.

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

Versionsschema: drei Zahlen für Final-Generation, Beta-Schritt und Bugfix mit `-final`, `-beta` oder `-bugfix`. App-Metadaten trennen numerische Version und vollständigen Release-Namen. Beta `0.2.0-beta` verwendet Build 2. Dev bleibt lokal. Quellstände werden gezielt übernommen, keine Dev-Historie veröffentlicht. Positivliste und Pre-Push-Hook prüfen Zielrepository, Branches und alle ausgehenden Commits. Der Hook muss über `git config core.hooksPath Scripts/git-hooks` repository-lokal aktiviert sein.

`package-beta.sh` verlangt einen sauberen, geprüften Beta-Commit und erstellt ZIP, DMG und SHA256SUMS. Es prüft Metadaten, arm64 und private Entwicklungspfade im eigenen Release-Programm. Ausgaben werden nicht überschrieben. Apps sind ad-hoc signiert und nicht notarisiert. Gatekeeper kann eine einmalige Freigabe erfordern. Build und Paketierung veröffentlichen nichts automatisch.

## Prüfergebnisse und Grenzen

- 16. Oktober 2026: Beta-Build `0.2.0-beta`, Build 2, erfolgreich. Alle 66 Tests in neun Suites bestanden im Beta-Quellstand. App-Signatur erfolgreich geprüft. Native Demo-Prüfung bestätigt About mit Version 0.2.0 und Build 2, beide Links, System/Ocean/Elfenbein/Bronze in der Auswahl sowie die Aufnahme-Schaltfläche in der Player-Leiste. ZIP und DMG samt App-Signaturen, Metadaten, arm64 und privaten Entwicklungspfaden geprüft. Frischer Checkout mit Leerzeichen im Pfad erfolgreich gebaut, mit getrennter Prüfkennung und deaktivierter Debug-Bibliothek. GitHub-Veröffentlichung folgt.
- Frühere native Prüfungen im Dev-Stand bestätigten synthetische Wiedergabe, Vollbildwechsel, Multiview-Tausch, Tonsteuerung, Themes und About. Live-TV ist zusätzlich durch einen Nutzer an einem realen Receiver bestätigt. FBC-Auswertung wurde mit bereinigten realen Zählern geprüft. Das ist kein vollständiger Hardware- oder Image-Kompatibilitätstest.
- macOS 26, weitere Receiver-Images, tatsächliche Hardwaredekodierung, Aufnahmen bei realen Netzwerk-/Speicherfehlern und dauerhaft dialogfreier Schlüsselbund-Zugriff bleiben zu prüfen.
- Beim lokalen Dev-Dock-Problem zeigte dasselbe Paket am alten Pfad das weiße dunkle Icon und an einem neuen Pfad das richtige. Nutzer bestätigte den neuen Pfad auch nach Paketersatz. Die genaue macOS-Ursache ist offen; dies belegt keinen allgemeinen Cache-Fix für alle Rechner.

## Veröffentlichungshistorie

- 15. Oktober 2026: erste Beta unter historischem Tag `v0.1.0-beta.1` veröffentlicht, 36 erfolgreiche Tests. Bilinguale READMEs, bereinigte Screenshots, Sicherheits- und Theme-Dokumentation folgten als Branch-Änderungen.
- 16. Oktober 2026: Anzeigename dieses ersten Releases auf `e2Atlas 0.1.0-beta` geändert; historischer Tag und Download-Dateien erhalten.
- 16. Oktober 2026: neue Beta `0.2.0-beta` mit Receiver-Info, Multiview-Tausch, lokaler Aufnahme, neuen Themes, Vorlagen, About und optionalem Anmeldehinweis vorbereitet. Feature-Listen, englischer Changelog und alle vier Kontextdateien sind auf diesen Quellstand gebracht.

- Beta-Paketprüfung, 16. Oktober 2026: erster ZIP-Kandidat enthielt lokale Entwicklungspfade in einer zusätzlichen Xcode-Debug-Bibliothek. Nicht veröffentlicht und zur lokalen Diagnose aufbewahrt. Verteilte Builds deaktivieren künftig diese Bibliothek; die Paketierung strippt und prüft alle eigenen Mach-O-Dateien. Erneuter Build und Paketprüfung folgen.

- Abschließende Paketierung: Debug-Bibliothek für verteilte Builds deaktiviert. Neuer ZIP-/DMG-Kandidat besteht Signatur-, Metadaten-, Architektur- und vollständige Home-Pfad-Prüfung. SHA256SUMS erstellt; frischer Checkout erneut erfolgreich gebaut. Keine weiteren Tests gestartet.
