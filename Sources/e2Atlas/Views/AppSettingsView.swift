import AppKit
import SwiftUI
import AtlasCore
import AtlasThemes

struct AppSettingsView: View {
    @Bindable var settings: SettingsStore
    let themes: ThemeCatalog
    var body: some View {
        TabView {
            Tab("Receiver", systemImage: "tv") { ReceiverManagementView(settings: settings) }
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
    @State private var notice: String?
    @Environment(\.atlasTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    private var folder: URL? { settings.paths?.support.appendingPathComponent("Themes", isDirectory: true) }

    var body: some View {
        Form {
            Picker("Darstellung", selection: $settings.preferences.appearance) {
                ForEach(Appearance.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Theme", selection: $settings.preferences.themeID) {
                ForEach(themes.themes) { Text($0.name).tag($0.id) }
            }
            Text("Automatisch folgt der hellen oder dunklen Darstellung von macOS.").font(.callout).foregroundStyle(.secondary)
            Section("Eigene Themes") {
                Text("Speichere eigene JSON-Themes im Theme-Ordner. Jede gültige Datei erscheint in der Auswahl. Die Vorlage enthält helle und dunkle Farben sowie einen optionalen Verlauf.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Theme-Vorlage erstellen", systemImage: "doc.badge.plus") {
                    do {
                        guard let folder else { throw CocoaError(.fileNoSuchFile) }
                        let created = try themes.createTemplate(in: folder)
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
                if let notice { Text(notice).font(.callout).foregroundStyle(.secondary) }
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
