import Foundation
import Observation
import CryptoKit
import AtlasCore
import AtlasReceiver

private struct GuideCacheSnapshot: Codable, Sendable {
    var version = 1
    let receiverKey: String
    let start: Date
    let end: Date
    var savedAt: Date
    var events: [String: [Programme]]

    func matches(receiverKey: String, range: GuideTimelineRange) -> Bool {
        version == 1 && self.receiverKey == receiverKey && start == range.start && end == range.end
            && savedAt.timeIntervalSinceNow <= 300 && savedAt.timeIntervalSinceNow > -7 * 86400
            && events.count <= 2000 && events.values.reduce(0, { $0 + $1.count }) <= 200_000
            && events.allSatisfy { id, values in values.allSatisfy {
                $0.channelID == id && $0.start.timeIntervalSince1970.isFinite && $0.end.timeIntervalSince1970.isFinite
                    && $0.end > $0.start && $0.end > start && $0.start < end
            } }
    }
}

/// Cache IO stays off the main actor and is ordered per guide store.
private actor GuideCacheStorage {
    private let maximumBytes = 64 * 1024 * 1024

    func read(_ url: URL) -> GuideCacheSnapshot? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= maximumBytes, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(GuideCacheSnapshot.self, from: data)
    }

    func write(_ snapshot: GuideCacheSnapshot, to url: URL) {
        guard let data = try? JSONEncoder().encode(snapshot), data.count <= maximumBytes else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch { /* An optional cache must not prevent displaying received EPG. */ }
    }
}

@MainActor @Observable
final class GuideStore {
    var window = GuideWindow(start: Date(), duration: .two)
    var timelineRange = GuideTimelineRange(containing: Date())
    private(set) var events: [String: [Programme]] = [:]
    private(set) var errors: [String: String] = [:]
    private(set) var isLoading = false
    var selection: Programme?
    var searchText = ""
    private(set) var freshRevision = 0
    private(set) var freshProgrammes: [Programme] = []
    private(set) var freshReceiverID: UUID?
    private var loadedTimelineEvents: [Programme] {
        events.values.flatMap { $0 }.filter { $0.end > timelineRange.start && $0.start < timelineRange.end }
    }
    var searchResults: [Programme] { Programme.search(searchText, in: loadedTimelineEvents) }
    func otherAirings(of event: Programme) -> [Programme] {
        loadedTimelineEvents.filter { $0.id != event.id && $0.start >= Date() && $0.title.localizedCompare(event.title) == .orderedSame }.sorted { $0.start < $1.start }
    }
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private let fetchProgrammes: @Sendable (OpenWebifClient, Channel, DateInterval) async throws -> [Programme]
    @ObservationIgnored private let cacheStorage = GuideCacheStorage()
    @ObservationIgnored private var timelineCache: GuideCacheSnapshot?
    @ObservationIgnored private var cacheURL: URL?
    @ObservationIgnored private var timelineNeedsReload = false

    init(fetchProgrammes: @escaping @Sendable (OpenWebifClient, Channel, DateInterval) async throws -> [Programme] = {
        try await $0.programmes(channel: $1, from: $2.start, to: $2.end)
    }) { self.fetchProgrammes = fetchProgrammes }

    func invalidateTimelineCache() { timelineNeedsReload = true }

    /// Load the seven-day range once; moving the viewport never calls this method.
    func loadTimeline(channels: [Channel], client: OpenWebifClient?, cacheDirectory: URL? = nil) async {
        guard let client else { reset(); return }
        let token = UUID(); generation = token; isLoading = true
        defer { if token == generation { isLoading = false } }
        let range = timelineRange
        let key = receiverKey(client.profile)
        let file = cacheDirectory?.appendingPathComponent(client.profile.id.uuidString + ".json")
        if timelineCache?.matches(receiverKey: key, range: range) != true {
            let stored = if let file { await cacheStorage.read(file) } else { nil as GuideCacheSnapshot? }
            guard token == generation, !Task.isCancelled else { return }
            timelineCache = stored?.matches(receiverKey: key, range: range) == true ? stored :
                GuideCacheSnapshot(receiverKey: key, start: range.start, end: range.end, savedAt: Date(), events: [:])
        }
        cacheURL = file
        let ids = Set(channels.map(\.id))
        events = (timelineCache?.events ?? [:]).filter { ids.contains($0.key) }
        errors = errors.filter { ids.contains($0.key) }
        if let selected = selection { selection = events[selected.channelID]?.first { $0.id == selected.id } }
        let missing = channels.filter { timelineNeedsReload || timelineCache?.events[$0.id] == nil }
        timelineNeedsReload = false
        guard !missing.isEmpty else { return }
        await fetch(channels: missing, client: client, query: DateInterval(start: range.start, end: range.end),
                    token: token, mergeWindow: false, updateCache: true)
        guard token == generation, !Task.isCancelled else { return }
        await persistCache()
    }

    func refresh(channels: [Channel], client: OpenWebifClient?) async {
        guard !isLoading, let client, !channels.isEmpty, !Task.isCancelled else { return }
        if timelineCache?.matches(receiverKey: receiverKey(client.profile), range: timelineRange) == true {
            let token = UUID(); generation = token; isLoading = true
            defer { if token == generation { isLoading = false } }
            // Update only the visible interval, retaining all other cached days.
            await fetch(channels: channels, client: client, query: DateInterval(start: window.start, end: window.end),
                        token: token, mergeWindow: true, updateCache: true)
            guard token == generation, !Task.isCancelled else { return }
            await persistCache()
        } else {
            await load(channels: channels, client: client, preservingEvents: true)
        }
    }

    func load(channels: [Channel], client: OpenWebifClient?, preservingEvents: Bool = false) async {
        let token = UUID(); generation = token
        if !preservingEvents { events = [:]; errors = [:]; selection = nil }
        guard let client else { isLoading = false; return }
        isLoading = true
        await fetch(channels: channels, client: client, query: DateInterval(start: window.start, end: window.end),
                    token: token, mergeWindow: false, updateCache: false)
        if token == generation { isLoading = false }
    }

    private func fetch(channels: [Channel], client: OpenWebifClient, query: DateInterval,
                       token: UUID, mergeWindow: Bool, updateCache: Bool) async {
        let fetch = fetchProgrammes
        var fresh: [Programme] = []
        // Bounded batches avoid flooding small receiver web servers.
        for offset in stride(from: 0, to: channels.count, by: 4) {
            if Task.isCancelled || token != generation { break }
            let batch = Array(channels[offset..<min(offset + 4, channels.count)])
            await withTaskGroup(of: (String, [Programme]?, String?).self) { group in
                for channel in batch {
                    group.addTask {
                        do { return (channel.id, try await fetch(client, channel, query), nil) }
                        catch is CancellationError { return (channel.id, nil, nil) }
                        catch { return (channel.id, nil, "Programmdaten konnten nicht geladen werden.") }
                    }
                }
                for await (id, values, message) in group {
                    guard token == generation, !Task.isCancelled else { continue }
                    if let values {
                        fresh += values
                        let incomingIDs = Set(values.map(\.id))
                        var combined = mergeWindow ? (events[id] ?? []).filter {
                            !incomingIDs.contains($0.id) && ($0.end <= query.start || $0.start >= query.end)
                        } : []
                        combined += values
                        if updateCache, let cache = timelineCache {
                            combined = combined.filter { $0.end > cache.start && $0.start < cache.end }
                        }
                        var seen = Set<String>()
                        combined = combined.filter { seen.insert($0.id).inserted }.sorted { $0.start < $1.start }
                        events[id] = combined; errors[id] = nil
                        if updateCache { timelineCache?.events[id] = combined }
                        if selection?.channelID == id { selection = combined.first { $0.id == selection?.id } }
                    }
                    if let message { errors[id] = message }
                }
            }
        }
        if token == generation, !Task.isCancelled {
            freshProgrammes = fresh; freshReceiverID = client.profile.id; freshRevision += 1
        }
    }

    private func persistCache() async {
        guard var snapshot = timelineCache, let cacheURL else { return }
        snapshot.savedAt = Date(); timelineCache = snapshot
        await cacheStorage.write(snapshot, to: cacheURL)
    }

    private func receiverKey(_ profile: ReceiverProfile) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return SHA256.hash(data: (try? encoder.encode(profile)) ?? Data()).map { String(format: "%02x", $0) }.joined()
    }

    func reset() {
        generation = UUID(); events = [:]; errors = [:]; selection = nil; isLoading = false
        timelineCache = nil; cacheURL = nil; timelineNeedsReload = false
        freshProgrammes = []; freshReceiverID = nil
    }
    func setDemoEvents(channels: [Channel]) {
        let titles = ["Unterwegs in den Alpen", "Weite Welt", "Stadtgeschichten", "Die Farben der Erde", "Wissen am Abend", "Sport am Abend"]
        let start = Calendar.current.startOfDay(for: Date())
        for (row, channel) in channels.enumerated() {
            events[channel.id] = (0..<24).map { hour in
                let begin = start.addingTimeInterval(Double(hour) * 3600)
                return Programme(id: "\(channel.id)-\(hour)", channelID: channel.id, title: titles[(row + hour) % titles.count], summary: "Synthetische Programmdaten für die Vorschau von e2Atlas.", start: begin, end: begin.addingTimeInterval(3600))
            }
        }
        selection = channels.first.flatMap { events[$0.id]?.first { $0.end > Date() } }
    }
}
