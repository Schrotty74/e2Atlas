import AppKit
import SwiftUI
import AtlasCore
import AtlasReceiver
import AtlasPlayback
import AtlasThemes

enum MainSection: String, CaseIterable { case television = "Fernsehen", multiview = "Multiview", guide = "Programm" }

private struct ReceiverSelection: Equatable {
    let profile: ReceiverProfile?
    let revision: Int
}

struct MainWindow: View {
    @Bindable var settings: SettingsStore
    let themes: ThemeCatalog
    let demo: Bool
    @State private var section: MainSection = .television
    @State private var channels = ChannelStore()
    @State private var guide = GuideStore()
    @State private var nowGuide = GuideStore()
    @State private var playback = PlaybackStore()
    @State private var videoOnly = VideoOnlyController()
    @State private var search = ""
    @State private var localError: String?
    @Environment(\.atlasTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    private var filteredChannels: [Channel] { channels.channels.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) } }

    var body: some View {
        Group {
            if let index = videoOnly.slotIndex {
                Group {
                    if demo { DemoPicture() }
                    else { PlaybackSurface(slot: playback.slots[index]) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
                .ignoresSafeArea()
                .onTapGesture(count: 2) { videoOnly.exit() }
                .contextMenu { Button("Zurück zur App", systemImage: "arrow.down.right.and.arrow.up.left") { videoOnly.exit() } }
            } else {
                appContent
            }
        }
        .background(VideoWindowReader(controller: videoOnly))
        .background(videoOnly.isActive ? Color.black : Color(atlasHex: theme.palette(for: scheme).background))
        .tint(theme.id == "system" ? .accentColor : Color(atlasHex: theme.palette(for: scheme).accent))
        .frame(minWidth: videoOnly.isActive ? 100 : 960, minHeight: videoOnly.isActive ? 100 : 680)
        .toolbar { appToolbar }
        .toolbarVisibility(videoOnly.isActive ? .hidden : .visible, for: .windowToolbar)
        .onExitCommand { videoOnly.exit() }
        .task(id: ReceiverSelection(profile: settings.selectedReceiver, revision: settings.connectionRevision)) { await connect() }
        .task(id: guideQueryID) {
            if !demo { await guide.load(channels: filteredChannels, client: channels.client) }
        }
        .task(id: channels.channels.map(\.id)) {
            if !demo {
                nowGuide.reset(); nowGuide.window = GuideWindow(start: Date(), duration: .six)
                await nowGuide.load(channels: channels.channels, client: channels.client)
            }
        }
        .onChange(of: section) { _, value in
            if value != .guide { playback.setMultiview(value == .multiview) }
        }
        .onChange(of: settings.preferences) { settings.persist() }
        .onDisappear { videoOnly.exit(); playback.stopAll() }
    }

    private var appContent: some View {
        VStack(spacing: 0) {
            if let error = localError ?? channels.error { ErrorNotice(message: error).padding([.horizontal, .top], 16) }
            if section == .guide {
                GuideView(store: guide, channels: filteredChannels, picons: channels.picons, settings: settings, playback: playback, demo: demo, onPlay: { channel in play(channel, index: 0) }, onPicon: { channel in await channels.loadPicon(channel) })
            } else {
                television
            }
            Divider()
            HStack {
                Label(demo ? "Demo · keine Receiver-Verbindung" : settings.selectedReceiver?.name ?? "Kein Receiver", systemImage: "tv")
                if channels.isLoading { ProgressView().controlSize(.mini); Text("Sender werden geladen …") }
                Spacer()
                if let info = channels.receiverInfo { Text("\(info.name) · \(info.image)") }
                if demo { Text("Synthetische Beispieldaten") }
            }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.vertical, 10)
        }
    }

    @ToolbarContentBuilder private var appToolbar: some ToolbarContent {
            ToolbarItem(placement: .principal) {
                Picker("Ansicht", selection: $section) { ForEach(MainSection.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented).frame(width: 340)
            }
            ToolbarItem(placement: .automatic) {
                if !demo {
                    Picker("Receiver", selection: $settings.preferences.selectedReceiverID) {
                        ForEach(settings.preferences.receivers) { Text($0.name).tag(Optional($0.id)) }
                    }.frame(maxWidth: 180)
                }
            }
            ToolbarItem(placement: .automatic) { SettingsLink { Label("Einstellungen", systemImage: "slider.horizontal.3") } }
            ToolbarItem(placement: .automatic) {
                Button("Nur Video", systemImage: "play.rectangle.fill") { enterVideoOnly(playback.targetIndex) }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                    .help("Nur das ausgewählte Video zeigen · Escape zum Zurückkehren")
                    .disabled(!demo && playback.slots[playback.targetIndex].channel == nil)
            }
    }

    private func enterVideoOnly(_ index: Int) {
        guard playback.slots.indices.contains(index), demo || playback.slots[index].channel != nil else { return }
        playback.selectAudio(index)
        videoOnly.enter(slot: index)
    }

    private var guideQueryID: String {
        "\(settings.preferences.selectedReceiverID?.uuidString ?? "")|\(channels.selectedBouquetID ?? "")|\(channels.channels.map(\.id).joined(separator: ";"))|\(guide.window.start.timeIntervalSince1970)|\(guide.window.duration.rawValue)|\(search)"
    }

    private var volumeBinding: Binding<Double> {
        Binding(get: { playback.volume }, set: { playback.setVolume($0) })
    }

    private var television: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker("Bouquet", selection: $channels.selectedBouquetID) {
                    ForEach(channels.bouquets) { Text($0.name).tag(Optional($0.id)) }
                }.frame(maxWidth: 280)
                Spacer()
                if section == .multiview {
                    Picker("Bilder", selection: Binding(get: { playback.visibleCount }, set: { playback.setCount($0) })) {
                        Text("2 Bilder").tag(2); Text("3 Bilder").tag(3); Text("4 Bilder").tag(4)
                    }.frame(width: 130)
                }
                TextField("Sender suchen", text: $search).textFieldStyle(.roundedBorder).frame(width: 190)
                Button("Neu laden", systemImage: "arrow.clockwise") { Task { await connect() } }.labelStyle(.iconOnly)
            }.padding(.horizontal, 20).padding(.vertical, 12)
            GeometryReader { geometry in
                HStack(spacing: 12) {
                    VideoTile(slot: playback.slots[0], selected: playback.targetIndex == 0, audible: !playback.slots[0].isMuted, audioSelected: playback.audibleIndex == 0, volume: volumeBinding, demo: demo, large: true, select: { playback.targetIndex = 0 }, audio: { playback.toggleAudio(0) }, videoOnly: { enterVideoOnly(0) })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if section == .multiview {
                        VStack(spacing: 12) {
                            ForEach(1..<playback.visibleCount, id: \.self) { index in
                                VideoTile(slot: playback.slots[index], selected: playback.targetIndex == index, audible: !playback.slots[index].isMuted, audioSelected: playback.audibleIndex == index, volume: volumeBinding, demo: demo, large: false, select: { playback.targetIndex = index }, audio: { playback.toggleAudio(index) }, videoOnly: { enterVideoOnly(index) })
                            }
                        }.frame(width: max(220, geometry.size.width * 0.26))
                    }
                }
            }
            .frame(minHeight: 310).padding(12).background(.black)
            if let channel = playback.slots[0].channel {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text(channel.name).font(.headline)
                    Text(nowTitle(channel)).font(.callout).lineLimit(1)
                    Spacer()
                    if let next = nowGuide.events[channel.id]?.first(where: { $0.start > Date() }) {
                        Text("Danach: \(next.start.formatted(date: .omitted, time: .shortened)) · \(next.title)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }.padding(.horizontal, 24).padding(.vertical, 12)
            }
            senderShelf
        }
        .task(id: channels.selectedBouquetID) {
            guard !demo, let bouquet = channels.bouquets.first(where: { $0.id == channels.selectedBouquetID }) else { return }
            await channels.loadChannels(in: bouquet)
        }
    }

    private var senderShelf: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("Deine Sender").font(.headline)
                Spacer()
                if section == .multiview { Text("Sender für Bild \(playback.targetIndex + 1) wählen").font(.callout).foregroundStyle(.secondary) }
            }
            if filteredChannels.isEmpty {
                ContentUnavailableView(channels.isLoading ? "Sender werden geladen" : "Keine Sender", systemImage: "tv", description: Text("Wähle ein Bouquet oder prüfe die Verbindung zum Receiver."))
                    .frame(height: 115)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(filteredChannels) { channel in
                            Button { play(channel) } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10).fill(Color(atlasHex: theme.palette(for: scheme).surface))
                                        PiconView(data: channels.picons[channel.id], name: channel.name, size: 64)
                                    }.frame(width: 158, height: 66)
                                    Text(channel.name).font(.callout.weight(.semibold)).lineLimit(1)
                                    Text(nowTitle(channel)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }.frame(width: 158, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .task(id: "\(settings.connectionRevision)|\(settings.preferences.selectedReceiverID?.uuidString ?? "")|\(channel.id)") { if !demo { await channels.loadPicon(channel) } }
                        }
                    }.padding(.vertical, 3)
                }.frame(height: 125).scrollIndicators(.hidden)
            }
            if let message = playback.error { ErrorNotice(message: message) }
        }.padding(.horizontal, 24).padding(.vertical, 18)
    }

    private func nowTitle(_ channel: Channel) -> String {
        let now = Date()
        return (demo ? guide.events[channel.id] : nowGuide.events[channel.id])?.first(where: { $0.start <= now && $0.end > now })?.title ?? "Programminformationen"
    }
    private func play(_ channel: Channel, index: Int? = nil) {
        guard !demo, let profile = settings.selectedReceiver, let client = channels.client else { return }
        Task {
            do {
                let password = try settings.credentials.password(for: profile.id)
                await playback.play(channel, client: client, profile: profile, password: password, index: index)
            } catch { localError = error.localizedDescription }
        }
    }
    private func connect() async {
        playback.stopAll(); guide.reset(); nowGuide.reset(); guide.window.duration = settings.preferences.guideDuration; localError = nil
        if demo {
            channels.loadDemo()
            guide.loadDemo(channels: channels.channels)
            return
        }
        guard let profile = settings.selectedReceiver else { return }
        do { await channels.connect(profile, password: try settings.credentials.password(for: profile.id)) }
        catch { localError = error.localizedDescription }
    }
}

struct VideoTile: View {
    let slot: PlaybackSlot
    let selected: Bool
    let audible: Bool
    let audioSelected: Bool
    let volume: Binding<Double>
    let demo: Bool
    let large: Bool
    let select: () -> Void
    let audio: () -> Void
    let videoOnly: () -> Void
    private var audioLabel: String {
        audible ? "Ton aktiv" : audioSelected ? "Stumm" : "Ton wählen"
    }
    private var volumeControl: some View {
        Slider(value: volume, in: 0...1)
            .frame(width: large ? 110 : 80)
            .accessibilityLabel("Lautstärke")
            .accessibilityValue("\(Int((volume.wrappedValue * 100).rounded())) Prozent")
            .help("Lautstärke der aktiven Tonquelle")
    }
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                if demo { DemoPicture(compact: !large) }
                else { PlaybackSurface(slot: slot) }
                if !demo && slot.channel == nil {
                    VStack(spacing: 10) {
                        Image(systemName: "tv").font(large ? .largeTitle : .title2)
                        Text("Sender wählen").font(large ? .headline : .callout)
                    }.foregroundStyle(.white.opacity(0.7)).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if large {
                    HStack(spacing: 14) {
                        Button(action: audio) { Label(audioLabel, systemImage: audible ? "speaker.wave.2" : "speaker.slash") }
                        volumeControl
                        if slot.channel != nil || demo { Text(demo ? "Demo" : "Live").font(.caption) }
                        Spacer()
                        Button("Stoppen", systemImage: "stop.fill") { slot.stop() }.labelStyle(.iconOnly).disabled(demo)
                        Button("Nur Video", systemImage: "play.rectangle.fill", action: videoOnly).labelStyle(.iconOnly)
                            .help("Nur dieses Video zeigen · Escape zum Zurückkehren").disabled(!demo && slot.channel == nil)
                        Button("Vollbild", systemImage: "arrow.up.left.and.arrow.down.right") { NSApplication.shared.keyWindow?.toggleFullScreen(nil) }.labelStyle(.iconOnly)
                    }
                    .buttonStyle(.plain).font(.callout).padding(12).modifier(GlassPanel()).padding(18)
                }
            }
            .contentShape(Rectangle()).onTapGesture(perform: select)
            HStack {
                Button(action: select) { Text(slot.channel?.name ?? (demo ? "Beispielsender" : "Freies Bild")).font(.caption.weight(.semibold)).lineLimit(1) }.buttonStyle(.plain)
                Spacer()
                if !large {
                    volumeControl
                    Button("Nur Video", systemImage: "play.rectangle.fill", action: videoOnly).labelStyle(.iconOnly)
                        .help("Nur dieses Video zeigen · Escape zum Zurückkehren").disabled(!demo && slot.channel == nil)
                    Button(action: audio) { Image(systemName: audible ? "speaker.wave.2.fill" : "speaker.slash") }.buttonStyle(.plain).accessibilityLabel(audioLabel)
                }
            }.foregroundStyle(.white).padding(10).background(Color(white: 0.13))
        }
        .clipShape(.rect(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(audible ? Color.accentColor : selected ? .white.opacity(0.5) : .clear, lineWidth: 2) }
    }
}
