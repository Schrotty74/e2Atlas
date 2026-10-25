# Chat-Startvorlage – e2Atlas

Ich arbeite am Projekt e2Atlas: https://github.com/Schrotty74/e2Atlas

Verwende den aktuellen Projektordner; keinen festen lokalen Pfad voraussetzen. Lies zuerst vollständig die globale `~/.codex/AGENTS.md`, dann die Root-`AGENTS.md` und danach diese Dateien unter `Documentation/Project/`:

1. `AGENTS.md`
2. `PROJECT_CONTEXT.md`
3. `NEXT_STEPS.md`

Der lokale Dev-Hauptordner besitzt kein eigenes Git-Repository. Der zusätzliche Beta-Checkout liegt unter `Local/Channels/Beta` auf `beta`. Der Remote-Branch `main` enthält nur die ursprüngliche README und Lizenz. Main erst bei einem ausdrücklich beauftragten Final-Build ändern, auch keine README-/Feature-Seiten vorab ergänzen. Prüfe den tatsächlichen Quellstand und den aktuellen Branch. Öffne danach nur die für meinen Auftrag relevanten Dateien. Lokale Designreferenzen sind optional; die vorhandene Oberfläche und öffentlichen Screenshots liefern die mitgelieferte Gestaltung.

Die App verwendet SwiftUI, unterstützt Apple Silicon ab macOS 26 und folgt Kino + Regie mit eigener Programmansicht. Codex und Xcode bearbeiten denselben Quellbestand. Beachte Datenschutz, modulare Architektur, relative Pfade und getrennte Kanäle. Dev bleibt lokal; Beta wird auf `beta`, Final auf `main` veröffentlicht.

Keine Funktionen, Builds, Testergebnisse oder behobenen Fehler erfinden. Keine privaten Daten dokumentieren. Keine Git-Änderungen oder Veröffentlichungen ohne passenden Auftrag. Nach jedem Build alle vier Kontextdateien prüfen und relevante Änderungen samt Ergebnis nachführen. Nach jedem beauftragten Beta-/Final-Release den bereinigten Kontextstand im passenden Branch veröffentlichen.

Falls die lokale Gesamtstruktur vorhanden ist, liegen weitere Kanal-Quellstände unter `Local/Channels/`. Verwende für lokale Kanal-Builds die Einstiegsskripte im Hauptprojekt. App-Caches und Xcode-Build-Caches aller Kanäle bleiben getrennt.

Beachte das bestätigte Versionsschema in `AGENTS.md`: drei Zahlen mit der Endung `-final`, `-beta` oder `-bugfix`; keine zusätzliche Nummer nach `-beta`.

Fasse die notwendigen Prüfungen zu einem Abschlusscheck zusammen. Wiederhole nach einer Korrektur nur betroffene Teile. Changelog und Release-Notes verwenden das Beta-1-Muster.

Aktueller Stand: Dev-Build 53 mit Einstellungsexport/-import und Jetzt-und-danach-Übersicht. Beta 0.5.0-beta, Build 5, ist mit Tag v0.5.0-beta sowie ZIP, DMG und SHA256SUMS veröffentlicht. Der Tag verweist auf 9c728a1; die weitere Kontextpflege ergänzt nur Dokumentation. 34 gezielte Tests in vier Suites im Beta-Checkout bestanden; Build, Paketprüfung und Upload-Digests bestanden. Kein weiterer Build- oder Release-Auftrag offen. Der Nutzer bestätigt Export, Navigationsdarstellung, Ansichtswechsel ohne erneuten Datenabruf und senderweises Nachladen nach Sendungsende. Main bleibt auf 1af31eb mit ursprünglicher README und LICENSE; kein Final-Checkout vorhanden. Der vorgemerkte Dateimanager ist kein Umsetzungsauftrag.

Bei einem später ausdrücklich beauftragten Final-Build den freigegebenen Beta-Stand übernehmen und für Final anpassen, einschließlich Dokumentation und getrennter Daten-/Cache-/Schlüsselbundzuordnung. Bis dahin main unverändert lassen.

Aktueller Auftrag:

<Aktueller Auftrag>
