import SwiftUI
import AtlasCore

/// Recording controls intended for presentation from the app's settings sheet.
@MainActor
struct RecordingOptionsView: View {
    let recording: RecordingStore
    @Environment(\.locale) private var locale

    var body: some View {
        Form {
            Section("Aufnahme") {
                Picker("Maximale Dauer", selection: Binding(
                    get: { recording.recordingDurationMinutes },
                    set: { recording.setRecordingDurationMinutes($0) }
                )) {
                    Text("Unbegrenzt").tag(0)
                    ForEach([30, 60, 90, 120, 180, 240, 360, 480], id: \.self) { minutes in
                        Text(Duration.seconds(minutes * 60).formatted(.time(pattern: .hourMinute).locale(locale))).tag(minutes)
                    }
                }
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Standardordner")
                        Text(recording.standardFolder?.path ?? AppLanguage(locale: locale).localized("Filme"))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer()
                    Button("Auswählen …") { recording.chooseStandardFolder(language: AppLanguage(locale: locale)) }
                    if recording.standardFolder != nil { Button("Zurücksetzen") { recording.resetStandardFolder() } }
                }
            }
            if let message = recording.message {
                AppLocalizedText(resource: message).font(.caption).foregroundStyle(.secondary)
            }
            if let error = recording.optionsError {
                AppLocalizedText(error).font(.caption).foregroundStyle(.red)
            }
        }
        .disabled(!recording.canEditOptions)
        .formStyle(.grouped)
        .frame(maxWidth: 560)
    }
}
