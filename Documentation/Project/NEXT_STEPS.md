# Nächste Schritte

Stand: 18. Oktober 2026. Beta `0.3.0-beta`, Build 3, ist gebaut und geprüft; die GitHub-Veröffentlichung ist ausdrücklich beauftragt. Die Punkte sind keine automatisch abzuarbeitende Prüfliste.

- Neue Beta mit vorhandenen Beta-Einstellungen und einem realen Receiver prüfen; Dev-Bestätigungen sind kein eigener Beta-Bedienungstest.
- macOS 26, weitere Receiver-Images, Schlüsselbunddialoge nach Neubuilds und dunkles Dock-Icon im normalen Betrieb weiter prüfen.
- Tatsächliche Ausführung und Bearbeitung von Receiver-Timern, Konflikte, weitere Images und unbekannte Spezialtimer prüfen; Anlegen ist im Dev-Stand bestätigt.
- Lokale Aufnahme mit realen Streams, Beenden während Aufnahme, Speicherplatzmangel, externen Laufwerken und Verbindungsabbruch prüfen. Hardwaredekodierung und CPU-Last sind nicht gemessen.
- Wiederverbindung nach echtem Netzwerkausfall oder Receiver-Neustart, weitere Multiview-Kombinationen und Sleep-Timer während lokaler Aufnahme prüfen.
- Neustart mit ausgeschalteter Verbindungsautomatik und Webfehler-Anzeige bei echter Nichterreichbarkeit bestätigen.
- Beauftragte Veröffentlichung abschließen: Quellstand und geprüfte ZIP/DMG samt SHA256SUMS sind vorbereitet. Nachweis-Commit und Tag pushen, GitHub-Vorabrelease erstellen, tatsächliche Upload-Digests prüfen und danach Kontext aktualisieren.
- Final bleibt separat: main enthält bewusst nur README und Lizenz; erst auf Final-Auftrag Quellen übernehmen und Final-Paketierung vorbereiten.

Notwendige Prüfungen bündeln; bestandene Teile nur nach konkreter Änderung wiederholen. Keine zusätzlichen Prüf-Apps oder Projektkopien ohne ausdrücklichen Auftrag.
