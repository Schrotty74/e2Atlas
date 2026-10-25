import SwiftUI
import UniformTypeIdentifiers
import AtlasCore
import AtlasThemes

private struct SettingsJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct SettingsTransferView: View {
    let settings: SettingsStore
    let themes: ThemeCatalog
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var exportDocument: SettingsJSONDocument?
    @State private var importPlan: SettingsImportPlan?
    @State private var busy = false
    @State private var error: String?
    @State private var notice: LocalizedStringResource?
    @State private var reader = SettingsArchiveReader()
    @Environment(\.atlasTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    private var themeDirectory: URL? { settings.paths?.support.appendingPathComponent("Themes", isDirectory: true) }

    var body: some View {
        Form {
            Section("Einstellungen sichern") {
                Text("Exportiert Receiver-Profile, Favoriten, Multiview-Belegungen, Sprache, Darstellung, Startverbindung, EPG-Anzeigeoptionen, Zeitkürzel und gültige eigene Themes.")
                Text("Die JSON-Datei enthält Receiver-Adressen und Benutzernamen. Bewahre sie an einem geschützten Ort auf.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Einstellungen exportieren …", systemImage: "square.and.arrow.up", action: prepareExport)
            }
            Section("Einstellungen übernehmen") {
                Text("Prüfe die Zusammenfassung vor dem Import. Vorhandene Receiver, Favoriten, Belegungen und Themes bleiben erhalten; neue Einträge werden ergänzt. Allgemeine Einstellungen werden übernommen.")
                Button("Einstellungen importieren …", systemImage: "square.and.arrow.down") { error = nil; notice = nil; showImporter = true }
                if busy { ProgressView("Sicherung wird gelesen …").controlSize(.small) }
            }
            Text("Passwörter, Erinnerungen, Wiedergabepositionen, Aufnahmedateien, Aufnahmeordner-Freigaben und EPG-Caches sind nicht enthalten. Für neu importierte Receiver musst du Passwörter erneut eingeben. Receiver-Zeitpläne werden nicht verändert.")
                .font(.caption).foregroundStyle(.secondary)
            if let notice { AppLocalizedText(resource: notice).foregroundStyle(.secondary) }
            if let error = error ?? settings.error { ErrorNotice(message: error) }
        }
        .formStyle(.grouped).scrollContentBackground(.hidden)
        .padding(16).frame(width: 650, height: 560)
        .background { AtlasThemeBackground() }
        .foregroundStyle(theme.id == "system" ? Color.primary : Color(atlasHex: theme.palette(for: scheme).text))
        .tint(theme.id == "system" ? .accentColor : Color(atlasHex: theme.palette(for: scheme).accent))
        .disabled(busy)
        .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: .json, defaultFilename: "e2Atlas-settings") { result in
            switch result {
            case .success: notice = "Einstellungen exportiert."
            case .failure(let failure): if (failure as NSError).code != NSUserCancelledError { error = "Die Einstellungen konnten nicht exportiert werden." }
            }
            exportDocument = nil
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                busy = true
                Task {
                    defer { busy = false }
                    do {
                        let archive = try await reader.read(url)
                        themes.reload(customDirectory: themeDirectory)
                        importPlan = try SettingsImportPlan(archive: archive, current: settings.preferences, existingThemes: themes.themes)
                    } catch let failure as AtlasFailure { self.error = failure.localizedDescription }
                    catch { self.error = "Die Sicherung konnte nicht gelesen werden. Prüfe die Zugriffsberechtigung der Datei." }
                }
            case .failure(let failure): if (failure as NSError).code != NSUserCancelledError { error = "Die Sicherung konnte nicht geöffnet werden." }
            }
        }
        .sheet(item: $importPlan) { plan in
            SettingsImportPreview(plan: plan, onCancel: { importPlan = nil }, onImport: {
                do {
                    themes.reload(customDirectory: themeDirectory)
                    try settings.importSettings(plan, themes: themes.themes)
                    themes.reload(customDirectory: themeDirectory)
                    error = nil; notice = "Einstellungen importiert. Neue Receiver benötigen gegebenenfalls ein Passwort."
                } catch { self.error = error.localizedDescription }
                importPlan = nil
            })
        }
    }

    private func prepareExport() {
        error = nil; notice = nil
        do {
            themes.reload(customDirectory: themeDirectory)
            let archive = try SettingsArchive(preferences: settings.preferences, themes: themes.themes)
            exportDocument = SettingsJSONDocument(data: try archive.encoded())
            showExporter = true
        } catch { self.error = "Die Einstellungen konnten nicht exportiert werden." }
    }
}

private struct SettingsImportPreview: View {
    let plan: SettingsImportPlan
    let onCancel: () -> Void
    let onImport: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Einstellungen importieren?").font(.title2.weight(.semibold))
            Form {
                LabeledContent("Neue Receiver", value: plan.addedReceiverCount.formatted())
                    .accessibilityElement(children: .combine)
                LabeledContent("Neue Favoriten", value: plan.addedFavoriteCount.formatted())
                    .accessibilityElement(children: .combine)
                LabeledContent("Neue Multiview-Belegungen", value: plan.addedPresetCount.formatted())
                    .accessibilityElement(children: .combine)
                LabeledContent("Neue eigene Themes", value: plan.themesToAdd.count.formatted())
                    .accessibilityElement(children: .combine)
            }.formStyle(.grouped).frame(height: 190)
            Text("Sprache, Darstellung, Startverbindung, EPG-Anzeigeoptionen und Zeitkürzel werden ersetzt. Vorhandene Receiver, Favoriten, Multiview-Belegungen und Themes bleiben erhalten. Ein Receiverwechsel beendet die laufende Wiedergabe.")
                .font(.callout)
            Text("Die Sicherung enthält keine Passwörter und ändert keine gespeicherten Passwörter. Für neue Receiver ist bei geschütztem Zugang eine erneute Eingabe nötig.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Abbrechen", action: onCancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Importieren", action: onImport).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 570)
    }
}
