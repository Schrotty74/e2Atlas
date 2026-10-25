#if !SWIFT_PACKAGE
import Foundation
import Testing
import AtlasCore
import AtlasReceiver

@Suite("Now and next programme cache")
@MainActor
struct NowNextCacheTests {
    @Test("reuses fetched channels across repeated view returns and bouquet switches")
    func retainsChannelsAcrossBouquetSwitches() async {
        let log = NowNextRequestLog()
        let channelA = Channel(id: "a", name: "A")
        let channelB = Channel(id: "b", name: "B")
        let store = GuideStore(fetchProgrammes: { _, channel, interval in
            await log.record(channel.id)
            return Self.coveringSchedule(channelID: channel.id, from: interval.start)
        })
        let receiver = Self.client()
        let at = store.timelineRange.start.addingTimeInterval(3_600)

        await store.ensureNowNext(channels: [channelA], client: receiver, at: at)
        await store.ensureNowNext(channels: [channelA], client: receiver, at: at.addingTimeInterval(10))
        await store.ensureNowNext(channels: [channelB], client: receiver, at: at)
        await store.ensureNowNext(channels: [channelA], client: receiver, at: at.addingTimeInterval(20))

        #expect(await log.channelIDs == ["a", "b"])
        #expect(store.events["a"]?.first?.id == "a-current")
        #expect(store.events["b"]?.first?.id == "b-current")
    }

    @Test("advances cached schedules and refreshes only the sender without a successor")
    func refreshesOnlyMissingSuccessor() async {
        let log = NowNextRequestLog()
        let channelA = Channel(id: "a", name: "A")
        let channelB = Channel(id: "b", name: "B")
        let store = GuideStore(fetchProgrammes: { _, channel, interval in
            await log.record(channel.id)
            if channel.id == "a" {
                if await log.count(for: "a") == 1 {
                    return [
                        Self.programme("a-first", channelID: "a", from: interval.start.addingTimeInterval(-60), duration: 120),
                        Self.programme("a-second", channelID: "a", from: interval.start.addingTimeInterval(60), duration: 60),
                        Self.programme("a-third", channelID: "a", from: interval.start.addingTimeInterval(120), duration: 60)
                    ]
                }
                return [
                    Self.programme("a-third", channelID: "a", from: interval.start, duration: 60),
                    Self.programme("a-fourth", channelID: "a", from: interval.start.addingTimeInterval(60), duration: 60)
                ]
            }
            return [
                Self.programme("b-current", channelID: "b", from: interval.start.addingTimeInterval(-60), duration: 240),
                Self.programme("b-next", channelID: "b", from: interval.start.addingTimeInterval(180), duration: 60)
            ]
        })
        let receiver = Self.client()
        let at = store.timelineRange.start.addingTimeInterval(3_600)

        await store.ensureNowNext(channels: [channelA, channelB], client: receiver, at: at)
        let initialA = NowNextProgramme.selection(from: store.events["a"] ?? [], at: at)
        #expect(initialA.current?.id == "a-first")
        #expect(initialA.next?.id == "a-second")
        let atSecond = at.addingTimeInterval(60)
        let secondA = NowNextProgramme.selection(from: store.events["a"] ?? [], at: atSecond)
        #expect(secondA.current?.id == "a-second")
        #expect(secondA.next?.id == "a-third")
        await store.ensureNowNext(channels: [channelA, channelB], client: receiver, at: atSecond)
        #expect(await log.channelIDs.count == 2)

        let atThirdEnd = at.addingTimeInterval(120)
        let due = store.nextNowNextCheck(channels: [channelA, channelB], after: atThirdEnd.addingTimeInterval(-1))
        #expect(due == atThirdEnd)
        let before = NowNextProgramme.selection(from: store.events["b"] ?? [], at: atThirdEnd)
        #expect(before.current?.id == "b-current")
        #expect(before.next?.id == "b-next")

        let lastA = NowNextProgramme.selection(from: store.events["a"] ?? [], at: atThirdEnd)
        #expect(lastA.current?.id == "a-third")
        #expect(lastA.next == nil)
        await store.ensureNowNext(channels: [channelA, channelB], client: receiver, at: atThirdEnd)

        #expect(await log.channelIDs.filter { $0 == "a" }.count == 2)
        #expect(await log.channelIDs.filter { $0 == "b" }.count == 1)
        #expect(store.events["a"]?.contains(where: { $0.id == "a-fourth" }) == true)
        #expect(store.events["b"]?.map(\.id) == ["b-current", "b-next"])
    }

    @Test("reuses validated in-memory and disk weekly timelines without another request")
    func reusesWeeklyTimelineCaches() async {
        let directory = Self.temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = NowNextRequestLog()
        let channel = Channel(id: "cached", name: "Cached")
        let profile = ReceiverProfile(name: "Synthetic", address: "receiver.example")
        let receiver = Self.client(profile: profile)
        let timeline = GuideStore(fetchProgrammes: { _, channel, interval in
            await log.record(channel.id)
            return Self.coveringSchedule(channelID: channel.id, from: interval.start.addingTimeInterval(3_600))
        })
        await timeline.loadTimeline(channels: [channel], client: receiver, cacheDirectory: directory)
        let at = timeline.timelineRange.start.addingTimeInterval(3_600)

        let memoryStore = GuideStore(fetchProgrammes: { _, _, _ in
            Issue.record("In-memory timeline reuse unexpectedly fetched programmes")
            return []
        })
        await memoryStore.ensureNowNext(channels: [channel], client: receiver, timeline: timeline, at: at)

        let diskStore = GuideStore(fetchProgrammes: { _, _, _ in
            Issue.record("Disk timeline reuse unexpectedly fetched programmes")
            return []
        })
        await diskStore.ensureNowNext(channels: [channel], client: receiver, cacheDirectory: directory, at: at)

        #expect(await log.channelIDs == ["cached"])
        #expect(memoryStore.events["cached"]?.first?.id == "cached-current")
        #expect(diskStore.events["cached"]?.first?.id == "cached-current")
        #expect(memoryStore.freshRevision == 0)
        #expect(diskStore.freshRevision == 0)

        let explicitRefresh = GuideStore(fetchProgrammes: { _, channel, interval in
            Self.coveringSchedule(channelID: channel.id, from: interval.start, prefix: "manual")
        })
        explicitRefresh.invalidateNowNext()
        await explicitRefresh.ensureNowNext(channels: [channel], client: receiver, timeline: timeline, at: at)
        #expect(explicitRefresh.freshRevision == 1)
        #expect(explicitRefresh.events[channel.id]?.first?.id == "manual-current")
    }

    @Test("discards old now data and rejects weekly cache for a changed receiver address")
    func rejectsCacheAfterReceiverAddressChange() async {
        let directory = Self.temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = NowNextRequestLog()
        let channel = Channel(id: "channel", name: "Channel")
        let profileID = UUID()
        let oldProfile = ReceiverProfile(id: profileID, name: "Synthetic", address: "old.example")
        let oldReceiver = Self.client(profile: oldProfile)
        let timeline = GuideStore(fetchProgrammes: { _, channel, interval in
            await log.record(channel.id)
            return Self.coveringSchedule(channelID: channel.id, from: interval.start.addingTimeInterval(3_600))
        })
        await timeline.loadTimeline(channels: [channel], client: oldReceiver, cacheDirectory: directory)
        let at = timeline.timelineRange.start.addingTimeInterval(3_600)

        let store = GuideStore(fetchProgrammes: { receiver, channel, interval in
            await log.record(channel.id)
            return Self.coveringSchedule(channelID: channel.id, from: interval.start,
                                         prefix: receiver.profile.address == "new.example" ? "new" : nil)
        })
        await store.ensureNowNext(channels: [channel], client: oldReceiver, at: at)
        #expect(store.events["channel"]?.first?.id == "channel-current")

        let changedProfile = ReceiverProfile(id: profileID, name: "Synthetic", address: "new.example")
        await store.ensureNowNext(channels: [channel], client: Self.client(profile: changedProfile),
                                  timeline: timeline, cacheDirectory: directory, at: at)

        #expect(await log.channelIDs == ["channel", "channel", "channel"])
        #expect(store.events["channel"]?.first?.id == "new-current")
    }

    @Test("empty and failed responses respect the five-minute retry cooldown")
    func retriesEmptyAndFailedResponsesAfterCooldown() async {
        let log = NowNextRequestLog()
        let empty = Channel(id: "empty", name: "Empty")
        let failed = Channel(id: "failed", name: "Failed")
        let store = GuideStore(fetchProgrammes: { _, channel, _ in
            await log.record(channel.id)
            if channel.id == "failed" { throw AtlasFailure.unreachable }
            return []
        })
        let receiver = Self.client()
        let at = store.timelineRange.start.addingTimeInterval(3_600)

        await store.ensureNowNext(channels: [empty, failed], client: receiver, at: at)
        await store.ensureNowNext(channels: [empty, failed], client: receiver, at: at.addingTimeInterval(299))
        #expect(await log.channelIDs.count == 2)
        #expect(store.nextNowNextCheck(channels: [empty, failed], after: at.addingTimeInterval(299)) == at.addingTimeInterval(300))

        await store.ensureNowNext(channels: [empty, failed], client: receiver, at: at.addingTimeInterval(300))

        #expect(await log.channelIDs.count == 4)
        #expect(store.errors["failed"] != nil)
    }

    @Test("forced refresh failure preserves previously loaded programmes")
    func forcedRefreshFailurePreservesData() async {
        let log = NowNextRequestLog()
        let channel = Channel(id: "channel", name: "Channel")
        let store = GuideStore(fetchProgrammes: { _, channel, interval in
            if await log.record(channel.id) == 1 {
                return Self.coveringSchedule(channelID: channel.id, from: interval.start)
            }
            throw AtlasFailure.unreachable
        })
        let receiver = Self.client()
        let at = store.timelineRange.start.addingTimeInterval(3_600)

        await store.ensureNowNext(channels: [channel], client: receiver, at: at)
        let previous = store.events[channel.id]
        await store.ensureNowNext(channels: [channel], client: receiver, at: at.addingTimeInterval(1), force: true)

        #expect(store.events[channel.id] == previous)
        #expect(store.errors[channel.id] != nil)
        #expect(await log.channelIDs == ["channel", "channel"])
    }

    @Test("reset rejects a late now and next response")
    func resetDiscardsLateResponse() async {
        let gate = NowNextFetchGate()
        let store = GuideStore(fetchProgrammes: { _, channel, interval in
            await gate.enter()
            return Self.coveringSchedule(channelID: channel.id, from: interval.start, prefix: "stale")
        })
        let channel = Channel(id: "channel", name: "Channel")
        let task = Task {
            await store.ensureNowNext(channels: [channel], client: Self.client(),
                                      at: store.timelineRange.start.addingTimeInterval(3_600))
        }
        await gate.waitUntilEntered()

        store.reset()
        await gate.release()
        await task.value

        #expect(store.events.isEmpty)
        #expect(store.errors.isEmpty)
        #expect(!store.isLoading)
        #expect(await gate.calls == 1)
    }

    nonisolated private static func programme(_ id: String, channelID: String, from start: Date,
                                               duration: TimeInterval) -> Programme {
        Programme(id: id, channelID: channelID, title: id, summary: "", start: start,
                  end: start.addingTimeInterval(duration))
    }

    nonisolated private static func coveringSchedule(channelID: String, from start: Date,
                                                      prefix: String? = nil) -> [Programme] {
        let name = prefix ?? channelID
        return [
            programme("\(name)-current", channelID: channelID, from: start.addingTimeInterval(-60), duration: 120),
            programme("\(name)-next", channelID: channelID, from: start.addingTimeInterval(60), duration: 120)
        ]
    }

    nonisolated private static func client(profile: ReceiverProfile = ReceiverProfile(name: "Synthetic", address: "receiver.example")) -> OpenWebifClient {
        OpenWebifClient(profile: profile, password: "")
    }

    nonisolated private static func temporaryCacheDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("NowNextCacheTests-\(UUID().uuidString)", isDirectory: true)
    }
}

private actor NowNextRequestLog {
    private(set) var channelIDs: [String] = []

    @discardableResult func record(_ channelID: String) -> Int {
        channelIDs.append(channelID)
        return channelIDs.count
    }

    func count(for channelID: String) -> Int {
        channelIDs.filter { $0 == channelID }.count
    }
}

private actor NowNextFetchGate {
    private(set) var calls = 0
    private var entered: CheckedContinuation<Void, Never>?
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var released = false

    func enter() async {
        calls += 1
        entered?.resume()
        entered = nil
        if released { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func waitUntilEntered() async {
        if calls > 0 { return }
        await withCheckedContinuation { entered = $0 }
    }

    func release() {
        released = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}
#endif
