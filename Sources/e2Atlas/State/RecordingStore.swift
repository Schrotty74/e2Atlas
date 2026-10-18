import AppKit
import AtlasCore
import AtlasReceiver
import AtlasRecording
import Observation
import UniformTypeIdentifiers

/// Owns one local recording independently of the playback slots.
@MainActor @Observable
final class RecordingStore {
    private(set) var isActive = false
    private(set) var isStopping = false
    private(set) var channelName = ""
    private(set) var channelID: String?
    private(set) var receiverID: UUID?
    private(set) var startedAt = Date()
    private(set) var bytes: Int64 = 0
    private(set) var destination: URL?
    private(set) var message: LocalizedStringResource?
    private(set) var optionsError: String?
    private(set) var recordingDurationMinutes: Int
    private(set) var standardFolder: URL?

    @ObservationIgnored private let optionsURL: URL?
    @ObservationIgnored private var folderBookmark: Data?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var durationTask: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var choosingDestination = false
    @ObservationIgnored private var lowDiskWarningSent = false
    @ObservationIgnored private var lastDiskCheck = Date.distantPast
    @ObservationIgnored private var hasFolderAccess = false
    @ObservationIgnored private var accessedFolder: URL?
    @ObservationIgnored private var canSaveOptions = true

    private static let minimumFreeBytes: Int64 = 1_073_741_824
    private static let diskCheckInterval: TimeInterval = 30

    init(paths: AppPaths? = try? AppPaths()) {
        optionsURL = paths?.support.appendingPathComponent("recording-options.json")
        var options = RecordingOptions()
        if let optionsURL {
            do {
                if FileManager.default.fileExists(atPath: optionsURL.path) {
                    options = try JSONDecoder().decode(RecordingOptions.self, from: Data(contentsOf: optionsURL))
                    guard (0...1440).contains(options.durationMinutes) else { throw CocoaError(.fileReadCorruptFile) }
                }
            } catch {
                canSaveOptions = false
                optionsError = "Die gespeicherten Aufnahmeoptionen sind ungültig. Die Datei bleibt erhalten; Änderungen werden nicht gespeichert."
            }
        } else {
            canSaveOptions = false
            optionsError = "Der Speicherort für Aufnahmeoptionen ist nicht verfügbar."
        }
        recordingDurationMinutes = max(0, min(1440, options.durationMinutes))
        folderBookmark = options.folderBookmark
        standardFolder = Self.resolveFolder(options.folderBookmark)
    }

    func setRecordingDurationMinutes(_ value: Int) {
        guard canSaveOptions, !isActive, !choosingDestination else { return }
        recordingDurationMinutes = max(0, min(1440, value))
        persistOptions()
    }

    func chooseStandardFolder(language: AppLanguage = .system) {
        guard canSaveOptions, !isActive, !choosingDestination else { return }
        choosingDestination = true
        let panel = NSOpenPanel()
        panel.title = language.localized("Aufnahmeordner auswählen")
        panel.prompt = language.localized("Ordner verwenden")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard let self else { return }
            self.choosingDestination = false
            guard response == .OK, let url = panel.url else { return }
            do {
                let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                self.folderBookmark = bookmark
                self.standardFolder = url
                self.persistOptions()
            } catch {
                self.message = "Der Aufnahmeordner konnte nicht gespeichert werden."
            }
        }
    }

    func resetStandardFolder() {
        guard canSaveOptions, !isActive, !choosingDestination else { return }
        folderBookmark = nil
        standardFolder = nil
        persistOptions()
    }

    func start(channel: Channel, profile: ReceiverProfile, client: OpenWebifClient, settings: SettingsStore,
               programmeTitle: String? = nil) {
        guard !isActive, !choosingDestination else { return }
        choosingDestination = true
        let request = UUID()
        generation = request
        let panel = NSSavePanel()
        panel.title = settings.language.localized("Stream aufnehmen")
        panel.prompt = settings.language.localized("Aufnehmen")
        panel.allowedContentTypes = [UTType(filenameExtension: "ts") ?? .data]
        panel.canCreateDirectories = true
        panel.directoryURL = standardFolder ?? FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
        if let standardFolder, folderBookmark != nil {
            hasFolderAccess = standardFolder.startAccessingSecurityScopedResource()
            if hasFolderAccess { accessedFolder = standardFolder }
            else { panel.directoryURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first }
        }
        let stamp = Date().formatted(.iso8601.year().month().day().dateSeparator(.dash).time(includingFractionalSeconds: false).timeSeparator(.omitted))
        panel.nameFieldStringValue = "\(StreamRecorder.filenameStem(channelName: channel.name, programmeTitle: programmeTitle))-\(stamp).ts"
        panel.begin { [weak self] response in
            guard let self else { return }
            guard self.generation == request else { return }
            guard response == .OK, let destination = panel.url else {
                self.choosingDestination = false
                self.releaseFolderAccess()
                return
            }
            Task { @MainActor in
                guard !FileManager.default.fileExists(atPath: destination.path) else {
                    self.message = "Die Datei existiert bereits. Wähle einen anderen Dateinamen."
                    self.choosingDestination = false
                    self.releaseFolderAccess()
                    return
                }
                let folder = destination.deletingLastPathComponent()
                let free = await Task.detached(priority: .utility) { availableBytes(at: folder) }.value
                guard self.generation == request else { return }
                if let free, free < Self.minimumFreeBytes {
                    self.message = "Auf dem gewählten Laufwerk ist weniger als 1 GB verfügbar. Es wurde keine Aufnahme gestartet."
                    self.choosingDestination = false
                    self.releaseFolderAccess()
                    return
                }
                let password: String
                do { password = try settings.credentials.availablePassword(for: profile.id) }
                catch {
                    self.message = "Die Zugangsdaten sind nicht verfügbar."
                    self.choosingDestination = false
                    self.releaseFolderAccess()
                    return
                }
                self.choosingDestination = false
                self.begin(channel: channel, profile: profile, client: client, password: password, destination: destination)
            }
        }
    }

    private func begin(channel: Channel, profile: ReceiverProfile, client: OpenWebifClient, password: String, destination: URL) {
        let token = UUID()
        generation = token
        self.destination = destination
        channelName = channel.name
        channelID = channel.id
        receiverID = profile.id
        startedAt = Date()
        bytes = 0
        message = nil
        lowDiskWarningSent = false
        lastDiskCheck = Date()
        isActive = true
        isStopping = false

        if recordingDurationMinutes > 0 {
            let limit = recordingDurationMinutes
            durationTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(limit * 60)) } catch { return }
                guard let self, self.generation == token, self.isActive else { return }
                self.message = "Aufnahmedauer erreicht. Die Datei wird gespeichert."
                self.stop()
            }
        }

        task = Task { [weak self] in
            do {
                let url = try await client.streamURL(for: channel)
                let count = try await StreamRecorder.record(url: url, to: destination, username: profile.username, password: password) { [weak self] count in
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == token, self.isActive else { return }
                        self.bytes = count
                        self.checkDiskSpaceIfDue(at: destination, token: token)
                    }
                }
                guard let self, self.generation == token else { return }
                self.bytes = count
                if self.message == nil { self.message = "Aufnahme gespeichert: \(destination.lastPathComponent)" }
            } catch {
                guard let self, self.generation == token else { return }
                if self.message == nil { self.message = "Die Aufnahme konnte nicht abgeschlossen werden. Bereits gespeicherte Streamdaten bleiben erhalten." }
            }
            guard let self, self.generation == token else { return }
            self.durationTask?.cancel()
            self.durationTask = nil
            self.releaseFolderAccess()
            self.isActive = false
            self.isStopping = false
            self.task = nil
        }
    }

    private func checkDiskSpaceIfDue(at destination: URL, token: UUID) {
        guard Date().timeIntervalSince(lastDiskCheck) >= Self.diskCheckInterval else { return }
        lastDiskCheck = Date()
        let folder = destination.deletingLastPathComponent()
        // Volume metadata can block on network or removable volumes; keep it off the UI actor.
        Task.detached(priority: .utility) { [weak self] in
            let free = availableBytes(at: folder)
            await MainActor.run {
                guard let self, self.generation == token, self.isActive,
                      let free, free < Self.minimumFreeBytes, !self.lowDiskWarningSent else { return }
                self.lowDiskWarningSent = true
                self.message = "Wenig Speicherplatz. Die Aufnahme wird beendet; bereits empfangene Streamdaten werden gespeichert."
                self.stop()
            }
        }
    }

    private func releaseFolderAccess() {
        if hasFolderAccess { accessedFolder?.stopAccessingSecurityScopedResource() }
        accessedFolder = nil
        hasFolderAccess = false
    }

    private static func resolveFolder(_ bookmark: Data?) -> URL? {
        guard let bookmark else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale), !stale else { return nil }
        return url
    }

    private func persistOptions() {
        guard canSaveOptions, let optionsURL else { return }
        do {
            try FileManager.default.createDirectory(at: optionsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let value = RecordingOptions(durationMinutes: recordingDurationMinutes, folderBookmark: folderBookmark)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(value).write(to: optionsURL, options: .atomic)
            message = nil
        } catch { optionsError = "Die Aufnahmeoptionen konnten nicht gespeichert werden." }
    }

    func stop() {
        if choosingDestination {
            generation = UUID()
            choosingDestination = false
            releaseFolderAccess()
        }
        guard isActive else { return }
        isStopping = true
        durationTask?.cancel()
        task?.cancel()
    }

    func reveal() {
        guard let destination, FileManager.default.fileExists(atPath: destination.path) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([destination])
    }

    var canReveal: Bool { destination.map { FileManager.default.fileExists(atPath: $0.path) } ?? false }
    var canEditOptions: Bool { canSaveOptions && !isActive && !choosingDestination }
    func dismissMessage() { message = nil; destination = nil }
}

private func availableBytes(at url: URL) -> Int64? {
    guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]) else { return nil }
    return values.volumeAvailableCapacityForImportantUsage
}

private struct RecordingOptions: Codable {
    var durationMinutes = 0
    var folderBookmark: Data?
}
