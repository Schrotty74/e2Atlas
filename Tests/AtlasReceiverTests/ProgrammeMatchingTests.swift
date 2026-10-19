import Foundation
import Testing
import AtlasCore
@testable import AtlasReceiver

@Suite("Loaded programme matching")
struct ProgrammeMatchingTests {
    private var calendar: Calendar { var value = Calendar(identifier: .gregorian); value.timeZone = TimeZone(secondsFromGMT: 0)!; return value }
    private func event(_ id: String, hour: Int, minute: Int = 0, channel: String = "one", title: String = "World News") -> Programme {
        let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: hour, minute: minute))!
        return Programme(id: id, channelID: channel, title: title, summary: "Synthetic", start: start, end: start.addingTimeInterval(1800))
    }
    @Test func previewCombinesTitleChannelWeekdayAndTimeWindow() {
        var draft = ReceiverAutoTimerDraft(title: "News", match: "news", target: .service("one"), beginTime: "19:00", endTime: "22:00", weekdays: [1])
        let programmes = [event("yes", hour: 20), event("early", hour: 18), event("wrong", hour: 20, channel: "two"), event("title", hour: 20, title: "Sport")]
        #expect(ProgrammeMatching.preview(draft, programmes: programmes, allowedChannels: ["one"], calendar: calendar).map(\.id) == ["yes"])
        draft.weekdays = [2]
        #expect(ProgrammeMatching.preview(draft, programmes: programmes, allowedChannels: ["one"], calendar: calendar).isEmpty)
        draft.weekdays = []; draft.enabled = false
        #expect(ProgrammeMatching.preview(draft, programmes: programmes, allowedChannels: ["one"], calendar: calendar).isEmpty)
    }
    @Test func previewSupportsOvernightWindowAndAvoidsDuplicateRows() {
        let draft = ReceiverAutoTimerDraft(title: "News", match: "News", target: .bouquet("bouquet"), beginTime: "23:00", endTime: "01:00")
        let late = event("late", hour: 23, minute: 30)
        #expect(ProgrammeMatching.preview(draft, programmes: [late, late, event("morning", hour: 0), event("noon", hour: 12)], allowedChannels: ["one"], calendar: calendar).map(\.id) == ["morning", "late"])
    }
    @Test func alternativesRequireSameTitleAndFutureNonoverlappingBroadcast() {
        let original = event("original", hour: 18)
        let draft = ReceiverTimerDraft(serviceReference: "one", begin: original.start, end: original.end, name: original.title)
        let later = event("later", hour: 21, channel: "two")
        #expect(ProgrammeMatching.alternatives(to: draft, in: [original, later, later, event("other", hour: 22, title: "Sport"), event("old", hour: 16)], after: original.start).map(\.id) == ["later"])
    }
}
