#if !SWIFT_PACKAGE
import Foundation
import Testing
import AtlasCore
@testable import AtlasPlayback
import AtlasReceiver
import VLCKit

@Suite("Playback store preset state", .serialized)
@MainActor
struct PlaybackStoreTests {
    private func makeReceiver() -> ReceiverProfile {
        ReceiverProfile(name: "Synthetic loopback", address: "127.0.0.1", streamPort: 9)
    }

    private func channel(_ suffix: String) -> Channel {
        Channel(id: "1:0:1:\(suffix):0:0:0:0:0:0:", name: "Synthetic \(suffix)")
    }

    private func seedPlayingSlot(_ slot: PlaybackSlot, channel: Channel) {
        slot.play(url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("missing.ts"),
                  channel: channel, username: "", password: "")
        slot.updateVLCPlayback(state: .playing, displayedPictures: 1)
    }

    @Test func restoreAppliesPresetCountChannelsAndAudibleState() async {
        let receiver = makeReceiver()
        let store = PlaybackStore()
        store.restoreStartupTimeout = .zero
        defer { store.stopAll() }
        let first = channel("101")
        let third = channel("303")
        let preset = MultiviewPreset(name: "Evening", receiverID: receiver.id,
                                     channels: [first, nil, third], audibleIndex: 2,
                                     volume: 0.35, isMuted: false)

        await store.restore(preset, client: OpenWebifClient(profile: receiver, password: ""),
                            profile: receiver, password: "")

        #expect(store.isMultiview)
        #expect(store.visibleCount == 3)
        #expect(store.slots[0].channel == first)
        #expect(store.slots[1].channel == nil)
        #expect(store.slots[2].channel == third)
        #expect(store.audibleIndex == 2)
        #expect(store.volume == 0.35)
        #expect(!store.isAudioMuted)
        #expect(store.slots[2].isMuted == false)
        #expect(store.slots[0].isMuted)

        let muted = MultiviewPreset(name: "Muted", receiverID: receiver.id,
                                    channels: [first, nil], audibleIndex: 0,
                                    volume: 0.6, isMuted: true)
        await store.restore(muted, client: OpenWebifClient(profile: receiver, password: ""),
                            profile: receiver, password: "")
        #expect(store.visibleCount == 2)
        #expect(store.audibleIndex == 0)
        #expect(store.volume == 0.6)
        #expect(store.isAudioMuted)
        #expect(store.slots[0].isMuted)
        #expect(store.slots[1].isMuted)
    }

    @Test func restoreStartsAudibleStreamBeforeOtherPictures() async {
        let receiver = makeReceiver()
        let store = PlaybackStore()
        defer { store.stopAll() }
        let first = channel("101")
        let second = channel("202")
        let preset = MultiviewPreset(name: "Staged", receiverID: receiver.id,
                                     channels: [first, second], audibleIndex: 1,
                                     volume: 0.4, isMuted: false)
        let task = Task {
            await store.restore(preset, client: OpenWebifClient(profile: receiver, password: ""),
                                profile: receiver, password: "")
        }
        defer { task.cancel() }
        let deadline = ContinuousClock.now + .seconds(2)
        while store.slots[1].channel == nil, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(store.slots[1].channel == second)
        #expect(store.slots[0].channel == nil)
        #expect(store.audibleIndex == 1)
        #expect(!store.slots[1].isMuted)
        #expect(store.slots[1].volume == 0.4)
        // A delayed section notification must not cancel this same restore.
        store.setMultiview(true)
        store.slots[1].updateVLCPlayback(state: .buffering, displayedPictures: 1)
        await task.value
        #expect(store.slots[0].channel == first)
        #expect(store.slots[0].isMuted)
        store.stopAll()
        try? await Task.sleep(for: .milliseconds(300))
    }

    @Test func userStopCancelsStagedRestore() async {
        let receiver = makeReceiver()
        let store = PlaybackStore()
        defer { store.stopAll() }
        let preset = MultiviewPreset(name: "Cancel", receiverID: receiver.id,
                                     channels: [channel("101"), channel("202")], audibleIndex: 1,
                                     volume: 0.4, isMuted: false)
        let task = Task {
            await store.restore(preset, client: OpenWebifClient(profile: receiver, password: ""),
                                profile: receiver, password: "")
        }
        let deadline = ContinuousClock.now + .seconds(2)
        while store.slots[1].channel == nil, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(store.slots[1].channel != nil)
        store.stopAll()
        await task.value
        #expect(store.slots.allSatisfy { $0.channel == nil })
        try? await Task.sleep(for: .milliseconds(300))
    }

    @Test func invalidPresetLeavesCurrentPlaybackAndLayoutUntouched() async {
        let receiver = makeReceiver()
        let store = PlaybackStore()
        store.restoreStartupTimeout = .zero
        defer { store.stopAll() }
        store.setMultiview(true)
        store.setCount(2)
        let current = channel("777")
        seedPlayingSlot(store.slots[0], channel: current)
        let invalid = MultiviewPreset(name: "Invalid", receiverID: receiver.id,
                                      channels: [], audibleIndex: 0, volume: 0.2, isMuted: false)

        await store.restore(invalid, client: OpenWebifClient(profile: receiver, password: ""),
                            profile: receiver, password: "")

        #expect(store.isMultiview)
        #expect(store.visibleCount == 2)
        #expect(store.slots[0].channel == current)
        #expect(store.slots[0].status == .playing)
    }

    @Test func alreadyCancelledRestoreDoesNotReplaceCurrentState() async {
        let receiver = makeReceiver()
        let store = PlaybackStore()
        store.restoreStartupTimeout = .zero
        defer { store.stopAll() }
        let current = channel("888")
        seedPlayingSlot(store.slots[0], channel: current)
        let preset = MultiviewPreset(name: "Later", receiverID: receiver.id,
                                     channels: [channel("101"), channel("202")],
                                     audibleIndex: 1, volume: 0.4, isMuted: false)
        let task = Task {
            await store.restore(preset, client: OpenWebifClient(profile: receiver, password: ""),
                                profile: receiver, password: "")
        }
        task.cancel()
        await task.value

        #expect(store.slots[0].channel == current)
        #expect(store.slots[0].status == .playing)
        #expect(store.slots[1].channel == nil)
    }

    @Test func reducingCountMovesAudioOffHiddenSlot() async {
        let receiver = makeReceiver()
        let store = PlaybackStore()
        store.restoreStartupTimeout = .zero
        defer { store.stopAll() }
        let preset = MultiviewPreset(name: "Four", receiverID: receiver.id,
                                     channels: [channel("101"), channel("202"), channel("303"), channel("404")],
                                     audibleIndex: 3, volume: 0.5, isMuted: false)
        await store.restore(preset, client: OpenWebifClient(profile: receiver, password: ""),
                            profile: receiver, password: "")

        store.setCount(2)

        #expect(store.audibleIndex == 0)
        #expect(store.slots[0].isMuted == false)
        #expect(store.slots[2].channel == nil)
        #expect(store.slots[3].channel == nil)
    }
}
#endif
