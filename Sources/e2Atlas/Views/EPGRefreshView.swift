import SwiftUI
import AtlasCore
import AtlasReceiver

struct EPGRefreshView: View {
    let client: OpenWebifClient?
    let preferredBouquetID: String?
    @Environment(\.dismiss) private var dismiss
    @State private var original: EPGRefreshConfiguration?
    @State private var draft: EPGRefreshConfiguration?
    @State private var bouquets: [Bouquet] = []
    @State private var selection = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?
    @State private var saved = false

    private var chosenBouquets: [Bouquet] {
        selection == "all" ? bouquets : bouquets.filter { $0.id == selection }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("EPG automatisch aktualisieren").font(.title2.weight(.semibold))
                Spacer()
                Button("Fertig") { dismiss() }.disabled(isSaving)
                    .help("EPGRefresh-Einstellungen schließen")
            }
            Text(client?.profile.name ?? "").foregroundStyle(.secondary)
            if isLoading {
                ProgressView("EPGRefresh-Einstellungen werden geladen …")
                    .frame(maxWidth: .infinity, minHeight: 240)
            } else if let configuration = draft {
                Form {
                    Toggle("Automatische EPG-Aktualisierung", isOn: binding(\.enabled, fallback: configuration.enabled))
                    Section("Tägliches Zeitfenster") {
                        DatePicker("Von", selection: binding(\.begin, fallback: configuration.begin), displayedComponents: .hourAndMinute)
                        DatePicker("Bis", selection: binding(\.end, fallback: configuration.end), displayedComponents: .hourAndMinute)
                        Text("Uhrzeiten gelten für den Receiver.").font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Senderauswahl") {
                        Picker("Bouquets", selection: $selection) {
                            Text("Bitte auswählen").tag("")
                            Text("Alle vorhandenen Bouquets").tag("all")
                            ForEach(bouquets) { bouquet in Text(bouquet.name).tag(bouquet.id) }
                        }
                        TextField("Verweildauer in Sekunden", value: binding(\.durationSeconds, fallback: configuration.durationSeconds), format: .number.grouping(.never))
                        Text("1 bis 86400 Sekunden. Für eine neue Auswahl sind 50 Sekunden voreingestellt.")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("Die Auswahl ersetzt die bisherige Senderliste von EPGRefresh. Sender desselben Transponders kann der Receiver zusammenfassen.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .formStyle(.grouped)
                .environment(\.timeZone, configuration.receiverTimeZone)
                .disabled(isSaving)
                Text("Der Zeitplan wird auf dem Receiver gespeichert. Die App muss dafür nicht geöffnet bleiben. EPGRefresh muss am Receiver installiert und über OpenWebif erreichbar sein.")
                    .font(.callout).foregroundStyle(.secondary)
                Text("Geplante Läufe berücksichtigen Standby und laufende Aufnahmen. Eine Aktualisierung wird nicht erzwungen.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let error { ErrorNotice(message: error) }
            if saved { Label("EPG-Zeitplan wurde auf dem Receiver gespeichert.", systemImage: "checkmark.circle").foregroundStyle(.green) }
            HStack {
                Button("Neu laden") { Task { await load() } }.disabled(isLoading || isSaving || client == nil)
                    .help("EPGRefresh-Einstellungen vom Receiver neu laden")
                Spacer()
                if isSaving { ProgressView().controlSize(.small) }
                Button("Auf Receiver speichern") { Task { await save() } }
                    .buttonStyle(.glassProminent)
                    .disabled(isLoading || isSaving || draft == nil || chosenBouquets.isEmpty)
                    .help("EPGRefresh-Zeitplan und Senderauswahl auf dem Receiver speichern")
            }
        }
        .padding(24).frame(width: 640, height: 620)
        .interactiveDismissDisabled(isSaving)
        .task(id: client?.profile) { await load() }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<EPGRefreshConfiguration, Value>, fallback: Value) -> Binding<Value> {
        Binding(get: { draft?[keyPath: keyPath] ?? fallback }, set: { draft?[keyPath: keyPath] = $0; saved = false })
    }

    private func load() async {
        isLoading = true; error = nil; saved = false; draft = nil; original = nil
        defer { isLoading = false }
        guard let client else { error = "Kein Receiver ausgewählt."; return }
        do {
            let configuration = try await client.epgRefreshConfiguration()
            let list = try await client.bouquets()
            guard !Task.isCancelled else { return }
            bouquets = list; original = configuration; draft = configuration
            if configuration.references.isEmpty {
                draft?.durationSeconds = 50
                selection = list.first(where: { $0.id == preferredBouquetID })?.id ?? "all"
            } else if Set(configuration.references) == Set(list.map(\.id)) {
                selection = "all"
            } else {
                selection = configuration.references.count == 1 && list.contains(where: { $0.id == configuration.references.first })
                    ? configuration.references[0] : ""
            }
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }

    private func save() async {
        guard let client, let draft, let original else { return }
        isSaving = true; error = nil; saved = false
        defer { isSaving = false }
        do {
            let configuration = try await client.saveEPGRefresh(draft, bouquets: chosenBouquets, replacing: original)
            self.original = configuration; self.draft = configuration; saved = true
        } catch { self.error = error.localizedDescription }
    }
}
