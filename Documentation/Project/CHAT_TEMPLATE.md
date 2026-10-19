# Chat-Startvorlage – e2Atlas

Ich arbeite am Projekt e2Atlas: https://github.com/Schrotty74/e2Atlas

Verwende den aktuellen Projektordner; keinen festen lokalen Pfad voraussetzen. Lies zuerst vollständig die globale `~/.codex/AGENTS.md`, dann die Root-`AGENTS.md` und danach diese Dateien unter `Documentation/Project/`:

1. `AGENTS.md`
2. `PROJECT_CONTEXT.md`
3. `NEXT_STEPS.md`

Der lokale Dev-Hauptordner besitzt kein eigenes Git-Repository. Der zusätzliche Beta-Checkout liegt unter `Local/Channels/Beta` auf `beta`. Der Remote-Branch `main` enthält öffentliche README-/Feature-Seiten und die Lizenz; fehlende App- und Kontextdateien dort nicht automatisch ergänzen. Prüfe den tatsächlichen Quellstand und den aktuellen Branch. Öffne danach nur die für meinen Auftrag relevanten Dateien. Lokale Designreferenzen sind optional; die vorhandene Oberfläche und öffentlichen Screenshots liefern die mitgelieferte Gestaltung.

Die App verwendet SwiftUI, unterstützt Apple Silicon ab macOS 26 und folgt Kino + Regie mit eigener Programmansicht. Codex und Xcode bearbeiten denselben Quellbestand. Beachte Datenschutz, modulare Architektur, relative Pfade und getrennte Kanäle. Dev bleibt lokal; Beta wird auf `beta`, Final auf `main` veröffentlicht.

Keine Funktionen, Builds, Testergebnisse oder behobenen Fehler erfinden. Keine privaten Daten dokumentieren. Keine Git-Änderungen oder Veröffentlichungen ohne passenden Auftrag. Nach jedem Build alle vier Kontextdateien prüfen und relevante Änderungen samt Ergebnis nachführen. Nach jedem beauftragten Beta-/Final-Release den bereinigten Kontextstand im passenden Branch veröffentlichen.

Falls die lokale Gesamtstruktur vorhanden ist, liegen weitere Kanal-Quellstände unter `Local/Channels/`. Verwende für lokale Kanal-Builds die Einstiegsskripte im Hauptprojekt. App-Caches und Xcode-Build-Caches aller Kanäle bleiben getrennt.

Beachte das bestätigte Versionsschema in `AGENTS.md`: drei Zahlen mit der Endung `-final`, `-beta` oder `-bugfix`; keine zusätzliche Nummer nach `-beta`.

Fasse die notwendigen Prüfungen zu einem Abschlusscheck zusammen. Wiederhole nach einer Korrektur nur betroffene Teile. Changelog und Release-Notes verwenden das Beta-1-Muster.

Mein aktueller Auftrag folgt als nächste Nachricht.
