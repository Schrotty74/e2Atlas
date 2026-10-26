import Foundation


public struct ProgrammeReminder: Codable, Identifiable, Sendable, Equatable {
    public let receiverID: UUID
    public let programme: Programme
    public let channelName: String
    public let minutesBefore: Int
    public var id: String { "e2atlas.reminder.\(receiverID.uuidString).\(programme.id)" }
    public var fireDate: Date { programme.start.addingTimeInterval(-Double(minutesBefore) * 60) }
    public init(receiverID: UUID, programme: Programme, channelName: String, minutesBefore: Int) {
        self.receiverID = receiverID; self.programme = programme
        self.channelName = channelName; self.minutesBefore = minutesBefore
    }
    public func isValid(after date: Date) -> Bool {
        (1...60).contains(minutesBefore) && !programme.id.isEmpty && !programme.title.isEmpty
            && programme.start.timeIntervalSince1970.isFinite && programme.end > programme.start && fireDate > date
    }
}

/// Finds a shifted EPG entry only when its channel/title match and its start is
/// the unique nearest candidate inside a deliberately narrow correction window.
public enum ProgrammeReminderMatcher {
    public static func match(_ reminder: ProgrammeReminder, in programmes: [Programme], maximumShift: TimeInterval = 6 * 60 * 60) -> Programme? {
        guard maximumShift > 0 else { return nil }
        let oldSummary = reminder.programme.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !oldSummary.isEmpty else { return nil }
        let oldDuration = reminder.programme.end.timeIntervalSince(reminder.programme.start)
        let durationTolerance = max(5 * 60, oldDuration * 0.2)
        let candidates = programmes.filter {
            $0.channelID == reminder.programme.channelID
                && $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    .localizedCompare(reminder.programme.title.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
                && !$0.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && $0.summary.trimmingCharacters(in: .whitespacesAndNewlines).localizedCompare(oldSummary) == .orderedSame
                && abs($0.start.timeIntervalSince(reminder.programme.start)) <= maximumShift
                && $0.end > $0.start
                && abs($0.end.timeIntervalSince($0.start) - oldDuration) <= durationTolerance
        }.sorted {
            abs($0.start.timeIntervalSince(reminder.programme.start)) < abs($1.start.timeIntervalSince(reminder.programme.start))
        }
        guard let nearest = candidates.first else { return nil }
        if candidates.count > 1 {
            let firstDistance = abs(nearest.start.timeIntervalSince(reminder.programme.start))
            let secondDistance = abs(candidates[1].start.timeIntervalSince(reminder.programme.start))
            guard firstDistance < secondDistance else { return nil }
        }
        return nearest
    }
}
