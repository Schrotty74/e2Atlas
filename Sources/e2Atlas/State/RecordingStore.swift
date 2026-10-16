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
    private(set) var message: String?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var choosingDestination = false

    func start(channel: Channel, profile: ReceiverProfile, client: OpenWebifClient, settings: SettingsStore) {
        guard !isActive, !choosingDestination else { return }
        choosingDestination = true
        let panel = NSSavePanel()
        panel.title = "Stream aufnehmen"
        panel.prompt = "Aufnehmen"
        panel.allowedContentTypes = [UTType(filenameExtension: "ts") ?? .data]
        panel.canCreateDirectories = true
        panel.directoryURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
        let name = channel.name.components(separatedBy: CharacterSet.alphanumerics.union(.init(charactersIn: " -_" )).inverted).joined(separator: "_")
        let stamp = Date().formatted(.iso8601.year().month().day().dateSeparator(.dash).time(includingFractionalSeconds: false).timeSeparator(.omitted))
        panel.nameFieldStringValue = "\(name.isEmpty ? "e2Atlas" : name)-\(stamp).ts"
        panel.begin { [weak self] response in
            guard let self else { return }
            self.choosingDestination = false
            guard response == .OK, let destination = panel.url else { return }
            // The transfer also creates exclusively, protecting against races after this check.
            guard !FileManager.default.fileExists(atPath: destination.path) else {
                self.message = "Die Datei existiert bereits. Wähle einen anderen Dateinamen."
                return
            }
            let password: String
            do { password = try settings.credentials.availablePassword(for: profile.id) }
            catch { self.message = "Die Zugangsdaten sind nicht verfügbar."; return }
            self.begin(channel: channel, profile: profile, client: client, password: password, destination: destination)
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
        isActive = true
        isStopping = false
        task = Task { [weak self] in
            do {
                let url = try await client.streamURL(for: channel)
                let count = try await StreamRecorder.record(url: url, to: destination, username: profile.username, password: password) { [weak self] count in
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == token, self.isActive else { return }
                        self.bytes = count
                    }
                }
                guard let self, self.generation == token else { return }
                self.bytes = count
                self.message = "Aufnahme gespeichert: \(destination.lastPathComponent)"
            } catch {
                guard let self, self.generation == token else { return }
                self.message = "Die Aufnahme konnte nicht abgeschlossen werden. Bereits gespeicherte Streamdaten bleiben erhalten."
            }
            guard let self, self.generation == token else { return }
            self.isActive = false
            self.isStopping = false
            self.task = nil
        }
    }

    func stop() {
        guard isActive else { return }
        isStopping = true
        task?.cancel()
    }

    func reveal() {
        guard let destination, FileManager.default.fileExists(atPath: destination.path) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([destination])
    }

    var canReveal: Bool { destination.map { FileManager.default.fileExists(atPath: $0.path) } ?? false }
    func dismissMessage() { message = nil; destination = nil }
}
