import AppKit
import SwiftUI
import AtlasCore
import AtlasReceiver
import AtlasPlayback
import AtlasThemes

enum MainSection: String, CaseIterable { case television = "Fernsehen", multiview = "Multiview", nowNext = "Jetzt und danach", guide = "Programm", recordings = "Aufnahmen" }

private struct ReceiverSelection: Equatable {
    let profile: ReceiverProfile?
    let revision: Int
}

private struct TimerRequest: Identifiable {
    let id = UUID()
    let programme: Programme?
    let channel: Channel?
}

struct MainWindow: View {
    @Bindable var settings: SettingsStore
    let themes: ThemeCatalog
    let demo: Bool
    @Bindable var reminders: ProgrammeReminderStore
    @State private var section: MainSection = .television
    @State private var channels = ChannelStore()
    @State private var guide = GuideStore()
    @State private var nowGuide = GuideStore()
    @State private var receiverTimers = ReceiverTimerStore()
    @State private var guideStatusDate = Date()
    @State private var library = ReceiverRecordingsStore()
    @State private var playback = PlaybackStore()
    @State private var videoOnly = VideoOnlyController()
    @State private var recording = RecordingStore()
    @State private var search = ""
    @State private var favoritesOnly = false
    @State private var openedReminder: ProgrammeReminder?
    @State private var needsReminderSelection = false
    @State private var pendingNowNextSelection: Programme?
    @State private var pendingNowNextChannel: Channel?
    @State private var showPresets = false
    @State private var showEPGRefresh = false
    @State private var showAutoTimer = false
    @State private var showReminders = false
    @State private var showRecordingOptions = false
    @State private var timerRequest: TimerRequest?
    @State private var sleepDeadline: Date?
    @State private var restoreTask: Task<Void, Never>?
    @State private var bouquetTask: Task<Void, Never>?
    @State private var presetGuideChannels: [Channel] = []
    @State private var hasInitializedReceiver = false
    @State private var epgRefreshSessionStart = Date()
    @State private var localError: String?
    @Environment(\.atlasTheme) private var theme
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var scheme
    @Environment(\.locale) private var locale
    private var favoriteChannels: [Channel] {
        (settings.preferences.favoriteChannels ?? []).filter { $0.receiverID == settings.selectedReceiver?.id }.map(\.channel)
    }
    private var guideChannels: [Channel] {
        var values = channels.channels
        if let target = openedReminder, target.receiverID == settings.selectedReceiver?.id, !values.contains(where: { $0.id == target.programme.channelID }) {
            values.append(Channel(id: target.programme.channelID, name: target.channelName))
        }
        if let channel = pendingNowNextChannel, !values.contains(where: { $0.id == channel.id }) { values.append(channel) }
        return values
    }
    private var loadedProgrammes: [Programme] {
        var seen = Set<String>()
        return (guide.events.values.flatMap { $0 } + nowGuide.events.values.flatMap { $0 }).filter { seen.insert($0.id).inserted }
    }
    private var filteredChannels: [Channel] {
        (favoritesOnly ? favoriteChannels : channels.channels).filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
    }

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
        .background {
            if videoOnly.isActive { Color.black }
            else { AtlasThemeBackground() }
        }
        .foregroundStyle(theme.id == "system" ? Color.primary : Color(atlasHex: theme.palette(for: scheme).text))
        .tint(theme.id == "system" ? .accentColor : Color(atlasHex: theme.palette(for: scheme).accent))
        .frame(minWidth: videoOnly.isActive ? 100 : 960, minHeight: videoOnly.isActive ? 100 : 680)
        .toolbar { appToolbar }
        .toolbarVisibility(videoOnly.isActive ? .hidden : .visible, for: .windowToolbar)
        .onExitCommand { videoOnly.exit() }
        .task(id: ReceiverSelection(profile: settings.selectedReceiver, revision: settings.connectionRevision)) {
            let loadMetadata = hasInitializedReceiver || settings.preferences.connectsOnLaunch
            hasInitializedReceiver = true
            await connect(loadMetadata: loadMetadata)
        }
        .task(id: guideQueryID) {
            if !demo, section == .guide {
                await guide.loadTimeline(channels: guideChannels, client: channels.client, cacheDirectory: settings.paths?.cache.appendingPathComponent("EPG", isDirectory: true))
                guard !Task.isCancelled else { return }
                applyReminderSelection()
                applyNowNextSelection()
            }
        }
        .task(id: "\(settings.selectedReceiver?.id.uuidString ?? "")|\(settings.connectionRevision)|\(channels.metadataRevision)|\(section == .guide)") {
            if !demo, section == .guide, !channels.channels.isEmpty {
                while !Task.isCancelled {
                    if timerRequest == nil && !showAutoTimer { await receiverTimers.load(using: channels.client) }
                    guard !Task.isCancelled else { return }
                    guideStatusDate = Date()
                    do { try await Task.sleep(for: .seconds(30)) } catch { return }
                }
            }
        }
        .onChange(of: reminders.pendingOpen?.id, initial: true) { _, _ in
            guard let target = reminders.takePendingOpen() else { return }
            pendingNowNextSelection = nil; pendingNowNextChannel = nil
            guard settings.preferences.receivers.contains(where: { $0.id == target.receiverID }) else { localError = "Der Receiver dieser Erinnerung ist nicht mehr eingerichtet."; return }
            openedReminder = target; needsReminderSelection = true
            settings.preferences.selectedReceiverID = target.receiverID; settings.persist()
            section = .guide; videoOnly.exit()
            guide.timelineRange = GuideTimelineRange(containing: target.programme.start)
            guide.window.start = target.programme.start
            applyReminderSelection(finish: false)
            openWindow(id: "main"); NSApplication.shared.activate()
        }
        .task(id: guide.freshRevision) {
            if let id = guide.freshReceiverID { await reminders.reconcile(receiverID: id, channels: guideChannels, freshProgrammes: guide.freshProgrammes, language: settings.language) }
        }
        .task(id: nowGuide.freshRevision) {
            if let id = nowGuide.freshReceiverID { await reminders.reconcile(receiverID: id, channels: currentGuideChannels, freshProgrammes: nowGuide.freshProgrammes, language: settings.language) }
        }
        .task(id: nowGuideQueryID) {
            if !demo, section != .guide {
                while !Task.isCancelled {
                    await nowGuide.ensureNowNext(channels: currentGuideChannels, client: channels.client, timeline: guide,
                                                cacheDirectory: settings.paths?.cache.appendingPathComponent("EPG", isDirectory: true))
                    guard !Task.isCancelled, channels.client != nil,
                          let next = nowGuide.nextNowNextCheck(channels: currentGuideChannels, after: Date()) else { return }
                    do { try await Task.sleep(for: .seconds(max(0.05, next.timeIntervalSinceNow))) } catch { return }
                }
            }
        }
        .task(id: "\(guideQueryID)|\(nowGuideQueryID)|\(settings.preferences.epgRefreshMinutes)|\(settings.preferences.epgRefreshStartDate?.timeIntervalSince1970 ?? 0)") {
            let minutes = settings.preferences.epgRefreshMinutes
            guard !demo, minutes > 0, channels.client != nil else { return }
            while !Task.isCancelled {
                guard let next = settings.preferences.nextEPGRefresh(after: Date(), sessionStartedAt: epgRefreshSessionStart) else { return }
                do { try await Task.sleep(for: .seconds(max(0, next.timeIntervalSinceNow))) } catch { return }
                guard !Task.isCancelled else { return }
                // EPG only: never reload receiver metadata or touch stream players.
                guard channels.error == nil, !channels.isLoading else { continue }
                if section == .guide {
                    await guide.refresh(channels: channels.channels, client: channels.client)
                    guard !Task.isCancelled else { return }
                    await receiverTimers.load(using: channels.client)
                } else {
                    await nowGuide.ensureNowNext(channels: currentGuideChannels, client: channels.client, timeline: guide,
                                                cacheDirectory: settings.paths?.cache.appendingPathComponent("EPG", isDirectory: true), force: true)
                }
            }
        }
        .onChange(of: section) { _, value in
            if value == .television || value == .multiview { playback.setMultiview(value == .multiview) }
            if value != .recordings { library.stopPlayback() }
            if value != .guide { pendingNowNextSelection = nil; pendingNowNextChannel = nil }
        }
        .onChange(of: settings.preferences) { settings.persist() }
        .sheet(isPresented: $showAutoTimer, onDismiss: {
            Task { await receiverTimers.load(using: channels.client) }
        }) {
            ReceiverAutoTimersView(client: channels.client, channels: channels.channels, bouquets: channels.bouquets, loadedProgrammes: loadedProgrammes)
        }
        .sheet(isPresented: $showReminders) { ProgrammeRemindersView(store: reminders, settings: settings) }
        .sheet(isPresented: $showEPGRefresh) {
            EPGRefreshView(client: channels.client, preferredBouquetID: channels.selectedBouquetID)
        }
        .sheet(isPresented: $showPresets) {
            MultiviewPresetsView(settings: settings, playback: playback, onRestore: restorePreset)
        }
        .sheet(isPresented: $showRecordingOptions) {
            VStack {
                RecordingOptionsView(recording: recording)
                Button("Fertig") { showRecordingOptions = false }.keyboardShortcut(.cancelAction)
            }.padding().frame(width: 560, height: 340)
        }
        .sheet(item: $timerRequest) { request in
            ReceiverTimersView(client: channels.client, store: receiverTimers, programme: request.programme, channel: request.channel, loadedProgrammes: loadedProgrammes, guideChannels: guideChannels)
        }
        .task(id: sleepDeadline) {
            guard let deadline = sleepDeadline else { return }
            do { try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow))) } catch { return }
            guard !Task.isCancelled, sleepDeadline == deadline else { return }
            restoreTask?.cancel(); playback.stopAll(); library.stopPlayback(); videoOnly.exit(); sleepDeadline = nil
        }
        .onDisappear { restoreTask?.cancel(); bouquetTask?.cancel(); videoOnly.exit(); playback.stopAll(); library.reset(); recording.stop() }
    }

    private var appContent: some View {
        VStack(spacing: 0) {
            if recording.isActive || recording.message != nil { recordingStatus }
            if let error = localError { ErrorNotice(message: error).padding([.horizontal, .top], 16) }
            else if let error = channels.error {
                ErrorNotice(message: error == AtlasFailure.unreachable.localizedDescription
                    ? settings.language.localized("Die Receiver-Weboberfläche ist nicht erreichbar. Bild und Ton können trotzdem weiterlaufen.")
                    : settings.language.localized("Receiver-Weboberfläche:") + " " + settings.language.localized(error))
                    .padding([.horizontal, .top], 16)
            }
            if section == .guide {
                GuideView(store: guide, channels: guideChannels, picons: channels.picons, settings: settings, playback: playback, demo: demo, reminders: reminders, recording: recording, statusDate: guideStatusDate, timers: receiverTimers.timers, timerError: receiverTimers.error.map { settings.language.localized($0) }, onPlay: { channel in play(channel, index: 0) }, onPicon: { channel in await channels.loadPicon(channel) }, onSchedule: { event, channel in
                    timerRequest = TimerRequest(programme: event, channel: channel)
                }, onEPGRefresh: { showEPGRefresh = true }, onAutoTimer: { showAutoTimer = true })
            } else if section == .nowNext {
                NowNextView(channels: filteredChannels, bouquets: channels.bouquets, selectedBouquetID: bouquetSelection,
                            favoritesOnly: $favoritesOnly, search: $search, events: demo ? guide.events : nowGuide.events,
                            errors: nowGuide.errors, isLoading: !demo && nowGuide.isLoading, picons: channels.picons,
                            language: settings.language, piconRevision: "\(settings.connectionRevision)|\(settings.selectedReceiver?.id.uuidString ?? "")",
                            demo: demo, isMetadataLoading: channels.isLoading,
                            onPicon: { channel in await channels.loadPicon(channel) },
                            onProgramme: openNowNextProgramme, onPlay: { channel in section = .television; play(channel, index: 0) },
                            onRefresh: refreshChannels)
            } else if section == .recordings {
                ReceiverRecordingsView(store: library, client: demo ? nil : channels.client, settings: settings, onPlay: {
                    restoreTask?.cancel(); playback.stopAll(); videoOnly.exit()
                })
            } else {
                television
            }
            Divider()
            HStack {
                Label {
                    if demo { Text("Demo · keine Receiver-Verbindung") }
                    else if let receiver = settings.selectedReceiver { Text(receiver.name) }
                    else { Text("Kein Receiver") }
                } icon: { Image(systemName: "tv") }
                if channels.isLoading { ProgressView().controlSize(.mini); Text("Sender werden geladen …") }
                Spacer()
                if let deadline = sleepDeadline {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text("Wiedergabestopp in \(Duration.seconds(max(0, deadline.timeIntervalSince(context.date))).formatted(.time(pattern: .hourMinuteSecond).locale(locale)))")
                            .monospacedDigit()
                    }
                    Button("Abbrechen") { sleepDeadline = nil }
                }
                if let info = channels.receiverInfo { Text("\(info.name) · \(info.image)") }
                if demo { Text("Synthetische Beispieldaten") }
            }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.vertical, 10)
        }
    }

    @ToolbarContentBuilder private var appToolbar: some ToolbarContent {
            ToolbarItem(placement: .principal) {
                sectionPicker
                    .pickerStyle(.segmented)
                    .fixedSize(horizontal: true, vertical: false)
            }
            ToolbarItem(placement: .automatic) {
                if !demo {
                    Picker("Receiver", selection: $settings.preferences.selectedReceiverID) {
                        ForEach(settings.preferences.receivers) { Text($0.name).tag(Optional($0.id)) }
                    }.frame(maxWidth: 180)
                }
            }
            ToolbarItem(placement: .automatic) {
                Button("Receiver-Info", systemImage: "info.circle") { openWindow(id: "receiver-info") }
                    .help("Hardware und Tuner des ausgewählten Receivers anzeigen")
                    .disabled(demo || settings.selectedReceiver == nil)
            }
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("AutoTimer-Regeln …") { showAutoTimer = true }.disabled(demo || channels.client == nil)
                    Button("Erinnerungen …") { showReminders = true }.disabled(demo)
                    Button("Receiver-Timer …") { timerRequest = TimerRequest(programme: nil, channel: nil) }.disabled(demo || channels.client == nil)
                    Button("Multiview-Belegungen …") { showPresets = true }.disabled(demo || settings.selectedReceiver == nil)
                    Button("Aufnahmeoptionen …") { showRecordingOptions = true }
                    Menu("Sleep-Timer") {
                        ForEach([15, 30, 60, 90, 120], id: \.self) { minutes in
                            Button("In \(minutes) Minuten Wiedergabe stoppen") { sleepDeadline = Date().addingTimeInterval(Double(minutes * 60)) }
                        }
                        if sleepDeadline != nil { Button("Sleep-Timer abbrechen") { sleepDeadline = nil } }
                        Text("Lokale Aufnahmen laufen weiter.")
                    }
                } label: { Label("Weitere Funktionen", systemImage: "ellipsis.circle") }
            }
            ToolbarItem(placement: .automatic) { SettingsLink { Label("Einstellungen", systemImage: "slider.horizontal.3") } }
            ToolbarItem(placement: .automatic) {
                Button("Nur Video", systemImage: "play.rectangle.fill") { enterVideoOnly(playback.targetIndex) }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                    .help("Nur das ausgewählte Video zeigen · Escape zum Zurückkehren")
                    .disabled(section == .recordings || (!demo && playback.slots[playback.targetIndex].channel == nil))
            }
    }

    private var sectionPicker: some View {
        Picker("Ansicht", selection: $section) {
            ForEach(MainSection.allCases, id: \.self) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
        }
    }

    private var recordingStatus: some View {
        HStack(spacing: 12) {
            if recording.isActive {
                Image(systemName: "record.circle.fill").foregroundStyle(.red)
                Text(recording.channelName).fontWeight(.semibold).lineLimit(1)
                TimelineView(.periodic(from: recording.startedAt, by: 1)) { context in
                    Text(Duration.seconds(max(0, context.date.timeIntervalSince(recording.startedAt))).formatted(.time(pattern: .hourMinuteSecond).locale(locale)))
                        .monospacedDigit()
                }
                Text(recording.bytes, format: .byteCount(style: .file)).monospacedDigit()
                Spacer()
                Button(LocalizedStringKey(recording.isStopping ? "Wird gespeichert …" : "Aufnahme stoppen")) { recording.stop() }.disabled(recording.isStopping)
            } else {
                AppLocalizedText(resource: recording.message ?? "").lineLimit(2)
                Spacer()
                if recording.canReveal { Button("Im Finder zeigen") { recording.reveal() } }
                Button("Schließen", systemImage: "xmark") { recording.dismissMessage() }.labelStyle(.iconOnly)
            }
        }
        .font(.callout).padding(.horizontal, 20).padding(.vertical, 10)
        .accessibilityElement(children: .contain)
    }

    private func isRecording(_ slot: PlaybackSlot) -> Bool {
        recording.isActive && recording.channelID == slot.channel?.id && recording.receiverID == settings.selectedReceiver?.id
    }

    private func toggleRecording(_ slot: PlaybackSlot) {
        if isRecording(slot) { recording.stop(); return }
        guard !recording.isActive, !demo, let channel = slot.channel,
              let profile = settings.selectedReceiver, let client = channels.client else { return }
        let title = nowGuide.events[channel.id]?.first { $0.start <= Date() && $0.end > Date() }?.title
        recording.start(channel: channel, profile: profile, client: client, settings: settings, programmeTitle: title)
    }

    private func enterVideoOnly(_ index: Int) {
        guard playback.slots.indices.contains(index), demo || playback.slots[index].channel != nil else { return }
        playback.selectAudio(index)
        videoOnly.enter(slot: index)
    }

    private var currentGuideChannels: [Channel] {
        var seen = Set<String>()
        return (channels.channels + presetGuideChannels + (favoritesOnly ? favoriteChannels : [])).filter { seen.insert($0.id).inserted }
    }

    private var nowGuideQueryID: String {
        "\(channels.metadataRevision)|\(settings.selectedReceiver?.id.uuidString ?? "")|\(settings.connectionRevision)|\(section == .guide)|\(currentGuideChannels.map(\.id).joined(separator: ";"))"
    }

    private var guideQueryID: String {
        "\(channels.metadataRevision)|\(settings.selectedReceiver?.id.uuidString ?? "")|\(settings.connectionRevision)|\(section == .guide)|\(channels.selectedBouquetID ?? "")|\(guideChannels.map(\.id).joined(separator: ";"))|\(guide.timelineRange.start.timeIntervalSince1970)|\(guide.timelineRange.end.timeIntervalSince1970)"
    }

    private var volumeBinding: Binding<Double> {
        Binding(get: { playback.volume }, set: { playback.setVolume($0) })
    }

    private var bouquetSelection: Binding<String?> {
        Binding(get: { channels.selectedBouquetID }, set: { selectBouquet($0) })
    }

    private func refreshChannels() {
        guide.invalidateTimelineCache(); nowGuide.invalidateNowNext()
        Task { await channels.refresh() }
    }

    private func selectBouquet(_ id: String?) {
        guard !demo, let id, id != channels.selectedBouquetID,
              let profile = settings.selectedReceiver,
              let bouquet = channels.bouquets.first(where: { $0.id == id }) else { return }
        bouquetTask?.cancel()
        channels.selectedBouquetID = id
        bouquetTask = Task {
            guard !Task.isCancelled, settings.selectedReceiver == profile,
                  channels.client?.profile == profile, channels.selectedBouquetID == id else { return }
            await channels.loadChannels(in: bouquet)
        }
    }

    private var television: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker("Bouquet", selection: bouquetSelection) {
                    ForEach(channels.bouquets) { Text(demo ? settings.language.localized($0.name) : $0.name).tag(Optional($0.id)) }
                }.frame(maxWidth: 280)
                Toggle("Favoriten", systemImage: "star.fill", isOn: $favoritesOnly).toggleStyle(.button).disabled(demo)
                Spacer()
                if section == .multiview {
                    Picker("Bilder", selection: Binding(get: { playback.visibleCount }, set: { restoreTask?.cancel(); playback.setCount($0) })) {
                        Text("2 Bilder").tag(2); Text("3 Bilder").tag(3); Text("4 Bilder").tag(4)
                    }.frame(width: 130)
                }
                TextField("Sender suchen", text: $search).textFieldStyle(.roundedBorder).frame(width: 190)
                Button("Neu laden", systemImage: "arrow.clockwise", action: refreshChannels).labelStyle(.iconOnly).disabled(channels.isLoading)
            }.padding(.horizontal, 20).padding(.vertical, 12)
            GeometryReader { geometry in
                HStack(spacing: 12) {
                    VideoTile(slot: playback.slots[0], selected: playback.targetIndex == 0, audible: !playback.slots[0].isMuted, audioSelected: playback.audibleIndex == 0, volume: volumeBinding, demo: demo, large: true, select: { playback.targetIndex = 0 }, audio: { playback.toggleAudio(0) }, videoOnly: { enterVideoOnly(0) }, swapWithMain: nil, recordingActive: isRecording(playback.slots[0]), recordingEnabled: !recording.isStopping && (!recording.isActive || isRecording(playback.slots[0])), record: { toggleRecording(playback.slots[0]) }, stop: { playback.stop(playback.slots[0]) })
                        .id(playback.slots[0].id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if section == .multiview {
                        VStack(spacing: 12) {
                            ForEach(Array(playback.slots[1..<playback.visibleCount])) { slot in
                                let index = playback.slots.firstIndex(where: { $0.id == slot.id }) ?? 1
                                VideoTile(slot: slot, selected: playback.targetIndex == index, audible: !playback.slots[index].isMuted, audioSelected: playback.audibleIndex == index, volume: volumeBinding, demo: demo, large: false, select: { playback.targetIndex = index }, audio: { playback.toggleAudio(index) }, videoOnly: { enterVideoOnly(index) }, swapWithMain: { playback.swapWithMain(index) }, recordingActive: isRecording(slot), recordingEnabled: !recording.isStopping && (!recording.isActive || isRecording(slot)), record: { toggleRecording(slot) }, stop: { playback.stop(slot) })
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
                        Text("Danach: \(next.start.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))) · \(next.title)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }.padding(.horizontal, 24).padding(.vertical, 12)
            }
            senderShelf
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
                            .overlay(alignment: .topTrailing) {
                                if let profile = settings.selectedReceiver {
                                    let selected = settings.preferences.isFavorite(channel, receiverID: profile.id)
                                    Button(LocalizedStringKey(selected ? "Aus Favoriten entfernen" : "Zu Favoriten hinzufügen"), systemImage: selected ? "star.fill" : "star") {
                                        settings.preferences.toggleFavorite(channel, receiverID: profile.id); settings.persist()
                                    }.labelStyle(.iconOnly).buttonStyle(.plain).padding(7)
                                        .background(.black.opacity(0.6), in: Circle()).foregroundStyle(selected ? .yellow : .white).padding(4)
                                }
                            }
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
        if let title = (demo ? guide.events[channel.id] : nowGuide.events[channel.id])?.first(where: { $0.start <= now && $0.end > now })?.title {
            return demo ? settings.language.localized(title) : title
        }
        return settings.language.localized("Programminformationen")
    }
    private func play(_ channel: Channel, index: Int? = nil) {
        restoreTask?.cancel()
        guard !demo, let profile = settings.selectedReceiver, let client = channels.client else { return }
        Task {
            do {
                let password = try settings.credentials.availablePassword(for: profile.id)
                await playback.play(channel, client: client, profile: profile, password: password, index: index)
            } catch { localError = error.localizedDescription }
        }
    }
    private func restorePreset(_ preset: MultiviewPreset) {
        guard let profile = settings.selectedReceiver, preset.receiverID == profile.id, let client = channels.client else { return }
        restoreTask?.cancel()
        section = .multiview
        restoreTask = Task {
            do {
                let password = try settings.credentials.availablePassword(for: profile.id)
                await playback.restore(preset, client: client, profile: profile, password: password)
                guard !Task.isCancelled, settings.selectedReceiver == profile else { return }
                while channels.isLoading {
                    try await Task.sleep(for: .milliseconds(100))
                    guard !Task.isCancelled, settings.selectedReceiver == profile else { return }
                }
                if channels.error != nil || channels.channels.isEmpty { await channels.refresh() }
                guard !Task.isCancelled, settings.selectedReceiver == profile else { return }
                presetGuideChannels = preset.channels.compactMap { $0 }
            } catch is CancellationError { }
            catch { localError = error.localizedDescription }
        }
    }
    private func applyReminderSelection(finish: Bool = true) {
        guard needsReminderSelection, let target = openedReminder, target.receiverID == settings.selectedReceiver?.id, channels.client?.profile.id == target.receiverID else { return }
        if finish { needsReminderSelection = false }
        guide.selection = guide.events[target.programme.channelID]?.first(where: { $0.id == target.programme.id }) ?? target.programme
    }
    private func openNowNextProgramme(_ programme: Programme, channel: Channel) {
        videoOnly.exit()
        guide.timelineRange = GuideTimelineRange(containing: programme.start)
        guide.window.start = programme.start
        if demo {
            guide.selection = guide.events[programme.channelID]?.first { $0.id == programme.id } ?? programme
            section = .guide
        } else {
            pendingNowNextSelection = programme
            pendingNowNextChannel = channel
            section = .guide
        }
    }
    private func applyNowNextSelection() {
        guard let programme = pendingNowNextSelection else { return }
        pendingNowNextSelection = nil
        guide.selection = guide.events[programme.channelID]?.first { $0.id == programme.id } ?? programme
    }
    private func connect(loadMetadata: Bool) async {
        bouquetTask?.cancel()
        restoreTask?.cancel(); timerRequest = nil; showPresets = false; showAutoTimer = false; receiverTimers.reset(); library.reset()
        pendingNowNextSelection = nil; pendingNowNextChannel = nil
        playback.stopAll(); presetGuideChannels = []; guide.reset(); nowGuide.reset(); guide.window.duration = settings.preferences.guideDuration; localError = nil
        if demo {
            channels.loadDemo()
            guide.loadDemo(channels: channels.channels)
            return
        }
        guard let profile = settings.selectedReceiver else { return }
        do {
            await channels.connect(profile, password: try settings.credentials.availablePassword(for: profile.id), loadMetadata: loadMetadata)
            if needsReminderSelection, let target = openedReminder, target.receiverID == profile.id, settings.selectedReceiver?.id == profile.id {
                guide.timelineRange = GuideTimelineRange(containing: target.programme.start); guide.window.start = target.programme.start
                applyReminderSelection(finish: false)
                if channels.channels.isEmpty {
                    await guide.loadTimeline(channels: guideChannels, client: channels.client, cacheDirectory: settings.paths?.cache.appendingPathComponent("EPG", isDirectory: true))
                    if !Task.isCancelled { applyReminderSelection() }
                }
            }
        }
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
    let swapWithMain: (() -> Void)?
    let recordingActive: Bool
    let recordingEnabled: Bool
    let record: () -> Void
    let stop: () -> Void
    @Environment(\.atlasTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.locale) private var locale
    private var accent: Color { theme.id == "system" ? .accentColor : Color(atlasHex: theme.palette(for: scheme).accent) }
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
    private var recordingButton: some View {
        Button(LocalizedStringKey(recordingActive ? "Aufnahme stoppen" : "Stream aufnehmen"), systemImage: recordingActive ? "stop.circle.fill" : "record.circle", action: record)
            .labelStyle(.iconOnly)
            .foregroundStyle(recordingActive ? Color.red : Color.white)
            .help(Text(LocalizedStringKey(recordingActive ? "Aufnahme dieses Senders stoppen" : "Dieses Bild als Originalstream aufnehmen")))
            .disabled(demo || slot.channel == nil || !recordingEnabled)
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
                if slot.isReconnecting {
                    VStack(spacing: 8) {
                        Text("Verbindung wird wiederhergestellt · Versuch \(slot.reconnectAttempt) von 3")
                        Button("Wiederverbindung abbrechen", action: stop)
                    }.font(.caption).padding(12).background(.black.opacity(0.85), in: .rect(cornerRadius: 8))
                    .foregroundStyle(.white).frame(maxHeight: .infinity)
                }
                if large {
                    HStack(spacing: 14) {
                        Button(action: audio) { Label(LocalizedStringKey(audioLabel), systemImage: audible ? "speaker.wave.2" : "speaker.slash") }
                        volumeControl
                        if slot.channel != nil || demo { Text(LocalizedStringKey(demo ? "Demo" : "Live")).font(.caption) }
                        Spacer()
                        recordingButton
                        Button("Stoppen", systemImage: "stop.fill", action: stop).labelStyle(.iconOnly).disabled(demo)
                        Button("Nur Video", systemImage: "play.rectangle.fill", action: videoOnly).labelStyle(.iconOnly)
                            .help("Nur dieses Video zeigen · Escape zum Zurückkehren").disabled(!demo && slot.channel == nil)
                        Button("Vollbild", systemImage: "arrow.up.left.and.arrow.down.right") { NSApplication.shared.keyWindow?.toggleFullScreen(nil) }.labelStyle(.iconOnly)
                    }
                    .buttonStyle(.plain).font(.callout).padding(12).modifier(GlassPanel()).padding(18)
                }
            }
            .contentShape(Rectangle()).onTapGesture(perform: select)
            HStack {
                Button(action: select) { Text(slot.channel?.name ?? AppLanguage(locale: locale).localized(demo ? "Beispielsender" : "Freies Bild")).font(.caption.weight(.semibold)).lineLimit(1) }.buttonStyle(.plain)
                Spacer()
                if !large {
                    if let swapWithMain {
                        Button("Ins Hauptbild tauschen", systemImage: "arrow.up.arrow.down", action: swapWithMain)
                            .labelStyle(.iconOnly)
                            .help("Dieses Bild mit dem großen Bild tauschen")
                            .disabled(demo || slot.channel == nil)
                    }
                    volumeControl
                    recordingButton
                    Button("Nur Video", systemImage: "play.rectangle.fill", action: videoOnly).labelStyle(.iconOnly)
                        .help("Nur dieses Video zeigen · Escape zum Zurückkehren").disabled(!demo && slot.channel == nil)
                    Button(action: audio) { Image(systemName: audible ? "speaker.wave.2.fill" : "speaker.slash") }.buttonStyle(.plain).accessibilityLabel(Text(LocalizedStringKey(audioLabel)))
                }
            }.foregroundStyle(.white).padding(10).background(theme.id == "system" ? Color(white: 0.13) : Color(atlasHex: theme.dark.surface))
        }
        .clipShape(.rect(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(audible ? accent : selected ? .white.opacity(0.5) : .clear, lineWidth: 2) }
    }
}
