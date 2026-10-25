# e2Atlas – vollständige Funktionsübersicht

[English](FEATURES.md) · **Deutsch** · [Zurück zur Projektseite](README.de.md)

Diese Funktionen sind in **0.5.0-beta** enthalten. Die Kompatibilität hängt von OpenWebif, den Streaming-Diensten und den installierten Receiver-Plugins ab. Prüfergebnisse und bekannte Einschränkungen stehen im [englischen Changelog](https://github.com/Schrotty74/e2Atlas/blob/beta/CHANGELOG.md).

## Live-TV und Multiview

- Bouquets durchsehen, Sendernamen suchen und Senderlogos vom Receiver anzeigen.
- Einen Sender ansehen oder zwei, drei beziehungsweise vier Multiview-Bilder mit einer ausgewählten Tonquelle nutzen.
- Ein kleines Bild mit dem Hauptbild tauschen; die Toneinstellungen bleiben beim jeweiligen Player.
- Multiview-Belegungen je Receiver speichern, einschließlich Sendern, Tonquelle, Lautstärke und Stummschaltung. Beim Wiederherstellen starten die Streams schrittweise.
- Lautstärke und Stummschaltung steuern, zum reinen Video-Vollbild wechseln und per Escape oder Doppelklick zurückkehren.
- Jeden Live-Wiedergabeplatz unabhängig wiederverbinden, mit höchstens drei Versuchen und einer Abbruchmöglichkeit.
- Einen Sleep-Timer setzen, der die Wiedergabe stoppt und lokale Aufnahmen weiterlaufen lässt.
- Apples VideoToolbox-Decoder anfordern, wenn er unterstützt wird. Die Wiedergabebibliothek kann auf Software-Decodierung zurückfallen; Hardware-Decodierung und CPU-Auswirkung wurden nicht gemessen.

## Programmführer

- Sieben Kalendertage seitlich durchscrollen, mit sichtbarem Datum und festen Sendernamen. Als sichtbaren Ausschnitt zwei, vier oder sechs Stunden wählen.
- Zu jetzt, 20:15 Uhr oder gespeicherten eigenen Zeiten springen.
- Titel und Beschreibungen im geladenen Sieben-Tage-Bereich des gewählten Bouquets durchsuchen. Treffer in der Zeitlinie öffnen oder weitere geladene Ausstrahlungen desselben Titels finden.
- Sendungsbeschreibungen lesen und den Fortschritt der laufenden Sendung in den Details ansehen.
- Erinnerungsglocken sowie geplante und laufende Aufnahmen in Sendungsfeldern, Suchtreffern und Details sehen. Markierungen geplanter Timer gelten für unterstützte Einzelaufnahmen; wiederkehrende und spezielle Timer sind ausgenommen.
- EPG-Daten im Arbeitsspeicher und in einem lokalen Cache je Receiver und App-Kanal wiederverwenden. Scrollen und Zoom lösen keinen erneuten EPG-Abruf aus.
- Anzeigeaktualisierung im Programmführer oder unter Einstellungen → EPG festlegen: Aus, standardmäßig sechs Stunden oder ein eigenes Intervall von einer Minute bis sieben Tagen, mit gespeichertem Startdatum und Uhrzeit. Vorhandene Daten bleiben während des Ladens sichtbar; Wiedergabe und Senderliste werden nicht neu gestartet beziehungsweise eingelesen.

## Jetzt und danach

- Eine kompakte Programmübersicht mit Bouquet, Favoriten und Sendersuche öffnen. Sie zeigt die aktuelle und die folgende Sendung mit Details und Wiedergabesteuerung.
- Geladene Programmdaten beim Wechsel zwischen Ansichten und Bouquets behalten und den vorhandenen Wochen-EPG-Cache wiederverwenden.
- Sendungen an ihren Zeitgrenzen automatisch weiterschalten. Fehlt eine Folgesendung, lädt die App EPG-Daten für diesen Sender nach. Bei Fehlern bleiben die angezeigten Daten erhalten; vor der nächsten Anfrage gilt eine Wartezeit.

## EPGRefresh am Receiver

- Ein tägliches Zeitfenster, eines oder alle vorhandenen Bouquets und eine Verweildauer je Sender in Sekunden festlegen.
- EPGRefresh-Einstellungen des Receivers aus dem Programmführer oder den EPG-Einstellungen lesen und speichern.
- Der Receiver führt den Zeitplan auch bei geschlossener e2Atlas-App aus. Er benötigt ein kompatibles installiertes EPGRefresh-Plugin und eine korrekt eingestellte Uhr; das Plugin kann Sender desselben Transponders zusammenfassen.

## Aufnahmetimer und AutoTimer

- Receiver-Aufnahmen aus den Sendungsdetails planen und vorhandene Timer auflisten.
- Unterstützte Einzelaufnahmen bearbeiten und nach Bestätigung löschen. Unbekannte und spezielle Timertypen bleiben schreibgeschützt.
- Vom Receiver gemeldete Konflikte anzeigen und eine passende andere Ausstrahlung aus dem geladenen EPG in den Timereditor übernehmen. Beim Speichern prüft der Receiver erneut; eine reine Zeitüberschneidung belegt noch keinen Tunerkonflikt.
- Unterstützte AutoTimer-Regeln anlegen, bearbeiten und löschen: Titel-Teilwort, ein Sender oder Bouquet, optionales Startzeitfenster, Wochentage, Vor-/Nachlauf und Duplikaterkennung auf demselben Sender.
- Passende Sendungen nach Titel, Sender/Bouquet, Wochentag und Zeitfenster im bereits geladenen EPG vorab ansehen.
- AutoTimer läuft am Receiver; die regelmäßige Suche muss im Plugin separat aktiviert sein. Komplexe Regeln und nicht unterstützte geerbte Standardwerte bleiben geschützt. Die Vorschau verwendet die Zeitzone des Macs; Plugin-Filter und Duplikaterkennung können zu anderen tatsächlichen Timern führen.

## Receiver-Aufnahmen und lokale Aufnahme

- Vom Receiver angebotene Aufnahmeordner und Speicherorte öffnen; Titel und Beschreibungen durchsuchen.
- Geplante Timer, vom Receiver als laufend gemeldete Timer und Dateien gemeinsam anzeigen, mit den Filtern Alle, Geplant, Laufend und Bibliothek. Dateien heißen Bibliothek, weil OpenWebif abgeschlossene Aufnahmen nicht verlässlich kennzeichnet.
- Receiver-Aufnahmen mit Pause, Positionswechsel, Lautstärke und Vollbild abspielen. Positionen lokal je Receiver speichern und zwischen Fortsetzen und Wiedergabe von Anfang an wählen.
- Gemeldeten freien und gesamten Receiver-Speicherplatz anzeigen, nach Möglichkeit mit Zuordnung zum aktuellen Ordner. Fehlende Kapazitätswerte werden nicht geschätzt.
- Den Originalstream im Hauptplayer oder einem Multiview-Bild als lokale `.ts`-Datei aufnehmen. Ordner und Dauer wählen, Sendungstitel im Dateinamen verwenden, in der App stoppen und die Datei im Finder anzeigen.
- Bei wenig Speicherplatz die lokale Aufnahme stoppen. Receiver-Timer und lokale Streamaufnahme sind getrennte Funktionen.

## Erinnerungen und Favoriten

- Erinnerungen in den Sendungsdetails mit 1, 5, 10, 15, 30 oder 60 Minuten Vorlauf setzen; anstehende Erinnerungen auflisten und entfernen.
- Native lokale macOS-Mitteilungen auch bei geschlossener e2Atlas-App zustellen lassen. Die Freigabe wird beim Anlegen angefragt. Fokus, Mitteilungsfreigaben und der Betriebszustand des Macs beeinflussen die Zustellung.
- Die zugehörigen Sendungsdetails aus einer Mitteilung öffnen, auch beim Start der App.
- Erinnerungen anpassen, wenn frische EPG-Daten eine verschobene Sendung eindeutig zuordnen. Unklare Treffer bleiben unverändert; bereits vergangene neue Erinnerungszeitpunkte werden entfernt.
- Favoriten über den Stern neben dem Sender hinzufügen oder entfernen. Sie werden je Receiver gespeichert und unabhängig vom gewählten Bouquet angezeigt.

## Receiver, Darstellung und App-Bedienung

- Bis zu drei Receiver speichern. Zugangsdaten sind optional, wenn der Receiver dies erlaubt; Passwörter liegen im macOS-Schlüsselbund.
- Automatisches Verbinden beim Start in den Receiver-Einstellungen ein- oder ausschalten. Vorübergehende Erreichbarkeitsfehler werden begrenzt wiederholt; manuelles Aktualisieren kann Metadaten laden, ohne die Wiedergabe zu stoppen.
- Vom Receiver gemeldete Hardware- und Systeminformationen anzeigen. Bestätigte Tuner-Zuordnungen und Streams ohne Zuordnung werden unterschieden; die gesamte Belegung kann unbekannt bleiben, auch bei FBC-Tunern.
- Deutsch oder Englisch im Menü Sprache oder in den Darstellungseinstellungen wählen. Ansichten wechseln sofort; native macOS-Menüs nach erneutem Öffnen.
- System, Ocean, Elfenbein oder Bronze mit hellen und dunklen Paletten wählen. Der macOS-Darstellung folgen oder Hell und Dunkel manuell einstellen.
- Eigene JSON-Themes über die Vorlage in den Darstellungseinstellungen erstellen. Siehe [Theme-Anleitung](https://github.com/Schrotty74/e2Atlas/blob/beta/Documentation/Themes/README.de.md).
- Homepage und Repository unter Über öffnen. Schließen des Hauptfensters beendet die App auch bei offenen Nebenfenstern.
- Einstellungen, Caches und Schlüsselbund-Services für Dev, Beta und Final getrennt halten.
- Einstellungen als JSON-Backup exportieren und dessen Inhalt vor dem Import in einer Vorschau prüfen. Das Backup kann Receiver-Profile mit Adressen und Benutzernamen, Favoriten, Multiview-Belegungen, allgemeine Optionen, eigene EPG-Zeitkürzel und gültige eigene Themes enthalten. Passwörter, Erinnerungen, Wiedergabepositionen, lokale Aufnahmedateien, Ordnerrechte und EPG-Caches sind ausgeschlossen. Beim Import bleiben bestehende Profile und Einträge erhalten; allgemeine Einstellungen werden ersetzt. Für neu hinzugefügte Receiver kann ein Passwort erforderlich sein.
