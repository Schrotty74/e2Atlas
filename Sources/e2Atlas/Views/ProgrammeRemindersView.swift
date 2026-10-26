import SwiftUI
import AtlasCore

struct ProgrammeRemindersView: View {
    @Bindable var store: ProgrammeReminderStore
    let settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Erinnerungen").font(.title2.bold()); Spacer(); Button("Fertig") { dismiss() }.keyboardShortcut(.cancelAction).help("Erinnerungsfenster schließen") }
            Text("Erinnerungen erscheinen als macOS-Mitteilung. Der Mac muss eingeschaltet sein; Fokus und Mitteilungseinstellungen können die Anzeige unterdrücken. Sendezeitänderungen werden beim Laden neuer EPG-Daten nach Möglichkeit berücksichtigt.")
                .font(.callout).foregroundStyle(.secondary)
            if let error = store.error { ErrorNotice(message: settings.language.localized(error)) }
            List {
                ForEach(store.reminders.filter { $0.fireDate > Date() }) { value in
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(value.programme.title).font(.headline)
                            Text("\(value.channelName) · \(value.programme.start.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale)))")
                            Text("\(value.minutesBefore) Minuten vorher").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Entfernen", systemImage: "bell.slash") { store.remove(value) }.disabled(store.isSaving)
                            .help("Erinnerung für diese Sendung entfernen")
                    }
                }
            }.overlay { if store.reminders.allSatisfy({ $0.fireDate <= Date() }) { ContentUnavailableView("Keine Erinnerungen", systemImage: "bell") } }
        }.padding(24).frame(minWidth: 600, minHeight: 430)
    }
}
