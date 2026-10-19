import Foundation
import Testing
@testable import AtlasCore

@Suite("Programme reminders")
struct ProgrammeReminderTests {
    @Test func fireDateIdentityAndPersistence() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let event = Programme(id: "event", channelID: "channel", title: "Synthetic", summary: "", start: now.addingTimeInterval(3600), end: now.addingTimeInterval(7200))
        let receiver = UUID()
        let value = ProgrammeReminder(receiverID: receiver, programme: event, channelName: "Example", minutesBefore: 5)
        #expect(value.fireDate == now.addingTimeInterval(3300))
        #expect(value.isValid(after: now))
        #expect(!value.isValid(after: value.fireDate))
        #expect(try JSONDecoder().decode(ProgrammeReminder.self, from: JSONEncoder().encode(value)) == value)
        let replacement = ProgrammeReminder(receiverID: receiver, programme: event, channelName: "Example", minutesBefore: 10)
        #expect(replacement.id == value.id)
        #expect(ProgrammeReminder(receiverID: UUID(), programme: event, channelName: "Example", minutesBefore: 5).id != value.id)
    }
    @Test(arguments: [0, -1, 61]) func rejectsInvalidLeadTimes(_ minutes: Int) {
        let now = Date()
        let event = Programme(id: "event", channelID: "channel", title: "Synthetic", summary: "", start: now.addingTimeInterval(86400), end: now.addingTimeInterval(90000))
        #expect(!ProgrammeReminder(receiverID: UUID(), programme: event, channelName: "Example", minutesBefore: minutes).isValid(after: now))
    }

    @Test func matcherUsesOnlyUniqueNearbySameChannelTitle() {
        let start = Date(timeIntervalSince1970: 1_900_000_000)
        func event(_ id: String, _ channel: String, _ title: String, _ offset: TimeInterval,
                   summary: String = "episode-1", duration: TimeInterval = 1800) -> Programme {
            Programme(id: id, channelID: channel, title: title, summary: summary,
                      start: start.addingTimeInterval(offset), end: start.addingTimeInterval(offset + duration))
        }
        let original = ProgrammeReminder(receiverID: UUID(), programme: event("old", "c1", "News", 0), channelName: "One", minutesBefore: 5)
        #expect(ProgrammeReminderMatcher.match(original, in: [event("other", "c2", "News", 60)]) == nil)
        #expect(ProgrammeReminderMatcher.match(original, in: [event("other", "c1", "Movie", 60)]) == nil)
        #expect(ProgrammeReminderMatcher.match(original, in: [event("far", "c1", "News", 7 * 3600)]) == nil)
        #expect(ProgrammeReminderMatcher.match(original, in: [event("near", "c1", "News", 300)])?.id == "near")
        #expect(ProgrammeReminderMatcher.match(original, in: [event("neighbor", "c1", "News", 300, summary: "episode-2")]) == nil)
        #expect(ProgrammeReminderMatcher.match(original, in: [event("duration", "c1", "News", 300, duration: 3600)]) == nil)
        #expect(ProgrammeReminderMatcher.match(original, in: [event("left", "c1", "News", -300), event("right", "c1", "News", 300)]) == nil)
    }
}
