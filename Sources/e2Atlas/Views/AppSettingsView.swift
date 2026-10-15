import AppKit
import SwiftUI
import AtlasCore
import AtlasThemes

struct AppSettingsView: View {
    @Bindable var settings: SettingsStore
    let themes: ThemeCatalog
    @State private var folderError: String?
    var body: some View {
        TabView {
            Tab("Receiver", systemImage: "tv") { ReceiverManagementView(settings: settings) }
            Tab("Darstellung", systemImage: "paintpalette") {
                Form {
                    Picker("Darstellung", selection: $settings.preferences.appearance) {
                        ForEach(Appearance.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Picker("Theme", selection: $settings.preferences.themeID) {
                        ForEach(themes.themes) { Text($0.name).tag($0.id) }
                    }
                    Text("Automatisch folgt der hellen oder dunklen Darstellung von macOS.").font(.callout).foregroundStyle(.secondary)
                    HStack {
                        Button("Themes neu laden") { themes.reload(customDirectory: settings.paths?.support.appendingPathComponent("Themes", isDirectory: true)) }
                        Button("Theme-Ordner öffnen") {
                            guard let folder = settings.paths?.support.appendingPathComponent("Themes", isDirectory: true) else { return }
                            do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true); NSWorkspace.shared.open(folder) }
                            catch { folderError = "Der Theme-Ordner konnte nicht geöffnet werden." }
                        }
                    }
                    if themes.invalidFileCount > 0 { Text("\(themes.invalidFileCount) ungültige Theme-Dateien wurden ausgelassen.").font(.callout).foregroundStyle(.secondary) }
                    if let error = folderError ?? settings.error { ErrorNotice(message: error) }
                }.formStyle(.grouped).padding(16).frame(width: 570, height: 390)
            }
        }
        .onChange(of: settings.preferences) { settings.persist() }
    }
}
