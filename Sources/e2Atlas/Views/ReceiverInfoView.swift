import SwiftUI
import AtlasCore
import AtlasReceiver
import AtlasThemes

private struct HardwareRequest: Equatable {
    let profile: ReceiverProfile?
    let connectionRevision: Int
    let refresh: Int
}

struct ReceiverInfoView: View {
    let settings: SettingsStore
    @Environment(\.atlasTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    @State private var hardware: ReceiverHardware?
    @State private var loading = false
    @State private var error: String?
    @State private var refresh = 0
    @State private var updatedAt: Date?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Receiver-Info").font(.title2.weight(.semibold))
                    Text(settings.selectedReceiver?.name ?? "Kein Receiver ausgewählt")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Aktualisieren", systemImage: "arrow.clockwise") { refresh += 1 }
                    .disabled(loading || settings.selectedReceiver == nil)
            }.padding(24)
            Divider()
            if settings.selectedReceiver == nil {
                ContentUnavailableView("Kein Receiver eingerichtet", systemImage: "tv",
                                       description: Text("Füge in den Einstellungen einen Receiver hinzu."))
            } else if loading && hardware == nil {
                ProgressView("Receiver-Daten werden geladen …").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let hardware {
                details(hardware)
            } else {
                ContentUnavailableView {
                    Label("Receiver-Daten nicht verfügbar", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error ?? "Der Receiver hat keine Hardwaredaten geliefert.")
                } actions: {
                    Button("Erneut versuchen") { refresh += 1 }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 560)
        .background { AtlasThemeBackground() }
        .foregroundStyle(theme.id == "system" ? Color.primary : Color(atlasHex: theme.palette(for: scheme).text))
        .tint(theme.id == "system" ? .accentColor : Color(atlasHex: theme.palette(for: scheme).accent))
        .task(id: HardwareRequest(profile: settings.selectedReceiver,
                                  connectionRevision: settings.connectionRevision, refresh: refresh)) {
            hardware = nil; error = nil; updatedAt = nil
            repeat {
                await load()
                do { try await Task.sleep(for: .seconds(5)) }
                catch { return }
            } while !Task.isCancelled
        }
    }

    private func details(_ info: ReceiverHardware) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                GroupBox("Hardware und System") {
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                        row("Hersteller", info.brand)
                        row("Modell", info.model)
                        row("Chipsatz", info.chipset)
                        row("Image", info.image)
                        row("Image-Version", info.imageVersion)
                        row("Enigma2", info.enigmaVersion)
                        row("Kernel", info.kernelVersion)
                        row("OpenWebif", info.webifVersion)
                        row("Arbeitsspeicher", info.memory)
                        row("Laufzeit", info.uptime)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Tuner").font(.headline)
                        Spacer()
                        if info.tunerListAvailable {
                            Text(info.allTunerStatusesAvailable
                                 ? "\(info.tuners.count) gemeldet · \(info.activeTunerCount) Nutzung bestätigt"
                                 : "\(info.tuners.count) gemeldet · mindestens \(info.activeTunerCount) genutzt")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    if info.unassignedStreamCount > 0 {
                        Label("Stream-Zuordnung fehlt", systemImage: "exclamationmark.triangle")
                            .font(.callout.weight(.medium))
                        Text("\(info.unassignedStreamCount) gemeldete Streams sind keinem Tuner zugeordnet. OpenWebif liefert dafür keine verwendbare Tuner-ID. Die gesamte Belegung ist deshalb nicht bestimmbar.")
                            .font(.callout).foregroundStyle(.secondary)
                    } else if !info.allTunerStatusesAvailable {
                        Text("OpenWebif liefert keinen vollständigen Tunerstatus.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    if let count = info.streamCount {
                        Text("Gemeldete Streams: \(count)").font(.callout).foregroundStyle(.secondary)
                    }
                    if !info.tunerListAvailable {
                        Text("Der Receiver hat keine Tunerliste geliefert.").foregroundStyle(.secondary)
                    } else if info.tuners.isEmpty {
                        Text("Keine Tuner gemeldet.").foregroundStyle(.secondary)
                    }
                    ForEach(info.tuners) { tuner in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(tuner.name).font(.headline)
                                Spacer()
                                Label(tuner.isActive ? "In Nutzung" : tuner.statusAvailable ? "Keine Nutzung gemeldet" : "Status nicht verfügbar",
                                      systemImage: tuner.isActive ? "antenna.radiowaves.left.and.right" : "circle")
                                    .font(.caption).foregroundStyle(tuner.isActive ? Color.accentColor : .secondary)
                            }
                            if let type = tuner.type { Text(type).font(.callout).foregroundStyle(.secondary) }
                            if tuner.isActive {
                                Text([tuner.live ? "Live-TV" : nil, tuner.recording ? "Aufnahme" : nil,
                                      tuner.streaming ? "Streaming" : nil].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption)
                            }
                            if tuner.isActive && !tuner.statusAvailable {
                                Text("Weitere Statusangaben sind nicht verfügbar.").font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(12).background(.quaternary, in: .rect(cornerRadius: 10))
                    }
                    Text("OpenWebif meldet Empfangseinheiten. Bei FBC-Tunern können mehrere Einträge zu einem physischen Modul gehören. Mehrere Sender auf demselben Transponder können eine Empfangseinheit gemeinsam nutzen. Fehlende Angaben bedeuten nicht, dass ein Tuner deaktiviert ist.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let error { ErrorNotice(message: "Aktualisierung fehlgeschlagen: \(error)") }
                if let updatedAt {
                    Text("Zuletzt aktualisiert: \(updatedAt.formatted(date: .omitted, time: .standard)) · automatisch alle 5 Sekunden")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.padding(24).textSelection(.enabled)
        }
    }

    private func row(_ label: String, _ value: String?) -> some View {
        GridRow(alignment: .top) {
            Text(label).foregroundStyle(.secondary)
            Text(value ?? "Nicht verfügbar").frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func load() async {
        error = nil
        guard let profile = settings.selectedReceiver else { loading = false; return }
        loading = true
        do {
            let password = try settings.credentials.availablePassword(for: profile.id)
            let client = OpenWebifClient(profile: profile, password: password)
            let result = try await client.hardwareInfo()
            try Task.checkCancellation()
            hardware = result; updatedAt = Date(); loading = false
        } catch is CancellationError { }
        catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription; loading = false
        }
    }
}
