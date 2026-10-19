import Foundation
import Testing
import AtlasCore
@testable import AtlasReceiver

@Suite("Receiver timer matching")
struct ReceiverTimerMatchingTests {
    private let start: Int64 = 1_900_000_000
    private var programme: Programme {
        Programme(id: "event-1", channelID: "1:0:1:ABC", title: "News", summary: "",
                  start: Date(timeIntervalSince1970: TimeInterval(start)),
                  end: Date(timeIntervalSince1970: TimeInterval(start + 1800)))
    }

    @Test func fullEventCoverageMatchesAndAllowsPadding() {
        let timer = makeTimer(begin: start - 300, end: start + 2100, service: "1:0:1:abc")
        #expect(ReceiverTimerMatcher.matchingTimer(for: programme, in: [timer]) == timer)
    }

    @Test func partialOverlapAndNeighbouringProgrammeDoNotMatch() {
        let startsLate = makeTimer(begin: start + 60, end: start + 2100)
        let endsEarly = makeTimer(begin: start - 300, end: start + 1799)
        #expect(ReceiverTimerMatcher.matchingTimer(for: programme, in: [startsLate]) == nil)
        #expect(ReceiverTimerMatcher.matchingTimer(for: programme, in: [endsEarly]) == nil)
    }

    @Test func disabledZapCancelledAndUnknownTimersDoNotMatch() {
        let disabled = makeTimer(overrides: ["disabled": 1])
        let zap = makeTimer(overrides: ["justplay": 1])
        let cancelled = makeTimer(overrides: ["cancelled": 1])
        let completed = makeTimer(overrides: ["state": 3])
        let unknown = makeTimer(overrides: ["recordingtype": "unknown"])
        for timer in [disabled, zap, cancelled, completed, unknown] {
            #expect(ReceiverTimerMatcher.matchingTimer(for: programme, in: [timer]) == nil)
        }
    }

    @Test func zapBeforeRecordingStillCountsAsRecording() {
        let timer = makeTimer(overrides: ["always_zap": 1])
        #expect(ReceiverTimerMatcher.matchingTimer(for: programme, in: [timer]) == timer)
    }

    @Test func differentServiceAndRepeatedTimersDoNotMatch() {
        let otherService = makeTimer(service: "1:0:1:DEF")
        let repeated = makeTimer(overrides: ["repeated": 127])
        #expect(ReceiverTimerMatcher.matchingTimer(for: programme, in: [otherService]) == nil)
        #expect(ReceiverTimerMatcher.matchingTimer(for: programme, in: [repeated]) == nil)
    }

    @Test func duplicateTimersStillMarkTheProgrammeAsScheduled() {
        let first = makeTimer()
        let second = makeTimer(begin: start - 120, end: start + 2000)
        #expect(ReceiverTimerMatcher.matchingTimer(for: programme, in: [first, second]) == first)
    }

    @Test func distinguishesScheduledPreparingAndRunningReceiverStates() {
        let now = programme.start.addingTimeInterval(120)
        #expect(ReceiverTimerMatcher.recordingState(for: programme, in: [makeTimer()], at: now) == .scheduled)
        #expect(ReceiverTimerMatcher.recordingState(for: programme, in: [makeTimer(overrides: ["state": 1])], at: now) == .scheduled)
        #expect(ReceiverTimerMatcher.recordingState(for: programme, in: [makeTimer(overrides: ["state": 2])], at: now) == .recording)
        #expect(ReceiverTimerMatcher.recordingState(for: programme, in: [makeTimer(overrides: ["state": 3])], at: now) == nil)
    }

    @Test func runningRecordingWinsOverDuplicateScheduledTimer() {
        #expect(ReceiverTimerMatcher.recordingState(for: programme, in: [makeTimer(), makeTimer(overrides: ["state": 2])], at: programme.start.addingTimeInterval(120)) == .recording)
    }

    @Test func runningPartialRecordingMatchesOnlyTheCurrentProgramme() {
        let timer = makeTimer(begin: start + 60, end: start + 600, overrides: ["state": 2])
        #expect(ReceiverTimerMatcher.recordingState(for: programme, in: [timer], at: programme.start.addingTimeInterval(120)) == .recording)
        #expect(ReceiverTimerMatcher.recordingState(for: programme, in: [timer], at: programme.start.addingTimeInterval(601)) == nil)
        let next = Programme(id: "next", channelID: programme.channelID, title: "Next", summary: "", start: programme.end, end: programme.end.addingTimeInterval(1800))
        #expect(ReceiverTimerMatcher.recordingState(for: next, in: [timer], at: programme.start.addingTimeInterval(120)) == nil)
        let wrongService = makeTimer(service: "1:0:1:DEF", overrides: ["state": 2])
        #expect(ReceiverTimerMatcher.recordingState(for: programme, in: [wrongService], at: programme.start.addingTimeInterval(120)) == nil)
    }

    @Test func staleRunningStateIsNotShownAfterTheRecordingEnds() {
        let timer = makeTimer(overrides: ["state": 2])
        #expect(ReceiverTimerMatcher.recordingState(for: programme, in: [timer], at: programme.end) == nil)
        let disabled = makeTimer(overrides: ["state": 2, "disabled": 1])
        #expect(ReceiverTimerMatcher.recordingState(for: programme, in: [disabled], at: programme.start.addingTimeInterval(120)) == nil)
    }

    private func makeTimer(begin: Int64? = nil, end: Int64? = nil, service: String = "1:0:1:ABC",
                           overrides: [String: Any] = [:]) -> ReceiverTimer {
        var row: [String: Any] = [
            "serviceref": service, "servicename": "News", "eit": 42, "name": "News", "description": "",
            "begin": begin ?? start, "end": end ?? (start + 1800),
            "disabled": 0, "justplay": 0, "afterevent": 3, "dirname": "/movie/", "tags": "",
            "repeated": 0, "state": 0, "dontsave": 0, "cancelled": false,
            "vpsplugin_enabled": false, "vpsplugin_overwrite": false, "vpsplugin_time": -1,
            "always_zap": -1, "pipzap": -1, "isAutoTimer": 0, "allow_duplicate": 1,
            "autoadjust": -1, "recordingtype": "normal", "ice_timer_id": -1
        ]
        overrides.forEach { row[$0.key] = $0.value }
        guard let timer = ReceiverTimer.decode(row) else { fatalError("Synthetic timer fixture must decode") }
        return timer
    }
}
