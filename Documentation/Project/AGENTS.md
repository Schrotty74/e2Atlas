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
- Reproduzierbarkeit in einer frischen Prüf-Projektkopie nur auf ausdrücklichen Nutzerauftrag prüfen. Einen erfolgreichen Build im vorhandenen Arbeitsordner nicht als vollständigen Portabilitätsnachweis ausgeben.

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

- Ein Nutzerauftrag wie „neue Beta erstellen“ umfasst die Vorbereitung des aktuellen freigegebenen Funktionsstands, Beta-Build, erforderliche Prüfungen, bereinigte Dokumentation, Commit und Push auf beta, passenden Beta-Tag sowie GitHub-Vorabrelease mit ZIP, DMG und SHA256SUMS. Nur bei ausdrücklich lokalem Build-Auftrag ohne Veröffentlichung bleiben Upload und Release aus. Dev und Final werden dadurch nicht veröffentlicht.

- Changelog-Einträge immer auf Englisch verfassen.

- Final normalerweise aus dem freigegebenen Beta-Stand erstellen; eine ausdrücklich anders benannte Quelle hat Vorrang. Für Final 1.0.0 ist der aktuelle Dev-Stand auf Nutzerauftrag direkt freigegeben. Ein Final-Build allein erteilt keine automatische Veröffentlichungsfreigabe; für diesen Auftrag ist die GitHub-Veröffentlichung zusätzlich bestätigt.

- Ohne ausdrücklichen Auftrag keine Git-Initialisierung, Branch-Erstellung, Branch-Wechsel, Zusammenführungen, Löschungen, Commits, Pushes, Tags oder Releases.
- Veröffentlichungsziel ist ausschließlich `Schrotty74/e2Atlas`. Neben App-Quellen und baurelevanten Dateien gehören die vier bereinigten Kontextdateien unter `Documentation/Project/` zum öffentlichen Projekt. Designvorlagen, private Notizen, Build-Ausgaben und Receiver-Daten bleiben lokal. Die kurze Root-`AGENTS.md` dient nur als Einstieg in diese Regeln.
- `dev` bleibt ausschließlich lokal, `beta` ist der veröffentlichbare Beta-Stand, `main` der Final-Stand. Getrennte Checkouts, Build-Verzeichnisse, App-Namen und Bundle-Kennungen verwenden. Dev nicht unter einem anderen Remote-Namen oder durch Übernahme seiner vollständigen Historie veröffentlichen.
- Im lokalen Gesamtprojekt liegen zusätzliche Kanal-Checkouts unter `Local/Channels/Beta` beziehungsweise `Local/Channels/Final`. Kein zweiter Projektordner neben dem Gesamtprojekt. Die Einstiegsskripte im Hauptprojekt legen fertige Apps unter `Build/Dev/Application`, `Build/Beta` und `Build/Final` ab. Ein eigenständig heruntergeladener Checkout bleibt ohne diese lokale Zusatzstruktur baubar.
- Dev, Beta und Final müssen getrennte App-Caches, Einstellungen, Schlüsselbund-Services und Xcode-Build-Caches behalten. Ein gemeinsamer übergeordneter Ordner oder ein anderer Ausgabeort darf diese Trennung nicht aufheben. Die bestehende Dev-Zuordnung auf seinen früheren Dev-Speicher bleibt ausschließlich innerhalb des Dev-Kanals.
- Vor einem Push den gesamten ausgehenden Quellstand einschließlich neuer Historie gegen `Scripts/check-public-tree.sh` prüfen. `.gitignore` allein ist kein Nachweis. Der Hook `Scripts/git-hooks/pre-push` darf nur die Branches `beta` und `main` sowie Final-Tags am aktuellen Main-Commit und Beta-/Beta-Bugfix-Tags am aktuellen Beta-Commit zum vorgesehenen Repository zulassen. Vor tatsächlicher Git-Veröffentlichung muss er eingerichtet und geprüft sein.
- Die lokalen Build-Skripte bauen ausschließlich ihren Kanal. `Scripts/build_dev_app.sh`, `Scripts/build_beta_app.sh` und `Scripts/build_final_app.sh` führen keinen Commit, Push oder Release aus. Getrennte Veröffentlichungsabläufe erst für einen ausdrücklich beauftragten Beta-/Final-Stand ausführen; Release-Tags nicht über einen derzeit nicht unterstützten Hook umgehen.
- Quellen gezielt aus Dev in den vorgesehenen Beta-/Final-Stand übernehmen; keine pauschale Mischung der Entwicklungsstände. Die ThermalAtlas-Build-Skripte dienen als strukturelle Vorlage, produktspezifische Ressourcen und Annahmen nicht übernehmen.
- Nur ausdrücklich beauftragte und für den Zielstand geeignete Änderungen in eine Veröffentlichungsstufe übernehmen.
- Bestehende spezifische Projekt-, Datenschutz-, Build- und Release-Grenzen erhalten. Prüfergebnisse und offene Punkte wahrheitsgemäß dokumentieren.

- Ausdrücklich für Beta freigegebene öffentliche Begleitdateien: englische und deutsche README, SECURITY-Dateien, App-Icon und bereinigte Screenshots unter `Documentation/Images/` und `Documentation/Screenshots/`. Originale mit privaten Daten bleiben lokal. `main` erst im Rahmen eines ausdrücklich beauftragten Final-Builds ändern. Das gilt auch für README- und Feature-Seiten; Beta-Dokumentation ausschließlich auf `beta` pflegen.

## Kontextpflege nach Builds und Releases

- Die vier Dateien `AGENTS.md`, `PROJECT_CONTEXT.md`, `NEXT_STEPS.md` und `CHAT_TEMPLATE.md` werden unter `Documentation/Project/` gepflegt. Keine getrennten vollständigen Kopien im Projekt-Root führen.
- Nach jedem Buildversuch, ob Dev, Beta oder Final, und vor der Übergabe alle vier Dateien prüfen. Relevante Änderungen an Verhalten, Architektur, Build, Datenschutz und Regeln sowie das tatsächliche Build- und Prüfergebnis nachführen. Fehlschläge und ungetestete Punkte ausdrücklich kennzeichnen. Unveränderte Regeln und Startvorlagen nicht künstlich umschreiben.
- Im Projektkontext ein datiertes Änderungsprotokoll führen: Kanal, konkrete Änderung, Build-Ergebnis und tatsächlich ausgeführte Prüfungen. Offene Aufgaben nachführen; erledigte Aufgaben entfernen. Keine Zugangsdaten, privaten Pfade oder vollständigen lokalen Logs übernehmen.
- Nach jeder ausdrücklich beauftragten Beta- oder Final-Veröffentlichung den zum veröffentlichten Quellstand passenden Stand aller vier Dateien bereinigen, prüfen und im jeweiligen Branch hochladen. Diese Pflege gehört zum Release-Auftrag. Dev-Code, Dev-Historie und nur lokal vorhandene Änderungen nicht als veröffentlicht darstellen oder automatisch hochladen.
- Build-Skripte führen weiterhin keine automatischen Commits oder Pushes aus. Die inhaltliche Kontextpflege und Veröffentlichung sind verbindliche Arbeitsschritte des ausführenden Agenten; ein erfolgreicher Compilerlauf allein ersetzt sie nicht.

- Öffentliche Theme-Anleitungen und die bereinigte JSON-Vorlage unter `Documentation/Themes/` sind ausdrücklich freigegeben. Versionsabhängige Funktionen in der Anleitung dem tatsächlich veröffentlichten Download zuordnen.

## Versionsbezeichnungen

- Nutzerdefiniertes Schema mit drei Zahlen: erste Zahl für die Final-Generation, zweite Zahl für den Beta-Schritt, dritte Zahl für Bugfixes. Diese Konvention ist verbindlich, auch wenn sie von üblicher semantischer Versionierung abweicht.
- Versionsnamen enden auf `-final`, `-beta` oder `-bugfix`. Beispiele: `0.1.0-beta`, `0.2.0-beta`, `1.0.0-final`, `1.1.0-beta`, `1.2.0-beta`, `1.0.1-bugfix`. Keine zusätzliche laufende Nummer hinter `-beta`.
- Der Kanal bleibt unabhängig vom Versionsnamen explizit konfiguriert. Ein Bugfix für eine Beta wird weiterhin als Beta gebaut und als Vorabrelease veröffentlicht; seine Caches bleiben vom Final-Kanal getrennt. Die Endung allein darf den Kanal nicht wechseln.
- App-Metadaten verwenden die drei Zahlen als `CFBundleShortVersionString`; der vollständige Name einschließlich Endung steht in `E2AtlasReleaseVersion`. Künftige Tags verwenden `v` vor dem vollständigen Versionsnamen. `Scripts/package-final.sh` erstellt Final-Pakete auf main. Final-Tags verwenden `vX.Y.Z-final` und müssen beim Push auf den aktuellen main-Commit zeigen.
- Das bestehende erste Release wurde nur im Anzeigenamen auf `e2Atlas 0.1.0-beta` geändert. Sein historischer Tag `v0.1.0-beta.1`, Download-Dateien und ursprüngliche App-Metadaten bleiben erhalten.

## Abschlussprüfungen und Release-Texte

- Build- und Test-Logs zentral unter `Build/Logs/Dev`, `Beta`, `Final` beziehungsweise `Tests` ablegen. Die lokalen Einstiegsskripte verwenden `Scripts/run-logged.py`; dieser ersetzt Projekt-, Home- und temporäre Benutzerpfade im Text und behält pro Kategorie die letzten fünf abgeschlossenen Läufe. Historische Nachweise liegen getrennt unter `Build/Logs/Archive`. Logs bleiben lokal und sind keine Veröffentlichungsartefakte.
- Zusätzliche temporäre Prüfdateien in einem aufgabenbezogenen Verzeichnis unter `Build/Temporary` anlegen. Nach Abschluss Herkunft, Referenzen und weiteren Bedarf prüfen und erledigte Hilfsdateien sowie eigene Prüfkopien entfernen. Bei Skripten temporäre Verzeichnisse mit `mktemp` und einem Exit-Trap verwalten; notwendige Fehlernachweise vor der Bereinigung in den Log-Ordner übernehmen. Unklare oder fremde Dateien nicht pauschal löschen. Zusätzliche Test-/Prüf-Apps und Prüf-Projektkopien ausschließlich auf ausdrücklichen Nutzerauftrag erstellen. Ein allgemeiner Entwicklungs-, Fehlerbehebungs- oder Prüfauftrag genügt dafür nicht. Aufwand, Laufzeit und Tokenverbrauch berücksichtigen; beauftragte Prüf-Apps und Prüfkopien nach Abschluss entfernen, sobald sie nicht mehr benötigt werden.
- Notwendige Prüfungen zu einem gebündelten Abschlusscheck zusammenfassen. Bestandene Prüfungen nicht ohne neuen Anlass wiederholen. Nach einem konkreten Fehler nur die von der Korrektur betroffenen Teile erneut prüfen.
- Englischer Changelog und GitHub-Release-Notes folgen dem Muster der ersten Beta: `Added`, `Fixed`, `Known limitations`, `Validation` mit kurzen Aufzählungen. Tatsächlich ausgeführte Prüfungen und offene Grenzen benennen. Keine neuen App-Builds für reine Begleittextänderungen.
