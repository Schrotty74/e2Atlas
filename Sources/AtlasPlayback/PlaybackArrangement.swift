import Foundation

/// Presentation order only; slots keep their engines, channels and audio state.
@MainActor
public struct PlaybackArrangement {
    public private(set) var slots: [PlaybackSlot]
    public var targetIndex = 0
    public var audibleIndex = 0

    public init(slots: [PlaybackSlot]) { self.slots = slots }

    public mutating func swapWithMain(_ index: Int) {
        guard index > 0, slots.indices.contains(index) else { return }
        slots.swapAt(0, index)
        targetIndex = movedIndex(targetIndex, exchanging: index)
        audibleIndex = movedIndex(audibleIndex, exchanging: index)
    }

    private func movedIndex(_ value: Int, exchanging index: Int) -> Int {
        if value == 0 { return index }
        if value == index { return 0 }
        return value
    }
}
