# Projektregeln für e2Atlas

## Kontext und Dokumentation

- Vor Projektarbeit `Documentation/Project/PROJECT_CONTEXT.md` und `Documentation/Project/NEXT_STEPS.md` lesen und den tatsächlichen Dateistand prüfen.
- `PROJECT_CONTEXT.md` ist die Quelle für belegten, dauerhaften Projektkontext. Entscheidungen und tatsächlich implementierte Funktionen klar unterscheiden.
- `NEXT_STEPS.md` enthält nur offene Aufgaben, bestätigte Bugs und nächste Schritte. Erledigte Aufgaben entfernen.
- Relevante Änderungen an Funktionen, Architektur, Datenformaten, Datenschutz, Build oder Release in den zuständigen Dokumenten nachführen.
- Dauerhafte Regeln gehören hierher, technische Entscheidungen in `PROJECT_CONTEXT.md`, offene Arbeit in `NEXT_STEPS.md`, Chat-Startanweisungen ausschließlich in `CHAT_TEMPLATE.md`.

## Plattform, Oberfläche und Design

- Native SwiftUI-App für Apple Silicon; keine Intel-Unterstützung.
- Mit aktueller Xcode-/SDK-Version entwickeln. macOS 27 ist die aktuelle Entwicklungsplattform; macOS 26 bleibt die Mindestversion. Mindestversion nicht eigenmächtig erhöhen.
- Neue oder versionsabhängige APIs anhand offizieller Apple-Dokumentation oder des vorhandenen SDK prüfen. Auf macOS 26 geeignete native Fallbacks vorsehen; Kernfunktionen erhalten.
- Apple Human Interface Guidelines, Accessibility und native Mac-Bedienung beachten. Neue Systemfunktionen nur mit konkretem Nutzen einsetzen.
- Verbindliche Gestaltung: Kino + Regie für Fernsehen und Multiview; eigene Programmansicht. Die vorhandene Oberfläche und die öffentlichen Screenshots sind die mitgelieferte Referenz. Zusätzliche lokale Designvorlagen nur berücksichtigen, wenn sie vorhanden sind. Wesentliche Abweichungen abstimmen.
- Liquid Glass gezielt für Navigation und Bedienelemente verwenden. Lesbarkeit, erhöhte Kontraste sowie reduzierte Transparenz und Bewegung berücksichtigen.
- Automatische Darstellung nach macOS-Einstellung sowie manuell Hell/Dunkel unterstützen.

## Modularität und Fehlerbehandlung

- Themes, Receiver-Anbindung, Programmlogik, Videowiedergabe und Oberfläche über kleine, eindeutige Schnittstellen trennen. Gemeinsame Modelle klein halten; keine zirkulären Abhängigkeiten oder globalen Zustands-Singletons.
- Themes als deklarative, versionierte Daten behandeln. Neue Themes dürfen keine Änderungen an Receiver-, EPG- oder Player-Logik erfordern. Ungültige Themes lokal verwerfen und auf ein gültiges Standardtheme zurückfallen.
- Fehlerzustände und Abbruch laufender Aufgaben pro Funktionsbereich behandeln. Ein fehlerhafter Stream darf andere Streams nicht pauschal stoppen. EPG-Ausfälle dürfen Navigation und Wiedergabe nicht sperren.
- Normale Dienstfehler lokal abfangen. Modulgrenzen nicht als Schutz vor einem vollständigen Prozessabsturz darstellen.
- Tests auf relevante Schnittstellen, Datenformate, Fehlerfälle und Regressionen ausrichten. Builds und tatsächliche UI-Prüfung getrennt belegen; Codeanalyse ersetzt keinen Bedienungstest.

## Portabilität und Xcode

- Codex und Xcode bearbeiten denselben Quellbestand. Ab Beginn der nativen Implementierung ein unmittelbar öffnungsfähiges Xcode-Projekt erstellen und funktionsfähig pflegen; keine getrennten Projektkopien.
- Alle erforderlichen Quellen, Ressourcen, Konfigurationen, Skripte und Projektdateien im Projekt halten, relativ referenzieren oder reproduzierbar über offizielle Mechanismen bereitstellen.
- In dauerhaft gespeicherten Projektdateien keine absoluten lokalen Pfade verwenden, auch keine anonymisierten oder synthetischen Beispiele solcher Pfade. Benutzer-, Installations-, Datenträger- und Entwicklungsrechner-Pfade nicht fest einbauen.
- Laufzeitverzeichnisse über macOS-APIs ermitteln; Ressourcen über das App-/Modul-Bundle laden. Application Support, Caches und temporäre Dateien entsprechend ihrem Zweck verwenden.
- Normaler lokaler Build ohne persönliche Zertifikate, Developer-Team-ID oder Secrets. Lokale Ad-hoc-Signierung ist zulässig.
- Reproduzierbarkeit zusätzlich in einer frischen Projektkopie prüfen. Einen erfolgreichen Build im vorhandenen Arbeitsordner nicht als vollständigen Portabilitätsnachweis ausgeben.

## Datenschutz und Zugangsdaten

- Öffentliche Entwicklerangaben ausschließlich unter `Schrotty74`. Keine privaten Namen, Kontaktdaten, Gewohnheiten oder Fähigkeiten dokumentieren.
- Keine realen Zugangsdaten, Gerätekennungen, privaten Hostnamen, internen URLs, persönlichen Hardware-Identifikatoren, privaten Inhalte oder sensiblen Diagnosedaten in Projektdateien aufnehmen.
- Demo-, Test- und Screenshotdaten müssen synthetisch, anonymisiert oder bewusst öffentlich sein. Bei Unsicherheit Daten vorerst nicht dauerhaft aufnehmen.
- Receiver-Adressen und Anmeldedaten werden vom jeweiligen Nutzer eingegeben. Passwörter in der späteren App über den macOS-Schlüsselbund verwalten; nicht in normalen Einstellungen, URLs, Logs oder Themes speichern.
- Keine Zugangsdaten, Accounts, Teams, Zertifikate oder Tokens eigenmächtig anlegen oder dauerhaft speichern.

## Werkzeuge und Abhängigkeiten

- Vor neuer Implementierung relevante Manifeste, Lockfiles, Build-Skripte, CI-Konfiguration und dokumentierte Abhängigkeiten prüfen.
- Das am besten geeignete vorhandene Werkzeug verwenden. Bei einer fehlenden, deutlich besseren Fähigkeit zuerst Verfügbarkeit, Berechtigungen und tatsächlichen Nutzen prüfen; nicht auf Vorrat installieren.
- Native Apple-APIs und offizielle integrierte Werkzeuge bevorzugen. Zusätzliche Abhängigkeiten nur mit konkreter Notwendigkeit; versionierte Projektabhängigkeiten projektgebunden halten.
- Dauerhafte Änderungen an der allgemeinen Entwicklungsumgebung erst nach Darstellung des konkreten Unterschieds und ausdrücklicher Zustimmung. Keine globalen Paketinstallationen als Projektlösung.
- Wenn ein geeigneteres Werkzeug nicht nutzbar ist, den Grund und die Einschränkungen einer Alternative benennen. Keine Installation, Aktivierung oder Prüfung behaupten, die nicht stattgefunden hat.
- Öffentliche und nutzergerichtete Fließtexte mit dem sprachlich passenden vorhandenen Humanizer prüfen. Technische Literale, Fakten und Aussagen erhalten; keine zusätzliche Skill-Installation ohne Auftrag.

## Git und Veröffentlichung

- Changelog-Einträge immer auf Englisch verfassen.

- Ohne ausdrücklichen Auftrag keine Git-Initialisierung, Branch-Erstellung, Branch-Wechsel, Zusammenführungen, Löschungen, Commits, Pushes, Tags oder Releases.
- Veröffentlichungsziel ist ausschließlich `Schrotty74/e2Atlas`. Neben App-Quellen und baurelevanten Dateien gehören die vier bereinigten Kontextdateien unter `Documentation/Project/` zum öffentlichen Projekt. Designvorlagen, private Notizen, Build-Ausgaben und Receiver-Daten bleiben lokal. Die kurze Root-`AGENTS.md` dient nur als Einstieg in diese Regeln.
- `dev` bleibt ausschließlich lokal, `beta` ist der veröffentlichbare Beta-Stand, `main` der Final-Stand. Getrennte Checkouts, Build-Verzeichnisse, App-Namen und Bundle-Kennungen verwenden. Dev nicht unter einem anderen Remote-Namen oder durch Übernahme seiner vollständigen Historie veröffentlichen.
- Vor einem Push den gesamten ausgehenden Quellstand einschließlich neuer Historie gegen `Scripts/check-public-tree.sh` prüfen. `.gitignore` allein ist kein Nachweis. Der Hook `Scripts/git-hooks/pre-push` darf nur `beta`, `main` und nummerierte Beta-Tags am aktuellen Beta-Commit zum vorgesehenen Repository zulassen. Vor tatsächlicher Git-Veröffentlichung muss er eingerichtet und geprüft sein.
- Die lokalen Build-Skripte bauen ausschließlich ihren Kanal. `Scripts/build_dev_app.sh`, `Scripts/build_beta_app.sh` und `Scripts/build_final_app.sh` führen keinen Commit, Push oder Release aus. Getrennte Veröffentlichungsabläufe erst für einen ausdrücklich beauftragten Beta-/Final-Stand ausführen; Release-Tags nicht über einen derzeit nicht unterstützten Hook umgehen.
- Quellen gezielt aus Dev in den vorgesehenen Beta-/Final-Stand übernehmen; keine pauschale Mischung der Entwicklungsstände. Die ThermalAtlas-Build-Skripte dienen als strukturelle Vorlage, produktspezifische Ressourcen und Annahmen nicht übernehmen.
- Nur ausdrücklich beauftragte und für den Zielstand geeignete Änderungen in eine Veröffentlichungsstufe übernehmen.
- Bestehende spezifische Projekt-, Datenschutz-, Build- und Release-Grenzen erhalten. Prüfergebnisse und offene Punkte wahrheitsgemäß dokumentieren.

- Ausdrücklich für Beta freigegebene öffentliche Begleitdateien: englische und deutsche README, SECURITY-Dateien, App-Icon und bereinigte Screenshots unter `Documentation/Images/` und `Documentation/Screenshots/`. Originale mit privaten Daten bleiben lokal. README erst nach dem ersten ausdrücklich beauftragten Final-Build nach `main` übernehmen.

## Kontextpflege nach Builds und Releases

- Die vier Dateien `AGENTS.md`, `PROJECT_CONTEXT.md`, `NEXT_STEPS.md` und `CHAT_TEMPLATE.md` werden unter `Documentation/Project/` gepflegt. Keine getrennten vollständigen Kopien im Projekt-Root führen.
- Nach jedem Buildversuch, ob Dev, Beta oder Final, und vor der Übergabe alle vier Dateien prüfen. Relevante Änderungen an Verhalten, Architektur, Build, Datenschutz und Regeln sowie das tatsächliche Build- und Prüfergebnis nachführen. Fehlschläge und ungetestete Punkte ausdrücklich kennzeichnen. Unveränderte Regeln und Startvorlagen nicht künstlich umschreiben.
- Im Projektkontext ein datiertes Änderungsprotokoll führen: Kanal, konkrete Änderung, Build-Ergebnis und tatsächlich ausgeführte Prüfungen. Offene Aufgaben nachführen; erledigte Aufgaben entfernen. Keine Zugangsdaten, privaten Pfade oder vollständigen lokalen Logs übernehmen.
- Nach jeder ausdrücklich beauftragten Beta- oder Final-Veröffentlichung den zum veröffentlichten Quellstand passenden Stand aller vier Dateien bereinigen, prüfen und im jeweiligen Branch hochladen. Diese Pflege gehört zum Release-Auftrag. Dev-Code, Dev-Historie und nur lokal vorhandene Änderungen nicht als veröffentlicht darstellen oder automatisch hochladen.
- Build-Skripte führen weiterhin keine automatischen Commits oder Pushes aus. Die inhaltliche Kontextpflege und Veröffentlichung sind verbindliche Arbeitsschritte des ausführenden Agenten; ein erfolgreicher Compilerlauf allein ersetzt sie nicht.

- Öffentliche Theme-Anleitungen und die bereinigte JSON-Vorlage unter `Documentation/Themes/` sind ausdrücklich freigegeben. Versionsabhängige Funktionen in der Anleitung dem tatsächlich veröffentlichten Download zuordnen.
