import Foundation
import Observation
import AtlasCore
import AtlasPlayback
import AtlasReceiver

@MainActor @Observable
final class PlaybackStore {
    let slots = (0..<4).map { _ in PlaybackSlot() }
    var targetIndex = 0
    private(set) var audibleIndex = 0
    private(set) var isAudioMuted = false
    private(set) var volume: Double = 1
    @ObservationIgnored private var lastAudibleVolume: Double = 1
    var isMultiview = false
    var visibleCount = 4
    var error: String?
    @ObservationIgnored private var generation = UUID()

    init() { applyAudio() }

    func selectAudio(_ index: Int) {
        guard slots.indices.contains(index) else { return }
        audibleIndex = index
        applyAudio()
    }

    func toggleAudio(_ index: Int) {
        guard slots.indices.contains(index) else { return }
        if volume == 0 {
            audibleIndex = index
            volume = lastAudibleVolume
            isAudioMuted = false
        } else if audibleIndex != index {
            audibleIndex = index
            isAudioMuted = false
        } else {
            isAudioMuted.toggle()
        }
        applyAudio()
    }

    func setVolume(_ value: Double) {
        guard value.isFinite else { return }
        volume = min(max(value, 0), 1)
        if volume > 0 {
            lastAudibleVolume = volume
            isAudioMuted = false
        }
        applyAudio()
    }

    private func applyAudio() {
        // Mute every previous source before enabling the chosen source.
        for slot in slots { slot.isMuted = true; slot.volume = volume }
        slots[audibleIndex].isMuted = isAudioMuted || volume == 0
    }
    func play(_ channel: Channel, client: OpenWebifClient, profile: ReceiverProfile, password: String, index: Int? = nil) async {
        let selectedIndex = index ?? (isMultiview ? targetIndex : 0)
        guard slots.indices.contains(selectedIndex) else { return }
        let token = generation
        do {
            let url = try await client.streamURL(for: channel)
            guard token == generation, !Task.isCancelled else { return }
            slots[selectedIndex].play(url: url, channel: channel, username: profile.username, password: password)
            selectAudio(selectedIndex)
            error = nil
        } catch { self.error = error.localizedDescription }
    }
    func setMultiview(_ active: Bool) {
        isMultiview = active; targetIndex = 0
        if !active { for slot in slots.dropFirst() { slot.stop() }; selectAudio(0) }
    }
    func setCount(_ count: Int) {
        visibleCount = min(max(count, 2), 4)
        for index in visibleCount..<slots.count { slots[index].stop() }
        if audibleIndex >= visibleCount { selectAudio(0) }
        if targetIndex >= visibleCount { targetIndex = 0 }
    }
    func stopAll() { generation = UUID(); for slot in slots { slot.stop() }; error = nil; targetIndex = 0; selectAudio(0) }
}
