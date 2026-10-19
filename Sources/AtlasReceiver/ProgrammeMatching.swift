import Foundation
import AtlasCore

public enum ProgrammeMatching {
    public static func preview(_ draft: ReceiverAutoTimerDraft, programmes: [Programme], allowedChannels: Set<String>, calendar: Calendar = .current) -> [Programme] {
        guard draft.enabled, !draft.match.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        var seen = Set<String>()
        return programmes.filter { event in
            guard allowedChannels.contains(event.channelID), event.title.localizedCaseInsensitiveContains(draft.match), seen.insert(event.id).inserted else { return false }
            if !draft.weekdays.isEmpty {
                let weekday = (calendar.component(.weekday, from: event.start) + 5) % 7 + 1
                guard draft.weekdays.contains(weekday) else { return false }
            }
            if let begin = minute(draft.beginTime), let end = minute(draft.endTime) {
                let time = calendar.component(.hour, from: event.start) * 60 + calendar.component(.minute, from: event.start)
                return begin <= end ? time >= begin && time <= end : time >= begin || time <= end
            }
            return true
        }.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
    }

    public static func alternatives(to draft: ReceiverTimerDraft, in programmes: [Programme], after date: Date) -> [Programme] {
        let title = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return [] }
        var seen = Set<String>()
        return programmes.filter {
            $0.start > date && ($0.end <= draft.begin || $0.start >= draft.end)
                && $0.title.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(title) == .orderedSame
                && seen.insert($0.id).inserted
        }.sorted { $0.start < $1.start }
    }

    private static func minute(_ value: String?) -> Int? {
        guard let value else { return nil }
        let parts = value.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else { return nil }
        return parts[0] * 60 + parts[1]
    }
}

public struct ReceiverTimerConflict: Error, LocalizedError, Sendable, Equatable {
    public let timers: [ReceiverTimer]
    public var errorDescription: String? { "Der Receiver meldet einen Timerkonflikt. Die betroffenen Timer sind unten aufgeführt." }
    public init(timers: [ReceiverTimer]) { self.timers = timers }
}
