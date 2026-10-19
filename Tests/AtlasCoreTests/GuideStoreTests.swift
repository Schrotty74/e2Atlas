#if !SWIFT_PACKAGE
import Foundation
import Testing
import AtlasCore
import AtlasReceiver

@Suite("Guide store query state")
@MainActor
struct GuideStoreTests {
    @Test func changingBouquetDropsOldChannelsFromSearch() async {
        let store = GuideStore()
        let oldBouquet = [Channel(id: "old-1", name: "Old News"), Channel(id: "old-2", name: "Old Sport")]
        let newBouquet = [Channel(id: "new-1", name: "New News")]
        store.setDemoEvents(channels: oldBouquet)
        #expect(!store.searchResults.isEmpty)
        #expect(store.searchResults.allSatisfy { $0.end > store.timelineRange.start && $0.start < store.timelineRange.end })

        // A nil client models a receiver change while the new bouquet is selected.
        await store.load(channels: newBouquet, client: nil)

        #expect(store.searchResults.isEmpty)
    }

    @Test func freshRevisionTracksNetworkResponsesButNotCacheReuse() async {
        let channel = Channel(id: "channel", name: "Synthetic")
        let store = GuideStore(fetchProgrammes: { _, channel, interval in
            [programme(id: "fresh", channelID: channel.id, start: interval.start.addingTimeInterval(3600))]
        })
        let receiver = client()
        await store.loadTimeline(channels: [channel], client: receiver)
        let revision = store.freshRevision
        #expect(revision > 0)
        #expect(store.freshReceiverID == receiver.profile.id)
        #expect(store.freshProgrammes.map(\.id) == ["fresh"])
        await store.loadTimeline(channels: [channel], client: receiver)
        #expect(store.freshRevision == revision)
        store.reset()
        #expect(store.freshReceiverID == nil)
        #expect(store.freshProgrammes.isEmpty)
    }

    @Test func refreshLoadsEventsWhenTheStoreIsEmpty() async {
        let expected = programme(id: "new", channelID: "channel")
        let store = GuideStore(fetchProgrammes: { _, channel, _ in [programme(id: expected.id, channelID: channel.id)] })
        let channel = Channel(id: "channel", name: "Synthetic")

        await store.refresh(channels: [channel], client: client())

        #expect(store.events[channel.id] == [expected])
        #expect(store.errors[channel.id] == nil)
    }

    @Test func failedRefreshKeepsExistingEventsAndSelection() async {
        let store = GuideStore(fetchProgrammes: { _, _, _ in throw AtlasFailure.unreachable })
        let channel = Channel(id: "channel", name: "Synthetic")
        store.setDemoEvents(channels: [channel])
        let oldEvents = store.events[channel.id]
        let oldSelection = store.selection

        await store.refresh(channels: [channel], client: client())

        #expect(store.events[channel.id] == oldEvents)
        #expect(store.selection == oldSelection)
        #expect(store.errors[channel.id] != nil)
    }

    @Test func overlappingRefreshIsSkipped() async {
        let gate = ProgrammeFetchGate()
        let store = GuideStore(fetchProgrammes: { _, channel, _ in
            await gate.enter()
            return [programme(id: "loaded", channelID: channel.id)]
        })
        let channel = Channel(id: "channel", name: "Synthetic")
        let first = Task { await store.refresh(channels: [channel], client: client()) }
        await gate.waitUntilEntered()

        await store.refresh(channels: [channel], client: client())
        #expect(await gate.calls == 1)

        await gate.release()
        await first.value
        #expect(store.events[channel.id]?.map(\.id) == ["loaded"])
    }

    @Test func resetDiscardsAnInFlightRefreshResponse() async {
        let gate = ProgrammeFetchGate()
        let store = GuideStore(fetchProgrammes: { _, channel, _ in
            await gate.enter()
            return [programme(id: "stale", channelID: channel.id)]
        })
        let channel = Channel(id: "channel", name: "Synthetic")
        let refresh = Task { await store.refresh(channels: [channel], client: client()) }
        await gate.waitUntilEntered()

        store.reset()
        await gate.release()
        await refresh.value

        #expect(store.events.isEmpty)
        #expect(store.selection == nil)
        #expect(!store.isLoading)
    }

    @Test func timelineLoadsSevenDaysOnceIncludingEmptyChannels() async {
        let log = GuideRequestLog()
        let store = GuideStore(fetchProgrammes: { _, channel, interval in
            await log.record(channelID: channel.id, interval: interval)
            guard channel.id != "empty" else { return [] }
            return [programme(id: "one", channelID: channel.id, start: interval.start.addingTimeInterval(3600))]
        })
        let channels = [Channel(id: "filled", name: "Filled"), Channel(id: "empty", name: "Empty")]
        let receiver = client()
        let range = store.timelineRange

        await store.loadTimeline(channels: channels, client: receiver)
        let initialRequests = await log.requests
        #expect(initialRequests.count == 2)
        #expect(initialRequests.allSatisfy { $0.interval.start == range.start && $0.interval.end == range.end })
        #expect(Set(initialRequests.map(\.channelID)) == Set(["filled", "empty"]))
        #expect(store.events["empty"] == [])

        store.window.start = range.start.addingTimeInterval(3 * 86400)
        store.window.duration = .six
        await store.loadTimeline(channels: channels, client: receiver)

        let finalRequests = await log.requests
        #expect(finalRequests.count == 2)
        #expect(store.timelineRange == range)
    }

    @Test func searchAndOtherAiringsUseTheLoadedSevenDayTimeline() async {
        let store = GuideStore(fetchProgrammes: { _, channel, interval in
            let offset: TimeInterval = channel.id == "channel" ? 4 * 86400 : 5 * 86400
            let start = interval.start.addingTimeInterval(offset)
            return [Programme(id: "late-\(channel.id)", channelID: channel.id,
                              title: "Late Week News", summary: "", start: start, end: start.addingTimeInterval(3600))]
        })
        let channels = [Channel(id: "channel", name: "Synthetic"), Channel(id: "channel-2", name: "Synthetic 2")]
        let range = store.timelineRange
        store.window = GuideWindow(start: range.start, duration: .two)

        await store.loadTimeline(channels: channels, client: client())
        store.searchText = "Late Week"

        #expect(store.searchResults.map(\.id) == ["late-channel", "late-channel-2"])
        #expect(store.otherAirings(of: store.searchResults[0]).map(\.id) == ["late-channel-2"])
    }

    @Test func diskCacheSurvivesRestartButReceiverAddressIsPartOfItsKey() async {
        let directory = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = GuideRequestLog()
        let profileID = UUID()
        let channel = Channel(id: "channel", name: "Synthetic")
        let profile = ReceiverProfile(id: profileID, name: "Synthetic", address: "first.example")
        let firstStore = GuideStore(fetchProgrammes: { _, channel, interval in
            await log.record(channelID: channel.id, interval: interval)
            return [programme(id: "cached", channelID: channel.id, start: interval.start.addingTimeInterval(3600))]
        })
        let range = firstStore.timelineRange
        await firstStore.loadTimeline(channels: [channel], client: client(profile: profile), cacheDirectory: directory)

        let restartedStore = GuideStore(fetchProgrammes: { _, channel, interval in
            await log.record(channelID: channel.id, interval: interval)
            return []
        })
        restartedStore.timelineRange = range
        await restartedStore.loadTimeline(channels: [channel], client: client(profile: profile), cacheDirectory: directory)
        #expect(restartedStore.events[channel.id]?.map(\.id) == ["cached"])

        let changedAddress = ReceiverProfile(id: profileID, name: "Synthetic", address: "second.example")
        let changedStore = GuideStore(fetchProgrammes: { _, channel, interval in
            await log.record(channelID: channel.id, interval: interval)
            return [programme(id: "fresh", channelID: channel.id, start: interval.start.addingTimeInterval(7200))]
        })
        changedStore.timelineRange = range
        await changedStore.loadTimeline(channels: [channel], client: client(profile: changedAddress), cacheDirectory: directory)

        let requests = await log.requests
        #expect(requests.count == 2)
        #expect(changedStore.events[channel.id]?.map(\.id) == ["fresh"])
    }

    @Test func visibleRefreshReplacesOnlyItsIntervalAndKeepsOtherDays() async {
        let directory = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = GuideRequestLog()
        let store = GuideStore(fetchProgrammes: { _, channel, interval in
            let call = await log.record(channelID: channel.id, interval: interval)
            if call == 1 {
                return [
                    programme(id: "day-one", channelID: channel.id, start: interval.start.addingTimeInterval(3600)),
                    programme(id: "old-section", channelID: channel.id, start: interval.start.addingTimeInterval(3 * 86400 + 11 * 3600)),
                    programme(id: "day-five", channelID: channel.id, start: interval.start.addingTimeInterval(5 * 86400 + 3600))
                ]
            }
            return [programme(id: "new-section", channelID: channel.id, start: interval.start.addingTimeInterval(60))]
        })
        let channel = Channel(id: "channel", name: "Synthetic")
        let receiver = client()
        await store.loadTimeline(channels: [channel], client: receiver, cacheDirectory: directory)
        store.window = GuideWindow(start: store.timelineRange.start.addingTimeInterval(3 * 86400 + 10 * 3600), duration: .four)

        await store.refresh(channels: [channel], client: receiver)

        let ids = Set((store.events[channel.id] ?? []).map(\.id))
        #expect(ids == Set(["day-one", "new-section", "day-five"]))
        let requests = await log.requests
        #expect(requests.count == 2)
        #expect(requests[1].interval.start == store.window.start)
        #expect(requests[1].interval.end == store.window.end)
    }

    @Test func timelineCacheInvalidationFetchesFreshData() async {
        let log = GuideRequestLog()
        let store = GuideStore(fetchProgrammes: { _, channel, interval in
            let call = await log.record(channelID: channel.id, interval: interval)
            return [programme(id: "version-\(call)", channelID: channel.id, start: interval.start.addingTimeInterval(3600))]
        })
        let channel = Channel(id: "channel", name: "Synthetic")
        let receiver = client()

        await store.loadTimeline(channels: [channel], client: receiver)
        store.invalidateTimelineCache()
        await store.loadTimeline(channels: [channel], client: receiver)

        let requests = await log.requests
        #expect(requests.count == 2)
        #expect(store.events[channel.id]?.map(\.id) == ["version-2"])
    }

    private func client() -> OpenWebifClient {
        OpenWebifClient(profile: ReceiverProfile(name: "Synthetic", address: "receiver.example"), password: "")
    }

    private func client(profile: ReceiverProfile) -> OpenWebifClient {
        OpenWebifClient(profile: profile, password: "")
    }

    private func temporaryCacheDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("GuideStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    nonisolated private func programme(id: String, channelID: String) -> Programme {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        return Programme(id: id, channelID: channelID, title: "Synthetic programme", summary: "", start: start, end: start.addingTimeInterval(3600))
    }

    nonisolated private func programme(id: String, channelID: String, start: Date) -> Programme {
        Programme(id: id, channelID: channelID, title: "Synthetic programme", summary: "", start: start, end: start.addingTimeInterval(3600))
    }
}

private actor GuideRequestLog {
    struct Request: Sendable {
        let channelID: String
        let interval: DateInterval
    }

    private(set) var requests: [Request] = []

    func record(channelID: String, interval: DateInterval) -> Int {
        requests.append(Request(channelID: channelID, interval: interval))
        return requests.count
    }
}

private actor ProgrammeFetchGate {
    private(set) var calls = 0
    private var entered: CheckedContinuation<Void, Never>?
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []
    private var isReleased = false

    func enter() async {
        calls += 1
        entered?.resume()
        entered = nil
        if isReleased { return }
        await withCheckedContinuation { releaseWaiters.append($0) }
    }

    func waitUntilEntered() async {
        if calls > 0 { return }
        await withCheckedContinuation { entered = $0 }
    }

    func release() {
        isReleased = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}
#endif
