import SwiftUI
import Observation
import AtlasCore
import AtlasThemes
import AtlasPlayback
import AtlasReceiver

struct GuideView: View {
    @Bindable var store: GuideStore
    let channels: [Channel]
    let picons: [String: Data]
    @Bindable var settings: SettingsStore
    let playback: PlaybackStore
    let demo: Bool
    @Bindable var reminders: ProgrammeReminderStore
    let recording: RecordingStore
    let statusDate: Date
    let timers: [ReceiverTimer]
    let timerError: String?
    let onPlay: (Channel) -> Void
    let onPicon: (Channel) async -> Void
    let onSchedule: (Programme, Channel) -> Void
    let onEPGRefresh: () -> Void
    let onAutoTimer: () -> Void
    @State private var addTime = false
    @State private var customTime = Date()
    @State private var viewport = GuideViewportState()
    @Environment(\.atlasTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.locale) private var locale

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Programmübersicht").font(.caption).foregroundStyle(theme.id == "system" ? Color.secondary : Color(atlasHex: theme.palette(for: scheme).secondary))
                        DatePicker("Tag", selection: $store.window.start, displayedComponents: .date).labelsHidden().font(.title2)
                    }
                    Spacer()
                    GuideVisibleWindowLabel(viewport: viewport, fallback: store.window)
                    if store.isLoading { ProgressView().controlSize(.small) }
                }
                HStack {
                    Picker("Zeitspanne", selection: $store.window.duration) {
                        ForEach(GuideDuration.allCases, id: \.self) { Text("\($0.rawValue) Stunden").tag($0) }
                    }.frame(width: 200)
                    Spacer()
                    Button("EPG automatisch aktualisieren …", systemImage: "calendar.badge.clock", action: onEPGRefresh)
                        .disabled(demo)
                    Button("Zurück", systemImage: "chevron.left") { store.window.start.addTimeInterval(-store.window.duration.seconds) }.labelStyle(.iconOnly)
                    Button("Weiter", systemImage: "chevron.right") { store.window.start.addTimeInterval(store.window.duration.seconds) }.labelStyle(.iconOnly)
                }
                HStack {
                    EPGDisplayRefreshPicker(settings: settings)
                        .fixedSize()
                        .disabled(demo)
                    Button("AutoTimer-Regeln …", systemImage: "repeat", action: onAutoTimer).disabled(demo)
                    Spacer()
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
                TextField("Sendung oder Beschreibung suchen", text: $store.searchText).textFieldStyle(.roundedBorder)
                if let timerError {
                    Text(timerError).font(.caption).foregroundStyle(.secondary)
                }
                if !store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Suche in den geladenen Programmdaten aller Sender dieses Bouquets für sieben Tage.")
                        .font(.caption).foregroundStyle(.secondary)
                    List(store.searchResults) { event in
                        Button { openSearchResult(event) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(demo ? settings.language.localized(event.title) : event.title).font(.headline)
                                    eventBadges(event)
                                }
                                Text("\(channels.first { $0.id == event.channelID }?.name ?? settings.language.localized("Sender")) · \(event.start.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale)))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain)
                    }.overlay { if store.searchResults.isEmpty { ContentUnavailableView.search(text: store.searchText) } }
                } else {
                GuideTimelineView(store: store, channels: channels, picons: picons,
                                  settings: settings, demo: demo, timers: timers, reminders: reminders, recording: recording, statusDate: statusDate, onPicon: onPicon, viewport: viewport)
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

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if demo { DemoPicture(compact: true).aspectRatio(16 / 9, contentMode: .fit).clipShape(.rect(cornerRadius: 10)) }
                else { AtlasPlayback.PlaybackSurface(slot: playback.slots[0]).aspectRatio(16 / 9, contentMode: .fit).clipShape(.rect(cornerRadius: 10)) }
                if let event = store.selection {
                    Text(channels.first { $0.id == event.channelID }?.name ?? "").font(.caption).foregroundStyle(theme.id == "system" ? Color.secondary : Color(atlasHex: theme.palette(for: scheme).secondary))
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(demo ? settings.language.localized(event.title) : event.title).font(.title2.weight(.semibold))
                    }
                    eventBadges(event)
                    Text("\(event.start.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))) – \(event.end.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)))").font(.callout).monospacedDigit()
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        if event.start <= context.date && event.end > context.date {
                            ProgressView(value: event.progress(at: context.date)) { Text("Sendung läuft") }
                                .accessibilityValue("\(Int(event.progress(at: context.date) * 100)) Prozent")
                        }
                    }
                    Text(event.summary.isEmpty ? settings.language.localized("Keine weitere Beschreibung vorhanden.") : demo ? settings.language.localized(event.summary) : event.summary).font(.callout).foregroundStyle(theme.id == "system" ? Color.secondary : Color(atlasHex: theme.palette(for: scheme).secondary))
                    Button("Sender ansehen", systemImage: "play.fill") {
                        if let channel = channels.first(where: { $0.id == event.channelID }) { onPlay(channel) }
                    }.buttonStyle(.glassProminent).disabled(demo)
                    Button("Auf Receiver aufnehmen", systemImage: "calendar.badge.plus") {
                        if let channel = channels.first(where: { $0.id == event.channelID }) { onSchedule(event, channel) }
                    }.disabled(demo || event.end <= Date() || scheduledTimer(for: event) != nil)
                    if let reminder = reminders.reminder(for: event, receiverID: settings.selectedReceiver?.id) {
                        Button("Erinnerung entfernen", systemImage: "bell.slash") { reminders.remove(reminder) }.disabled(reminders.isSaving)
                    } else {
                        Menu("Erinnern", systemImage: "bell.badge") {
                            ForEach([1, 5, 10, 15, 30, 60], id: \.self) { minutes in
                                Button("\(minutes) Minuten vorher") {
                                    if let receiver = settings.selectedReceiver, let channel = channels.first(where: { $0.id == event.channelID }) {
                                        Task { await reminders.add(event: event, channel: channel, receiverID: receiver.id, minutes: minutes, language: settings.language) }
                                    }
                                }.disabled(event.start.addingTimeInterval(-Double(minutes) * 60) <= Date())
                            }
                        }.disabled(demo || event.start <= Date() || reminders.isSaving)
                    }
                    if let error = reminders.error { Text(settings.language.localized(error)).font(.caption).foregroundStyle(.secondary) }
                    let airings = store.otherAirings(of: event)
                    if !airings.isEmpty {
                        Text("Weitere geladene Ausstrahlungen").font(.headline)
                        ForEach(airings.prefix(10)) { airing in
                            Button { store.selection = airing } label: {
                                Text("\(channels.first { $0.id == airing.channelID }?.name ?? settings.language.localized("Sender")) · \(airing.start.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale)))")
                            }
                        }
                    }
                } else {
                    Text("Sendung auswählen").font(.title3.weight(.semibold))
                    Text("Wähle eine Sendung für Uhrzeit und Beschreibung.").font(.callout).foregroundStyle(theme.id == "system" ? Color.secondary : Color(atlasHex: theme.palette(for: scheme).secondary))
                }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }.background(Color(atlasHex: theme.palette(for: scheme).surface))
    }

    private func eventBadges(_ event: Programme) -> some View {
        GuideEventBadges(event: event, timers: timers, reminders: reminders, recording: recording,
                         receiverID: settings.selectedReceiver?.id, date: statusDate)
    }

    private func scheduledTimer(for event: Programme) -> ReceiverTimer? {
        ReceiverTimerMatcher.matchingTimer(for: event, in: timers)
    }

    private func openSearchResult(_ event: Programme) {
        store.selection = event
        store.window.start = event.start
        store.searchText = ""
    }
}


@MainActor @Observable
private final class GuideViewportState {
    var window: GuideWindow?
}

private struct GuideVisibleWindowLabel: View {
    let viewport: GuideViewportState
    let fallback: GuideWindow
    @Environment(\.locale) private var locale

    var body: some View {
        let window = viewport.window ?? fallback
        VStack(alignment: .trailing, spacing: 3) {
            Text(dateLabel(window)).font(.callout.weight(.semibold))
            Text("\(window.start.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))) – \(window.end.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)))")
                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
        }
    }

    private func dateLabel(_ window: GuideWindow) -> String {
        let format = Date.FormatStyle(date: .complete, time: .omitted).locale(locale)
        let start = window.start.formatted(format)
        guard !Calendar.current.isDate(window.start, inSameDayAs: window.end) else { return start }
        return "\(start) – \(window.end.formatted(format))"
    }
}

private struct GuideTimelineView: View {
    @Bindable var store: GuideStore
    let channels: [Channel]
    let picons: [String: Data]
    let settings: SettingsStore
    let demo: Bool
    let timers: [ReceiverTimer]
    let reminders: ProgrammeReminderStore
    let recording: RecordingStore
    let statusDate: Date
    let onPicon: (Channel) async -> Void
    let viewport: GuideViewportState
    @State private var horizontalOffset: CGFloat = 0
    @State private var scrollWidth: CGFloat = 0
    @State private var visibleTimelineWidth: CGFloat = 0
    @State private var scrollPosition = ScrollPosition()
    @State private var scrollCommitTask: Task<Void, Never>?
    @State private var pendingScrollCommitDate: Date?
    @Environment(\.atlasTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.locale) private var locale

    var body: some View {
        GeometryReader { geometry in
            let viewportWidth = max(100, geometry.size.width - 80)
            let contentWidth = viewportWidth * CGFloat(timelineRange.seconds / store.window.duration.seconds)
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(spacing: 7, pinnedViews: .sectionHeaders) {
                    Section {
                        ForEach(channels) { channel in
                            HStack(spacing: 8) {
                                VStack(spacing: 5) {
                                    PiconView(data: picons[channel.id], name: channel.name, size: 32)
                                    Text(channel.name).font(.caption).lineLimit(1)
                                }
                                .frame(width: 72, height: 75)
                                .background(Color(atlasHex: theme.palette(for: scheme).background))
                                .offset(x: horizontalOffset)
                                .zIndex(2)
                                timeline(channel, width: contentWidth)
                            }.task(id: "\(settings.connectionRevision)|\(settings.preferences.selectedReceiverID?.uuidString ?? "")|\(channel.id)") { if !demo { await onPicon(channel) } }
                        }
                    } header: { timeHeader(width: contentWidth) }
                }.frame(width: contentWidth + 80, alignment: .leading)
            }
            .scrollPosition($scrollPosition)
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x } action: { _, value in
                let offset = min(max(0, value), max(0, contentWidth + 80 - geometry.size.width))
                if horizontalOffset != offset { horizontalOffset = offset }
                if scrollWidth != contentWidth { scrollWidth = contentWidth }
                if visibleTimelineWidth != viewportWidth { visibleTimelineWidth = viewportWidth }
                updateVisibleSummary()
            }
            .onScrollPhaseChange { _, phase in
                if phase == .tracking || phase == .interacting || phase == .decelerating {
                    scrollCommitTask?.cancel()
                } else if phase == .idle, scrollPosition.isPositionedByUser {
                    commitVisibleWindow()
                }
            }
            .onAppear {
                if store.window.start < timelineRange.start || store.window.end > timelineRange.end {
                    store.timelineRange = GuideTimelineRange(containing: store.window.start)
                }
                scrollWidth = contentWidth
                visibleTimelineWidth = viewportWidth
                positionAtStoreStart(viewportWidth: viewportWidth, contentWidth: contentWidth)
            }
            .onChange(of: contentWidth) { _, _ in
                positionAtStoreStart(viewportWidth: viewportWidth, contentWidth: contentWidth)
            }
            .onChange(of: store.window.start) { oldValue, newValue in
                guard abs(oldValue.timeIntervalSince(newValue)) > 0.5 else { return }
                if let committed = pendingScrollCommitDate, abs(committed.timeIntervalSince(newValue)) < 0.5 {
                    pendingScrollCommitDate = nil
                } else if newValue < timelineRange.start || store.window.end > timelineRange.end {
                    store.timelineRange = GuideTimelineRange(containing: newValue)
                }
                positionAtStoreStart(viewportWidth: viewportWidth, contentWidth: contentWidth)
            }
            .onChange(of: store.window.duration) { _, _ in
                positionAtStoreStart(viewportWidth: viewportWidth, contentWidth: contentWidth)
            }
            .onDisappear { scrollCommitTask?.cancel() }
        }
    }

    private func timeHeader(width: CGFloat) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sender")
                    .font(.caption)
                    .foregroundStyle(theme.id == "system" ? Color.secondary : Color(atlasHex: theme.palette(for: scheme).secondary))
                Text(visibleWindow.start.formatted(Date.FormatStyle(date: .complete, time: .omitted).locale(locale)))
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(theme.id == "system" ? Color.primary : Color(atlasHex: theme.palette(for: scheme).text))
            }
                .frame(width: 72, alignment: .leading)
                .background(Color(atlasHex: theme.palette(for: scheme).background))
                .offset(x: horizontalOffset)
                .zIndex(2)
            ZStack(alignment: .leading) {
                ForEach(hourTicks, id: \.self) { tick in
                    let isDayStart = Calendar.current.component(.hour, from: tick) == 0 && Calendar.current.component(.minute, from: tick) == 0
                    let label = isDayStart
                        ? tick.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
                        : tick.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
                    Text(label).font(.caption).monospacedDigit()
                        .offset(x: width * CGFloat(tick.timeIntervalSince(rangeAnchor) / timelineRange.seconds))
                }
            }.frame(width: width, alignment: .leading).clipped()
        }.padding(.vertical, 8).background(Color(atlasHex: theme.palette(for: scheme).background))
    }

    private func timeline(_ channel: Channel, width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 7).fill(.quaternary.opacity(0.5))
            let values = store.events[channel.id] ?? []
            if values.isEmpty {
                AppLocalizedText(store.errors[channel.id] ?? "Keine Programmdaten")
                    .font(.caption)
                    .foregroundStyle(theme.id == "system" ? Color.secondary : Color(atlasHex: theme.palette(for: scheme).secondary))
                    .padding(10)
                    .frame(width: max(1, visibleTimelineWidth - 20), alignment: .leading)
                    .offset(x: horizontalOffset)
            }
            // Keep the full week in the data cache, but only build nearby event views.
            let margin = store.window.duration.seconds / 2
            let lower = visibleWindow.start.addingTimeInterval(-margin)
            let upper = visibleWindow.end.addingTimeInterval(margin)
            let displayedValues = values.filter { $0.end > lower && $0.start < upper }
            ForEach(displayedValues) { event in
                if let part = timelineRange.visibleFraction(of: event) {
                    GuideProgrammeCell(event: event, channelName: channel.name, demo: demo,
                                       language: settings.language, store: store,
                                       timers: timers, reminders: reminders, recording: recording,
                                       receiverID: settings.selectedReceiver?.id, statusDate: statusDate)
                        .frame(width: max(1, width * part.width - 4), height: 73, alignment: .leading).clipped()
                        .offset(x: width * part.offset)
                }
            }
        }.frame(width: width, height: 75).clipped()
    }

    private var visibleWindow: GuideWindow {
        let start = timelineRange.visibleStart(offset: horizontalOffset, timelineWidth: max(1, scrollWidth), duration: store.window.duration)
        return GuideWindow(start: start, duration: store.window.duration)
    }

    private var rangeAnchor: Date { store.timelineRange.start }
    private var timelineRange: GuideTimelineRange { store.timelineRange }

    private var hourTicks: [Date] {
        let secondsPerTick: TimeInterval = 30 * 60
        let start = visibleWindow.start.timeIntervalSince(timelineRange.start)
        let end = visibleWindow.end.timeIntervalSince(timelineRange.start)
        let firstIndex = max(0, Int(floor(start / secondsPerTick)) - 1)
        let lastIndex = min(Int(ceil(timelineRange.seconds / secondsPerTick)), Int(ceil(end / secondsPerTick)) + 1)
        guard firstIndex <= lastIndex else { return [] }
        return (firstIndex...lastIndex).compactMap { index in
            let tick = timelineRange.start.addingTimeInterval(Double(index) * secondsPerTick)
            return tick < timelineRange.end ? tick : nil
        }
    }

    private func commitVisibleWindow() {
        scrollCommitTask?.cancel()
        scrollCommitTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, scrollPosition.isPositionedByUser else { return }
            let target = visibleWindow.start
            guard abs(store.window.start.timeIntervalSince(target)) > 60 else { return }
            pendingScrollCommitDate = target
            store.window.start = target
        }
    }

    private func positionAtStoreStart(viewportWidth: CGFloat, contentWidth: CGFloat) {
        let boundedStart = timelineRange.boundedStart(store.window.start, duration: store.window.duration)
        let fraction = timelineRange.fraction(of: boundedStart)
        let target = max(0, min(contentWidth - viewportWidth, contentWidth * fraction))
        scrollPosition.scrollTo(x: target)
        horizontalOffset = target
        scrollWidth = contentWidth
        updateVisibleSummary()
    }

    private func updateVisibleSummary() {
        let summary = visibleWindow
        // Date labels need minute precision, not a redraw for each fraction of a pixel.
        let minute = Date(timeIntervalSince1970: floor(summary.start.timeIntervalSince1970 / 60) * 60)
        let displayed = GuideWindow(start: minute, duration: summary.duration)
        if viewport.window != displayed { viewport.window = displayed }
    }

}


/// Pixel scrolling moves the cell; unchanged programme text stays in this leaf view.
private struct GuideProgrammeCell: View {
    let event: Programme
    let channelName: String
    let demo: Bool
    let language: AppLanguage
    let store: GuideStore
    let timers: [ReceiverTimer]
    let reminders: ProgrammeReminderStore
    let recording: RecordingStore
    let receiverID: UUID?
    let statusDate: Date
    @Environment(\.atlasTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.locale) private var locale

    var body: some View {
        Button { store.selection = event } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text(demo ? language.localized(event.title) : event.title).font(.callout.weight(.medium)).lineLimit(1)

                }
                Text("\(event.start.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))) – \(event.end.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)))")
                    .font(.caption).foregroundStyle(theme.id == "system" ? Color.secondary : Color(atlasHex: theme.palette(for: scheme).secondary)).lineLimit(1)
                GuideEventBadges(event: event, timers: timers, reminders: reminders, recording: recording,
                                 receiverID: receiverID, date: statusDate)
            }
            .padding(10).frame(maxWidth: .infinity, minHeight: 73, alignment: .leading)
            .background(Color(atlasHex: store.selection?.id == event.id ? theme.palette(for: scheme).selection : theme.palette(for: scheme).surface), in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("\(demo ? language.localized(event.title) : event.title) · \(event.start.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))) – \(event.end.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)))")
        .accessibilityLabel("\(channelName): \(demo ? language.localized(event.title) : event.title)")
    }
}


/// Reads reminder and local-recording state only in the small status row, away from scroll geometry.
private struct GuideEventBadges: View {
    let event: Programme
    let timers: [ReceiverTimer]
    let reminders: ProgrammeReminderStore
    let recording: RecordingStore
    let receiverID: UUID?
    let date: Date

    var body: some View {
        let local = recording.isActive && recording.receiverID == receiverID && recording.channelID == event.channelID
            && recording.startedAt < event.end && event.start <= date && event.end > date
        let state = ReceiverTimerMatcher.recordingState(for: event, in: timers, at: date)
        let reminder = reminders.reminder(for: event, receiverID: receiverID)
        HStack(spacing: 6) {
            if local || state == .recording {
                Label("Aufnahme läuft", systemImage: "record.circle.fill")
                    .foregroundStyle(.red)
                    .help(Text(LocalizedStringKey(local ? "Lokale Aufnahme läuft" : "Receiver-Aufnahme läuft")))
            } else if state == .scheduled {
                Label("Geplant", systemImage: "calendar.badge.checkmark")
                    .foregroundStyle(.orange).help("Aufnahme geplant")
            }
            if reminder != nil {
                Image(systemName: "bell.fill").foregroundStyle(.yellow)
                    .accessibilityLabel("Erinnerung gesetzt").help("Erinnerung gesetzt")
            }
        }.font(.caption2).lineLimit(1).fixedSize(horizontal: false, vertical: true)
    }
}
