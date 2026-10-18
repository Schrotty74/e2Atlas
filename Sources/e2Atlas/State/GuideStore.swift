import Foundation
import Observation
import AtlasCore
import AtlasReceiver

@MainActor @Observable
final class GuideStore {
    var window = GuideWindow(start: Date(), duration: .two)
    private(set) var events: [String: [Programme]] = [:]
    private(set) var errors: [String: String] = [:]
    private(set) var isLoading = false
    var selection: Programme?
    var searchText = ""
    private var windowEvents: [Programme] {
        events.values.flatMap { $0 }.filter { $0.end > window.start && $0.start < window.end }
    }
    var searchResults: [Programme] { Programme.search(searchText, in: windowEvents) }
    func otherAirings(of event: Programme) -> [Programme] {
        windowEvents.filter { $0.id != event.id && $0.start >= Date() && $0.title.localizedCompare(event.title) == .orderedSame }.sorted { $0.start < $1.start }
    }
    @ObservationIgnored private var generation = UUID()

    func load(channels: [Channel], client: OpenWebifClient?) async {
        let token = UUID(); generation = token
        events = [:]; errors = [:]; selection = nil
        guard let client else { isLoading = false; return }
        let query = window; isLoading = true
        // Bounded batches avoid flooding small receiver web servers.
        for offset in stride(from: 0, to: channels.count, by: 4) {
            if Task.isCancelled || token != generation { break }
            let batch = Array(channels[offset..<min(offset + 4, channels.count)])
            await withTaskGroup(of: (String, [Programme]?, String?).self) { group in
                for channel in batch {
                    group.addTask {
                        do { return (channel.id, try await client.programmes(channel: channel, from: query.start, to: query.end), nil) }
                        catch is CancellationError { return (channel.id, nil, nil) }
                        catch { return (channel.id, nil, "Programmdaten konnten nicht geladen werden.") }
                    }
                }
                for await (id, values, message) in group {
                    guard token == generation, !Task.isCancelled else { continue }
                    if let values { events[id] = values }
                    if let message { events[id] = []; errors[id] = message }
                }
            }
        }
        if token == generation { isLoading = false }
    }
    func reset() { generation = UUID(); events = [:]; errors = [:]; selection = nil; isLoading = false }
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
