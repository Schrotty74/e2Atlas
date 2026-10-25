import Foundation
import Testing
import AtlasCore

@Suite("Now and next programme selection")
struct NowNextProgrammeTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func programme(_ id: String, from: TimeInterval, to: TimeInterval) -> Programme {
        Programme(id: id, channelID: "channel", title: id, summary: "", start: start.addingTimeInterval(from), end: start.addingTimeInterval(to))
    }

    @Test("selects the covering and upcoming programmes from unsorted input")
    func unsortedInput() {
        let values = [programme("next", from: 120, to: 240), programme("current", from: 0, to: 120)]
        let result = NowNextProgramme.selection(from: values, at: start.addingTimeInterval(60))
        #expect(result.current?.id == "current")
        #expect(result.next?.id == "next")
    }

    @Test("treats a programme end as exclusive")
    func boundary() {
        let values = [programme("ended", from: 0, to: 60), programme("starting", from: 60, to: 120)]
        let result = NowNextProgramme.selection(from: values, at: start.addingTimeInterval(60))
        #expect(result.current?.id == "starting")
        #expect(result.next == nil)
    }

    @Test("reports a future event as next when the schedule has a gap")
    func gap() {
        let values = [programme("later", from: 180, to: 240)]
        let result = NowNextProgramme.selection(from: values, at: start.addingTimeInterval(60))
        #expect(result.current == nil)
        #expect(result.next?.id == "later")
    }

    @Test("ignores invalid intervals and returns empty when there is no future event")
    func invalidAndEmpty() {
        let values = [
            programme("invalid", from: 90, to: 30),
            programme("past", from: 0, to: 60),
            Programme(id: "infinite-start", channelID: "channel", title: "infinite-start", summary: "", start: Date(timeIntervalSince1970: .infinity), end: start.addingTimeInterval(300)),
            Programme(id: "infinite-end", channelID: "channel", title: "infinite-end", summary: "", start: start.addingTimeInterval(240), end: Date(timeIntervalSince1970: .infinity))
        ]
        let result = NowNextProgramme.selection(from: values, at: start.addingTimeInterval(120))
        #expect(result.current == nil)
        #expect(result.next == nil)
        #expect(NowNextProgramme.selection(from: [], at: start) == NowNextProgramme(current: nil, next: nil))
    }

    @Test("advances current and next at exact transitions across three programmes")
    func successiveProgrammes() {
        let values = [
            programme("third", from: 120, to: 180),
            programme("first", from: 0, to: 60),
            programme("second", from: 60, to: 120)
        ]

        #expect(NowNextProgramme.nextTransition(in: values, after: start.addingTimeInterval(30)) == start.addingTimeInterval(60))
        let atFirstEnd = NowNextProgramme.selection(from: values, at: start.addingTimeInterval(60))
        #expect(atFirstEnd.current?.id == "second")
        #expect(atFirstEnd.next?.id == "third")
        #expect(NowNextProgramme.nextTransition(in: values, after: start.addingTimeInterval(60)) == start.addingTimeInterval(120))
        let atSecondEnd = NowNextProgramme.selection(from: values, at: start.addingTimeInterval(120))
        #expect(atSecondEnd.current?.id == "third")
        #expect(atSecondEnd.next == nil)
        #expect(NowNextProgramme.nextTransition(in: values, after: start.addingTimeInterval(120)) == start.addingTimeInterval(180))
        #expect(NowNextProgramme.nextTransition(in: values, after: start.addingTimeInterval(180)) == nil)
    }

    @Test("returns the earliest boundary across valid programmes and gaps")
    func earliestBoundaryAcrossGap() {
        let values = [programme("later", from: 300, to: 360), programme("upcoming", from: 120, to: 180)]
        #expect(NowNextProgramme.nextTransition(in: values, after: start.addingTimeInterval(60)) == start.addingTimeInterval(120))
        #expect(NowNextProgramme.nextTransition(in: values, after: start.addingTimeInterval(150)) == start.addingTimeInterval(180))
        #expect(NowNextProgramme.nextTransition(in: values, after: start.addingTimeInterval(180)) == start.addingTimeInterval(300))
    }

    @Test("returns no transition for invalid, expired, or non-finite query dates")
    func invalidTransitionInputs() {
        let values = [
            programme("reversed", from: 180, to: 120),
            programme("expired", from: 0, to: 60),
            Programme(id: "nan", channelID: "channel", title: "nan", summary: "", start: Date(timeIntervalSince1970: .nan), end: start.addingTimeInterval(240))
        ]
        #expect(NowNextProgramme.nextTransition(in: values, after: start.addingTimeInterval(240)) == nil)
        #expect(NowNextProgramme.nextTransition(in: values, after: Date(timeIntervalSince1970: .infinity)) == nil)
    }
}
