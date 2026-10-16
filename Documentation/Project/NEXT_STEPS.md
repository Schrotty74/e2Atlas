# Nächste Schritte

Stand: 16. Oktober 2026.

1. Lauf und zentrale Bedienung auf macOS 26 prüfen.
2. Weitere Receiver und Images mit OpenWebif, EPG, Picons und Wiedergabe prüfen. Live-TV ist durch einen Nutzer bestätigt; eine vollständige eigene Hardwareprüfung fehlt.
3. Die Korrekturen für Ladeanzeige, Vollbild, Stummschaltung und Lautstärke mit echten Receiverstreams prüfen. Automatische Tests und synthetische Bedienungsprüfungen bestehen.
4. Automatischen Schlüsselbund-Zugriff ohne Dialog und unauthentifizierten Ersatz nach Neubuilds und Neustarts auf dem Nutzergerät bestätigen. Receiver mit erforderlicher Anmeldung separat prüfen. Bestehende Einträge erhalten; Änderungen an Signieridentitäten oder Freigaben erfordern ausdrückliche Zustimmung.
6. Lokale Streamaufnahme mit echten Receiverstreams prüfen, einschließlich Verbindungsausfall, Speicherplatzmangel und Beenden der App. Receiver-Timer sind weiterhin nicht implementiert. Hardwaredekodierung und CPU-Last auf verschiedenen M-Chips und mit unterschiedlichen Codecs messen.
7. Final-Paketierung und geprüfte Final-/Bugfix-Tags nach dem bestätigten Versionsschema im getrennten `main`-Checkout vorbereiten. Nur auf ausdrücklichen Final-Auftrag veröffentlichen.
8. Nach dem ersten erfolgreichen Final-Build die zweisprachigen READMEs und Bilder auf den Final-Stand anpassen und nach `main` übernehmen.

9. Receiver-Info visuell einschließlich Aktualisierung, Fehlerdarstellung und Receiverwechsel prüfen; der erste native Versuch wurde durch einen Ausfall der Computersteuerung unterbrochen. Die korrigierte Auswertung ist direkt am echten Receiver geprüft; die Darstellung bei FBC ohne Stream-Tuner-IDs, automatische Aktualisierung und Fehlerhinweise noch in der neu gestarteten App prüfen. Exakte Gesamtbelegung ist ohne Receiver-Zuordnung nicht bestimmbar.

10. Multiview-Tausch mit echten Receiverstreams prüfen, einschließlich weiterer kleiner Bilder, Nur-Video-Wechsel und Reduzieren der Bildanzahl. Tests und native synthetische Bedienungsprüfung bestehen.

11. Eigene Theme-Farben zusätzlich auf macOS 26, mit erhöhtem Kontrast und reduzierter Transparenz prüfen. Template-Erstellung, Mehrfachauswahl und Hell-/Dunkel-Paletten sind getestet.

Nach jedem Build gelten die Kontextpflege-Regeln in `AGENTS.md`; nach Beta-/Final-Veröffentlichungen gehört die bereinigte Aktualisierung aller vier Kontextdateien zum Abschluss.


- Dunkles Dock-Icon beim normalen Receiverbetrieb und weiteren Neustarts aus `Build/Dev/Application/` bestätigen. Derselbe Dev-Build 6 zeigt am alten Pfad auch im Demo-Modus das weiße Icon, aus einem anderen Ordner das richtige. Dev-Builds 7 und 8 am neuen Ausgabeort zeigen laut Nutzer das korrekte dunkle Icon, auch nach Paketersatz. Die fehlerhafte macOS-Zuordnung am alten Pfad bleibt ungeklärt. Receiver-Daten, Themes und Passwort-Einträge bleiben erhalten.

- Bei der ersten Final-Vorbereitung den getrennten `main`-Checkout unter `Local/Channels/Final` anlegen und die Ausgabe nach `Build/Final` sowie die getrennten Kanal-Caches prüfen.

- Veröffentlichung `0.2.0-beta` abschließen: frischen Checkout, Downloadpakete und GitHub-Artefakte prüfen; den tatsächlichen Abschluss anschließend dokumentieren.
