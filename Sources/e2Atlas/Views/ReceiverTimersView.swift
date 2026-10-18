import SwiftUI
import AtlasCore
import AtlasReceiver
import AtlasThemes

private struct TimerSource: Equatable {
    let id: UUID
    let address: String
    init?(_ client: OpenWebifClient?) {
        guard let profile = client?.profile else { return nil }
        id = profile.id; address = profile.address
    }
}

private struct TimerEditorSession: Identifiable {
    let id = UUID()
    let timer: ReceiverTimer?
    let draft: ReceiverTimerDraft
    let serviceName: String
}

struct ReceiverTimersView: View {
    let client: OpenWebifClient?
    let programme: Programme?
    let channel: Channel?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var store = ReceiverTimerStore()
    @State private var editor: TimerEditorSession?
    @State private var deleteCandidate: ReceiverTimer?

    init(client: OpenWebifClient?, programme: Programme? = nil, channel: Channel? = nil) {
        self.client = client; self.programme = programme; self.channel = channel
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Receiver-Timer").font(.title2.weight(.semibold))
                    Text(client?.profile.name ?? AppLanguage(locale: locale).localized("Kein Receiver ausgewählt")).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Aktualisieren", systemImage: "arrow.clockwise") {
                    Task { await store.load(using: client) }
                }.disabled(store.isLoading || store.isSaving || client == nil)
                Button("Fertig") { dismiss() }.keyboardShortcut(.defaultAction)
            }.padding(22)
            Divider()
            if client == nil {
                ContentUnavailableView("Kein Receiver ausgewählt", systemImage: "tv",
                                       description: Text("Wähle zuerst einen Receiver aus."))
            } else if store.isLoading && store.timers.isEmpty {
                ProgressView("Timer werden geladen …").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if let notice = store.notice { Label(LocalizedStringKey(notice), systemImage: "checkmark.circle").foregroundStyle(.green) }
                    if let error = store.error { ErrorNotice(message: error) }
                    if let programme, let channel {
                        Section {
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(channel.name) · \(programme.title)").font(.headline).lineLimit(2)
                                    Text("\(programme.start.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale))) – \(programme.end.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale)))")
                                        .font(.callout).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Timer hinzufügen", systemImage: "plus") { addProgrammeTimer() }
                                    .disabled(store.isSaving)
                            }
                        } header: { Text("Programm") }
                    }
                    Section("Geplante Timer") {
                        if store.timers.isEmpty && !store.isLoading {
                            ContentUnavailableView("Keine Timer", systemImage: "calendar", description: Text("Für diesen Receiver sind keine Timer eingetragen."))
                        }
                        ForEach(store.timers) { timer in
                            timerRow(timer)
                        }
                    }
                }.listStyle(.inset)
            }
        }
        .frame(minWidth: 650, minHeight: 480)
        .background { AtlasThemeBackground() }
        .task(id: TimerSource(client)) {
            store.reset(); editor = nil; deleteCandidate = nil
            await store.load(using: client)
        }
        .sheet(item: $editor) { session in
            TimerEditorView(session: session, timers: store.timers, store: store, client: client) {
                editor = nil
            }
        }
        .confirmationDialog("Timer löschen?", isPresented: Binding(
            get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } }),
            titleVisibility: .visible, presenting: deleteCandidate) { timer in
                Button("Timer löschen", role: .destructive) {
                    Task { _ = await store.delete(timer, using: client); deleteCandidate = nil }
                }
                Button("Abbrechen", role: .cancel) { deleteCandidate = nil }
            } message: { timer in
                Text("„\(timer.name)“ auf \(timer.serviceName) wird vom Receiver entfernt.")
            }
    }

    private func timerRow(_ timer: ReceiverTimer) -> some View {
        HStack(spacing: 12) {
            Image(systemName: timer.justPlay ? "play.tv" : "record.circle")
                .font(.title3).foregroundStyle(timer.disabled ? Color.secondary : Color.red)
            VStack(alignment: .leading, spacing: 4) {
                Text(timer.name.isEmpty ? timer.serviceName : timer.name).font(.headline)
                Text(timer.serviceName).font(.callout).foregroundStyle(.secondary)
                Text("\(timer.begin.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale))) – \(timer.end.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale)))")
                    .font(.callout).foregroundStyle(.secondary)
                if timer.disabled { Text("Deaktiviert").font(.caption).foregroundStyle(.secondary) }
                else if timer.cancelled { Text("Abgebrochen").font(.caption).foregroundStyle(.secondary) }
                if !timer.isEditable {
                    Text("Bearbeitet werden nur normale einmalige Aufnahmetimer. Wiederholungs-, AutoTimer-, VPS-, Zap-, Sonderformat- und receiver-spezifische Timer bleiben unverändert.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Menu {
                Button("Bearbeiten", systemImage: "pencil") { edit(timer) }
                    .disabled(!timer.isEditable || store.isSaving)
                Button("Löschen", systemImage: "trash", role: .destructive) { deleteCandidate = timer }
                    .disabled(store.isSaving)
            } label: { Image(systemName: "ellipsis.circle").font(.title3) }
                .menuStyle(.borderlessButton)
        }.padding(.vertical, 5)
    }

    private func addProgrammeTimer() {
        guard let programme else { return }
        let name = programme.title
        let draft = ReceiverTimerDraft(serviceReference: channel?.id ?? programme.channelID,
                                       begin: programme.start, end: programme.end,
                                       name: name, description: programme.summary)
        editor = TimerEditorSession(timer: nil, draft: draft,
                                    serviceName: channel?.name ?? AppLanguage(locale: locale).localized("Sender aus Programmdaten"))
    }

    private func edit(_ timer: ReceiverTimer) {
        editor = TimerEditorSession(timer: timer, draft: ReceiverTimerDraft(editing: timer),
                                    serviceName: timer.serviceName)
    }
}

private struct TimerEditorView: View {
    let session: TimerEditorSession
    let timers: [ReceiverTimer]
    let store: ReceiverTimerStore
    let client: OpenWebifClient?
    let close: () -> Void
    @State private var draft: ReceiverTimerDraft

    init(session: TimerEditorSession, timers: [ReceiverTimer], store: ReceiverTimerStore,
         client: OpenWebifClient?, close: @escaping () -> Void) {
        self.session = session; self.timers = timers; self.store = store; self.client = client; self.close = close
        _draft = State(initialValue: session.draft)
    }

    private var overlaps: [ReceiverTimer] {
        timers.filter {
            $0.id != session.timer?.id && !$0.disabled && !$0.cancelled && $0.end > Date()
                && $0.begin < draft.end && $0.end > draft.begin
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(LocalizedStringKey(session.timer == nil ? "Timer hinzufügen" : "Timer bearbeiten")).font(.title2.weight(.semibold))
                Spacer()
                Button("Abbrechen", action: close)
            }
            Form {
                TextField("Titel", text: $draft.name)
                LabeledContent("Sender", value: session.serviceName)
                DatePicker("Beginn", selection: $draft.begin, displayedComponents: [.date, .hourAndMinute])
                DatePicker("Ende", selection: $draft.end, displayedComponents: [.date, .hourAndMinute])
                Picker("Nach der Aufnahme", selection: $draft.afterEvent) {
                    Text("Nichts tun").tag(0)
                    Text("Standby").tag(1)
                    Text("Ausschalten").tag(2)
                    Text("Automatisch").tag(3)
                }
                Toggle("Timer deaktiviert", isOn: $draft.disabled)
            }
            if !overlaps.isEmpty {
                Label("Zeitüberschneidung mit \(overlaps.map(\.name).filter { !$0.isEmpty }.joined(separator: ", ")). Der Receiver entscheidet, ob der Timer angelegt werden kann.", systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.orange)
            }
            if let error = store.error { ErrorNotice(message: error) }
            HStack {
                Spacer()
                Button("Speichern") {
                    Task {
                        if await store.save(draft, editing: session.timer, using: client) { close() }
                    }
                }.keyboardShortcut(.defaultAction).disabled(store.isSaving || draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.end <= draft.begin || draft.end <= Date() || draft.serviceReference.isEmpty)
            }
            if draft.end <= Date() {
                Text("Die Endzeit muss in der Zukunft liegen.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(24).frame(width: 560).frame(minHeight: 440)
        .disabled(store.isSaving)
    }
}
