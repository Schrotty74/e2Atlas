import Testing
import AtlasCore
@testable import AtlasPlayback

@Suite("Multiview presentation order")
@MainActor
struct PlaybackArrangementTests {
    @Test func swapPreservesPlayersAndMovesAudioAndSelectionWithTheirStreams() {
        let slots = (0..<4).map { _ in PlaybackSlot() }
        var arrangement = PlaybackArrangement(slots: slots)
        arrangement.targetIndex = 2
        arrangement.audibleIndex = 0
        slots[0].isMuted = false
        slots[0].volume = 0.35
        slots[2].isMuted = true
        slots[2].volume = 0.35
        arrangement.swapWithMain(2)
        #expect(arrangement.slots[0] === slots[2])
        #expect(arrangement.slots[2] === slots[0])
        #expect(arrangement.slots[1] === slots[1])
        #expect(arrangement.targetIndex == 0)
        #expect(arrangement.audibleIndex == 2)
        #expect(!arrangement.slots[2].isMuted)
        #expect(arrangement.slots[0].isMuted)
        #expect(arrangement.slots[2].volume == 0.35)
        arrangement.swapWithMain(2)
        #expect(arrangement.slots.map(\.id) == slots.map(\.id))
        #expect(arrangement.audibleIndex == 0)
        #expect(arrangement.targetIndex == 2)
    }

    @Test func swapLeavesUninvolvedAudioAndSelectionUnchanged() {
        var arrangement = PlaybackArrangement(slots: (0..<4).map { _ in PlaybackSlot() })
        arrangement.targetIndex = 1
        arrangement.audibleIndex = 3
        arrangement.swapWithMain(2)
        #expect(arrangement.targetIndex == 1)
        #expect(arrangement.audibleIndex == 3)
    }

    @Test(arguments: [-1, 0, 4, 99])
    func invalidSwapDoesNotChangeLayout(_ index: Int) {
        var arrangement = PlaybackArrangement(slots: (0..<4).map { _ in PlaybackSlot() })
        let ids = arrangement.slots.map(\.id)
        arrangement.swapWithMain(index)
        #expect(arrangement.slots.map(\.id) == ids)
    }
}
