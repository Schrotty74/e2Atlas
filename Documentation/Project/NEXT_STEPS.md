# Nächste Schritte

Stand: 19. Oktober 2026. Beta `0.4.0-beta`, Build 4, wird auf Nutzerauftrag vorbereitet. Build, Paketprüfung und GitHub-Veröffentlichung sind noch abzuschließen. Die folgenden Hardwareprüfungen sind keine automatisch abzuarbeitende Liste.

- Neue Beta mit bestehenden Beta-Einstellungen und echtem Receiver prüfen; Dev-Bestätigungen sind kein eigener Beta-Bedienungstest.
- macOS 26, weitere Receiver-Images, Schlüsselbunddialoge nach Neubuilds und dunkles Dock-Icon im normalen Betrieb weiter prüfen.
- Tatsächliche Aufnahmeausführung, Receiver-Konfliktmeldung und alternative Ausstrahlung im normalen Betrieb prüfen. Keinen künstlichen Konflikt auf Kosten laufender Aufnahmen erzwingen.
- Fortsetzen einer Receiver-Aufnahme nach App-Neustart, weitere Ordner und authentifizierte Wiedergabe prüfen. Bibliotheksdateien besitzen keinen verlässlich gemeldeten Fertig-Status.
- Benachrichtigung bei geschlossener App anklicken und richtige Sendung öffnen. Zustellung bei geschlossener App ist im Dev-Stand bestätigt. Erinnerung bei einer echten eindeutigen EPG-Zeitverschiebung nachführen; nicht künstlich am Receiver provozieren.
- AutoTimer-Vorschau mit tatsächlichen Plugin-Ergebnissen vergleichen; Zeitzone, Spezialfilter und Duplikatregeln beachten. EPGRefresh-Ablauf einschließlich Standby und laufender Aufnahme weiter beobachten.
- Lokale Aufnahme mit realen Streams, Beenden während Aufnahme, Speicherplatzmangel, externen Laufwerken und Verbindungsabbruch prüfen. Hardwaredekodierung und CPU-Last sind nicht gemessen.
- Wiederverbindung nach echtem Netzwerkausfall oder Receiver-Neustart, weitere Multiview-Kombinationen und Sleep-Timer während lokaler Aufnahme prüfen.
- Final bleibt separat: main enthält bewusst nur README und Lizenz; erst auf Final-Auftrag Quellen übernehmen und Final-Paketierung vorbereiten.

Notwendige Prüfungen bündeln; bestandene Teile nur nach konkreter Änderung wiederholen. Keine zusätzlichen Prüf-Apps oder Projektkopien ohne ausdrücklichen Auftrag.
