import SwiftUI
import AtlasCore

struct MultiviewPresetsView: View {
    @Bindable var settings: SettingsStore
    let playback: PlaybackStore
    let onRestore: (MultiviewPreset) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var message: String?

    private var presets: [MultiviewPreset] {
        (settings.preferences.multiviewPresets ?? []).filter { $0.receiverID == settings.selectedReceiver?.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Multiview-Belegungen").font(.title2)
            Text("Sender und Tonquelle für den ausgewählten Receiver speichern.").foregroundStyle(.secondary)
            HStack {
                TextField("Name der Belegung", text: $name)
                Button("Aktuelle Belegung speichern") { save() }
                    .disabled(!playback.isMultiview || !playback.slots.prefix(playback.visibleCount).contains { $0.channel != nil } || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("Sender und Tonquelle für den ausgewählten Receiver speichern")
            }
            if !playback.isMultiview { Text("Zum Speichern zuerst Multiview öffnen.").font(.caption) }
            List(presets) { preset in
                HStack {
                    VStack(alignment: .leading) {
                        Text(preset.name).font(.headline)
                        Text(preset.channels.map { $0?.name ?? settings.language.localized("Freies Bild") }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Öffnen") { onRestore(preset); dismiss() }
                        .help("Diese Belegung für den ausgewählten Receiver wiederherstellen")
                    Button("Löschen", role: .destructive) {
                        settings.preferences.multiviewPresets?.removeAll { $0.id == preset.id }; settings.persist()
                    }
                    .help("Gespeicherte Multiview-Belegung löschen")
                }
            }.overlay { if presets.isEmpty { Text("Noch keine Belegungen gespeichert.").foregroundStyle(.secondary) } }
            if let message = message ?? settings.error { AppLocalizedText(message).foregroundStyle(.red) }
            HStack { Spacer(); Button("Fertig") { dismiss() }.keyboardShortcut(.cancelAction).help("Multiview-Belegungen schließen") }
        }.padding(24).frame(width: 640, height: 420)
    }

    private func save() {
        guard let receiverID = settings.selectedReceiver?.id else { return }
        let preset = playback.preset(name: name, receiverID: receiverID)
        guard preset.isValid else { message = "Bitte einen Namen mit höchstens 80 Zeichen und mindestens einen Sender wählen."; return }
        guard (settings.preferences.multiviewPresets ?? []).count < 30 else { message = "Es können höchstens 30 Belegungen gespeichert werden."; return }
        if settings.preferences.multiviewPresets == nil { settings.preferences.multiviewPresets = [] }
        settings.preferences.multiviewPresets?.append(preset); settings.persist(); name = ""; message = nil
    }
}
