import Foundation
import Observation
import AtlasCore
import AtlasReceiver
import AtlasPlayback

enum RecordingOverviewFilter: String, CaseIterable, Identifiable {
    case all, scheduled, running, library
    var id: Self { self }
    var title: String {
        switch self {
        case .all: "Alle"
        case .scheduled: "Geplant"
        case .running: "Laufend"
        case .library: "Bibliothek"
        }
    }
}

enum RecordingOverviewItem: Identifiable {
    case timer(ReceiverTimer)
    case recording(ReceiverRecording)

    var id: String {
        switch self {
        case .timer(let timer): "timer:\(timer.id)"
        case .recording(let recording): "recording:\(recording.id)"
        }
    }

    var title: String {
        switch self {
        case .timer(let timer): timer.name.isEmpty ? timer.serviceName : timer.name
        case .recording(let recording): recording.title
        }
    }

    var serviceName: String {
        switch self {
        case .timer(let timer): timer.serviceName
        case .recording(let recording): recording.serviceName
        }
    }

    var date: Date {
        switch self {
        case .timer(let timer): timer.begin
        case .recording(let recording): recording.begin ?? .distantPast
        }
    }
}

@MainActor @Observable
final class ReceiverRecordingsStore {
    private(set) var recordings: [ReceiverRecording] = []
    private(set) var directories: [ReceiverRecordingDirectory] = []
    private(set) var currentDirectory: String?
    private(set) var storage: [ReceiverStorage] = []
    private(set) var isLoadingStorage = false
    private(set) var storageError: String?
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var timerError: String?
    private(set) var timers: [ReceiverTimer] = []
    private(set) var isLoadingTimers = false
    private(set) var player: PlaybackSlot?
    private(set) var playingTitle: String?
    private(set) var savedProgress: TimeInterval?
    private(set) var progressError: String?
    var selectedID: String?
    var searchText = ""
    var filter: RecordingOverviewFilter = .all
    @ObservationIgnored private var source: ReceiverProfile?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var storageGeneration = UUID()
    @ObservationIgnored private var timerGeneration = UUID()
    @ObservationIgnored private var history: [String] = []
    @ObservationIgnored private var progressFile: URL?
    @ObservationIgnored private var checkpoints: [String: RecordingPlaybackCheckpoint] = [:]
    @ObservationIgnored private var canPersistProgress = true
    @ObservationIgnored private var progressTask: Task<Void, Never>?
    @ObservationIgnored private var restoreTask: Task<Void, Never>?
    @ObservationIgnored private var activeRecording: ReceiverRecording?
    @ObservationIgnored private var activeReceiverID: UUID?
    @ObservationIgnored private var playbackGeneration = UUID()

    private static let maximumCheckpointCount = 500
    private static let maximumCheckpointFileBytes = 256 * 1024

    init(paths: AppPaths? = try? AppPaths()) {
        progressFile = paths?.support.appendingPathComponent("receiver-recording-progress.json")
        guard let progressFile else { canPersistProgress = false; return }
        do {
            if FileManager.default.fileExists(atPath: progressFile.path) {
                let fileSize = try progressFile.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard fileSize <= Self.maximumCheckpointFileBytes else { throw CocoaError(.fileReadTooLarge) }
                let data = try Data(contentsOf: progressFile)
                guard data.count <= Self.maximumCheckpointFileBytes else { throw CocoaError(.fileReadTooLarge) }
                let stored = try JSONDecoder().decode([RecordingPlaybackCheckpoint].self, from: data)
                checkpoints = Dictionary(stored.filter { $0.isValid && $0.isResumable }
                    .sorted { $0.updatedAt > $1.updatedAt }
                    .prefix(Self.maximumCheckpointCount).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            }
        } catch {
            canPersistProgress = false
            progressError = "Der Wiedergabefortschritt konnte nicht gelesen werden. Die Datei bleibt erhalten."
        }
    }

    var canGoBack: Bool { !history.isEmpty }
    var selectedRecording: ReceiverRecording? {
        guard let selectedID, selectedID.hasPrefix("recording:") else { return nil }
        return recordings.first { "recording:\($0.id)" == selectedID }
    }
    var selectedTimer: ReceiverTimer? {
        guard let selectedID, selectedID.hasPrefix("timer:") else { return nil }
        return timers.first { "timer:\($0.id)" == selectedID }
    }
    var savedProgressForSelection: TimeInterval? {
        guard let recording = selectedRecording, let source else { return nil }
        return checkpoint(for: recording, receiverID: source.id)?.seconds
    }

    var overviewItems: [RecordingOverviewItem] {
        let now = Date()
        var items: [RecordingOverviewItem] = []
        if filter == .all || filter == .scheduled {
            items += timers.filter { isScheduled($0, at: now) }.map(RecordingOverviewItem.timer)
        }
        if filter == .all || filter == .running {
            items += timers.filter { isRunning($0, at: now) }.map(RecordingOverviewItem.timer)
        }
        if filter == .all || filter == .library {
            items += recordings.map(RecordingOverviewItem.recording)
        }
        return items.filter { item in
            searchText.isEmpty || item.title.localizedCaseInsensitiveContains(searchText)
                || item.serviceName.localizedCaseInsensitiveContains(searchText)
                || itemDescription(item).localizedCaseInsensitiveContains(searchText)
        }.sorted {
            if $0.date != $1.date { return $0.date > $1.date }
            return $0.title.localizedCompare($1.title) == .orderedAscending
        }
    }

    private func itemDescription(_ item: RecordingOverviewItem) -> String {
        if case .recording(let recording) = item { return recording.description }
        if case .timer(let timer) = item { return timer.description }
        return ""
    }

    private func isRunning(_ timer: ReceiverTimer, at date: Date) -> Bool {
        !timer.disabled && !timer.justPlay && !timer.cancelled && !timer.dontSave
            && timer.recordingType == "normal" && timer.pipZap != 1 && timer.state == 2 && timer.end > date
    }

    private func isScheduled(_ timer: ReceiverTimer, at date: Date) -> Bool {
        !timer.disabled && !timer.justPlay && !timer.cancelled && !timer.dontSave
            && timer.recordingType == "normal" && timer.pipZap != 1 && (0...1).contains(timer.state)
            && timer.begin > date && timer.end > date
    }

    @discardableResult
    func load(using client: OpenWebifClient?, directory: String? = nil) async -> Bool {
        guard let client else { reset(); error = "Kein Receiver ausgewählt."; return false }
        if source != client.profile { reset(); source = client.profile }
        let token = UUID(); generation = token; isLoading = true; error = nil
        defer { if token == generation { isLoading = false } }
        do {
            let page = try await client.recordings(directory: directory)
            guard token == generation, !Task.isCancelled else { return false }
            var seen = Set<String>()
            recordings = page.recordings.filter { seen.insert($0.id).inserted }.sorted {
                if $0.begin != $1.begin { return ($0.begin ?? .distantPast) > ($1.begin ?? .distantPast) }
                return $0.title.localizedCompare($1.title) == .orderedAscending
            }
            directories = page.directories.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            currentDirectory = page.currentDirectory
            if selectedRecording == nil && !recordings.contains(where: { "recording:\($0.id)" == selectedID }) { selectedID = overviewItems.first?.id }
            return true
        } catch is CancellationError { return false }
        catch {
            guard token == generation, !Task.isCancelled else { return false }
            self.error = error.localizedDescription; return false
        }
    }

    func loadTimers(using client: OpenWebifClient?) async {
        guard let client else { timerGeneration = UUID(); timers = []; timerError = nil; isLoadingTimers = false; return }
        if source != client.profile { reset(); source = client.profile }
        let token = UUID(); timerGeneration = token; isLoadingTimers = true; timerError = nil
        defer { if token == timerGeneration { isLoadingTimers = false } }
        do {
            let values = try await client.timers()
            guard token == timerGeneration, !Task.isCancelled, client.profile == source else { return }
            timers = values.sorted { $0.begin < $1.begin }
        } catch is CancellationError { return }
        catch {
            guard token == timerGeneration, !Task.isCancelled, client.profile == source else { return }
            timers = []; timerError = error.localizedDescription
        }
    }

    func loadStorage(using client: OpenWebifClient?) async {
        guard let client else {
            storageGeneration = UUID(); storage = []; storageError = nil; isLoadingStorage = false
            return
        }
        if source != client.profile { reset(); source = client.profile }
        let token = UUID(); storageGeneration = token; isLoadingStorage = true; storageError = nil
        defer { if token == storageGeneration { isLoadingStorage = false } }
        do {
            let result = try await client.storageInfo()
            guard token == storageGeneration, !Task.isCancelled, client.profile == source else { return }
            storage = result
        } catch is CancellationError { return }
        catch {
            guard token == storageGeneration, !Task.isCancelled, client.profile == source else { return }
            storage = []; storageError = error.localizedDescription
        }
    }

    func open(_ directory: ReceiverRecordingDirectory, using client: OpenWebifClient?) async {
        let previous = currentDirectory ?? ""
        if await load(using: client, directory: directory.path) { history.append(previous); searchText = "" }
    }

    func goBack(using client: OpenWebifClient?) async {
        guard let previous = history.last else { return }
        if await load(using: client, directory: previous.isEmpty ? nil : previous) { history.removeLast(); searchText = "" }
    }

    func openRoot(using client: OpenWebifClient?) async {
        if await load(using: client) { history = []; searchText = "" }
    }

    func play(_ recording: ReceiverRecording, fromBeginning: Bool = false, using client: OpenWebifClient?, settings: SettingsStore, onStart: () -> Void) async {
        guard let client, client.profile == source, recordings.contains(where: { $0.id == recording.id }) else { return }
        let token = generation
        do {
            let url = try await client.recordingURL(for: recording)
            guard token == generation, !Task.isCancelled, client.profile == source else { return }
            let password = try settings.credentials.availablePassword(for: client.profile.id)
            onStart(); stopPlayback()
            let slot = PlaybackSlot()
            player = slot; playingTitle = recording.title; error = nil
            activeRecording = recording; activeReceiverID = client.profile.id
            playbackGeneration = UUID()
            slot.volume = 1; slot.isMuted = false
            slot.playRecording(url: url, channel: Channel(id: recording.id, name: recording.title),
                               username: client.profile.username, password: password)
            savedProgress = fromBeginning ? nil : checkpoint(for: recording, receiverID: client.profile.id)?.seconds
            startProgressTracking(slot: slot, recording: recording, receiverID: client.profile.id)
            if let savedProgress, !fromBeginning { restorePosition(savedProgress, duration: checkpoint(for: recording, receiverID: client.profile.id)?.duration, slot: slot) }
            else { removeCheckpoint(for: recording, receiverID: client.profile.id) }
        } catch { self.error = error.localizedDescription }
    }

    private func restorePosition(_ seconds: TimeInterval, duration: TimeInterval?, slot: PlaybackSlot) {
        restoreTask?.cancel()
        let token = playbackGeneration
        restoreTask = Task { @MainActor [weak self, weak slot] in
            let deadline = ContinuousClock.now + .seconds(8)
            while !Task.isCancelled && ContinuousClock.now < deadline {
                guard let self, let slot, self.playbackGeneration == token, self.player === slot else { return }
                if slot.canSeekRecording {
                    let actualDuration = slot.recordingDuration ?? duration
                    guard let actualDuration, actualDuration.isFinite, actualDuration > 0 else { return }
                    let position = min(max(0, seconds), max(0, actualDuration - 1))
                    slot.seekRecording(to: position / actualDuration)
                    self.savedProgress = position
                    return
                }
                do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
            }
        }
    }

    private func startProgressTracking(slot: PlaybackSlot, recording: ReceiverRecording, receiverID: UUID) {
        progressTask?.cancel()
        let token = playbackGeneration
        progressTask = Task { @MainActor [weak self, weak slot] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(10)) } catch { return }
                guard let self, let slot, self.playbackGeneration == token, self.player === slot else { return }
                self.captureProgress(slot: slot, recording: recording, receiverID: receiverID)
            }
        }
    }

    private func captureProgress(slot: PlaybackSlot, recording: ReceiverRecording, receiverID: UUID, force: Bool = false) {
        if slot.status == .idle {
            removeCheckpoint(for: recording, receiverID: receiverID)
            savedProgress = nil
            return
        }
        guard force || slot.status == .playing else { return }
        guard slot.isRecordingPlayback, let duration = slot.recordingDuration,
              duration.isFinite, duration > 0 else { return }
        let seconds = slot.recordingProgress * duration
        guard seconds.isFinite, seconds >= 0 else { return }
        if duration - seconds <= 15 {
            removeCheckpoint(for: recording, receiverID: receiverID)
            savedProgress = nil
        } else if seconds > 2 {
            guard let checkpoint = RecordingPlaybackCheckpoint(receiverID: receiverID, recordingID: recording.id,
                                                               seconds: seconds, duration: duration) else { return }
            checkpoints[checkpoint.id] = checkpoint
            savedProgress = seconds
            persistCheckpoints()
        }
    }

    private func checkpoint(for recording: ReceiverRecording, receiverID: UUID) -> RecordingPlaybackCheckpoint? {
        let key = "\(receiverID.uuidString)|\(recording.id)"
        guard let value = checkpoints[key], value.isResumable else { return nil }
        return value
    }

    private func removeCheckpoint(for recording: ReceiverRecording, receiverID: UUID) {
        let key = "\(receiverID.uuidString)|\(recording.id)"
        guard checkpoints.removeValue(forKey: key) != nil else { return }
        persistCheckpoints()
    }

    private func persistCheckpoints() {
        guard canPersistProgress, let progressFile else { return }
        do {
            try FileManager.default.createDirectory(at: progressFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            var entries = checkpoints.values.sorted { $0.updatedAt > $1.updatedAt }
                .prefix(Self.maximumCheckpointCount).map { $0 }
            var data = try encoder.encode(entries)
            while data.count > Self.maximumCheckpointFileBytes, !entries.isEmpty {
                entries.removeLast()
                data = try encoder.encode(entries)
            }
            guard !entries.isEmpty || checkpoints.isEmpty else { throw CocoaError(.fileWriteOutOfSpace) }
            checkpoints = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            try data.write(to: progressFile, options: .atomic)
            progressError = nil
        } catch { progressError = "Der Wiedergabefortschritt konnte nicht gespeichert werden." }
    }

    func stopPlayback() {
        if let player, let recording = activeRecording, let receiverID = activeReceiverID {
            captureProgress(slot: player, recording: recording, receiverID: receiverID, force: true)
        }
        playbackGeneration = UUID(); progressTask?.cancel(); progressTask = nil
        restoreTask?.cancel(); restoreTask = nil
        player?.stop(); player = nil; playingTitle = nil
        activeRecording = nil; activeReceiverID = nil; savedProgress = nil
    }

    func reset() {
        generation = UUID(); storageGeneration = UUID(); timerGeneration = UUID(); stopPlayback(); source = nil
        recordings = []; directories = []; currentDirectory = nil
        storage = []; storageError = nil; isLoadingStorage = false
        timers = []; timerError = nil; isLoadingTimers = false
        selectedID = nil; searchText = ""; history = []; error = nil; isLoading = false
    }
}
