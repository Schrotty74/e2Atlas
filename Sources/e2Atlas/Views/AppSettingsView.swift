import AppKit
import SwiftUI
import AtlasCore
import AtlasReceiver
import AtlasThemes

struct AppSettingsView: View {
    @Bindable var settings: SettingsStore
    let themes: ThemeCatalog
    var body: some View {
        TabView {
            Tab("Receiver", systemImage: "tv") { ReceiverManagementView(settings: settings) }
            Tab("EPG", systemImage: "calendar") { EPGSettingsView(settings: settings) }
            Tab("Darstellung", systemImage: "paintpalette") { ThemeSettingsView(settings: settings, themes: themes) }
            Tab("About", systemImage: "info.circle") { AboutSettingsView() }
        }
        .onChange(of: settings.preferences) { settings.persist() }
    }
}

private struct ThemeSettingsView: View {
    @Bindable var settings: SettingsStore
    let themes: ThemeCatalog
    @State private var folderError: String?
    @State private var notice: LocalizedStringResource?
    @Environment(\.atlasTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    private var folder: URL? { settings.paths?.support.appendingPathComponent("Themes", isDirectory: true) }

    var body: some View {
        Form {
            Picker("Sprache", selection: Binding(get: { settings.language }, set: { settings.setLanguage($0) })) {
                Text("System").tag(AppLanguage.system)
                Text(verbatim: "Deutsch").tag(AppLanguage.german)
                Text(verbatim: "English").tag(AppLanguage.english)
            }
            Text("System folgt der Sprache von macOS.").font(.caption).foregroundStyle(.secondary)
            Text("Die Oberfläche wechselt sofort. Einige macOS-Menüs und Dialoge übernehmen die Sprache beim nächsten App-Start.").font(.caption).foregroundStyle(.secondary)
            Picker("Darstellung", selection: $settings.preferences.appearance) {
                ForEach(Appearance.allCases, id: \.self) { Text(LocalizedStringKey($0.title)).tag($0) }
            }
            Picker("Theme", selection: $settings.preferences.themeID) {
                ForEach(themes.themes) { value in Text(["system", "ocean", "ivory", "bronze"].contains(value.id) ? settings.language.localized(value.name) : value.name).tag(value.id) }
            }
            Text("Automatisch folgt der hellen oder dunklen Darstellung von macOS.").font(.callout).foregroundStyle(.secondary)
            Section("Eigene Themes") {
                Text("Speichere eigene JSON-Themes im Theme-Ordner. Jede gültige Datei erscheint in der Auswahl. Die Vorlage enthält helle und dunkle Farben sowie einen optionalen Verlauf.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Theme-Vorlage erstellen", systemImage: "doc.badge.plus") {
                    do {
                        guard let folder else { throw CocoaError(.fileNoSuchFile) }
                        let created = try themes.createTemplate(in: folder, language: settings.language.resolved.rawValue)
                        reload()
                        settings.preferences.themeID = created.theme.id
                        folderError = nil
                        notice = "Vorlage „\(created.url.lastPathComponent)“ erstellt. Eine Anleitung liegt im selben Ordner."
                        NSWorkspace.shared.activateFileViewerSelecting([created.url])
                    } catch { folderError = "Die Theme-Vorlage konnte nicht erstellt werden." }
                }
                HStack {
                    Button("Theme-Ordner öffnen", systemImage: "folder") {
                        do {
                            guard let folder else { throw CocoaError(.fileNoSuchFile) }
                            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                            guard NSWorkspace.shared.open(folder) else { throw CocoaError(.fileReadUnknown) }
                            folderError = nil
                        } catch { folderError = "Der Theme-Ordner konnte nicht geöffnet werden." }
                    }
                    Button("Themes neu laden", systemImage: "arrow.clockwise", action: reload)
                }
                Text("Die Liste wird hier alle zwei Sekunden aktualisiert. Verwende pro Theme eine eigene Kennung. Die Kennungen mitgelieferter Themes sind reserviert.")
                    .font(.caption).foregroundStyle(.secondary)
                if let notice { AppLocalizedText(resource: notice).font(.callout).foregroundStyle(.secondary) }
            }
            if themes.invalidFileCount > 0 {
                Text("\(themes.invalidFileCount) ungültige oder doppelte Theme-Dateien wurden ausgelassen. Hinweise zum Format stehen in der Anleitung bei der Vorlage.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if let error = folderError ?? settings.error { ErrorNotice(message: error) }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding(16).frame(width: 650, height: 560)
        .background { AtlasThemeBackground() }
        .foregroundStyle(theme.id == "system" ? Color.primary : Color(atlasHex: theme.palette(for: scheme).text))
        .tint(theme.id == "system" ? .accentColor : Color(atlasHex: theme.palette(for: scheme).accent))
        .task {
            repeat {
                reload()
                do { try await Task.sleep(for: .seconds(2)) }
                catch { return }
            } while !Task.isCancelled
        }
    }

    private func reload() {
        themes.reload(customDirectory: folder)
        if !themes.themes.contains(where: { $0.id == settings.preferences.themeID }) {
            settings.preferences.themeID = "system"
        }
    }
}


private struct AboutSettingsView: View {
    @Environment(\.atlasTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—" }
    private var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—" }

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable().scaledToFit().frame(width: 112, height: 112)
                .accessibilityHidden(true)
            Text("e2Atlas").font(.largeTitle.bold())
            Text("Version \(version) · Build \(build)").font(.callout).foregroundStyle(.secondary)
            Text("Fernsehen von deinem Enigma2-Receiver auf deinem Mac.")
                .font(.body).multilineTextAlignment(.center)
            HStack(spacing: 16) {
                if let url = URL(string: "https://schrotty74.github.io/Portfolio/") {
                    Link(destination: url) { Label("Homepage", systemImage: "globe") }
                }
                if let url = URL(string: "https://github.com/Schrotty74/e2Atlas") {
                    Link(destination: url) { Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right") }
                }
            }.buttonStyle(.bordered).controlSize(.large)
            Spacer()
        }
        .padding(32).frame(width: 650, height: 560)
        .background { AtlasThemeBackground() }
        .foregroundStyle(theme.id == "system" ? Color.primary : Color(atlasHex: theme.palette(for: scheme).text))
        .tint(theme.id == "system" ? .accentColor : Color(atlasHex: theme.palette(for: scheme).accent))
    }
}

private struct EPGScheduleRequest: Identifiable {
    let id = UUID()
    let client: OpenWebifClient
}

private struct EPGSettingsView: View {
    let settings: SettingsStore
    @State private var scheduleRequest: EPGScheduleRequest?
    @State private var error: String?
    @Environment(\.atlasTheme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Form {
            Section("EPG-Anzeige") {
                EPGDisplayRefreshPicker(settings: settings)
                Text("Aktualisiert die Programmanzeige in e2Atlas, solange die App geöffnet ist.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("EPGRefresh auf dem Receiver") {
                if let receiver = settings.selectedReceiver {
                    LabeledContent("Receiver", value: receiver.name)
                } else {
                    Text("Kein Receiver ausgewählt.").foregroundStyle(.secondary)
                }
                Text("Der Zeitplan wird auf dem Receiver gespeichert. Die App muss dafür nicht geöffnet bleiben. EPGRefresh muss am Receiver installiert und über OpenWebif erreichbar sein.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("EPG automatisch aktualisieren …", systemImage: "calendar.badge.clock", action: openSchedule)
                    .disabled(settings.selectedReceiver == nil)
            }
            if let error { ErrorNotice(message: error) }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding(16).frame(width: 650, height: 560)
        .background { AtlasThemeBackground() }
        .foregroundStyle(theme.id == "system" ? Color.primary : Color(atlasHex: theme.palette(for: scheme).text))
        .tint(theme.id == "system" ? .accentColor : Color(atlasHex: theme.palette(for: scheme).accent))
        .sheet(item: $scheduleRequest) { request in
            EPGRefreshView(client: request.client, preferredBouquetID: nil)
        }
        .onChange(of: settings.selectedReceiver) { scheduleRequest = nil; error = nil }
        .onChange(of: settings.connectionRevision) { scheduleRequest = nil; error = nil }
    }

    private func openSchedule() {
        guard let receiver = settings.selectedReceiver else { return }
        do {
            let password = try settings.credentials.availablePassword(for: receiver.id)
            error = nil
            scheduleRequest = EPGScheduleRequest(client: OpenWebifClient(profile: receiver, password: password))
        } catch { self.error = error.localizedDescription }
    }
}

struct EPGDisplayRefreshPicker: View {
    let settings: SettingsStore
    @State private var showEditor = false
    @State private var intervalValue = 6
    @State private var intervalUnit = 60
    @State private var startDate = Date()

    private var editedMinutes: Int? {
        guard intervalValue > 0, intervalValue <= 10080 / intervalUnit else { return nil }
        return intervalValue * intervalUnit
    }

    var body: some View {
        LabeledContent("EPG-Anzeige aktualisieren") {
            Menu {
                Button("Aus") {
                    settings.preferences.epgUpdateIntervalMinutes = 0
                    settings.persist()
                }
                Button("Alle 6 Stunden …") { edit(minutes: 360) }
                Button("Eigenes Intervall …") { edit(minutes: settings.preferences.epgRefreshMinutes > 0 ? settings.preferences.epgRefreshMinutes : 360) }
            } label: {
                if settings.preferences.epgRefreshMinutes == 0 { Text("Aus") }
                else if settings.preferences.epgRefreshMinutes == 1 { Text("Jede Minute") }
                else if settings.preferences.epgRefreshMinutes == 60 { Text("Stündlich") }
                else if settings.preferences.epgRefreshMinutes.isMultiple(of: 60) {
                    Text("Alle \(settings.preferences.epgRefreshMinutes / 60) Stunden")
                } else { Text("Alle \(settings.preferences.epgRefreshMinutes) Minuten") }
            }
            .accessibilityLabel("EPG-Anzeige aktualisieren")
            .fixedSize()
        }
        .popover(isPresented: $showEditor) {
            VStack(alignment: .leading, spacing: 16) {
                Text("EPG-Aktualisierung").font(.headline)
                HStack {
                    TextField("Intervall", value: $intervalValue, format: .number.grouping(.never))
                        .frame(width: 120)
                    Picker("Einheit", selection: $intervalUnit) {
                        Text("Minuten").tag(1)
                        Text("Stunden").tag(60)
                    }.frame(width: 180)
                }
                DatePicker("Beginn", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                Text("Die Startzeit bleibt bei einem App-Neustart erhalten. Danach gilt der nächste zukünftige Termin.")
                    .font(.caption).foregroundStyle(.secondary)
                if editedMinutes == nil {
                    Text("Bitte ein Intervall zwischen einer Minute und sieben Tagen eingeben.")
                        .font(.caption).foregroundStyle(.orange)
                }
                HStack {
                    Button("Abbrechen") { showEditor = false }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Übernehmen") {
                        guard let minutes = editedMinutes else { return }
                        settings.preferences.epgUpdateIntervalMinutes = minutes
                        settings.preferences.epgRefreshStartDate = Date(timeIntervalSince1970: floor(startDate.timeIntervalSince1970 / 60) * 60)
                        settings.persist(); showEditor = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(editedMinutes == nil)
                }
            }.padding(22).frame(width: 440)
        }
    }

    private func edit(minutes: Int) {
        let minutes = minutes > 0 ? minutes : 360
        intervalUnit = minutes.isMultiple(of: 60) ? 60 : 1
        intervalValue = minutes / intervalUnit
        startDate = settings.preferences.epgRefreshStartDate ?? Date().addingTimeInterval(Double(minutes) * 60)
        showEditor = true
    }
}
