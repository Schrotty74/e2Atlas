import SwiftUI
import AtlasCore
import AtlasReceiver

private struct AutoTimerEditorItem: Identifiable {
    let id = UUID()
    let rule: ReceiverAutoTimerRule?
}

struct ReceiverAutoTimersView: View {
    let client: OpenWebifClient?
    let channels: [Channel]
    let bouquets: [Bouquet]
    let loadedProgrammes: [Programme]
    @State private var rules: [ReceiverAutoTimerRule] = []
    @State private var isLoading = false
    @State private var isDeleting = false
    @State private var error: String?
    @State private var editor: AutoTimerEditorItem?
    @State private var deleteCandidate: ReceiverAutoTimerRule?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    private var language: AppLanguage { AppLanguage(locale: locale) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("AutoTimer-Regeln").font(.title2.bold())
                Spacer()
                if isLoading || isDeleting { ProgressView().controlSize(.small) }
                Button("Aktualisieren", systemImage: "arrow.clockwise") { Task { await load() } }.disabled(isLoading || isDeleting)
                Button("Neue Regel", systemImage: "plus") { editor = AutoTimerEditorItem(rule: nil) }
                    .disabled(client == nil || isLoading || isDeleting || (channels.isEmpty && bouquets.isEmpty))
                Button("Fertig") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text("AutoTimer sucht auf dem Receiver nach passenden EPG-Sendungen und erstellt Aufnahme-Timer. Das Plugin muss installiert und dessen regelmäßige Suche aktiviert sein. Wiederholungen lassen sich nur anhand der vorhandenen EPG-Angaben unterscheiden.")
                .font(.callout).foregroundStyle(.secondary)
            if let error { ErrorNotice(message: language.localized(error)) }
            List {
                ForEach(rules) { rule in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(rule.title).font(.headline)
                            Text(rule.match).font(.callout).foregroundStyle(.secondary)
                            Text(LocalizedStringKey(rule.enabled ? "Aktiv" : "Deaktiviert")).font(.caption)
                            if !rule.isEditable { Text("Erweiterte Regel: nur Anzeige möglich.").font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Button("Bearbeiten") { editor = AutoTimerEditorItem(rule: rule) }.disabled(!rule.isEditable || isDeleting)
                        Button("Löschen", role: .destructive) { deleteCandidate = rule }.disabled(isDeleting || !rule.isEditable)
                    }.padding(.vertical, 4)
                }
            }.overlay { if !isLoading && rules.isEmpty && error == nil { ContentUnavailableView("Keine AutoTimer-Regeln", systemImage: "repeat") } }
        }
        .padding(24).frame(minWidth: 750, minHeight: 520)
        .task(id: client?.profile) { await load() }
        .sheet(item: $editor) { item in
            AutoTimerRuleEditor(client: client, rule: item.rule, channels: channels, bouquets: bouquets, loadedProgrammes: loadedProgrammes) { Task { await load() } }
        }
        .confirmationDialog("AutoTimer-Regel löschen?", isPresented: Binding(get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } }), titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                guard let rule = deleteCandidate, let client else { return }
                deleteCandidate = nil; isDeleting = true
                Task {
                    defer { isDeleting = false }
                    do { try await client.deleteAutoTimer(rule); await load() }
                    catch { self.error = error.localizedDescription }
                }
            }
        } message: { Text("Bereits angelegte Aufnahme-Timer bleiben erhalten.") }
    }

    private func load() async {
        guard !isLoading else { return }
        guard let client else { error = "Kein Receiver ausgewählt."; return }
        isLoading = true; error = nil
        defer { isLoading = false }
        do {
            let loaded = try await client.autoTimerRules()
            guard !Task.isCancelled else { return }
            rules = loaded.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
}

private struct AutoTimerRuleEditor: View {
    let client: OpenWebifClient?
    let rule: ReceiverAutoTimerRule?
    let channels: [Channel]
    let bouquets: [Bouquet]
    let loadedProgrammes: [Programme]
    let onSaved: () -> Void
    @State private var title = ""
    @State private var match = ""
    @State private var enabled = true
    @State private var target = ""
    @State private var useTimespan = false
    @State private var begin = Date()
    @State private var end = Date()
    @State private var weekdays = Set<Int>()
    @State private var before = 5
    @State private var after = 5
    @State private var avoidDuplicates = true
    @State private var isSaving = false
    @State private var error: String?
    @State private var preview: [Programme]?
    @State private var isPreviewing = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    private var targets: [(key: String, name: String, target: ReceiverAutoTimerTarget)] {
        var values = channels.map { (key: "s:" + $0.id, name: $0.name, target: ReceiverAutoTimerTarget.service($0.id)) }
        values += bouquets.map { (key: "b:" + $0.id, name: $0.name, target: ReceiverAutoTimerTarget.bouquet($0.id)) }
        if let stored = rule?.target, !values.contains(where: { $0.target == stored }) {
            switch stored {
            case .service(let ref): values.append(("s:" + ref, ref, stored))
            case .bouquet(let ref): values.append(("b:" + ref, ref, stored))
            }
        }
        return values
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey(rule == nil ? "Neue AutoTimer-Regel" : "AutoTimer-Regel bearbeiten")).font(.title2.bold())
            Form {
                TextField("Name", text: $title)
                TextField("Titel enthält", text: $match)
                Toggle("Aktiv", isOn: $enabled)
                Picker("Sender oder Bouquet", selection: $target) {
                    ForEach(targets, id: \.key) { entry in Text(entry.name).tag(entry.key) }
                }
                Toggle("Zeitfenster begrenzen", isOn: $useTimespan)
                if useTimespan {
                    DatePicker("Von (Receiver-Ortszeit)", selection: $begin, displayedComponents: .hourAndMinute)
                    DatePicker("Bis (Receiver-Ortszeit)", selection: $end, displayedComponents: .hourAndMinute)
                }
                LabeledContent("Wochentage") {
                    HStack {
                        ForEach(1...7, id: \.self) { day in
                            Toggle(dayTitle(day), isOn: Binding(get: { weekdays.contains(day) }, set: { if $0 { weekdays.insert(day) } else { weekdays.remove(day) } }))
                                .toggleStyle(.button)
                        }
                    }
                }
                Text("Ohne ausgewählte Wochentage gilt die Regel täglich.").font(.caption).foregroundStyle(.secondary)
                Stepper("Vorlauf: \(before) Minuten", value: $before, in: 0...120)
                Stepper("Nachlauf: \(after) Minuten", value: $after, in: 0...120)
                Toggle("Doppelte Aufnahmen vermeiden", isOn: $avoidDuplicates)
                Text("Vergleicht Titel und Beschreibung auf demselben Sender. Eine sichere Erkennung neuer Folgen ist damit nicht garantiert.").font(.caption).foregroundStyle(.secondary)
            }.formStyle(.grouped)
            if let preview {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Passende geladene Sendungen: \(preview.count)").font(.headline)
                    Text("Lokale Vorschau in der Zeitzone dieses Macs. Weitere Plugin-Filter und Duplikate können das Receiver-Ergebnis ändern.").font(.caption).foregroundStyle(.secondary)
                    if preview.isEmpty { Text("Keine passenden Sendungen in den geladenen EPG-Daten.").font(.caption) }
                    else {
                        List(preview.prefix(100)) { event in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title).font(.callout)
                                Text("\(channels.first(where: { $0.id == event.channelID })?.name ?? event.channelID) · \(event.start.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale)))").font(.caption).foregroundStyle(.secondary)
                            }
                        }.frame(height: 140)
                    }
                }
            }
            if let error { ErrorNotice(message: AppLanguage(locale: locale).localized(error)) }
            HStack {
                Button("Vorschau", systemImage: "list.bullet.rectangle") { Task { await showPreview() } }.disabled(isPreviewing || isSaving || candidate == nil)
                if isPreviewing { ProgressView().controlSize(.small) }
                Spacer()
                Button("Abbrechen") { dismiss() }.disabled(isSaving).keyboardShortcut(.cancelAction)
                Button("Speichern") { Task { await save() } }
                    .buttonStyle(.glassProminent).disabled(isSaving || title.trimmingCharacters(in: .whitespaces).isEmpty || match.trimmingCharacters(in: .whitespaces).isEmpty || target.isEmpty)
            }
        }.padding(24).frame(width: 680, height: preview == nil ? 650 : 820).interactiveDismissDisabled(isSaving)
        .onChange(of: candidate) { _, _ in preview = nil }
        .onAppear {
            title = rule?.title ?? ""; match = rule?.match ?? ""; enabled = rule?.enabled ?? true
            target = targets.first(where: { $0.target == rule?.target })?.key ?? targets.first?.key ?? ""
            useTimespan = rule?.beginTime != nil; begin = date(rule?.beginTime); end = date(rule?.endTime)
            weekdays = rule?.weekdays ?? []; before = rule?.marginBefore ?? 5; after = rule?.marginAfter ?? 5
            avoidDuplicates = !(rule?.allowDuplicate ?? false)
        }
    }
    private func dayTitle(_ day: Int) -> String {
        let formatter = DateFormatter(); formatter.locale = locale
        return formatter.shortWeekdaySymbols[day % 7]
    }
    private func date(_ clock: String?) -> Date {
        let parts = clock?.split(separator: ":").compactMap { Int($0) } ?? [20, 0]
        return Calendar.current.date(bySettingHour: parts.first ?? 20, minute: parts.count > 1 ? parts[1] : 0, second: 0, of: Date()) ?? Date()
    }
    private func clock(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
    private var candidate: ReceiverAutoTimerDraft? {
        guard let chosen = targets.first(where: { $0.key == target }) else { return nil }
        return ReceiverAutoTimerDraft(title: title, match: match, enabled: enabled, target: chosen.target,
            beginTime: useTimespan ? clock(begin) : nil, endTime: useTimespan ? clock(end) : nil,
            weekdays: weekdays, marginBefore: before, marginAfter: after, allowDuplicate: !avoidDuplicates)
    }
    private func showPreview() async {
        guard let draft = candidate else { return }
        isPreviewing = true; error = nil
        defer { isPreviewing = false }
        do {
            let allowed: Set<String>
            switch draft.target {
            case .service(let reference): allowed = [reference]
            case .bouquet(let reference):
                guard let client else { return }
                allowed = Set(try await client.channels(in: Bouquet(id: reference, name: "")).map(\.id))
            }
            guard candidate == draft, !Task.isCancelled else { return }
            preview = ProgrammeMatching.preview(draft, programmes: loadedProgrammes.filter { $0.end > Date() }, allowedChannels: allowed)
        } catch { self.error = error.localizedDescription }
    }

    private func save() async {
        guard let client, let chosen = targets.first(where: { $0.key == target }) else { return }
        isSaving = true; error = nil
        defer { isSaving = false }
        let draft = ReceiverAutoTimerDraft(title: title, match: match, enabled: enabled, target: chosen.target,
            beginTime: useTimespan ? clock(begin) : nil, endTime: useTimespan ? clock(end) : nil,
            weekdays: weekdays, marginBefore: before, marginAfter: after, allowDuplicate: !avoidDuplicates)
        do {
            if let rule { try await client.editAutoTimer(rule, with: draft) } else { try await client.addAutoTimer(draft) }
            onSaved(); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
