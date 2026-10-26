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
    @Environment(\.locale) private var locale
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
                    Text(settings.selectedReceiver?.name ?? settings.language.localized("Kein Receiver ausgewählt"))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Aktualisieren", systemImage: "arrow.clockwise") { refresh += 1 }
                    .disabled(loading || settings.selectedReceiver == nil)
                    .help("Hardware- und Tunerdaten des Receivers neu laden")
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
                    if let error { Text("Receiver-Daten konnten nicht geladen werden: \(settings.language.localized(error))") }
                    else { Text("Der Receiver hat keine Hardwaredaten geliefert.") }
                } actions: {
                    Button("Erneut versuchen") { refresh += 1 }
                        .help("Receiver-Daten erneut abrufen")
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
                            if info.allTunerStatusesAvailable {
                                Text("\(info.tuners.count) gemeldet · \(info.activeTunerCount) Nutzung bestätigt")
                                    .font(.callout).foregroundStyle(.secondary)
                            } else {
                                Text("\(info.tuners.count) gemeldet · mindestens \(info.activeTunerCount) genutzt")
                                    .font(.callout).foregroundStyle(.secondary)
                            }
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
                                if tuner.isActive {
                                    Label("In Nutzung", systemImage: "antenna.radiowaves.left.and.right")
                                        .font(.caption).foregroundStyle(Color.accentColor)
                                } else if tuner.statusAvailable {
                                    Label("Keine Nutzung gemeldet", systemImage: "circle")
                                        .font(.caption).foregroundStyle(.secondary)
                                } else {
                                    Label("Status nicht verfügbar", systemImage: "circle")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            if let type = tuner.type { Text(type).font(.callout).foregroundStyle(.secondary) }
                            if tuner.isActive {
                                HStack(spacing: 4) {
                                    if tuner.live { Text("Live-TV") }
                                    if tuner.recording {
                                        if tuner.live { Text("·").accessibilityHidden(true) }
                                        Text("Aufnahme")
                                    }
                                    if tuner.streaming {
                                        if tuner.live || tuner.recording { Text("·").accessibilityHidden(true) }
                                        Text("Streaming")
                                    }
                                }.font(.caption)
                            }
                            if tuner.isActive && !tuner.statusAvailable {
                                Text("Weitere Statusangaben sind nicht verfügbar.").font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(12).background(.quaternary, in: .rect(cornerRadius: 10))
                    }
                    Text("OpenWebif meldet Empfangseinheiten. Bei FBC-Tunern können mehrere Einträge zu einem physischen Modul gehören. Mehrere Sender auf demselben Transponder können eine Empfangseinheit gemeinsam nutzen. Fehlende Angaben bedeuten nicht, dass ein Tuner deaktiviert ist.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let error {
                    Label("Aktualisierung fehlgeschlagen: \(settings.language.localized(error))", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                if let updatedAt {
                    Text("Zuletzt aktualisiert: \(updatedAt.formatted(Date.FormatStyle(date: .omitted, time: .standard, locale: locale))) · automatisch alle 5 Sekunden")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.padding(24).textSelection(.enabled)
        }
    }

    private func row(_ label: LocalizedStringKey, _ value: String?) -> some View {
        GridRow(alignment: .top) {
            Text(label).foregroundStyle(.secondary)
            if let value { Text(value).frame(maxWidth: .infinity, alignment: .leading) }
            else { Text("Nicht verfügbar").frame(maxWidth: .infinity, alignment: .leading) }
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
