# Sicherheitsrichtlinie

[English](SECURITY.md)

## Unterstützte Versionen

| Version | Status |
| --- | --- |
| 0.5.0-beta | Aktuelle Beta; Sicherheitsmeldungen sind willkommen |
| Stabile Version | Noch nicht veröffentlicht |

## Sicherheitsmodell

e2Atlas ist ein macOS-Client für Enigma2-Receiver, die du selbst einrichtest. Die App liest Senderlisten, Programmdaten, Senderlogos und TV-Streams über OpenWebif und den Streaming-Dienst des Receivers. Sie kann unterstützte Receiver-Aufnahmetimer planen und verwalten, EPGRefresh und unterstützte AutoTimer-Regeln konfigurieren sowie den MPEG-TS-Stream des Receivers in einer ausgewählten lokalen Datei speichern. Eine Systemadministration des Receivers bietet sie nicht. Die App installiert keinen privilegierten Hilfsprozess und fügt keine Telemetrie, Analysedienste oder Cloud-Konten hinzu.

Receiver-Passwörter liegen im macOS-Schlüsselbund. Erfolgreich gelesene Passwörter bleiben außerdem für die laufende App-Sitzung im Arbeitsspeicher. Receiver-Namen, Adressen, Benutzernamen und Anzeigeeinstellungen werden lokal in Application Support gespeichert. JSON-Einstellungs-Backups können Receiver-Adressen und Benutzernamen enthalten, Passwörter sind ausgeschlossen. Dev, Beta und Final verwenden getrennte Bundle-Kennungen und Speicherbereiche.

Der OpenWebif-API-Client verwendet eine flüchtige URLSession ohne dauerhafte Cookies oder Festplatten-Cache. Er übergibt HTTP-Basic-Zugangsdaten nur bei einer Anforderung vom eingerichteten Ursprung und lehnt Weiterleitungen zu anderen Ursprüngen ab. Für HTTPS-Anfragen der API gilt die normale Zertifikatsprüfung von macOS. Die Medienwiedergabe läuft über VLCKit oder AVFoundation mit deren eigener Netzwerk- und Decoderlogik; die Weiterleitungsprüfung des API-Clients deckt diese Engines nicht ab.

## Netzwerk- und Wiedergabegrenzen

Verwende den Receiver in einem vertrauenswürdigen lokalen Netzwerk oder über ein vertrauenswürdiges VPN. HTTP wird für die Receiver-Kompatibilität unterstützt und verschlüsselt weder Zugangsdaten noch Medien. HTTPS für OpenWebif sichert einen getrennten Streaming-Endpunkt nicht automatisch mit ab.

Receiver-Antworten, Programmtexte, Logos und Medien sind externe Eingaben. Fehler sollen auf den betroffenen Vorgang oder Stream begrenzt bleiben. Zugangsdaten dürfen nicht in URLs stehen oder über Fehlermeldungen offengelegt werden. Swift-Module und getrennte Wiedergabeplätze bilden keine Sicherheitsgrenze auf Prozessebene: Ein Decoderfehler kann den App-Prozess betreffen.

VLCKit 3.7.3 wird von VideoLAN geladen, mit einer festgelegten SHA-256-Prüfsumme geprüft und als austauschbare dynamische Bibliothek eingebunden. Die Prüfsumme bestätigt das ausgewählte Paket; Meldungen zu Sicherheitslücken in Abhängigkeiten bleiben relevant.

## Sicherheitslücke melden

Bitte kontaktiere [Schrotty74](https://github.com/Schrotty74) privat, bevor du Einzelheiten zu einer Sicherheitslücke weitergibst. Wenn du keinen privaten Kontaktweg hast, kannst du in einem Issue nach einem solchen fragen, ohne die Schwachstelle zu beschreiben.

Nenne die e2Atlas- und macOS-Version, die betroffene Komponente, Schritte zum Nachstellen, das erwartete Ergebnis und die Auswirkungen. Teile nur bereinigte Logs oder Screenshots. Entferne Passwörter, Authentifizierungs-Header, Receiver-Adressen, persönliche Dateinamen und Gerätekennungen.

Zum Prüfbereich gehören offengelegte Zugangsdaten, unbeabsichtigte Netzwerkzugriffe, Fehler bei Weiterleitung oder Anmeldung, unsichere Verarbeitung von Receiver-Daten oder Medien, offengelegte lokale Daten sowie manipulierte Abhängigkeiten oder Release-Pakete. Funktionswünsche und gewöhnliche Wiedergabeprobleme können in öffentlichen Issues gemeldet werden, sofern sie keine privaten Daten enthalten.

## Bekannte Einschränkungen

Die veröffentlichten Beta-Pakete sind ad-hoc signiert und nicht mit Apple Developer ID notarisiert. Gatekeeper kann beim ersten Start eine Freigabe verlangen. Wiederholte Schlüsselbund-Abfragen nach einem Neubuild werden weiterhin untersucht. Diese Richtlinie bescheinigt weder der App noch ihren Abhängigkeiten, frei von Sicherheitslücken zu sein.
