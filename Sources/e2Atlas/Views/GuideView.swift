import SwiftUI
import AtlasCore
import AtlasThemes
import AtlasPlayback

struct GuideView: View {
    @Bindable var store: GuideStore
    let channels: [Channel]
    let picons: [String: Data]
    @Bindable var settings: SettingsStore
    let playback: PlaybackStore
    let demo: Bool
    let onPlay: (Channel) -> Void
    let onPicon: (Channel) async -> Void
    @State private var addTime = false
    @State private var customTime = Date()
    @Environment(\.atlasTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    private var visibleChannels: [Channel] { channels }

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Programmübersicht").font(.caption).foregroundStyle(theme.id == "system" ? Color.secondary : Color(atlasHex: theme.palette(for: scheme).secondary))
                        DatePicker("Tag", selection: $store.window.start, displayedComponents: .date).labelsHidden().font(.title2)
                    }
                    Spacer()
                    Text("\(store.window.start.formatted(date: .omitted, time: .shortened)) – \(store.window.end.formatted(date: .omitted, time: .shortened))").font(.callout).monospacedDigit()
                    if store.isLoading { ProgressView().controlSize(.small) }
                }
                HStack {
                    Picker("Zeitspanne", selection: $store.window.duration) {
                        ForEach(GuideDuration.allCases, id: \.self) { Text("\($0.rawValue) Stunden").tag($0) }
                    }.frame(width: 200)
                    Spacer()
                    Button("Zurück", systemImage: "chevron.left") { store.window.start.addTimeInterval(-store.window.duration.seconds) }.labelStyle(.iconOnly)
                    Button("Weiter", systemImage: "chevron.right") { store.window.start.addTimeInterval(store.window.duration.seconds) }.labelStyle(.iconOnly)
                }
                HStack(spacing: 8) {
                    Text("Springen zu").font(.caption).foregroundStyle(theme.id == "system" ? Color.secondary : Color(atlasHex: theme.palette(for: scheme).secondary))
                    Button("Jetzt") { store.window.start = Date() }
                    ForEach(settings.preferences.shortcuts) { shortcut in
                        Button(shortcut.id) { if let date = shortcut.date(on: store.window.start) { store.window.start = date } }
                            .contextMenu {
                                Button("Schnellzugriff entfernen", role: .destructive) { settings.preferences.shortcuts.removeAll { $0.id == shortcut.id }; settings.persist() }
                            }
                    }
                    Button("Uhrzeit hinzufügen", systemImage: "plus") { addTime = true }.labelStyle(.iconOnly)
                }.buttonStyle(.glass)
                GeometryReader { geometry in
                    ScrollView {
                        LazyVStack(spacing: 7, pinnedViews: .sectionHeaders) {
                            Section {
                                ForEach(visibleChannels) { channel in
                                    HStack(spacing: 8) {
                                        VStack(spacing: 5) {
                                            PiconView(data: picons[channel.id], name: channel.name, size: 32)
                                            Text(channel.name).font(.caption).lineLimit(1)
                                        }.frame(width: 70)
                                        timeline(channel, width: max(100, geometry.size.width - 80))
                                    }.task(id: "\(settings.connectionRevision)|\(settings.preferences.selectedReceiverID?.uuidString ?? "")|\(channel.id)") { if !demo { await onPicon(channel) } }
                                }
                            } header: { timeHeader(width: max(100, geometry.size.width - 80)) }
                        }
                    }
                }
            }
            .padding(22).frame(minWidth: 530, maxWidth: .infinity)
            inspector.frame(minWidth: 240, idealWidth: 270, maxWidth: 330)
        }
        .popover(isPresented: $addTime) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Eigener Zeitsprung").font(.headline)
                DatePicker("Uhrzeit", selection: $customTime, displayedComponents: .hourAndMinute)
                Button("Hinzufügen") {
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: customTime)
                    if let hour = parts.hour, let minute = parts.minute, let value = try? TimeShortcut(hour: hour, minute: minute) {
                        settings.preferences.addShortcut(value); settings.persist()
                    }
                    addTime = false
                }.buttonStyle(.glassProminent)
            }.padding(22).frame(width: 270)
        }
        .onChange(of: store.window.duration) { _, value in settings.preferences.guideDuration = value; settings.persist() }
    }

    private func timeHeader(width: CGFloat) -> some View {
        HStack(spacing: 8) {
            Text("Sender").font(.caption).foregroundStyle(theme.id == "system" ? Color.secondary : Color(atlasHex: theme.palette(for: scheme).secondary)).frame(width: 70)
            HStack {
                ForEach(0..<4) { index in
                    Text(store.window.start.addingTimeInterval(store.window.duration.seconds * Double(index) / 4).formatted(date: .omitted, time: .shortened))
                        .font(.caption).monospacedDigit().frame(maxWidth: .infinity, alignment: .leading)
                }
            }.frame(width: width)
        }.padding(.vertical, 8).background(Color(atlasHex: theme.palette(for: scheme).background))
    }

    private func timeline(_ channel: Channel, width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 7).fill(.quaternary.opacity(0.5))
            let values = store.events[channel.id] ?? []
            if values.isEmpty {
                Text(store.errors[channel.id] ?? "Keine Programmdaten").font(.caption).foregroundStyle(theme.id == "system" ? Color.secondary : Color(atlasHex: theme.palette(for: scheme).secondary)).padding(10)
            }
            ForEach(values) { event in
                if let part = store.window.visibleFraction(of: event) {
                    Button { store.selection = event } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(event.title).font(.callout.weight(.medium)).lineLimit(1)
                            Text("\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))")
                                .font(.caption).foregroundStyle(theme.id == "system" ? Color.secondary : Color(atlasHex: theme.palette(for: scheme).secondary)).lineLimit(1)
                        }
                        .padding(10).frame(width: max(1, width * part.width - 4), height: 73, alignment: .leading).clipped()
                        .background(Color(atlasHex: store.selection?.id == event.id ? theme.palette(for: scheme).selection : theme.palette(for: scheme).surface), in: .rect(cornerRadius: 6))
                    }
                    .buttonStyle(.plain).offset(x: width * part.offset)
                    .help("\(event.title) · \(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))")
                    .accessibilityLabel("\(channel.name): \(event.title)")
                }
            }
        }.frame(width: width, height: 75).clipped()
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if demo { DemoPicture(compact: true).aspectRatio(16 / 9, contentMode: .fit).clipShape(.rect(cornerRadius: 10)) }
                else { AtlasPlayback.PlaybackSurface(slot: playback.slots[0]).aspectRatio(16 / 9, contentMode: .fit).clipShape(.rect(cornerRadius: 10)) }
                if let event = store.selection {
                    Text(channels.first { $0.id == event.channelID }?.name ?? "").font(.caption).foregroundStyle(theme.id == "system" ? Color.secondary : Color(atlasHex: theme.palette(for: scheme).secondary))
                    Text(event.title).font(.title2.weight(.semibold))
                    Text("\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))").font(.callout).monospacedDigit()
                    Text(event.summary.isEmpty ? "Keine weitere Beschreibung vorhanden." : event.summary).font(.callout).foregroundStyle(theme.id == "system" ? Color.secondary : Color(atlasHex: theme.palette(for: scheme).secondary))
                    Button("Sender ansehen", systemImage: "play.fill") {
                        if let channel = channels.first(where: { $0.id == event.channelID }) { onPlay(channel) }
                    }.buttonStyle(.glassProminent).disabled(demo)
                } else {
                    Text("Sendung auswählen").font(.title3.weight(.semibold))
                    Text("Wähle eine Sendung für Uhrzeit und Beschreibung.").font(.callout).foregroundStyle(theme.id == "system" ? Color.secondary : Color(atlasHex: theme.palette(for: scheme).secondary))
                }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }.background(Color(atlasHex: theme.palette(for: scheme).surface))
    }
}
